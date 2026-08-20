"""mod-environmental-effects: rule reading, validation and writing.

Schema (acore_world_ptr.mod_environmental_effects):
    zone_id, kind (0 buff / 1 debuff), slot, spell_id, trigger_type, time_flag, enabled

Semantics mirror src/EnvironmentalEffectsScript.cpp exactly:
  * buffs  ignore trigger_type
  * debuffs use trigger_type, see TRIGGER_LABELS (0 permanent, 1 rain, 2 snow,
    3 sand, 4 fog, 5 thunderstorm, 6 black rain, 7 black snow).
    Every weather state matches EXACTLY ONE trigger: a thunderstorm is not rain
    and black snow is not snow - separate effects with separate pools.
  * time_flag (0 any / 1 day-only / 2 night-only) applies to BOTH kinds: a
    debuff can be tied to the weather, to the time of day, or to both. 0 is the
    default, so a rule that says nothing about time works around the clock.
  * zone_id = 0 is the GLOBAL pool, not a zone. Its rules stand in per bucket
    (permanent / one weather / buffs), and buckets are matched at the CURRENT
    time of day, for zones that have no rule of their own in that bucket. The zone always wins; nothing is
    mixed. A zone with no rows at all gets nothing - globals do not opt it in.
  * only rows with enabled = 1 are loaded by the server
"""

from pydantic import BaseModel, Field

from . import dbc
from .db import cursor, query

TABLE = "mod_environmental_effects"

KIND_BUFF, KIND_DEBUFF = 0, 1

# zone_id 0 - не зона, а глобальный пул (см. модульный docstring).
GLOBAL_ZONE = 0
GLOBAL_NAME = "Глобальные правила"

TRIGGER_LABELS = {
    0: "Всегда",
    1: "Дождь",
    2: "Снег",
    3: "Песчаная буря",
    4: "Туман",
    5: "Гроза",
    6: "Чёрный дождь",
    7: "Чёрный снег",
}

# Триггеры, которых ядро не генерирует ВООБЩЕ: Weather::ReGenerate выбирает
# только дождь, снег и песчаную бурю по шансам game_weather. Туман, гроза и
# «порченые» осадки ставились удалённым mod-weather; теперь их может выставить
# только ручная команда (.rc weather / .weather) — то есть в норме такие
# правила молчат.
WEATHER_MODULE_TRIGGERS = {4, 5, 6, 7}

# Погода, которая раньше «считалась» другим триггером, а теперь отдельный
# эффект: {узкий: из чего он выделен}. Нужно только для подсказки в валидации -
# ядро эти связи не знает.
TRIGGER_SPLIT_FROM = {5: 1, 6: 1, 7: 2}
TIME_LABELS = {0: "Любое время", 1: "Только днём", 2: "Только ночью"}

# The rotation model is built around three slots per pool. More is not a hard
# error (the core just picks from a larger pool), so this is a warning bound.
RECOMMENDED_SLOTS = 3


class Rule(BaseModel):
    spell_id: int = Field(ge=1)
    trigger_type: int = Field(default=0, ge=0, le=7)
    time_flag: int = Field(default=0, ge=0, le=2)
    enabled: bool = True


class ZoneRules(BaseModel):
    buffs: list[Rule] = Field(default_factory=list)
    debuffs: list[Rule] = Field(default_factory=list)


class ValidationProblem(BaseModel):
    level: str  # "error" | "warning"
    message: str


# --- reading --------------------------------------------------------------

def zone_label(zone_id: int) -> str:
    return GLOBAL_NAME if zone_id == GLOBAL_ZONE else dbc.zone_name(zone_id)


def global_rules() -> dict:
    """The zone 0 pool as the server sees it (enabled rows only)."""
    rows = query(
        f"SELECT kind, spell_id, trigger_type, time_flag FROM `{TABLE}`"
        f" WHERE zone_id = %s AND enabled = 1", (GLOBAL_ZONE,))
    return {
        "buffs": [r for r in rows if int(r["kind"]) == KIND_BUFF],
        "debuffs": [r for r in rows if int(r["kind"]) == KIND_DEBUFF],
    }


def zone_summaries() -> list[dict]:
    rows = query(
        f"SELECT zone_id,"
        f" SUM(kind = 0) AS buffs,"
        f" SUM(kind = 1) AS debuffs,"
        f" SUM(enabled = 0) AS disabled"
        f" FROM `{TABLE}` GROUP BY zone_id")
    out = [{
        "zone_id": int(r["zone_id"]),
        "name": zone_label(int(r["zone_id"])),
        "global": int(r["zone_id"]) == GLOBAL_ZONE,
        "buffs": int(r["buffs"] or 0),
        "debuffs": int(r["debuffs"] or 0),
        "disabled": int(r["disabled"] or 0),
    } for r in rows]
    # Глобальный пул - всегда первым: он читается как «умолчание» для остальных.
    out.sort(key=lambda z: (not z["global"], z["name"]))
    return out


def zone_rules(zone_id: int) -> dict:
    rows = query(
        f"SELECT kind, slot, spell_id, trigger_type, time_flag, enabled"
        f" FROM `{TABLE}` WHERE zone_id = %s ORDER BY kind, slot", (zone_id,))
    buffs, debuffs = [], []
    for r in rows:
        rule = {
            "spell_id": int(r["spell_id"]),
            "trigger_type": int(r["trigger_type"]),
            "time_flag": int(r["time_flag"]),
            "enabled": bool(r["enabled"]),
            "spell": dbc.describe(int(r["spell_id"])),
        }
        (buffs if int(r["kind"]) == KIND_BUFF else debuffs).append(rule)
    return {
        "zone_id": zone_id,
        "name": zone_label(zone_id),
        "global": zone_id == GLOBAL_ZONE,
        "buffs": buffs,
        "debuffs": debuffs,
    }


def known_spell_ids() -> set[int]:
    """Spell ids that actually exist in spell_dbc.

    LoadRules() skips any row whose spell has no SpellInfo, so a rule pointing at
    a missing id is silently dead. The panel refuses to create one.
    """
    rows = query("SELECT ID FROM spell_dbc WHERE ID BETWEEN %s AND %s",
                 (dbc.BUFF_RANGE[0], dbc.NIGHT_SPELL))
    return {int(r["ID"]) for r in rows}


def spell_catalog() -> list[dict]:
    """Every env-effect spell the panel can offer, with existence flags."""
    known = known_spell_ids()
    meta = dbc.spell_meta()
    ids = sorted(set(meta) | {i for i in known if dbc.kind_of(i) is not None})
    used = {int(r["spell_id"]): int(r["n"]) for r in query(
        f"SELECT spell_id, COUNT(*) AS n FROM `{TABLE}` GROUP BY spell_id")}
    out = []
    for sid in ids:
        if dbc.kind_of(sid) is None:
            continue
        item = dbc.describe(sid)
        item["in_spell_dbc"] = sid in known
        item["used_by_rules"] = used.get(sid, 0)
        out.append(item)
    return out


# --- validation -----------------------------------------------------------

def validate(zone_id: int, payload: ZoneRules) -> list[ValidationProblem]:
    problems: list[ValidationProblem] = []
    known = known_spell_ids()
    is_global = zone_id == GLOBAL_ZONE
    # Что уже закрыто глобальным пулом — чтобы не пугать зону дырой, которую
    # подставит zone 0. При правке самого zone 0 сравнивать не с чем.
    globals_ = {"buffs": [], "debuffs": []} if is_global else global_rules()

    if zone_id < 0:
        problems.append(ValidationProblem(
            level="error", message="zone_id не может быть отрицательным."))
    elif not is_global and zone_id not in dbc.zone_names():
        problems.append(ValidationProblem(
            level="warning",
            message=f"Зона {zone_id} не найдена в AreaTable как зона верхнего "
                    f"уровня. Правила для под-области никогда не сработают."))

    for kind, rules, label in ((KIND_BUFF, payload.buffs, "бафф"),
                               (KIND_DEBUFF, payload.debuffs, "дебафф")):
        seen: set[int] = set()
        for idx, rule in enumerate(rules):
            where = f"{label} #{idx + 1} (спелл {rule.spell_id})"

            if rule.spell_id in seen:
                problems.append(ValidationProblem(
                    level="error",
                    message=f"{where}: дубль в том же пуле — ротация выбирает "
                            f"по спеллу, дубль просто удваивает шанс."))
            seen.add(rule.spell_id)

            if rule.spell_id not in known:
                problems.append(ValidationProblem(
                    level="error",
                    message=f"{where}: нет строки в spell_dbc, сервер пропустит "
                            f"правило при загрузке."))

            # 108500 модуль и так вешает сам — глобально, ночью, поверх
            # дебаффа зоны (NightDebuffSpell). Как строка пула он попадёт в
            # ротацию и будет висеть в том числе днём.
            if rule.spell_id == dbc.NIGHT_SPELL:
                problems.append(ValidationProblem(
                    level="warning",
                    message=f"{where}: это ночной дебафф NightDebuffSpell — "
                            f"модуль вешает его сам, ночью и во всех зонах. "
                            f"Правилом пула он будет висеть и днём."))

            block = dbc.kind_of(rule.spell_id)
            if block is None:
                problems.append(ValidationProblem(
                    level="warning",
                    message=f"{where}: id вне блоков модуля "
                            f"({dbc.BUFF_RANGE[0]}-{dbc.BUFF_RANGE[1]} баффы, "
                            f"{dbc.DEBUFF_RANGE[0]}-{dbc.DEBUFF_RANGE[1]} дебаффы)."))
            elif block != kind:
                other = "дебаффов" if block == KIND_DEBUFF else "баффов"
                problems.append(ValidationProblem(
                    level="warning",
                    message=f"{where}: id из блока {other}."))

            if kind == KIND_BUFF and rule.trigger_type != 0:
                problems.append(ValidationProblem(
                    level="warning",
                    message=f"{where}: у баффов trigger_type игнорируется ядром."))

        active = [r for r in rules if r.enabled]

        # Слоты считаются ПО КОРЗИНАМ: ротация выбирает не из всего пула, а из
        # той его части, что подходит текущим условиям: погоде И времени суток
        # для дебаффов, времени суток для баффов. Три дебаффа на дождь и три на
        # снег — это норма.
        if kind == KIND_DEBUFF:
            # Корзина дебаффа - это пара (погода, время суток): «дождь днём» и
            # «дождь ночью» выбираются независимо друг от друга.
            for tod, when in ((1, "днём"), (2, "ночью")):
                buckets: dict[int, list] = {}
                for r in active:
                    if r.time_flag in (0, tod):
                        buckets.setdefault(r.trigger_type, []).append(r)
                for trig, group in sorted(buckets.items()):
                    if len(group) > RECOMMENDED_SLOTS:
                        problems.append(ValidationProblem(
                            level="warning",
                            message=f"дебаффов «{TRIGGER_LABELS.get(trig, trig)}»,"
                                    f" доступных {when}, активно {len(group)} — "
                                    f"модель рассчитана на {RECOMMENDED_SLOTS}. "
                                    f"Работать будет, ротация просто шире."))
        else:
            for tod, when in ((1, "днём"), (2, "ночью")):
                group = [r for r in active if r.time_flag in (0, tod)]
                if len(group) > RECOMMENDED_SLOTS:
                    problems.append(ValidationProblem(
                        level="warning",
                        message=f"баффов, доступных {when}, активно {len(group)} "
                                f"— модель рассчитана на {RECOMMENDED_SLOTS}. "
                                f"Работать будет, ротация просто шире."))

        # Дебафф тоже можно запереть во времени - и так же случайно оставить
        # корзину пустой на вторую половину суток.
        if kind == KIND_DEBUFF and active:
            globals_by_trigger: dict[int, set] = {}
            for g in globals_["debuffs"]:
                globals_by_trigger.setdefault(int(g["trigger_type"]), set()).add(
                    int(g["time_flag"]))
            by_trigger: dict[int, list] = {}
            for r in active:
                by_trigger.setdefault(r.trigger_type, []).append(r)
            for trig, group in sorted(by_trigger.items()):
                for tod, when, other in ((1, "только днём", "ночью"),
                                         (2, "только ночью", "днём")):
                    if not all(r.time_flag == tod for r in group):
                        continue
                    label = TRIGGER_LABELS.get(trig, trig)
                    # 3 - tod даёт противоположный флаг: 1 <-> 2.
                    covered = bool(globals_by_trigger.get(trig, set())
                                   & {0, 3 - tod})
                    if is_global:
                        tail = f"{other} подставлять зонам будет нечего."
                    elif covered:
                        tail = f"{other} подставится глобальный дебафф."
                    else:
                        tail = (f"{other} дебаффа в такую погоду не будет вовсе — "
                                f"глобальный пул эту дыру не закрывает.")
                    problems.append(ValidationProblem(
                        level="warning",
                        message=f"все дебаффы «{label}» помечены «{when}» — {tail}"))

        if kind == KIND_BUFF and active:
            for tod, when, other in ((1, "днём", "ночью"), (2, "ночью", "днём")):
                if not all(r.time_flag == tod for r in active):
                    continue
                # 3 - tod даёт противоположный флаг: 1 <-> 2.
                covered = any(int(g["time_flag"]) in (0, 3 - tod)
                              for g in globals_["buffs"])
                if is_global:
                    problems.append(ValidationProblem(
                        level="warning",
                        message=f"все глобальные баффы помечены «только {when}» "
                                f"— {other} подставлять зонам будет нечего."))
                elif covered:
                    problems.append(ValidationProblem(
                        level="warning",
                        message=f"все баффы зоны помечены «только {when}» — "
                                f"{other} подставится глобальный бафф."))
                else:
                    problems.append(ValidationProblem(
                        level="warning",
                        message=f"все баффы помечены «только {when}» — {other} "
                                f"в зоне не будет ни одного баффа, и глобальный "
                                f"пул эту дыру не закрывает."))

    weather_triggers = {r.trigger_type for r in payload.debuffs
                        if r.enabled and r.trigger_type != 0}

    if weather_triggers and not is_global:
        has_weather = query(
            "SELECT 1 FROM game_weather WHERE zone = %s LIMIT 1", (zone_id,))
        if not has_weather:
            problems.append(ValidationProblem(
                level="warning",
                message=f"У зоны {zone_id} нет строки в game_weather — погодные "
                        f"дебаффы никогда не сработают. См. "
                        f"mod_env_effects_game_weather.sql."))

    # Триггеры 4-7 ядро не генерирует само (см. WEATHER_MODULE_TRIGGERS):
    # раньше их ставил mod-weather, теперь остались только ручные команды.
    module_triggers = weather_triggers & WEATHER_MODULE_TRIGGERS
    if module_triggers:
        names = ", ".join(TRIGGER_LABELS[t] for t in sorted(module_triggers))
        problems.append(ValidationProblem(
            level="warning",
            message=f"Ядро такую погоду не генерирует: триггеры {names} "
                    f"сработают только если состояние выставить вручную "
                    f"(RemoteControlUI / .weather). Само по себе такое "
                    f"правило молчит."))

    # Гроза больше не «сильный дождь»: у каждого состояния погоды ровно один
    # триггер. Значит правило «Дождь» в грозу молчит — и если ни у зоны, ни в
    # глобальном пуле нет грозового правила, дебаффа в грозу не будет вовсе.
    if not is_global:
        global_triggers = {int(g["trigger_type"]) for g in globals_["debuffs"]}
        for narrow, wide in TRIGGER_SPLIT_FROM.items():
            if wide not in weather_triggers:
                continue
            if narrow in weather_triggers or narrow in global_triggers:
                continue
            problems.append(ValidationProblem(
                level="warning",
                message=f"«{TRIGGER_LABELS[narrow]}» — отдельный эффект, а не "
                        f"разновидность «{TRIGGER_LABELS[wide]}»: в такую погоду "
                        f"правило «{TRIGGER_LABELS[wide]}» не сработает. Заведите "
                        f"правило «{TRIGGER_LABELS[narrow]}» здесь или в "
                        f"глобальном пуле."))

    return problems


# --- writing --------------------------------------------------------------

def save_zone(zone_id: int, payload: ZoneRules) -> int:
    """Replace every rule of a zone in one transaction. Returns rows written."""
    rows = []
    for kind, rules in ((KIND_BUFF, payload.buffs), (KIND_DEBUFF, payload.debuffs)):
        for slot, rule in enumerate(rules):
            rows.append((
                zone_id, kind, slot, rule.spell_id,
                rule.trigger_type if kind == KIND_DEBUFF else 0,
                rule.time_flag,
                1 if rule.enabled else 0,
            ))

    with cursor(commit=True) as cur:
        cur.execute(f"DELETE FROM `{TABLE}` WHERE zone_id = %s", (zone_id,))
        if rows:
            cur.executemany(
                f"INSERT INTO `{TABLE}`"
                f" (zone_id, kind, slot, spell_id, trigger_type, time_flag, enabled)"
                f" VALUES (%s, %s, %s, %s, %s, %s, %s)", rows)
    return len(rows)


def delete_zone(zone_id: int) -> int:
    with cursor(commit=True) as cur:
        return cur.execute(f"DELETE FROM `{TABLE}` WHERE zone_id = %s", (zone_id,))


def all_rules() -> list[dict]:
    return query(
        f"SELECT zone_id, kind, slot, spell_id, trigger_type, time_flag, enabled"
        f" FROM `{TABLE}` ORDER BY zone_id, kind, slot")
