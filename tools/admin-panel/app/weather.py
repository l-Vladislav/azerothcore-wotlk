"""mod-advanced-weather: live weather control.

Unlike the other editors this one owns no table: the module keeps weather in
memory on purpose (see modules/mod-advanced-weather/README.md). So the panel
talks to the running worldserver over SOAP with the module's own `.aw` protocol
and parses the `AW:` lines it answers with:

    AW:ZONE:<zone>:<state>:<grade%>:<source>:<secondsLeft>:<hasClimate>:<hasPlayers>

The zone list itself comes from AreaTable, not from the server: weather can be
set in any zone, and `.aw list` only knows the ones the director has touched.
`game_weather` is read for one thing — the climate the director rolls against.
"""

import re

from pydantic import BaseModel, Field

from . import dbc, soap
from .db import query

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
}

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


_ZONE_RE = re.compile(r"^AW:ZONE:(\d+):(\d+):(\d+):(\d+):(-?\d+):(\d+):(\d+)$")
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
        int(g) for g in m.groups())
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
            zones.append(row)

    for zone_id, row in known.items():
        row["name"] = names.get(zone_id, f"Зона {zone_id}")
        row["continent"] = OTHER_KEY
        row["continent_name"] = OTHER_NAME
        climate = climates.get(zone_id)
        row["seasons"] = climate["seasons"] if climate else None
        zones.append(row)

    zones.sort(key=lambda z: z["name"])

    groups = [{"key": c["key"], "name": c["name"]} for c in CONTINENTS]
    if any(z["continent"] == OTHER_KEY for z in zones):
        groups.append({"key": OTHER_KEY, "name": OTHER_NAME})

    return {
        "module": status,
        "states": STATES,
        "sources": SOURCES,
        "grade_min": GRADE_MIN_PCT,
        "module_only": sorted(MODULE_ONLY),
        "continents": groups,
        "zones": zones,
        "live_count": sum(1 for z in zones if z["players"]),
        "known_count": sum(1 for z in zones if z["known"]),
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
