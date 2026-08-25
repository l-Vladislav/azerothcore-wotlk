"""Catalogue of what the panel can manage.

One list, read by the home page and by the board (a card can point at a
module). Adding a module means adding an entry here plus a page under
`static/` — nothing else in the panel hardcodes module names.

`status`:
  ready   — has an editor in this panel, `url` opens it
  planned — known module, no editor yet; cards can still be filed against it
"""

from typing import Literal

from pydantic import BaseModel


class ModuleInfo(BaseModel):
    id: str
    name: str
    summary: str
    status: Literal["ready", "planned"]
    url: str | None = None
    icon: str = "cube"
    tags: list[str] = []


MODULES: list[ModuleInfo] = [
    ModuleInfo(
        id="items",
        name="Каталог предметов",
        summary="Поиск по item_template, копии в собственных блоках id, "
                "правка свойств и выгрузка в миграцию.",
        status="ready", url="/items.html", icon="cube",
        tags=["предметы", "мир"],
    ),
    ModuleInfo(
        id="env-effects",
        name="Эффекты окружения",
        summary="Баффы и дебаффы по зонам: погода, время суток, пулы спеллов.",
        status="ready", url="/envfx.html", icon="weather",
        tags=["зоны", "погода", "спеллы"],
    ),
    ModuleInfo(
        id="advanced-weather",
        name="Погода",
        summary="Режиссёр погоды: состояние зоны, сила, закрепление, туман и гроза.",
        status="ready", url="/weather.html", icon="weather",
        tags=["зоны", "погода"],
    ),
    ModuleInfo(
        id="advanced-weather-settings",
        name="Настройки погоды",
        summary="Режиссёр, циклоны и все числа модуля - без правки конфига "
                "и рестарта.",
        status="ready", url="/weather-settings.html", icon="weather",
        tags=["погода", "настройки", "циклоны"],
    ),
    ModuleInfo(
        id="familiars",
        name="Фамильяры (гача)",
        summary="10 стихий x 10 питомцев: ауры владельца, сундуки, свитки.",
        status="planned", icon="pet", tags=["гача", "питомцы"],
    ),
    ModuleInfo(
        id="nemesis",
        name="Немезис",
        summary="Антагонисты, доска наград, титулы и репутация охоты.",
        status="planned", icon="skull", tags=["боссы", "награды"],
    ),
    ModuleInfo(
        id="item-talents",
        name="Таланты предметов",
        summary="Пробуждение снаряжения: категории, пулы перков, пороги убийств.",
        status="ready", url="/italents.html", icon="tree",
        tags=["предметы", "перки"],
    ),
    ModuleInfo(
        id="gear-ascension",
        name="Вознесение снаряжения",
        summary="Апгрейд предметов по ступеням качества, наборы копий.",
        status="planned", icon="arrow-up", tags=["предметы"],
    ),
    ModuleInfo(
        id="worn-drops",
        name="Дроп надетого",
        summary="NPC роняют то, что носят: броня и оружие по уровням.",
        status="planned", icon="loot", tags=["дроп", "предметы"],
    ),
    ModuleInfo(
        id="statbooster",
        name="Фортуна и свитки",
        summary="Пулы кастомных энчантов, свитки удачи, ставки по тирам.",
        status="planned", icon="sparkle", tags=["энчанты"],
    ),
    ModuleInfo(
        id="transmog",
        name="Трансмогрификация",
        summary="Коллекция внешностей, доступные наборы, ограничения.",
        status="planned", icon="shirt", tags=["внешность"],
    ),
    ModuleInfo(
        id="ollama-chat",
        name="Чат с ИИ",
        summary="Персонажи-боты с LLM: промпты, модели, память, новости.",
        status="planned", icon="chat", tags=["llm", "боты"],
    ),
    ModuleInfo(
        id="playerbots",
        name="Плеербот-AI",
        summary="Стратегии ботов, уровневые брекеты, состав групп.",
        status="planned", icon="bot", tags=["боты"],
    ),
    ModuleInfo(
        id="profession-minigames",
        name="Мини-игры профессий",
        summary="Ручное крафтовое мини-игровое окно, качество и возврат.",
        status="planned", icon="hammer", tags=["профессии"],
    ),
]

BY_ID = {m.id: m for m in MODULES}
