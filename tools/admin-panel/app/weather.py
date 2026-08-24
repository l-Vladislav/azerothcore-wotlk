"""mod-advanced-weather: live weather control.

Unlike the other editors this one owns no table: the module keeps weather in
memory on purpose (see modules/mod-advanced-weather/README.md). So the panel
talks to the running worldserver over SOAP with the module's own `.aw` protocol
and parses the `AW:` lines it answers with:

    AW:ZONE:<zone>:<state>:<grade%>:<source>:<secondsLeft>:<hasClimate>
            :<hasPlayers>:<originZone>:<linkStrength>

The zone list itself comes from AreaTable, not from the server: weather can be
set in any zone, and `.aw list` only knows the ones the director has touched.
`game_weather` is read for one thing — the climate the director rolls against.

One table it does own: `mod_advanced_weather_zone_link`, the zone links. Those
are not live state but a setting, so they live in the database and the module
re-reads them on `.aw linkreload`. The panel writes the table and sends that
command; everything else on this page still goes through SOAP.
"""

import datetime
import re

from pydantic import BaseModel, Field

from . import dbc, soap
from .db import cursor, query

# WeatherState (src/server/game/Weather/Weather.h). Numbers are the client's,
# not a dense enum — do not renumber. 91 is the exception: it is not in
# Weather.h at all but a stock Weather.dbc row that our patch-MPQ re-points at
# a rain-with-thunder loop, owned by AdvancedWeather::WEATHER_STATE_STORM.
STATES: list[dict] = [
    {"id": 0,   "label": "Ясно",              "group": "clear"},
    {"id": 1,   "label": "Туман",             "group": "clear"},
    {"id": 3,   "label": "Слабый дождь",      "group": "rain"},
    {"id": 4,   "label": "Дождь",             "group": "rain"},
    {"id": 5,   "label": "Ливень",            "group": "rain"},
    {"id": 6,   "label": "Слабый снег",       "group": "snow"},
    {"id": 7,   "label": "Снег",              "group": "snow"},
    {"id": 8,   "label": "Метель",            "group": "snow"},
    {"id": 22,  "label": "Слабая песчаная буря", "group": "storm"},
    {"id": 41,  "label": "Песчаная буря",     "group": "storm"},
    {"id": 42,  "label": "Сильная песчаная буря", "group": "storm"},
    {"id": 91,  "label": "Гроза",             "group": "special"},
    {"id": 90,  "label": "Чёрный дождь",      "group": "special"},
    {"id": 106, "label": "Чёрный снег",       "group": "special"},
]

STATE_BY_ID = {s["id"]: s for s in STATES}

# Состояния, которые ядро не генерирует само: они существуют только пока ими
# распоряжается модуль. Совпадают с триггерами 4-7 mod-environmental-effects.
MODULE_ONLY = {1, 90, 91, 106}

SOURCES = {
    0: "режиссёр",
    1: "вручную",
    2: "закреплено",
    3: "по связи",
}

# Протокол, который панель умеет читать. Меньший номер = worldserver не
# пересобран: строка зоны придёт без полей связи, и страница обойдётся без них.
PROTOCOL = "3"

# Ниже 0.27 клиент показывает «ясно» независимо от состояния
# (Weather::GetWeatherState), поэтому ползунок в UI начинается с 30%.
GRADE_MIN_PCT = 30

# --- world zones ----------------------------------------------------------
# Погода имеет смысл только под открытым небом. AreaTable даёт 100+ зон
# верхнего уровня, но большая часть из них — подземелья, рейды, арены, моря,
# служебные и «НЕ ИСПОЛЬЗУЕТСЯ» заглушки: ставить там погоду можно, увидеть её
# нельзя. Поэтому список курируемый, а не вычисляемый.
#
# Группировка — географическая, а не по MapID: Кель'Талас и Остров Лазурной
# Дымки лежат на карте 530 (Запределье), но игрок считает их Восточными
# королевствами и Калимдором. Порядок внутри группы — как в списке ниже,
# сортировка идёт по имени уже на этапе выдачи.

CONTINENTS: list[dict] = [
    {
        "key": "ek",
        "name": "Восточные королевства",
        "zones": [
            # Черной горы тут нет намеренно: это подгорный интерьер, погоды
            # в нём не видно.
            12, 40, 10, 33, 51, 8, 4, 3, 46, 44, 41,
            1, 38, 11, 269, 47, 45, 36, 267,
            85, 130, 28, 139,
            1519, 1537, 1497,
            # Кель'Талас: DBC держит его на карте Запределья.
            3430, 3433, 3487, 4080,
        ],
    },
    {
        "key": "kalimdor",
        "name": "Калимдор",
        "zones": [
            141, 148, 331, 405, 406, 357, 361, 493, 16, 618,
            215, 14, 17, 400, 15, 440, 490, 1377,
            1637, 1638, 1657,
            # Дренейский старт: тоже карта 530, но континент — Калимдор.
            3524, 3525, 3557,
        ],
    },
    {
        "key": "outland",
        "name": "Запределье",
        "zones": [3483, 3521, 3519, 3518, 3520, 3522, 3523, 3703],
    },
    {
        "key": "northrend",
        "name": "Нордскол",
        "zones": [
            3537, 495, 394, 65, 66, 3711, 67, 2817, 210, 4742,
            4197, 4395,
        ],
    },
]

# Континент по зоне + порядок групп в UI.
ZONE_CONTINENT: dict[int, str] = {
    zone_id: c["key"] for c in CONTINENTS for zone_id in c["zones"]
}
CONTINENT_NAMES: dict[str, str] = {c["key"]: c["name"] for c in CONTINENTS}

# Зона вне списка, которую режиссёр всё-таки ведёт (закреплена вручную,
# осталась с прошлой версии панели): прятать её нельзя — иначе её не отпустить.
OTHER_KEY = "other"
OTHER_NAME = "Прочее (вне мира)"


# Последние два поля (зона-источник и сила связи) приехали с протоколом 3:
# на непересобранном worldserver'е их нет, и строка всё равно должна читаться.
_ZONE_RE = re.compile(
    r"^AW:ZONE:(\d+):(\d+):(\d+):(\d+):(-?\d+):(\d+):(\d+)(?::(\d+):(\d+))?$")
_LINK_RE = re.compile(r"^AW:LINK:(\d+):(\d+):(\d+):(\d+)$")
_ERR_RE = re.compile(r"^AW:ERR:([A-Z]+)$")
_HELLO_RE = re.compile(r"^AW:HELLO:(\d+):(\d+)$")

ERRORS = {
    "DISABLED": "Модуль выключен: AdvancedWeather.Enable = 0.",
    "BADARG": "Сервер не принял аргументы команды.",
    "NOZONE": "Не указана зона.",
    "WEATHEROFF": "Погода отключена в конфиге сервера (Weather.Enabled).",
}


class WeatherError(RuntimeError):
    pass


class SetPayload(BaseModel):
    state: int = Field(ge=0, le=106)
    grade: int = Field(default=80, ge=0, le=100)
    # 0 = держать AdvancedWeather.ManualHoldMinutes из конфига модуля.
    minutes: int = Field(default=0, ge=0, le=1440)


# --- protocol -------------------------------------------------------------

def _run(command: str) -> list[str]:
    """Execute a `.aw` command; return its lines, raising on AW:ERR."""
    out = soap.execute(command)
    lines = [ln.strip() for ln in out.splitlines() if ln.strip()]
    for line in lines:
        err = _ERR_RE.match(line)
        if err:
            code = err.group(1)
            raise WeatherError(ERRORS.get(code, f"Сервер ответил AW:ERR:{code}."))
    return lines


def _parse_zone(line: str) -> dict | None:
    m = _ZONE_RE.match(line)
    if not m:
        return None
    zone_id, state, grade, source, left, climate, players = (
        int(g) for g in m.groups()[:7])
    origin = int(m.group(8) or 0)
    origin_strength = int(m.group(9) or 0)
    meta = STATE_BY_ID.get(state, {"label": f"Состояние {state}", "group": "?"})
    return {
        "zone_id": zone_id,
        "name": dbc.zone_name(zone_id),
        "state": state,
        "state_label": meta["label"],
        "state_group": meta["group"],
        "grade": grade,
        "source": source,
        "source_label": SOURCES.get(source, str(source)),
        "seconds_left": max(0, left),
        "has_climate": bool(climate),
        "module_only": state in MODULE_ONLY,
        # known - режиссёр эту зону ведёт (или вёл); players - в ней сейчас
        # кто-то есть. Погода без игроков существует как решение, но не как
        # пакет: она уедет в мир, когда туда придут.
        "known": True,
        "players": bool(players),
        # Погода, принесённая связью: зона-источник и её сила. 0 = своя.
        "origin": origin,
        "origin_name": dbc.zone_name(origin) if origin else None,
        "origin_strength": origin_strength,
    }


def _zone_lines(lines: list[str]) -> list[dict]:
    return [z for z in (_parse_zone(ln) for ln in lines) if z]


# --- reading --------------------------------------------------------------

def hello() -> dict:
    """Is the module there, and is it switched on?"""
    for line in _run("aw hello"):
        m = _HELLO_RE.match(line)
        if m:
            return {"ok": True, "protocol": m.group(1),
                    "enabled": m.group(2) == "1"}
    # Ядро отвечает на неизвестную команду списком доступных подкоманд.
    raise WeatherError("Worldserver не знает команду .aw — модуль не собран "
                       "или worldserver не перезапущен после сборки.")


def climate_zones() -> dict[int, dict]:
    """Zones with a `game_weather` row, i.e. what the director can roll for."""
    rows = query(
        "SELECT zone,"
        " spring_rain_chance, spring_snow_chance, spring_storm_chance,"
        " summer_rain_chance, summer_snow_chance, summer_storm_chance,"
        " fall_rain_chance, fall_snow_chance, fall_storm_chance,"
        " winter_rain_chance, winter_snow_chance, winter_storm_chance"
        " FROM game_weather")
    out: dict[int, dict] = {}
    for r in rows:
        zone_id = int(r["zone"])
        out[zone_id] = {
            "zone_id": zone_id,
            "name": dbc.zone_name(zone_id),
            "seasons": {
                season: {
                    "rain": int(r[f"{season}_rain_chance"]),
                    "snow": int(r[f"{season}_snow_chance"]),
                    "storm": int(r[f"{season}_storm_chance"]),
                }
                for season in ("spring", "summer", "fall", "winter")
            },
        }
    return out


def overview() -> dict:
    """Открытые зоны мира, сгруппированные по континентам.

    Список — курируемый CONTINENTS, а не AreaTable целиком: под крышей
    подземелья и на арене погоды не видно, а «НЕ ИСПОЛЬЗУЕТСЯ»-заглушек в
    AreaTable больше, чем настоящих зон. Зона, которую ведёт режиссёр, но
    которой нет в списке, всё равно показывается — в группе «Прочее», иначе её
    нельзя было бы отпустить.
    """
    status = hello()
    known = {z["zone_id"]: z for z in _zone_lines(_run("aw list"))}
    climates = climate_zones()
    names = dbc.zone_names()
    counts = link_counts()

    def blank(zone_id: int) -> dict:
        return {
            "zone_id": zone_id,
            "state": 0,
            "state_label": STATE_BY_ID[0]["label"],
            "state_group": "clear",
            "grade": 0,
            "source": 0,
            "source_label": SOURCES[0],
            "seconds_left": 0,
            "has_climate": zone_id in climates,
            "module_only": False,
            "known": False,
            "players": False,
            # Те же поля, что и у зоны, которую режиссёр ведёт: страница не
            # должна гадать, есть они в строке или нет.
            "origin": 0,
            "origin_name": None,
            "origin_strength": 0,
        }

    zones: list[dict] = []
    for continent in CONTINENTS:
        for zone_id in continent["zones"]:
            row = known.pop(zone_id, None) or blank(zone_id)
            row["name"] = names.get(zone_id, f"Зона {zone_id}")
            row["continent"] = continent["key"]
            row["continent_name"] = continent["name"]
            climate = climates.get(zone_id)
            row["seasons"] = climate["seasons"] if climate else None
            row["links_out"], row["links_in"] = counts.get(zone_id, (0, 0))
            zones.append(row)

    for zone_id, row in known.items():
        row["name"] = names.get(zone_id, f"Зона {zone_id}")
        row["continent"] = OTHER_KEY
        row["continent_name"] = OTHER_NAME
        climate = climates.get(zone_id)
        row["seasons"] = climate["seasons"] if climate else None
        row["links_out"], row["links_in"] = counts.get(zone_id, (0, 0))
        zones.append(row)

    zones.sort(key=lambda z: z["name"])

    groups = [{"key": c["key"], "name": c["name"]} for c in CONTINENTS]
    if any(z["continent"] == OTHER_KEY for z in zones):
        groups.append({"key": OTHER_KEY, "name": OTHER_NAME})

    return {
        "module": status,
        "protocol_expected": PROTOCOL,
        "states": STATES,
        "sources": SOURCES,
        "grade_min": GRADE_MIN_PCT,
        "module_only": sorted(MODULE_ONLY),
        "continents": groups,
        "zones": zones,
        # Сезон нужен карточке зоны: в таблице климата помечается та строка,
        # по которой режиссёр катает погоду сегодня.
        "season": current_season(),
        "live_count": sum(1 for z in zones if z["players"]),
        "known_count": sum(1 for z in zones if z["known"]),
        "link_count": sum(z["links_out"] for z in zones),
        "links_table": bool(counts) or link_table_exists(),
    }


def zone(zone_id: int) -> dict:
    lines = _run(f"aw status {zone_id}")
    parsed = _zone_lines(lines)
    if not parsed:
        raise WeatherError("Сервер не ответил строкой AW:ZONE.")
    return parsed[0]


# --- writing --------------------------------------------------------------

def set_weather(zone_id: int, payload: SetPayload) -> dict:
    if payload.state not in STATE_BY_ID:
        raise WeatherError(f"Неизвестное состояние погоды: {payload.state}.")

    grade = payload.grade
    if payload.state != 0:
        grade = max(grade, GRADE_MIN_PCT)

    lines = _run(f"aw set {zone_id} {payload.state} {grade} {payload.minutes}")
    parsed = _zone_lines(lines)
    return parsed[0] if parsed else zone(zone_id)


def pin(zone_id: int) -> dict:
    parsed = _zone_lines(_run(f"aw pin {zone_id}"))
    return parsed[0] if parsed else zone(zone_id)


def release(zone_id: int) -> dict:
    parsed = _zone_lines(_run(f"aw release {zone_id}"))
    return parsed[0] if parsed else zone(zone_id)


def reload_module() -> str:
    return "\n".join(_run("aw reload"))


# --- zone links -----------------------------------------------------------
# Единственная таблица этой страницы. Связь переносит погоду зоны соседу с
# ослаблением: 100% — та же самая, слабее — на столько же ступеней ниже по
# лестнице своего семейства.
#
# Лестницы ниже — ЗЕРКАЛО C++ (AdvancedWeatherMgr.cpp, LADDER_*). Панель держит
# их ради предпросмотра «что приедет соседу»; решение всё равно принимает
# сервер, так что расхождение испортит подсказку, а не погоду. Меняете лестницу
# в модуле — поправьте и здесь.

LINK_TABLE = "mod_advanced_weather_zone_link"

LADDERS: dict[str, list[int]] = {
    "rain": [0, 3, 4, 5, 91, 90],
    "snow": [0, 6, 7, 8, 106],
    "sand": [0, 22, 41, 42],
    # У тумана градаций нет: связь слабее половины его не донесёт вовсе.
    "fog": [0, 1],
}

# состояние -> (семейство, ступень)
STEP_OF: dict[int, tuple[str, int]] = {
    state: (family, level)
    for family, ladder in LADDERS.items()
    for level, state in enumerate(ladder) if level
}

# Шанс в game_weather, отвечающий за семейство.
FAMILY_CHANCE = {"rain": "rain", "snow": "snow", "sand": "storm"}

# Канонический grade ступени, как в модуле: у осадков растёт со ступенью, у
# грозы, тумана и порченых осадков градаций нет.
FLAT_GRADE = 80
LEVEL_GRADE = {1: 33, 2: 55, 3: 85}


class LinkPayload(BaseModel):
    linked_zone: int = Field(ge=1)
    strength: int = Field(default=100, ge=1, le=100)
    enabled: bool = True
    comment: str = Field(default="", max_length=255)
    # Держать зеркальную связь той же силы. Снятая галочка обратную связь
    # удаляет — это и значит «сделать одностороннюю».
    mirror: bool = False


class LinksPayload(BaseModel):
    links: list[LinkPayload] = Field(default_factory=list)


def current_season() -> str:
    """Сезон ровно так, как его считает ядро в Weather::ReGenerate."""
    day = datetime.date.today().timetuple().tm_yday
    return ("spring", "summer", "fall", "winter")[((day - 78 + 365) // 91) % 4]


def _adapt_family(family: str, seasons: dict | None) -> str:
    """Семейство, которое зона-получатель вообще знает по своему климату."""
    if family == "fog" or not seasons:
        return family
    season = seasons.get(current_season(), {})
    if season.get(FAMILY_CHANCE.get(family, ""), 0):
        return family
    best, best_chance = family, 0
    for candidate, key in FAMILY_CHANCE.items():
        chance = season.get(key, 0)
        if chance > best_chance:
            best, best_chance = candidate, chance
    return best if best_chance else family


def degrade(state: int, grade: int, strength: int,
            target_seasons: dict | None = None) -> dict:
    """Во что превратится погода у соседа. Зеркало AdvancedWeatherMgr::Degrade."""
    step = STEP_OF.get(state)
    if not step or not strength:
        return {"state": 0, "grade": 0, "label": STATE_BY_ID[0]["label"],
                "adapted": False}

    family, level = step
    new_level = (level * strength + 50) // 100
    if not new_level:
        return {"state": 0, "grade": 0, "label": STATE_BY_ID[0]["label"],
                "adapted": False}

    new_family = _adapt_family(family, target_seasons)
    ladder = LADDERS[new_family]
    new_level = min(new_level, len(ladder) - 1)
    new_state = ladder[new_level]

    if new_family == family:
        new_grade = grade * strength // 100
    else:
        base = LEVEL_GRADE.get(new_level, FLAT_GRADE)
        new_grade = base * strength // 100

    meta = STATE_BY_ID.get(new_state, {"label": f"Состояние {new_state}"})
    return {
        "state": new_state,
        "grade": max(GRADE_MIN_PCT, min(99, new_grade)),
        "label": meta["label"],
        # Погода поменяла семейство: связь перевела дождь в снег по климату
        # получателя (AdvancedWeather.Links.RespectClimate).
        "adapted": new_family != family,
    }


def link_table_exists() -> bool:
    """Таблицы может не быть: миграцию ещё не прогнали на этой базе.

    Страница обязана это пережить — весь остальной пульт погоды к таблице
    отношения не имеет, и падать целиком из-за неприменённого SQL нельзя.
    """
    return bool(query(
        "SELECT 1 FROM information_schema.tables"
        " WHERE table_schema = DATABASE() AND table_name = %s LIMIT 1",
        (LINK_TABLE,)))


NO_TABLE = (f"Таблицы `{LINK_TABLE}` нет в базе панели. Примените "
            f"data/sql/updates/pending_db_world/"
            f"mod_advanced_weather_zone_link.sql — до этого связи зон не "
            f"работают ни здесь, ни на сервере.")


def link_counts() -> dict[int, tuple[int, int]]:
    """zone_id -> (исходящих, входящих). Для списка зон слева."""
    if not link_table_exists():
        return {}
    out: dict[int, list[int]] = {}
    for row in query(
            f"SELECT zone_id, linked_zone FROM `{LINK_TABLE}` WHERE enabled = 1"):
        out.setdefault(int(row["zone_id"]), [0, 0])[0] += 1
        out.setdefault(int(row["linked_zone"]), [0, 0])[1] += 1
    return {zone: (n[0], n[1]) for zone, n in out.items()}


def _live_states() -> dict[int, dict]:
    """Что стоит в зонах прямо сейчас — для предпросмотра связей."""
    return {z["zone_id"]: z for z in _zone_lines(_run("aw list"))}


def _link_row(zone_id: int, other: int, row: dict, incoming: bool,
              live: dict, climates: dict, mirrors: set[int]) -> dict:
    """Одна связь глазами зоны zone_id."""
    strength = int(row["strength"])
    # Источник — тот, кто отдаёт погоду: у входящей это сосед, у исходящей мы.
    source = other if incoming else zone_id
    target = zone_id if incoming else other
    now = live.get(source)
    preview = None
    if now and now["state"]:
        climate = climates.get(target)
        preview = degrade(now["state"], now["grade"], strength,
                          climate["seasons"] if climate else None)
        preview["from_label"] = now["state_label"]
    return {
        "zone_id": other,
        "name": dbc.zone_name(other),
        "strength": strength,
        "enabled": bool(row["enabled"]),
        "comment": row.get("comment") or "",
        "incoming": incoming,
        "mirror": other in mirrors,
        "preview": preview,
    }


def links(zone_id: int) -> dict:
    """Связи зоны в обе стороны, с предпросмотром по текущей погоде."""
    if not link_table_exists():
        raise WeatherError(NO_TABLE)

    out_rows = query(
        f"SELECT linked_zone, strength, enabled, comment FROM `{LINK_TABLE}`"
        f" WHERE zone_id = %s ORDER BY strength DESC, linked_zone", (zone_id,))
    in_rows = query(
        f"SELECT zone_id AS src, strength, enabled, comment FROM `{LINK_TABLE}`"
        f" WHERE linked_zone = %s ORDER BY strength DESC, zone_id", (zone_id,))

    # Зеркальные пары: связь двусторонняя, если есть строка и в обратную сторону.
    incoming_ids = {int(r["src"]) for r in in_rows}
    outgoing_ids = {int(r["linked_zone"]) for r in out_rows}
    mirrors = incoming_ids & outgoing_ids

    live = _live_states()
    climates = climate_zones()

    return {
        "zone_id": zone_id,
        "name": dbc.zone_name(zone_id),
        "season": current_season(),
        "out": [_link_row(zone_id, int(r["linked_zone"]), r, False, live,
                          climates, mirrors) for r in out_rows],
        "in": [_link_row(zone_id, int(r["src"]), r, True, live, climates,
                         mirrors) for r in in_rows],
    }


def set_links(zone_id: int, payload: LinksPayload) -> dict:
    """Переписать исходящие связи зоны и перечитать их на сервере.

    Правится ровно один список — исходящие связи выбранной зоны. Галочка
    «двусторонняя» дописывает или убирает обратную строку той же силы; чужие
    связи, которые ведут в эту зону сами по себе, остаются как есть и видны в
    списке входящих.
    """
    if not link_table_exists():
        raise WeatherError(NO_TABLE)

    seen: set[int] = set()
    for link in payload.links:
        if link.linked_zone == zone_id:
            raise WeatherError("Зона не может быть связана сама с собой.")
        if link.linked_zone in seen:
            raise WeatherError(
                f"Зона {dbc.zone_name(link.linked_zone)} указана дважды.")
        seen.add(link.linked_zone)

    with cursor(commit=True) as cur:
        cur.execute(f"DELETE FROM `{LINK_TABLE}` WHERE zone_id = %s", (zone_id,))
        for link in payload.links:
            cur.execute(
                f"INSERT INTO `{LINK_TABLE}`"
                f" (zone_id, linked_zone, strength, enabled, comment)"
                f" VALUES (%s, %s, %s, %s, %s)",
                (zone_id, link.linked_zone, link.strength,
                 1 if link.enabled else 0, link.comment))

            if link.mirror:
                # Зеркало ставим по силе прямой связи: две стороны с разной
                # силой читаются как ошибка ввода, а не как замысел.
                cur.execute(
                    f"INSERT INTO `{LINK_TABLE}`"
                    f" (zone_id, linked_zone, strength, enabled, comment)"
                    f" VALUES (%s, %s, %s, %s, %s)"
                    f" ON DUPLICATE KEY UPDATE strength = VALUES(strength),"
                    f" enabled = VALUES(enabled)",
                    (link.linked_zone, zone_id, link.strength,
                     1 if link.enabled else 0, link.comment))
            else:
                cur.execute(
                    f"DELETE FROM `{LINK_TABLE}`"
                    f" WHERE zone_id = %s AND linked_zone = %s",
                    (link.linked_zone, zone_id))

    reload_links()
    return links(zone_id)


def reload_links() -> int:
    """`.aw linkreload` — сервер перечитывает таблицу без рестарта."""
    for line in _run("aw linkreload"):
        m = re.match(r"^AW:OK:LINKS:(\d+)$", line)
        if m:
            return int(m.group(1))
    raise WeatherError(
        "Worldserver не знает команду .aw linkreload — модуль старый, "
        "связи применятся только после пересборки и рестарта.")


def server_links() -> list[dict]:
    """Связи глазами worldserver'а: чем он руководствуется прямо сейчас.

    Нужно ровно для одного — увидеть расхождение с таблицей, когда правку
    забыли применить или сервер поднимался без неё.
    """
    out = []
    for line in _run("aw links"):
        m = _LINK_RE.match(line)
        if m:
            out.append({"zone_id": int(m.group(1)),
                        "linked_zone": int(m.group(2)),
                        "strength": int(m.group(3))})
    return out
