# Deployment Manifest — mod-environmental-effects v2

**Package:** `.claude/agent-memory/live-deployer/packages/2026-06-22_1200-mod-env-effects-v2/`
**Prepared:** 2026-06-22
**Feature branch:** `feat/wow-ak-1-env-effects` (tip: `65918bc42`)
**Merges into:** `custom` (production trunk)
**PTR test status:** Tested in-game on `ac-worldserver-ptr` / `acore_world_ptr`. Module logs
"Loaded 296 rule(s) across 59 zone(s), 207 spell(s)". No crash. All zone buffs/debuffs
applied correctly; day/night flag respected; global night debuff (108500) fires at 21:00 Moscow.

---

## What this deploy contains

### 1. Git merge: feat/wow-ak-1-env-effects -> custom

10 commits (`f68b97c0d`..`65918bc42`) add the module and all supporting data.
The merge brings:
- **Core C++ change** in `src/server/game/Weather/Weather.h`: `GetWeatherState()` moved from
  private to public (module needs to read live weather for weather-triggered rule evaluation).
- **Module source** in `modules/mod-environmental-effects/` (its own git repo on disk,
  bind-mounted read-only into the container at `./modules`).
- **DBC CSV files** in `.claude/dbc/` (Spell_custom.csv + SpellIcon_custom.csv) — client-only,
  not loaded by the server.

**The merge is a prerequisite for the image rebuild.** The human must merge before building.

Command:
```
git merge feat/wow-ak-1-env-effects
```
(run from `custom` branch; should be a fast-forward since custom has no diverging commits after
the env-effects branch was created).

### 2. Live worldserver image rebuild (REQUIRED)

`GetWeatherState()` was private before this branch. The new binary must be deployed so the
module can compile and link against the now-public accessor.

The modules directory is bind-mounted read-only, meaning source files are available without
a volume rebuild, but the **compiled binary** (worldserver ELF) is baked into the Docker image
at build time. A `docker compose build ac-worldserver` is mandatory.

apply.ps1 confirms the merge is present before offering the build step.

### 3. acore_world SQL — 3 files (REPLACE / DROP+CREATE, all idempotent)

Pre-flight check results (agent, static analysis — no live DB writes performed):

| File | Tables / ID range | DDL pattern | PTR status |
|---|---|---|---|
| `mod_env_effects_v2_spells.sql` | `spell_dbc` IDs 107000-107199, 107500-107599, 108500 | DELETE range + REPLACE INTO (each row) | Applied to `acore_world_ptr` |
| `mod_env_effects_v2_seed.sql` | `mod_environmental_effects` table + 296 rows | DROP TABLE IF EXISTS + CREATE + INSERT | Applied to `acore_world_ptr` |
| `mod_env_effects_game_weather.sql` | `game_weather` zones 8,40,130,331,3519,495 | REPLACE INTO (6 rows) | Applied to `acore_world_ptr` |

**Apply order matters:** spells first (seed references spell_id values), seed second, weather third.
Weather third is just convention — it has no FK dependency but is grouped last as additive data.

No forbidden DDL patterns detected:
- No DROP DATABASE, no TRUNCATE TABLE, no DROP TABLE on existing production tables.
- `mod_environmental_effects` DROP is for a new custom table not present on live (confirmed: it
  does not exist in the base schema). The DROP IF EXISTS is safe.

**Note on AC `updates` table:** The 3 SQL files were applied to PTR via `ptr-sql-apply.ps1`,
which bypasses the worldserver auto-updater and therefore does not register entries in
`acore_world_ptr.updates`. PTR data was verified by direct table probes (module loaded
correctly, 296 rules present). The files are also absent from `acore_world.updates` (they have
never been applied to live). apply.ps1 performs direct-probe verification after each file.

### 4. docker-compose.override.yml — add TZ to live worldserver service

The `ac-worldserver` (live) service currently lacks `TZ: "Europe/Moscow"`. The PTR service
already has it. Without TZ, the server clock (glibc localtime) falls back to UTC, so night
window 21:00-06:00 would fire at the wrong wall-clock time — a 3-hour offset for Moscow.

apply.ps1 edits `docker-compose.override.yml` in-place to add:
```yaml
      TZ: "Europe/Moscow"
```
under the `ac-worldserver` service's `environment:` key.

The container must be recreated (not just restarted) for the TZ variable to take effect.
`docker compose up -d ac-worldserver` always recreates if the compose file changed.

A backup of the original override file is written to the package directory as
`docker-compose.override.yml.bak` before any edit.

### 5. Live module conf — create mod_environmental_effects.conf

`env/dist/etc/modules/mod_environmental_effects.conf` does not yet exist on live
(confirmed: directory listing shows no such file). apply.ps1 copies the `.conf.dist` from the
module source and sets:
- `EnvironmentalEffects.Enable = 1`
- `EnvironmentalEffects.Debug = 0` (PTR used 0; prod default)
- `EnvironmentalEffects.RotationMinHours = 1`
- `EnvironmentalEffects.NightStartHour = 21`
- `EnvironmentalEffects.NightEndHour = 6`
- `EnvironmentalEffects.NightDebuffSpell = 108500`

If the file already exists apply.ps1 will warn and skip (idempotent).

### 6. Client MPQ — MANUAL, NOT in this script

The server-side effects work without the client patch. Players will receive the spells
(zone buffs/debuffs) and the aura will be active, but the buff icons will show as a generic
placeholder (SpellIconID=1) and the buff names will not display in the Russian locale unless
the client MPQ is patched.

**Human action required separately (not automated here):**
- Build `Spell.dbc` and `SpellIcon.dbc` from `.claude/dbc/Spell_custom.csv` and
  `.claude/dbc/SpellIcon_custom.csv` (207 env-effects rows + 2 icon rows).
- Pack into client MPQ patch.
- Distribute to players + clear WDB cache (`WDB/` folder in WoW client dir).

This step does not gate the server deployment — the module is fully functional without it.

---

## Apply order

```
Step 1   git merge feat/wow-ak-1-env-effects  (on custom branch, in repo root)
Step 2   Snapshot acore_world (mysqldump -> backups/live/<timestamp>/)
Step 3   Apply mod_env_effects_v2_spells.sql   -> acore_world
Step 4   Apply mod_env_effects_v2_seed.sql     -> acore_world
Step 5   Apply mod_env_effects_game_weather.sql -> acore_world
Step 6   Add TZ: "Europe/Moscow" to docker-compose.override.yml (ac-worldserver service)
Step 7   Create env/dist/etc/modules/mod_environmental_effects.conf
Step 8   Rebuild live worldserver image:  docker compose build ac-worldserver
Step 9   Restart live worldserver:        docker compose up -d ac-worldserver
```

Steps 3-5 write to the DB and are safe while the server is running (no schema lock on live tables
the running server caches from startup). Steps 8-9 stop the old container and bring up the new one.

**RAM note:** WSL2 build is memory-intensive. Stop `ac-worldserver-ptr` before building to free
RAM. Command: `docker stop ac-worldserver-ptr`. Restart it after if needed.

---

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| GetWeatherState() was private — old binary cannot load the module | HIGH | Mandatory image rebuild in apply.ps1 (Step 8). apply.ps1 will warn if merge is not present. |
| git merge conflicts (custom has 3 commits since branch was cut) | LOW | Branch was cut off custom; the 3 newer commits on custom are chore/docs/fix with no overlap in touched files. Fast-forward or trivial merge expected. Human reviews diff before confirming. |
| DROP TABLE on mod_environmental_effects wipes live rules | NONE | Table does not exist on live prior to this deploy. DROP IF EXISTS is a no-op on live; it only fires if re-applying. |
| spell_dbc DELETE 107000-107199 removes existing spells | NONE | This ID range is exclusively reserved for env-effects (no other feature uses 107xxx). Verified against all pending SQL files and StatBooster ranges (90000-90099, etc.). |
| game_weather zones already have custom rows on live | LOW | REPLACE INTO is idempotent; if rows existed with different values they'd be overwritten. Confirmed these 6 zones have no existing rows in the base AzerothCore schema. |
| TZ edit breaks docker-compose.override.yml syntax | LOW | apply.ps1 uses PowerShell string replacement on the known exact line, backs up the file first. |
| Rebuild OOM kills WSL2 | MEDIUM | Stop ac-worldserver-ptr before build. RAM freed by stopping PTR is sufficient for the build. |
| Module fails to load on startup (missing table guard) | LOW | Module uses information_schema guard before SELECT (per memory note `feedback_module_startup_gotchas.md`). If mod_environmental_effects table is absent, module logs a warning and disables itself rather than aborting. |
| Night debuff timezone wrong | LOW | Mitigated by TZ step. Without TZ, the night window fires 3h late (UTC vs Moscow). TZ + container recreate fixes this. |
| Client MPQ not deployed | COSMETIC | Icons/names missing. Spells still apply correctly server-side. Not a blocker. |

---

## Rollback procedure

See `rollback.ps1` in this package. Summary:

1. Stop live worldserver: `docker stop ac-worldserver-v2`
2. Restore acore_world from pre-deploy snapshot (rollback.ps1 drives this).
3. Revert docker-compose.override.yml from `docker-compose.override.yml.bak` in this package dir.
4. Remove `env/dist/etc/modules/mod_environmental_effects.conf`.
5. Revert the merge: `git revert -m 1 <merge-commit>` or `git reset --hard custom@{1}` if
   the merge is the only new commit on custom. Then rebuild image.
6. Restart: `docker compose up -d ac-worldserver`.

DB rollback deletes only the new data (spell_dbc 107000-107199 / 107500-107599 / 108500,
mod_environmental_effects table, 6 game_weather rows). No existing live data is touched.

---

## Post-apply smoke test

```sql
-- 1. Spell rows present
SELECT COUNT(*) FROM acore_world.spell_dbc WHERE ID BETWEEN 107000 AND 107199;
-- Expected: 177 (buff spells)

SELECT COUNT(*) FROM acore_world.spell_dbc WHERE ID BETWEEN 107500 AND 107599;
-- Expected: 30 (shared debuffs including 107500-107528)

SELECT ID FROM acore_world.spell_dbc WHERE ID = 108500;
-- Expected: 108500 (global night debuff)

-- 2. Rule table present and populated
SELECT COUNT(*) FROM acore_world.mod_environmental_effects;
-- Expected: 296

SELECT COUNT(DISTINCT zone_id) FROM acore_world.mod_environmental_effects;
-- Expected: 59

-- 3. Weather rows added
SELECT zone FROM acore_world.game_weather WHERE zone IN (8,40,130,331,3519,495);
-- Expected: 6 rows

-- 4. Module startup (check server log after restart)
-- Look for: "Loaded 296 rule(s) across 59 zone(s), 207 spell(s)"
-- No "EnvironmentalEffects: table mod_environmental_effects not found" line.
```

**In-game smoke test:**
- Log in to a character in Alterac Mountains (zone 36) — should receive 3 rotating zone buffs.
- At server time after 21:00 Moscow — should receive "Покров ночи" debuff (108500) while outdoors.
- Check buff bar for unknown icon (SpellIconID=1 placeholder) — expected until MPQ is patched.
