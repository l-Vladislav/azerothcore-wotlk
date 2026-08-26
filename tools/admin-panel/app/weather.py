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

The director switch (`.aw enable`) is a setting too, but the panel does not
write its table — the module does, so that the command line and the panel
cannot disagree about it. Here it is one more `.aw` call.
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
    4: "фронт",
}

# Протокол, который панель умеет читать. Меньший номер = worldserver не
# пересобран: строка зоны придёт без полей связи, и страница обойдётся без них.
PROTOCOL = "3"

# Ниже 0.27 клиент показывает «ясно» независимо от состояния
# (Weather::GetWeatherState), поэтому ползунок в UI начинается с 30%.
GRADE_MIN_PCT = 30

# --- настройки модуля -----------------------------------------------------
# Имена, границы и значения по умолчанию приходят с сервера (".aw cfg"):
# реестр живёт в C++, и дублировать его тут значило бы разойтись при первой же
# правке. Панель добавляет только то, чего в реестре нет и быть не должно —
# человеческое имя, пояснение и группу, в которой поле стоит на странице.

SETTING_GROUPS: list[dict] = [
    {"key": "director", "name": "Режиссёр",
     "hint": "Кто ведёт погоду и как часто он оглядывает мир."},
    {"key": "cyclones", "name": "Циклоны",
     "hint": "Фронты, идущие через всю карту. Фронт ставит погоду ТОЛЬКО "
             "в зоне под своим центром - дальше она расходится по связям "
             "зон, ровно как выставленная руками. Радиус, глаз, рукава и "
             "вращение здесь - про рисунок; докуда достанет непогода, "
             "решает «Глубина переноса» в связях."},
    {"key": "rolls", "name": "Одиночные броски",
     "hint": "Старая модель: каждая зона сама катает себе погоду на "
             "случайный срок. Работает, только когда циклоны выключены."},
    {"key": "links", "name": "Связи зон",
     "hint": "ЕДИНСТВЕННЫЙ механизм растекания: и от фронта, и от "
             "выставленной руками. Сами связи правятся на странице «Погода»."},
]

SETTING_META: dict[str, dict] = {
    "enabled": {
        "group": "director", "label": "Режиссёр включён", "kind": "bool",
        "hint": "Выключенный модуль снимает свои наложения, и зоны "
                "возвращаются под ядровую генерацию по game_weather.",
    },
    "debug": {
        "group": "director", "label": "Подробный лог", "kind": "bool",
        "hint": "Каждое решение и применение уезжает в канал «module».",
    },
    "tick_seconds": {
        "group": "director", "label": "Тик режиссёра", "unit": "с",
        "hint": "Как часто модуль осматривает мир. Это же интервал "
                "самопочинки, если погоду сбила чужая команда.",
    },
    "manual_hold_minutes": {
        "group": "director", "label": "Ручная погода держится", "unit": "мин",
        "hint": "Сколько выставленная руками погода живёт до возврата "
                "режиссёру. Закрепление этот таймер не использует.",
    },
    "cyclones_enabled": {
        "group": "cyclones", "label": "Циклоны включены", "kind": "bool",
        "hint": "Погоду носят движущиеся фронты, а не одиночные броски. "
                "Фронт ставит её в зоне под своим центром, дальше разносят "
                "связи. Между фронтами ясно — и переход видно.",
    },
    "cyclones_per_map": {
        "group": "cyclones", "label": "Фронтов на карту", "unit": "шт",
        "hint": "Сколько фронтов держать над каждым континентом. 0 — ни "
                "одного, весь мир стоит ясным.",
    },
    "cyclone_radius": {
        "group": "cyclones", "label": "Радиус фронта", "unit": "ярдов",
        "hint": "На погоду НЕ влияет: фронт ставит её в зоне под центром, а "
                "дальше дело связей. Радиус задаёт длину пути через карту и "
                "размер рисунка.",
    },
    "cyclone_cross_minutes": {
        "group": "cyclones", "label": "Пересечь карту за", "unit": "мин",
        "hint": "Скорость задаётся временем, а не ярдами: одно число "
                "одинаково хорошо смотрится и на Калимдоре, и на Запределье.",
    },
    "cyclone_calm_chance": {
        "group": "cyclones", "label": "Шанс штиля", "unit": "%",
        "hint": "С этим шансом освободившееся место фронта остаётся пустым "
                "на тик. Без штиля над картой всегда ровно N фронтов.",
    },
    "cyclone_arms": {
        "group": "cyclones", "label": "Рукавов спирали", "unit": "шт",
        "hint": "Только рисунок: сколько рукавов у нарисованной спирали. "
                "На погоду не влияет.",
    },
    "cyclone_eye_pct": {
        "group": "cyclones", "label": "Глаз", "unit": "%",
        "hint": "Только рисунок: светлая середина вихря. На погоду не "
                "влияет - глаз у настоящего циклона меньше тысячи ярдов, а "
                "зона в разы больше, так что её накрывает вал, а не затишье.",
    },
    "cyclone_band_angle": {
        "group": "cyclones", "label": "Наклон рукавов", "unit": "°",
        "hint": "Только рисунок. Угол, под которым рукав пересекает "
                "окружности вокруг центра - у настоящих циклонов его и "
                "меряют: типично 9-15°, разброс 0-40°.",
    },
    "cyclone_weak_chance": {
        "group": "cyclones", "label": "Шанс слабого фронта", "unit": "%",
        "hint": "Фронт ставит в своей зоне самую сильную обычную погоду "
                "семейства: грозу, метель или сильную песчаную бурю. С этим "
                "шансом он выходит на ступень слабее - иначе все фронты "
                "одинаково грозовые.",
    },
    "cyclone_spin_minutes": {
        "group": "cyclones", "label": "Оборот спирали за", "unit": "мин",
        "hint": "Только рисунок: с какой скоростью крутится вихрь на карте, "
                "против часовой стрелки. На погоду не влияет.",
    },
    "min_minutes": {
        "group": "rolls", "label": "Фронт живёт от", "unit": "мин"},
    "max_minutes": {
        "group": "rolls", "label": "Фронт живёт до", "unit": "мин"},
    "fog_chance": {
        "group": "rolls", "label": "Туман", "unit": "%",
        "hint": "Разыгрывается там, где климат не дал осадков. У циклонов "
                "этим же шансом решается, будет ли фронт туманным.",
    },
    "thunders_chance": {
        "group": "rolls", "label": "Гроза", "unit": "%",
        "hint": "У циклонов — шанс, что в сердцевине фронта будет гроза.",
    },
    "black_rain_chance": {
        "group": "rolls", "label": "Чёрный дождь", "unit": "%"},
    "black_snow_chance": {
        "group": "rolls", "label": "Чёрный снег", "unit": "%"},
    "links_enabled": {
        "group": "links", "label": "Переносить погоду соседям", "kind": "bool"},
    "links_hops": {
        "group": "links", "label": "Глубина переноса", "unit": "зон",
        "hint": "1 - только прямой сосед; 2 - и сосед соседа, уже вдвойне "
                "ослабленной. Гроза при связи 49% приезжает соседу дождём, а "
                "через него - моросью. Назад к источнику погода не идёт.",
    },
    "links_respect_climate": {
        "group": "links", "label": "С оглядкой на климат", "kind": "bool",
        "hint": "Дождь из Хилсбрада приедет в Зимние Ключи снегом, а в "
                "Танарис песчаной бурей. Тем же переводом пользуются циклоны.",
    },
}

# Семейства осадков (AdvancedWeather::Family). Панель показывает, из чего
# сделан фронт, и красит его в цвет группы.
FAMILIES: dict[int, dict] = {
    0: {"name": "без осадков", "group": "clear"},
    1: {"name": "дождевой", "group": "rain"},
    2: {"name": "снежный", "group": "snow"},
    3: {"name": "песчаный", "group": "storm"},
    4: {"name": "туманный", "group": "clear"},
}


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
_ENABLED_RE = re.compile(r"^AW:ENABLED:(\d):(\d)$")
_SETTING_RE = re.compile(r"^AW:SET:([a-z_]+):(\d+):(\d+):(\d):(\d+):(\d+)$")
# Поля спирали (глаз, рукава, поворот, закрутка) приехали позже остальных:
# на непересобранном worldserver'е их нет, и строка всё равно должна читаться —
# фронт тогда просто нарисуется кругом.
_CYCLONE_RE = re.compile(
    r"^AW:CYC:(\d+):(\d+):(-?\d+):(-?\d+):(\d+):(\d+):(\d+):(\d+):(\d+):(\d+):(\d+)"
    r"(?::(\d+):(\d+):(\d+):(\d+):(\d+))?$")

ERRORS = {
    "DISABLED": "Режиссёр выключен — включите его кнопкой на карте "
                "(или AdvancedWeather.Enable в конфиге модуля).",
    "BADARG": "Сервер не принял аргументы команды.",
    "NOZONE": "Не указана зона.",
    "NOSETTING": "Сервер не знает такой настройки.",
    "WEATHEROFF": "Погода отключена в конфиге сервера (Weather.Enabled).",
}


class WeatherError(RuntimeError):
    pass


class DirectorPayload(BaseModel):
    enabled: bool


class SettingPayload(BaseModel):
    # None = вернуть значение из конфига модуля (".aw cfg <имя> reset").
    value: int | None = Field(default=None, ge=0, le=100000)


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
            status = {"ok": True, "protocol": m.group(1),
                      "enabled": m.group(2) == "1"}
            status.update(_director())
            return status
    # Ядро отвечает на неизвестную команду списком доступных подкоманд.
    raise WeatherError("Worldserver не знает команду .aw — модуль не собран "
                       "или worldserver не перезапущен после сборки.")


def _director() -> dict:
    """Переключатель режиссёра: включён ли и откуда взято значение.

    `can_toggle = False` означает, что worldserver собран без ".aw enable" —
    страница тогда показывает состояние из `hello`, но кнопку не даёт нажать.
    Ошибкой это не считается: на неизвестную подкоманду ядро отвечает списком
    доступных, а не AW:ERR.
    """
    for line in _run("aw enable"):
        m = _ENABLED_RE.match(line)
        if m:
            return {"can_toggle": True, "enabled": m.group(1) == "1",
                    "stored": m.group(2) == "1"}
    return {"can_toggle": False, "stored": False}


def set_director(enabled: bool) -> dict:
    """Включить или выключить режиссёра. Решение переживает рестарт.

    Выключение не просто «перестать вмешиваться»: модуль ещё и снимает свои
    наложения, иначе зона осталась бы с последней его погодой навсегда.
    """
    for line in _run(f"aw enable {1 if enabled else 0}"):
        m = _ENABLED_RE.match(line)
        if m:
            return {"enabled": m.group(1) == "1", "stored": m.group(2) == "1"}
    raise WeatherError("Worldserver не знает команду .aw enable — модуль не "
                       "пересобран после появления переключателя.")


def settings() -> dict:
    """Все настройки модуля, как их отдаёт `.aw cfg`.

    Пустой список означает worldserver без этой команды — страница настроек
    тогда честно говорит, что её нечем наполнить, вместо того чтобы рисовать
    пустые поля.
    """
    rows: list[dict] = []
    for line in _run("aw cfg"):
        m = _SETTING_RE.match(line)
        if not m:
            continue
        name = m.group(1)
        meta = SETTING_META.get(name, {})
        rows.append({
            "name": name,
            "value": int(m.group(2)),
            "default": int(m.group(3)),
            "stored": m.group(4) == "1",
            "min": int(m.group(5)),
            "max": int(m.group(6)),
            "label": meta.get("label", name),
            "hint": meta.get("hint", ""),
            "unit": meta.get("unit", ""),
            # Границы 0..1 — это переключатель, что бы ни было написано в
            # мета-данных: реестр на сервере тут авторитетнее.
            "kind": "bool" if int(m.group(5)) == 0 and int(m.group(6)) == 1
                    else meta.get("kind", "int"),
            "group": meta.get("group", "director"),
        })

    known = {g["key"] for g in SETTING_GROUPS}
    for row in rows:
        if row["group"] not in known:
            row["group"] = "director"

    return {
        "groups": SETTING_GROUPS,
        "settings": rows,
        "supported": bool(rows),
    }


def set_setting(name: str, value: int | None) -> dict:
    """Записать настройку; `value = None` возвращает значение из конфига."""
    arg = "reset" if value is None else str(int(value))
    for line in _run(f"aw cfg {name} {arg}"):
        m = _SETTING_RE.match(line)
        if m and m.group(1) == name:
            return {"name": name, "value": int(m.group(2)),
                    "default": int(m.group(3)), "stored": m.group(4) == "1"}
    raise WeatherError("Сервер не подтвердил настройку строкой AW:SET.")


def _parse_cyclone(line: str) -> dict | None:
    m = _CYCLONE_RE.match(line)
    if not m:
        return None
    family = int(m.group(6))
    meta = FAMILIES.get(family, FAMILIES[0])
    return {
        "id": int(m.group(1)),
        "map": int(m.group(2)),
        # Мировые ярды той карты, на которой фронт идёт. Пересчёт в пиксели
        # карты делает weather-map.js: у него есть прямоугольник континента.
        "x": int(m.group(3)),
        "y": int(m.group(4)),
        "radius": int(m.group(5)),
        "family": family,
        "family_name": meta["name"],
        "family_group": meta["group"],
        "peak": int(m.group(7)),
        "heading": int(m.group(8)),
        # Сервер шлёт сотые доли ярда в секунду: целым числом ярдов медленный
        # фронт округлился бы в ноль.
        "speed": int(m.group(9)) / 100.0,
        "seconds_left": int(m.group(10)),
        "zones": int(m.group(11)),
        # Спираль. Глаз в ярдах, рукава штуками, поворот в градусах, закрутка
        # логарифмической спирали r = eye * e^(twist * угол) — сервер шлёт её
        # умноженной на 1000, чтобы протокол остался целочисленным. Панель
        # рисует РОВНО по этим числам и своей константы закрутки не держит.
        "eye": int(m.group(12) or 0),
        "arms": int(m.group(13) or 0),
        "spin": int(m.group(14) or 0),
        "twist": int(m.group(15) or 0) / 1000.0,
        # Период оборота: панель крутит рисунок ровно с этой скоростью.
        "spin_minutes": int(m.group(16) or 0),
    }


def cyclones() -> list[dict]:
    """Фронты, идущие по картам прямо сейчас."""
    return [c for c in (_parse_cyclone(ln) for ln in _run("aw cyclones")) if c]


def reset_cyclones() -> list[dict]:
    return [c for c in (_parse_cyclone(ln) for ln in _run("aw cycreset")) if c]


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
    # Фронты идут в тот же ответ: страница рисует их поверх той же карты и
    # обновляет тем же таймером, лишний запрос раз в 15 секунд ни к чему.
    fronts = cyclones() if status.get("can_toggle") else []
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
        "cyclones": fronts,
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
