"""Export the live PTR rule table back into the tracked SQL migration.

The panel owns data/sql/updates/pending_db_world/mod_env_effects_v2_seed.sql, so
every edit ends up in git rather than only in the PTR database.

The file is written atomically (temp file + replace) so a crash mid-write cannot
leave a truncated migration behind.
"""

import os
import tempfile
from datetime import datetime, timezone

from . import config, envfx

_HEADER = """\
-- mod-environmental-effects v2 — rule table (rotation schema) + rules
--
-- SOURCE OF TRUTH: the admin panel (tools/admin-panel). Rules are edited live in
-- {schema}.mod_environmental_effects and exported back to this file.
-- Do not hand-edit; re-export from the panel instead.
-- scripts/gen_spells.py --seed can rebuild it from docs/, discarding panel edits.
--
-- Exported {stamp} — {rows} rule(s) across {zones} zone(s).
--
-- zone_id = 0 is not a zone: it is the GLOBAL pool, used for zones that have no
-- rule of their own in that bucket (permanent / one weather state / buffs of the
-- current time of day). See modules/mod-environmental-effects/docs/DESIGN.md §2.

CREATE TABLE IF NOT EXISTS `mod_environmental_effects` (
  `id`          INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  `zone_id`     INT UNSIGNED     NOT NULL,
  `kind`        TINYINT UNSIGNED NOT NULL              COMMENT '0=buff, 1=debuff',
  `slot`        TINYINT UNSIGNED NOT NULL              COMMENT 'rotation slot within zone+kind',
  `spell_id`    INT UNSIGNED     NOT NULL,
  `trigger_type` TINYINT UNSIGNED NOT NULL DEFAULT 0   COMMENT '0=always, 1=rain, 2=snow, 3=sand, 4=fog, 5=thunder, 6=black rain, 7=black snow',
  `time_flag`   TINYINT UNSIGNED NOT NULL DEFAULT 0    COMMENT '0=any, 1=day-only, 2=night-only',
  `enabled`     TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `idx_zone` (`zone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='mod-environmental-effects rotation rules (v2)';

DELETE FROM `mod_environmental_effects`;
"""


def build_sql() -> tuple[str, int, int]:
    rows = envfx.all_rules()
    zones = {int(r["zone_id"]) for r in rows}
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    parts = [_HEADER.format(schema=config.DB_NAME, stamp=stamp,
                            rows=len(rows), zones=len(zones))]
    if rows:
        parts.append("INSERT INTO `mod_environmental_effects`")
        parts.append("    (`zone_id`,`kind`,`slot`,`spell_id`,`trigger_type`,"
                     "`time_flag`,`enabled`) VALUES")
        values = [
            "    ({zone_id},{kind},{slot},{spell_id},{trigger_type},"
            "{time_flag},{enabled})".format(**{k: int(v) for k, v in r.items()})
            for r in rows
        ]
        parts.append(",\n".join(values) + ";")
    return "\n".join(parts) + "\n", len(rows), len(zones)


def write() -> dict:
    sql, n_rows, n_zones = build_sql()
    path = config.SEED_SQL
    directory = os.path.dirname(path)
    if not os.path.isdir(directory):
        raise FileNotFoundError(
            f"{directory} is not mounted — the repo must be bind-mounted at "
            f"{config.REPO_ROOT} for export to work.")

    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".export-", suffix=".sql")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
            f.write(sql)
        os.replace(tmp, path)
    except Exception:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise

    return {"path": path, "rows": n_rows, "zones": n_zones}
