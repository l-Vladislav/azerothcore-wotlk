"""Spell workshop — author custom spells for any module.

A custom spell has two halves and the panel can only own one of them outright:

  * the **server half** is a row in `spell_dbc` (acore_world_ptr). That is what
    makes the spell do something, and it is what this module reads and writes.
  * the **client half** is the row inside the MPQ's Spell.dbc — name,
    description, icon. The panel can emit the CSV line for it (see
    `export_client()`), but rebuilding the MPQ stays a manual step.

Two facts shape the whole design:

  * `spell_dbc` is read once at worldserver startup (DBCStores.cpp,
    `LoadDBCStores`) and there is no `.reload` for it, so a saved spell only
    takes effect after a PTR restart. `pending_restart()` reports how many rows
    are waiting, using the server's own uptime rather than a flag we could
    forget to clear.
  * `spell_dbc` has no column for the client icon *texture*, and no notion of
    which module a spell belongs to. Those live in `acore_admin.spell_meta`,
    keyed by spell id — the same panel-owned schema the board uses.

The field catalogue is deliberately data, not code: `FIELD_GROUPS` below plus
`app/data/spell_enums.json` (generated from the core headers by
`scripts/gen_spell_enums.py`) describe every editable column, and the frontend
renders whatever it is handed. Adding a field is one line here.
"""

import datetime as _dt
import json
import os
import re
from typing import Any, Iterator

from pydantic import BaseModel, Field

from . import board, config, soap
from .db import cursor as world_cursor
from .db import query, query_one

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
ENUMS_PATH = os.path.join(DATA_DIR, "spell_enums.json")

TABLE = "spell_dbc"


# --- id blocks ------------------------------------------------------------

class Block(BaseModel):
    id: str
    module: str
    lo: int
    hi: int
    name: str


# Re-inventoried against acore_world_ptr on 2026-08-19 (`GROUP BY
# FLOOR(ID/100)`): 90001-90008, 91003, 100000-100099, 102000-104099, 105000,
# 107000-107176, 107500-107528, 108000-108092, 108500, 108900-108914, 200100.
# 109000+ is empty, which is why the workshop's own block starts there.
#
# Three of those ranges had no block and so were invisible in the workshop's
# filter and in the catalogue's module filter — the row-5 proc pools of
# mod-item-talents above all, 86 spells of it. Ranges deliberately left
# unmapped are the ones we do not author: 91003 (upstream AzerothCore,
# Summon Onyxia Whelp) and 200100 (upstream mod-transmog pet).
BLOCKS: list[Block] = [
    Block(id="env-buffs", module="env-effects", lo=107000, hi=107499,
          name="Окружение — баффы"),
    Block(id="env-debuffs", module="env-effects", lo=107500, hi=107799,
          name="Окружение — дебаффы"),
    Block(id="env-global", module="env-effects", lo=108500, hi=108599,
          name="Окружение — глобальные"),
    Block(id="familiar-summons", module="familiars", lo=102000, hi=102099,
          name="Фамильяры — призывы"),
    Block(id="familiar-auras", module="familiars", lo=103000, hi=103099,
          name="Фамильяры — ауры владельца"),
    Block(id="familiar-auras-2", module="familiars", lo=104000, hi=104099,
          name="Фамильяры — ауры (резерв)"),
    # Ряд 5 «Пробуждение»: скрытый триггер-пассив 108000+ кастует парный
    # видимый спелл 108050+ (шаг 50). Канон — .claude/item-talents/
    # CUSTOM_SPELLS.md, который резервирует под это весь 108000-108099.
    Block(id="item-talent-procs", module="item-talents", lo=108000, hi=108049,
          name="Пробуждение — триггеры проков"),
    Block(id="item-talent-effects", module="item-talents", lo=108050, hi=108099,
          name="Пробуждение — эффекты проков"),
    Block(id="item-talents", module="item-talents", lo=108900, hi=108999,
          name="Таланты предметов — ауры рядов 1-4"),
    Block(id="gear-ascension", module="gear-ascension", lo=105000, hi=105099,
          name="Вознесение — служебные спеллы"),
    Block(id="statbooster", module="statbooster", lo=90000, hi=90999,
          name="Фортуна и свитки"),
    Block(id="custom-items", module="", lo=100000, hi=100999,
          name="Кастомные предметы"),
    Block(id="workshop", module="", lo=109000, hi=109999,
          name="Мастерская — свободный блок"),
]

BLOCK_BY_ID = {b.id: b for b in BLOCKS}


def block_of(spell_id: int) -> Block | None:
    for block in BLOCKS:
        if block.lo <= spell_id <= block.hi:
            return block
    return None


# --- field catalogue ------------------------------------------------------
# kind: int | text | enum | flags | ref
#   enum  -> `enum` names a list in spell_enums.json (single choice)
#   flags -> `enum` names a list of bit values (checkboxes)
#   ref   -> `ref` names a *_dbc table the panel reads for a live dropdown

def f(col: str, kind: str = "int", label: str = "", **extra) -> dict:
    return dict(col=col, kind=kind, label=label or col, **extra)


EFFECT_FIELDS = [
    f("Effect_%d", "enum", "Эффект", enum="effects",
      hint="Что эффект вообще делает: нанести урон, вылечить, вызвать "
           "существо, повесить ауру (APPLY_AURA = 6). Пустой Effect — "
           "эффект выключен, остальные его поля ядро не читает."),
    f("EffectAura_%d", "enum", "Аура", enum="auras",
      hint="Читается только при Effect = APPLY_AURA. Именно аура определяет, "
           "что даёт баф: +характеристика, % урона, периодический урон и т.д."),
    f("EffectBasePoints_%d", "int", "Base points",
      hint="Величина эффекта МИНУС 1: ядро считает base + 1. Хотите +10% — "
           "пишите 9. Так делают все генераторы модулей."),
    f("EffectDieSides_%d", "int", "Die sides",
      hint="Разброс: итог случаен в диапазоне base+1 … base+DieSides. "
           "Для фиксированного значения ставьте 1."),
    f("EffectRealPointsPerLevel_%d", "int", "За уровень",
      hint="Прибавка к величине за каждый уровень выше BaseLevel. "
           "0 — эффект не масштабируется."),
    f("EffectAuraPeriod_%d", "int", "Период, мс",
      hint="Как часто тикает периодическая аура (урон/лечение/мана). "
           "1000 = раз в секунду. 0 — аура не периодическая."),
    f("EffectMiscValue_%d", "int", "Misc value",
      hint="Смысл зависит от эффекта: для урона/сопротивления — маска школы, "
           "для +характеристики — её индекс, для призыва — entry существа."),
    f("EffectMiscValueB_%d", "int", "Misc value B",
      hint="Второй параметр эффекта. Например, у призыва — тип призыва "
           "(SummonProperties), у телепорта — карта."),
    f("EffectMechanic_%d", "enum", "Механика", enum="mechanics",
      hint="Механика конкретно этого эффекта: оглушение, страх, замедление. "
           "Через неё работают иммунитеты и сокращение длительности (DR)."),
    f("ImplicitTargetA_%d", "enum", "Цель A", enum="targets",
      hint="Кого задевает эффект. Без неё эффект обычно просто не срабатывает. "
           "Для баффа на себя — Unit caster (1)."),
    f("ImplicitTargetB_%d", "enum", "Цель B", enum="targets",
      hint="Второй селектор цели; вместе с A задаёт схему вроде «область "
           "вокруг цели». Для простых спеллов оставляйте 0."),
    f("EffectRadiusIndex_%d", "ref", "Радиус", ref="spellradius_dbc",
      hint="Индекс в SpellRadius.dbc — радиус области для AoE-целей. "
           "Нужен только когда цель area-типа."),
    f("EffectChainTargets_%d", "int", "Цепь, целей",
      hint="Сколько целей заденет цепной эффект (цепная молния). "
           "0 или 1 — цепи нет."),
    f("EffectTriggerSpell_%d", "int", "Триггерит спелл",
      hint="ID спелла, который применится при срабатывании этого эффекта. "
           "Так делают проки: аура ловит событие и кастует другой спелл."),
    f("EffectItemType_%d", "int", "Item type",
      hint="Предмет, который создаёт эффект (CREATE_ITEM), либо ID набора "
           "энчанта. Обычно 0."),
    f("EffectMultipleValue_%d", "int", "Multiple value",
      hint="Множитель для некоторых эффектов (например, длительность "
           "призванного существа). Обычно 0."),
    f("EffectPointsPerCombo_%d", "int", "За комбо-очко",
      hint="Прибавка к величине за каждое комбо-очко — только для "
           "разбойничьих финишеров."),
    f("EffectChainAmplitude_%d", "int", "Chain amplitude",
      hint="Во сколько раз слабеет эффект на каждом следующем звене цепи."),
    f("EffectBonusMultiplier_%d", "int", "Bonus multiplier",
      hint="Коэффициент, с которым в эффект входит сила заклинаний / атаки."),
    f("EffectSpellClassMaskA_%d", "int", "Class mask A",
      hint="Маска семейства: какие спеллы этого класса эффект изменяет. "
           "Нужна только для талантов вида «+X% к такому-то спеллу»."),
    f("EffectSpellClassMaskB_%d", "int", "Class mask B",
      hint="Продолжение маски семейства (биты 32-63)."),
    f("EffectSpellClassMaskC_%d", "int", "Class mask C",
      hint="Продолжение маски семейства (биты 64-95)."),
]

REAGENT_HINT = ("Entry предмета, который спелл потратит при применении. "
                "0 — слот пуст. Так работают создание предметов, "
                "зачарования и всё «ремесленное».")
REAGENT_COUNT_HINT = ("Сколько штук предмета из этого слота уйдёт. "
                      "Реагент без количества ядро не спишет.")


def _reagent_fields() -> list[dict]:
    """Reagent, totem and totem-category slots.

    These are the only *functional* columns of `spell_dbc` the catalogue used
    to have no editor for, and 4 372 stock spells use the reagent slots alone —
    which made every copy of a crafting or totem spell quietly different from
    its source.
    """
    out = []
    for slot in range(1, 9):
        out.append(f("Reagent_%d" % slot, "int", "Реагент %d" % slot,
                     hint=REAGENT_HINT))
        out.append(f("ReagentCount_%d" % slot, "int", "Реагент %d, шт" % slot,
                     hint=REAGENT_COUNT_HINT))
    for slot in (1, 2):
        out.append(f("Totem_%d" % slot, "int", "Тотем %d" % slot,
                     hint="Entry предмета-инструмента, который надо иметь при "
                          "себе (кирка, молот, тотем). Не тратится."))
    for slot in (1, 2):
        out.append(f("RequiredTotemCategoryID_%d" % slot, "int",
                     "Категория тотема %d" % slot,
                     hint="Ссылка на TotemCategory.dbc — годится любой предмет "
                          "этой категории, а не один конкретный. В клиентском "
                          "DBC колонка называется TotemCategory_%d." % slot))
    return out


FIELD_GROUPS: list[dict] = [
    {
        "id": "main", "label": "Основное",
        "hint": "Из чего спелл состоит на верхнем уровне: к какой школе "
                "относится, чем снимается, как выглядит.",
        "fields": [
            f("SchoolMask", "enum", "Школа", enum="school_mask",
              hint="Школа магии как битовая маска. От неё зависят "
                   "сопротивление цели, иммунитеты и то, чьи бонусы урона "
                   "работают. Физический урон — Normal."),
            f("DispelType", "enum", "Тип рассеивания", enum="dispel",
              hint="Чем ауру можно снять: магия, проклятие, болезнь, яд. "
                   "None — не снимается вообще."),
            f("Mechanic", "enum", "Механика", enum="mechanics",
              hint="Механика спелла целиком (оглушение, страх, корни). "
                   "Через неё работают иммунитеты и сокращение длительности "
                   "при повторном применении в PvP."),
            f("Category", "int", "Категория",
              hint="Группа спеллов с общим откатом: КД из "
                   "«КД категории» тратится сразу на всю группу. "
                   "0 — своя категория."),
            f("SpellIconID", "int", "SpellIconID",
              hint="Серверная колонка, игрой не читается. Настоящая иконка — "
                   "в клиентском Spell.dbc, задаётся полем «Иконка» ниже."),
            f("ActiveIconID", "int", "ActiveIconID",
              hint="Иконка активного состояния (когда аура висит). "
                   "Обычно 0."),
            f("SpellVisualID_1", "int", "Визуал 1",
              hint="Ссылка на SpellVisual.dbc: анимация каста, снаряд, "
                   "эффект на цели. 0 — спелл применяется невидимо."),
            f("SpellVisualID_2", "int", "Визуал 2",
              hint="Второй набор визуала (для другого состояния). "
                   "Обычно 0."),
            f("SpellDifficultyID", "int", "SpellDifficultyID",
              hint="Ссылка на SpellDifficulty.dbc: разные версии спелла для "
                   "10/25 человек и героика. Для кастомных — 0."),
        ],
    },
    {
        "id": "text", "label": "Тексты",
        "hint": "Что увидит игрок. В игре тексты читаются из клиентского "
                "Spell.dbc внутри MPQ — эти поля попадают туда через "
                "«Экспорт в клиент».",
        "fields": [
            f("Name_Lang_ruRU", "text", "Название (ru)",
              hint="Название спелла в русском клиенте — то, что видно в "
                   "тултипе, боевом логе и на панели способностей."),
            f("Name_Lang_enUS", "text", "Название (en)",
              hint="Английское название. Полезно для команд и поиска, "
                   "в русском клиенте не показывается."),
            f("Description_Lang_ruRU", "text", "Описание (ru)",
              hint="Тело тултипа. Поддерживает подстановки клиента: "
                   "$s1 — величина первого эффекта, $d — длительность, "
                   "$t1 — период тика."),
            f("Description_Lang_enUS", "text", "Описание (en)"),
            f("AuraDescription_Lang_ruRU", "text", "Описание ауры (ru)",
              hint="Тултип на панели баффов читает именно это поле."),
            f("AuraDescription_Lang_enUS", "text", "Описание ауры (en)"),
            f("NameSubtext_Lang_ruRU", "text", "Подпись (ru)",
              hint="Строка под названием — у стоковых спеллов там ранг "
                   "(«Уровень 3»)."),
        ],
    },
    {
        "id": "attrs", "label": "Атрибуты",
        "hint": "Восемь 32-битных наборов флагов поведения. Здесь включается "
                "почти всё «особенное»: пассивность, скрытность от игрока, "
                "запрет снимать ауру правым кликом (NO_AURA_CANCEL).",
        "fields": [
            f("Attributes", "flags", "Attributes", enum="attr0",
              hint="Базовый набор (SPELL_ATTR0). Здесь живут «пассивный», "
                   "«скрыт от игрока», «не показывать в боевом логе» и "
                   "NO_AURA_CANCEL — без последнего игрок снимет вашу ауру "
                   "правым кликом."),
            f("AttributesEx", "flags", "AttributesEx", enum="attr1",
              hint="SPELL_ATTR1: поведение при касте и с целью — "
                   "«не прерывается уроном», «требует цель в бою», "
                   "«снимается при выходе из области»."),
            f("AttributesEx2", "flags", "AttributesEx2", enum="attr2",
              hint="SPELL_ATTR2: исключения из общих правил — работа на "
                   "мёртвой цели, игнорирование линии видимости, "
                   "неиспользование реагентов."),
            f("AttributesEx3", "flags", "AttributesEx3", enum="attr3",
              hint="SPELL_ATTR3: в основном про проки и стакание — "
                   "«может прокать сам от себя», «не требует оружия», "
                   "правила PvP."),
            f("AttributesEx4", "flags", "AttributesEx4", enum="attr4",
              hint="SPELL_ATTR4: служебные флаги — не логировать, не "
                   "сбрасывать таймеры, поведение у питомцев и транспорта."),
            f("AttributesEx5", "flags", "AttributesEx5", enum="attr5",
              hint="SPELL_ATTR5: поддерживаемые спеллы, действия во время "
                   "каста, поведение в подземельях."),
            f("AttributesEx6", "flags", "AttributesEx6", enum="attr6",
              hint="SPELL_ATTR6: арена и особые случаи — не показывать КД "
                   "в тултипе, игнорировать иммунитеты."),
            f("AttributesEx7", "flags", "AttributesEx7", enum="attr7",
              hint="SPELL_ATTR7: поздние правки Blizzard — отражение "
                   "спеллов, длительность у цели, обличья."),
        ],
    },
    {
        "id": "timing", "label": "Тайминги",
        "hint": "Когда, как долго и на какой дистанции. Три поля — не числа, "
                "а индексы в справочных DBC (длительность, время каста, "
                "дальность).",
        "fields": [
            f("DurationIndex", "ref", "Длительность", ref="spellduration_dbc",
              hint="Не миллисекунды, а индекс в SpellDuration.dbc: "
                   "21 — постоянная, 5 — 5 минут, 9 — 30 секунд. "
                   "Для APPLY_AURA обязательна, "
                   "иначе аура молча не вешается."),
            f("CastingTimeIndex", "ref", "Время каста", ref="spellcasttimes_dbc",
              hint="Индекс в SpellCastTimes.dbc. 1 — мгновенно; каст можно "
                   "прервать уроном, если не выставлены нужные атрибуты."),
            f("RangeIndex", "ref", "Дальность", ref="spellrange_dbc",
              hint="Индекс в SpellRange.dbc. 1 — только на себя, 4 — ближний "
                   "бой, 6 — 30 метров."),
            f("RecoveryTime", "int", "КД, мс",
              hint="Персональный откат этого спелла в миллисекундах. "
                   "30000 = 30 секунд, 0 — без отката."),
            f("CategoryRecoveryTime", "int", "КД категории, мс",
              hint="Откат, общий для всех спеллов с той же «Категорией». "
                   "Так делают общий КД у группы зелий или печатей."),
            f("StartRecoveryCategory", "int", "GCD-категория",
              hint="Группа общего кулдауна. 133 — обычный GCD. "
                   "0 — спелл не завязан на GCD вообще."),
            f("StartRecoveryTime", "int", "GCD, мс",
              hint="Длина глобального кулдауна: обычно 1500 (1.5 с). "
                   "0 — применение не запускает GCD."),
            f("Speed", "int", "Скорость снаряда",
              hint="Скорость полёта снаряда в ярдах в секунду: урон придёт "
                   "с задержкой. 0 — попадание мгновенное."),
        ],
    },
    {
        "id": "proc", "label": "Прок и стеки",
        "hint": "Поведение ауры во времени: от чего срабатывает, сколько раз "
                "и сколько экземпляров висит одновременно.",
        "fields": [
            f("ProcChance", "int", "Шанс прока, %",
              hint="Модули ставят 101 — иначе аура может не примениться."),
            f("ProcTypeMask", "int", "Proc flags",
              hint="Битовая маска событий, на которых аура срабатывает: "
                   "удар в ближнем бою, получение урона, успешный каст "
                   "(PROC_FLAG_* в ядре)."),
            f("ProcCharges", "int", "Зарядов",
              hint="Сколько раз аура сработает, прежде чем спадёт. "
                   "0 — без ограничения по зарядам."),
            f("CumulativeAura", "int", "Макс. стеков",
              hint="Сколько экземпляров ауры копится на цели. "
                   "0 или 1 — стеков нет, повторное применение обновляет."),
            f("MaxTargets", "int", "Макс. целей",
              hint="Жёсткий потолок числа целей для AoE. 0 — ограничения нет "
                   "(кроме радиуса)."),
            f("MaxTargetLevel", "int", "Макс. уровень цели",
              hint="Не подействует на цель выше этого уровня. "
                   "0 — без ограничения."),
            f("InterruptFlags", "int", "Interrupt flags",
              hint="Что прерывает КАСТ: движение, поворот, полученный урон."),
            f("AuraInterruptFlags", "int", "Aura interrupt flags",
              hint="Что снимает уже висящую АУРУ: вход в бой, движение, "
                   "посадка на транспорт, атака."),
            f("ChannelInterruptFlags", "int", "Channel interrupt flags",
              hint="Что прерывает поддерживаемый (channel) спелл."),
        ],
    },
    {
        "id": "cost", "label": "Уровни и стоимость",
        "hint": "Кому доступен спелл и во что обходится применение.",
        "fields": [
            f("BaseLevel", "int", "Base level",
              hint="Уровень, от которого считается масштабирование величины "
                   "(«за уровень» в эффектах)."),
            f("SpellLevel", "int", "Spell level",
              hint="Уровень самого спелла. Влияет на снижение эффекта против "
                   "цели сильно выше уровнем."),
            f("MaxLevel", "int", "Max level",
              hint="Потолок масштабирования: выше этого уровня величина не "
                   "растёт. 0 — потолка нет."),
            f("PowerType", "enum", "Ресурс", enum="powers",
              hint="Чем платим: мана, ярость, энергия, руны. "
                   "Отдельным значением задаётся оплата здоровьем."),
            f("ManaCost", "int", "Стоимость",
              hint="Фиксированная стоимость в выбранном ресурсе."),
            f("ManaCostPct", "int", "Стоимость, %",
              hint="Стоимость в процентах от БАЗОВОГО запаса ресурса. "
                   "Складывается с фиксированной."),
            f("ManaCostPerLevel", "int", "Стоимость за уровень",
              hint="Прибавка к стоимости за каждый уровень выше BaseLevel."),
            f("ManaPerSecond", "int", "Расход в секунду",
              hint="Расход во время поддержания спелла (channel)."),
            f("ManaPerSecondPerLevel", "int", "Расход/сек за уровень"),
            f("PowerDisplayID", "int", "PowerDisplayID",
              hint="Альтернативная шкала ресурса у транспортов и боссов. "
                   "Для обычных спеллов 0."),
            f("RuneCostID", "int", "RuneCostID",
              hint="Ссылка на SpellRuneCost.dbc — стоимость в рунах "
                   "рыцаря смерти. Для остальных 0."),
        ],
    },
    {
        "id": "require", "label": "Требования",
        "hint": "Условия, без которых спелл не применится. Всё, что здесь "
                "не нужно, должно быть нулём — лишнее условие превращается в "
                "«спелл молча не работает».",
        "fields": [
            f("EquippedItemClass", "int", "Класс предмета",
              hint="-1 — без требования к экипировке. 2 — оружие, 4 — броня: "
                   "спелл сработает, только если надет предмет этого класса."),
            f("EquippedItemSubclass", "int", "Подкласс предмета",
              hint="Битовая маска подклассов внутри класса (мечи, топоры). "
                   "-1 — любой."),
            f("EquippedItemInvTypes", "int", "Слоты предмета",
              hint="Маска слотов экипировки, в которых предмет должен "
                   "находиться."),
            f("Targets", "int", "Targets mask",
              hint="Маска допустимых типов цели (юнит, труп, предмет, точка "
                   "на земле) — SPELL_CAST_TARGET_FLAG_* в ядре."),
            f("TargetCreatureType", "int", "Тип существа",
              hint="Маска типов существ, на которых спелл действует: "
                   "нежить, демоны, звери. 0 — на всех."),
            f("RequiresSpellFocus", "int", "Требует фокус",
              hint="Рядом должен стоять объект-фокус (наковальня, "
                   "алхимический стол). 0 — не нужен."),
            f("ShapeshiftMask", "int", "Требуемые стойки",
              hint="Маска обличий/стоек, в которых спелл доступен "
                   "(медведь, кошка, боевые стойки). 0 — в любой."),
            f("ShapeshiftExclude", "int", "Исключённые стойки",
              hint="Маска обличий, в которых спелл, наоборот, запрещён."),
            f("CasterAuraState", "int", "Состояние кастера",
              hint="Кастер должен быть в состоянии (низкое здоровье, "
                   "оглушён, горит). 0 — без условия."),
            f("TargetAuraState", "int", "Состояние цели",
              hint="То же требование, но к цели."),
            f("ExcludeCasterAuraState", "int", "Исключая состояние кастера",
              hint="Если кастер в этом состоянии — спелл не применится. "
                   "Обратная сторона «Состояния кастера»."),
            f("ExcludeTargetAuraState", "int", "Исключая состояние цели",
              hint="Если цель в этом состоянии — спелл не применится."),
            f("CasterAuraSpell", "int", "Аура кастера (спелл)",
              hint="На кастере должна висеть аура именно этого спелла."),
            f("TargetAuraSpell", "int", "Аура цели (спелл)",
              hint="На цели должна висеть аура этого спелла."),
            f("ExcludeCasterAuraSpell", "int", "Исключая ауру кастера",
              hint="Если на кастере есть эта аура — спелл не применится."),
            f("ExcludeTargetAuraSpell", "int", "Исключая ауру цели",
              hint="Если на цели есть эта аура — спелл не применится."),
            f("RequiredAreasID", "int", "Требуемая зона",
              hint="Ссылка на AreaGroup.dbc: спелл работает только в этих "
                   "зонах. 0 — везде."),
            f("MinFactionID", "int", "Фракция",
              hint="Фракция, репутацию с которой проверяем. 0 — не проверяем."),
            f("MinReputation", "int", "Репутация",
              hint="Минимальный уровень репутации с указанной фракцией."),
            f("FacingCasterFlags", "int", "Facing flags",
              hint="1 — кастер должен стоять лицом к цели. 0 — не важно."),
        ],
    },
    {
        "id": "reagents", "label": "Реагенты и тотемы",
        "hint": "Что спелл тратит и что нужно иметь при себе. Пусто у "
                "подавляющего большинства спеллов — но именно эти поля делают "
                "копию рецепта или тотема настоящей копией.",
        "fields": _reagent_fields(),
    },
    {
        "id": "misc", "label": "Прочее",
        "hint": "Классификация спелла для боевых расчётов и мелкие "
                "клиентские поля.",
        "fields": [
            f("DefenseType", "enum", "Класс урона", enum="dmg_class",
              hint="Как считается попадание: магия (проверка сопротивления) "
                   "или ближний/дальний бой (промах, блок, парирование). "
                   "None — эффект не считается атакой."),
            f("PreventionType", "enum", "Тип блокировки", enum="prevention",
              hint="Чем спелл затыкается: молчанием (магия) или "
                   "обезоруживанием/пацификацией (физика)."),
            f("SpellClassSet", "int", "Семейство спеллов",
              hint="Семейство классовых спеллов: 3 — маг, 4 — воин, "
                   "6 — жрец, 15 — рыцарь смерти. Через него таланты "
                   "находят «свои» спеллы. Для кастомных обычно 0."),
            f("SpellClassMask_1", "int", "Family mask 1",
              hint="Бит внутри семейства — «адрес» спелла, по которому его "
                   "цепляют таланты. Нужен только вместе с семейством."),
            f("SpellClassMask_2", "int", "Family mask 2"),
            f("SpellClassMask_3", "int", "Family mask 3"),
            f("SpellMissileID", "int", "SpellMissileID",
              hint="Траектория снаряда (дуга, прямая) из SpellMissile.dbc."),
            f("SpellDescriptionVariableID", "int", "Description variable",
              hint="Ссылка на SpellDescriptionVariables.dbc — переменные для "
                   "текста тултипа. Для кастомных 0."),
            f("ModalNextSpell", "int", "Следующий спелл",
              hint="Спелл, в который кнопка превращается после применения."),
            f("SpellPriority", "int", "Приоритет",
              hint="Клиентский порядок сортировки на панели. На механику не "
                   "влияет."),
            f("StanceBarOrder", "int", "Порядок в панели стоек",
              hint="Позиция кнопки на панели стоек/обличий."),
            f("RequiredAuraVision", "int", "Требуемое видение",
              hint="Требование к «видению» (невидимые объекты фаз). "
                   "Обычно 0."),
        ],
    },
]


def _all_columns() -> list[str]:
    cols = ["ID"]
    for group in FIELD_GROUPS:
        cols += [x["col"] for x in group["fields"]]
    for index in (1, 2, 3):
        cols += [x["col"] % index for x in EFFECT_FIELDS]
    return cols


# Whitelist: nothing outside this set ever reaches a SQL statement, so a
# crafted payload cannot name an arbitrary column.
COLUMNS = _all_columns()
COLUMN_SET = set(COLUMNS)
TEXT_COLUMNS = {x["col"] for g in FIELD_GROUPS for x in g["fields"]
                if x["kind"] == "text"}

# The six `float` columns of `spell_dbc` (verified against information_schema).
# They are the spell-power and per-level coefficients: 0.6 rounded to 0 is the
# difference between a spell that scales and one that does not, so these are
# read and written as real numbers, not as the ints every other column is.
FLOAT_COLUMNS = {"Speed"} | {
    "%s_%d" % (name, index)
    for name in ("EffectRealPointsPerLevel", "EffectMultipleValue",
                 "EffectPointsPerCombo", "EffectChainAmplitude",
                 "EffectBonusMultiplier")
    for index in (1, 2, 3)
}


# --- reference data -------------------------------------------------------

_enums_cache: dict | None = None


def enums() -> dict:
    global _enums_cache
    if _enums_cache is None:
        with open(ENUMS_PATH, encoding="utf-8") as handle:
            _enums_cache = json.load(handle)
    return _enums_cache


_refs_cache: dict[str, list[dict]] | None = None

# Label builders for the *_dbc dropdowns: show the value, not just the index.
REF_TABLES = {
    "spellduration_dbc": ("ID", "Duration, DurationPerLevel, MaxDuration",
                          lambda r: _duration_label(r)),
    "spellcasttimes_dbc": ("ID", "Base, PerLevel, Minimum",
                           lambda r: _ms_label(r["Base"])),
    "spellrange_dbc": ("ID", "RangeMin_1, RangeMax_1",
                       lambda r: _range_label(r)),
    "spellradius_dbc": ("ID", "Radius, RadiusMax",
                        lambda r: "%g м" % r["Radius"]),
}


def _ms_label(ms: int) -> str:
    if not ms:
        return "мгновенно"
    return "%g с" % (ms / 1000.0)


def _duration_label(row: dict) -> str:
    """Human duration. Units go up to days: the file holds rows of hours and
    one of ~24 days, and printing those in minutes is unreadable."""
    duration = int(row["Duration"])
    if duration < 0:
        return "постоянная"
    if duration == 0:
        return "нет"
    if duration >= 86400000:
        return "%g дн" % round(duration / 86400000.0, 1)
    if duration >= 3600000:
        return "%g ч" % round(duration / 3600000.0, 2)
    if duration >= 60000:
        return "%g мин" % round(duration / 60000.0, 2)
    return "%g с" % (duration / 1000.0)


def _range_label(row: dict) -> str:
    low, high = float(row["RangeMin_1"]), float(row["RangeMax_1"])
    if not high:
        return "на себя"
    if low:
        return "%g–%g м" % (low, high)
    return "%g м" % high


def refs() -> dict[str, list[dict]]:
    """Dropdown contents for the index columns.

    Two sources, merged the way the server merges them: the client DBC file
    first, then the `*_dbc` table on top. In practice those tables are empty —
    the durations and ranges a spell can use come from the files — so without
    the DBC half every dropdown would offer exactly one option, the value the
    spell already had.
    """
    global _refs_cache
    if _refs_cache is not None:
        return _refs_cache

    # Deferred: spelldex imports this module, so the dependency can only run
    # one way at import time.
    from . import spelldex

    try:
        from_files = spelldex.ref_entries()
    except Exception:
        from_files = {}

    out: dict[str, list[dict]] = {}
    for table, (key, cols, label) in REF_TABLES.items():
        entries = {item["id"]: item for item in from_files.get(table, [])}
        try:
            rows = query("SELECT `%s`, %s FROM `%s` ORDER BY `%s`"
                         % (key, cols, table, key))
        except Exception:
            rows = []
        for row in rows:
            try:
                text = label(row)
            except Exception:
                text = ""
            entries[int(row[key])] = {"id": int(row[key]), "label": text}
        out[table] = [entries[key_] for key_ in sorted(entries)]
    _refs_cache = out
    return out


def reload_cache() -> None:
    global _enums_cache, _refs_cache
    _enums_cache = None
    _refs_cache = None


# --- panel-owned metadata -------------------------------------------------

META_SCHEMA = """
CREATE TABLE IF NOT EXISTS `spell_meta` (
  `spell_id`     INT UNSIGNED NOT NULL,
  `module`       VARCHAR(64) NOT NULL DEFAULT '',
  `icon_texture` VARCHAR(128) NOT NULL DEFAULT '',
  `notes`        TEXT NOT NULL,
  `author`       VARCHAR(64) NOT NULL DEFAULT '',
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                 ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`spell_id`),
  KEY `idx_module` (`module`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
"""

_meta_ready = False


def ensure_meta() -> None:
    """Metadata lives beside the board, in the panel's own schema."""
    global _meta_ready
    if _meta_ready:
        return
    board.ensure_schema()
    with board.cursor(commit=True) as cur:
        cur.execute(META_SCHEMA)
    _meta_ready = True


def meta_for(spell_ids: list[int]) -> dict[int, dict]:
    if not spell_ids:
        return {}
    ensure_meta()
    marks = ",".join(["%s"] * len(spell_ids))
    with board.cursor() as cur:
        cur.execute("SELECT * FROM spell_meta WHERE spell_id IN (%s)" % marks,
                    tuple(spell_ids))
        out = {}
        for row in cur.fetchall():
            row = dict(row)
            for field in ("created_at", "updated_at"):
                if isinstance(row.get(field), _dt.datetime):
                    row[field] = row[field].isoformat(sep=" ", timespec="minutes")
            out[int(row["spell_id"])] = row
        return out


def save_meta(spell_id: int, module: str, icon_texture: str, notes: str,
              author: str) -> None:
    ensure_meta()
    with board.cursor(commit=True) as cur:
        cur.execute(
            "INSERT INTO spell_meta (spell_id, module, icon_texture, notes, author) "
            "VALUES (%s,%s,%s,%s,%s) ON DUPLICATE KEY UPDATE "
            "module=VALUES(module), icon_texture=VALUES(icon_texture), "
            "notes=VALUES(notes), author=VALUES(author)",
            (spell_id, module, icon_texture, notes, author))


def delete_meta(spell_id: int) -> None:
    ensure_meta()
    with board.cursor(commit=True) as cur:
        cur.execute("DELETE FROM spell_meta WHERE spell_id = %s", (spell_id,))


# --- models ---------------------------------------------------------------

class SpellIn(BaseModel):
    id: int | None = None
    block: str | None = None
    module: str = ""
    icon_texture: str = ""
    notes: str = ""
    author: str = ""
    # Only whitelisted spell_dbc columns survive `_clean_fields`.
    fields: dict[str, Any] = Field(default_factory=dict)


class ValidationProblem(BaseModel):
    level: str          # error | warning
    text: str


# --- reads ----------------------------------------------------------------

def _effect_summary(row: dict) -> list[str]:
    """One short line per used effect, so the list is readable without opening."""
    by_id = {e["id"]: e["label"] for e in enums()["effects"]}
    auras = {a["id"]: a["label"] for a in enums()["auras"]}
    out = []
    for index in (1, 2, 3):
        effect = int(row.get("Effect_%d" % index) or 0)
        if not effect:
            continue
        text = by_id.get(effect, "effect %d" % effect)
        if effect == 6:      # APPLY_AURA
            aura = int(row.get("EffectAura_%d" % index) or 0)
            points = int(row.get("EffectBasePoints_%d" % index) or 0)
            text = "%s %+d" % (auras.get(aura, "aura %d" % aura), points + 1)
        out.append(text)
    return out


LIST_COLUMNS = ["ID", "Name_Lang_ruRU", "Name_Lang_enUS", "SchoolMask",
                "DurationIndex", "ProcChance", "Attributes", "SpellIconID"] + \
               ["Effect_%d" % i for i in (1, 2, 3)] + \
               ["EffectAura_%d" % i for i in (1, 2, 3)] + \
               ["EffectBasePoints_%d" % i for i in (1, 2, 3)]


# The cap is a guard against a runaway query, not a page size: all custom
# blocks together hold ~520 rows, and at the old 300 everything above the
# familiar ranges fell off the end of the sidebar — including all 86 row-5
# proc spells — which looked exactly like "этих спеллов нет".
def list_spells(block: str | None = None, module: str | None = None,
                q: str | None = None, limit: int = 2000) -> list[dict]:
    where, args = [], []
    if block and block in BLOCK_BY_ID:
        blk = BLOCK_BY_ID[block]
        where.append("`ID` BETWEEN %s AND %s")
        args += [blk.lo, blk.hi]
    else:
        # Stock Blizzard spells are not editable content; only custom blocks.
        where.append("`ID` >= %s")
        args.append(min(b.lo for b in BLOCKS))
    if q:
        if q.isdigit():
            where.append("(`ID` = %s OR `Name_Lang_ruRU` LIKE %s)")
            args += [int(q), "%" + q + "%"]
        else:
            where.append("(`Name_Lang_ruRU` LIKE %s OR `Name_Lang_enUS` LIKE %s)")
            args += ["%" + q + "%"] * 2
    sql = ("SELECT %s FROM `%s` WHERE %s ORDER BY `ID` LIMIT %d"
           % (", ".join("`%s`" % c for c in LIST_COLUMNS), TABLE,
              " AND ".join(where), int(limit)))
    rows = query(sql, tuple(args))
    metas = meta_for([int(r["ID"]) for r in rows])
    out = []
    for row in rows:
        spell_id = int(row["ID"])
        meta = metas.get(spell_id, {})
        blk = block_of(spell_id)
        if module and meta.get("module", blk.module if blk else "") != module:
            continue
        out.append({
            "id": spell_id,
            "name_ru": row["Name_Lang_ruRU"] or "",
            "name_en": row["Name_Lang_enUS"] or "",
            "block": blk.id if blk else None,
            "block_name": blk.name if blk else "вне блоков",
            "module": meta.get("module") or (blk.module if blk else ""),
            "icon_texture": meta.get("icon_texture") or resolved_icon_texture(
                spell_id, int(row["SpellIconID"] or 0)),
            "effects": _effect_summary(row),
            "duration_index": int(row["DurationIndex"] or 0),
            "proc_chance": int(row["ProcChance"] or 0),
        })
    return out


def resolved_icon_texture(spell_id: int, icon_id: int) -> str:
    """The icon the client draws, for spells the panel did not author.

    `spell_meta.icon_texture` is filled in only when someone picks an icon
    *here*, so every spell a module shipped had an empty icon field and a blank
    preview — even though the catalogue, reading `Spell_custom.csv` and
    `SpellIcon.dbc`, showed the picture. Display only: it is never written back
    into `spell_meta`, so opening a module's spell cannot quietly re-record its
    icon as a choice the operator made.
    """
    from . import spelldex

    try:
        return spelldex.workshop_icon(spell_id, icon_id)
    except Exception:
        return ""


def _typed(col: str, value: Any):
    """One column as the editor wants it: text, real number, or int."""
    if col in TEXT_COLUMNS:
        return value
    if col in FLOAT_COLUMNS:
        return round(float(value or 0), 6)
    return int(value or 0)


def get_spell(spell_id: int) -> dict | None:
    cols = ", ".join("`%s`" % c for c in COLUMNS)
    row = query_one("SELECT %s FROM `%s` WHERE `ID` = %%s" % (cols, TABLE),
                    (spell_id,))
    if not row:
        return None
    meta = meta_for([spell_id]).get(spell_id, {})
    blk = block_of(spell_id)
    return {
        "id": spell_id,
        "fields": {k: _typed(k, v) for k, v in row.items()},
        "module": meta.get("module") or (blk.module if blk else ""),
        "icon_texture": meta.get("icon_texture", ""),
        "icon_resolved": resolved_icon_texture(
            spell_id, int(row.get("SpellIconID") or 0)),
        "notes": meta.get("notes", ""),
        "author": meta.get("author", ""),
        "block": blk.id if blk else None,
        "updated_at": meta.get("updated_at"),
    }


def next_free_id(block_id: str) -> int | None:
    blk = BLOCK_BY_ID.get(block_id)
    if not blk:
        return None
    rows = query("SELECT `ID` FROM `%s` WHERE `ID` BETWEEN %%s AND %%s "
                 "ORDER BY `ID`" % TABLE, (blk.lo, blk.hi))
    taken = {int(r["ID"]) for r in rows}
    for candidate in range(blk.lo, blk.hi + 1):
        if candidate not in taken:
            return candidate
    return None


def block_status(block_id: str) -> dict | None:
    """One block with its live occupancy and the id a new spell would take.

    The editor asks for this every time the operator switches the pool, so the
    number under the select is the answer to "what id do I actually get", not a
    count cached when the page loaded.
    """
    blk = BLOCK_BY_ID.get(block_id)
    if not blk:
        return None
    row = query_one("SELECT COUNT(*) AS n FROM `%s` WHERE `ID` BETWEEN %%s "
                    "AND %%s" % TABLE, (blk.lo, blk.hi))
    return {**blk.model_dump(), "used": int(row["n"]) if row else 0,
            "size": blk.hi - blk.lo + 1,
            "next_free": next_free_id(blk.id)}


def block_usage() -> list[dict]:
    return [block_status(blk.id) for blk in BLOCKS]


def module_choices() -> list[dict]:
    """Modules a spell can be filed under, with the names the home page uses.

    The catalogue of modules is `registry.MODULES` — the same list the panel
    shows on its front page — plus any module a block names but the registry
    does not, so a block can never point at a module the editor cannot pick.
    """
    from . import registry

    out = [{"id": m.id, "name": m.name} for m in registry.MODULES]
    known = {m["id"] for m in out}
    for blk in BLOCKS:
        if blk.module and blk.module not in known:
            out.append({"id": blk.module, "name": blk.module})
            known.add(blk.module)
    return out


# --- clone ----------------------------------------------------------------
# "Make a new spell like that one." The source may be a row we own, a stock
# Blizzard spell, or a stock spell a module rewrote — so the values come from
# the same merge the catalogue shows, not from `spell_dbc` alone.

# The client's Spell.dbc keeps one `Name` column with a locale block inside it,
# while `spell_dbc` has a column per language. Each workshop text column is
# mapped to (DBC column, index into the ruRU CSV tuple) — the CSV is the only
# place the Russian strings of stock spells exist.
CLONE_TEXT_SOURCES = {
    "Name_Lang_ruRU": ("Name", 0),
    "Name_Lang_enUS": ("Name", None),
    "NameSubtext_Lang_ruRU": ("NameSubtext", 1),
    "Description_Lang_ruRU": ("Description", 2),
    "Description_Lang_enUS": ("Description", None),
    "AuraDescription_Lang_ruRU": ("AuraDescription", 3),
    "AuraDescription_Lang_enUS": ("AuraDescription", None),
}

# The one thing a copy must not inherit: two spells with the same name are
# indistinguishable in the tooltip, the combat log and this very list.
CLONE_SKIP_COLUMNS = ("Name_Lang_ruRU", "Name_Lang_enUS")

# `spell_dbc` column → the name the same field carries in the client Spell.dbc.
# Verified column by column against information_schema: the table's order is
# the file's field order exactly, and this pair is the only place where the two
# disagree about the *name*. Without the alias a copy of a totem spell would
# come out without its totem category.
CLONE_DBC_ALIASES = {
    "RequiredTotemCategoryID_1": "TotemCategory_1",
    "RequiredTotemCategoryID_2": "TotemCategory_2",
}


def _as_int(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        try:
            return int(float(value))
        except (TypeError, ValueError):
            return 0


def clone_draft(source_id: int, block_id: str = "workshop") -> dict:
    """An unsaved copy of `source_id`, ready for the editor.

    Nothing is written: the draft is handed to the frontend as if the operator
    had filled the form by hand, and the usual create path (with its
    validation) does the saving. That way a copy of a Blizzard spell still has
    to pass the same checks as a spell typed from scratch.
    """
    from . import spelldex

    merged = spelldex.merged_row(source_id)
    if merged is None:
        raise LookupError("Спелла %d нет ни в DBC, ни в spell_dbc." % source_id)
    row, db_row, source = merged

    blk = BLOCK_BY_ID.get(block_id)
    if not blk:
        raise ValueError("Неизвестный блок ID: %s" % block_id)
    new_id = next_free_id(block_id)
    if new_id is None:
        raise ValueError("В блоке «%s» не осталось свободных ID." % blk.name)

    try:
        ru = spelldex.text().get(source_id, ("", "", "", ""))
    except Exception:
        ru = ("", "", "", "")

    fields: dict[str, Any] = {}
    lossy: list[str] = []
    for col in COLUMNS:
        if col == "ID":
            continue
        if col in TEXT_COLUMNS:
            fields[col] = _clone_text(col, row, ru)
            continue
        value = row.get(col)
        if value is None and col in CLONE_DBC_ALIASES:
            value = row.get(CLONE_DBC_ALIASES[col])
        # Outside the six float columns the editor only knows integers, so a
        # fractional value would be silently truncated on save. Copy the
        # truncated number, but say which fields lost something.
        if col not in FLOAT_COLUMNS and isinstance(value, float) \
                and value != int(value):
            lossy.append("%s = %g → %d" % (col, value, int(value)))
        fields[col] = _typed(col, value)

    for col in CLONE_SKIP_COLUMNS:
        fields[col] = ""

    source_meta = meta_for([source_id]).get(source_id, {})
    try:
        icon_id, icon = spelldex.resolved_icon(source_id, row, source)
    except Exception:
        icon_id, icon = 0, ""
    # `export_client` writes the CSV icon column from this field, so carrying
    # the resolved id (not the placeholder a module left in `spell_dbc`) is
    # what makes the copy come out with the same picture.
    if icon_id:
        fields["SpellIconID"] = icon_id
    icon = source_meta.get("icon_texture") or icon

    source_name = (ru[0] or (db_row or {}).get("Name_Lang_ruRU")
                   or row.get("Name") or (db_row or {}).get("Name_Lang_enUS")
                   or "")

    warnings: list[str] = []
    if lossy:
        warnings.append("Дробные значения округлены: " + ", ".join(lossy[:6]))
    dropped = _unsupported_columns(row)
    if dropped:
        warnings.append(
            "Панель не умеет эти поля, в копии они будут нулевыми: "
            + ", ".join(dropped[:8]))
    if source == spelldex.SOURCE_DBC:
        warnings.append(
            "Источник — стоковый спелл Blizzard. Скрипты ядра, привязанные к "
            "его ID, на копию не перейдут: копируются только поля DBC.")

    return {
        "id": new_id,
        "block": block_id,
        "module": source_meta.get("module") or blk.module,
        "icon_texture": icon,
        "notes": "Копия #%d «%s»" % (source_id, source_name) if source_name
                 else "Копия #%d" % source_id,
        "author": source_meta.get("author", ""),
        "fields": fields,
        "clone_of": {"id": source_id, "name": source_name, "source": source},
        "warnings": warnings,
    }


def _unsupported_columns(row: dict) -> list[str]:
    """Columns the source uses that the field catalogue has no editor for.

    Reagents, totems and the two `Exclude*AuraState` columns are the usual
    hits. They are not copied — the INSERT only names whitelisted columns — so
    the honest thing is to say which ones the copy will not carry.
    """
    covered = COLUMN_SET | set(CLONE_DBC_ALIASES.values())
    out = []
    for col, value in row.items():
        # Strings here are the DBC's own locale columns (`Name`, `Description`),
        # which `_clone_text` already folds into the workshop's text fields.
        if col in covered or isinstance(value, str):
            continue
        if _as_int(value):
            out.append(col)
    return sorted(out)


def _clone_text(col: str, row: dict, ru: tuple) -> str:
    """One text column, preferring the most specific source there is:
    `spell_dbc` → the ruRU CSV → the English string in the DBC."""
    value = row.get(col)
    if value:
        return str(value)
    dbc_col, ru_index = CLONE_TEXT_SOURCES.get(col, (None, None))
    if ru_index is not None and len(ru) > ru_index and ru[ru_index]:
        return str(ru[ru_index])
    if dbc_col and row.get(dbc_col):
        return str(row[dbc_col])
    return ""


# --- validation -----------------------------------------------------------

APPLY_AURA = 6
NO_AURA_CANCEL = 0x80000000


def _clean_fields(raw: dict[str, Any]) -> dict[str, Any]:
    """Drop anything not on the whitelist, coerce to the column's type."""
    out: dict[str, Any] = {}
    for col, value in raw.items():
        if col not in COLUMN_SET or col == "ID":
            continue
        if col in TEXT_COLUMNS:
            out[col] = "" if value is None else str(value)[:800]
        elif col in FLOAT_COLUMNS:
            try:
                out[col] = float(value)
            except (TypeError, ValueError):
                out[col] = 0.0
        else:
            try:
                out[col] = int(value)
            except (TypeError, ValueError):
                out[col] = 0
    return out


def validate(spell_id: int, fields: dict[str, Any], icon_texture: str,
             creating: bool) -> list[ValidationProblem]:
    problems: list[ValidationProblem] = []

    def err(text):
        problems.append(ValidationProblem(level="error", text=text))

    def warn(text):
        problems.append(ValidationProblem(level="warning", text=text))

    blk = block_of(spell_id)
    if not blk:
        warn("ID %d вне известных блоков модулей — можно случайно "
             "перекрыть чужой спелл." % spell_id)

    if creating:
        exists = query_one("SELECT `ID` FROM `%s` WHERE `ID` = %%s" % TABLE,
                           (spell_id,))
        if exists:
            err("Спелл с ID %d уже существует." % spell_id)

    has_aura = any(int(fields.get("Effect_%d" % i) or 0) == APPLY_AURA
                   for i in (1, 2, 3))
    if has_aura:
        # Both of these fail silently in game rather than erroring, which is
        # exactly why they are hard errors here.
        if not int(fields.get("DurationIndex") or 0):
            err("APPLY_AURA без DurationIndex — аура не повесится. "
                "21 = постоянная, 5 = 5 минут, 9 = 30 секунд.")
        if not int(fields.get("ProcChance") or 0):
            err("APPLY_AURA с ProcChance=0 — аура может не примениться. "
                "В модулях стоит 101.")
        if not int(fields.get("Attributes") or 0) & NO_AURA_CANCEL:
            warn("Без флага NO_AURA_CANCEL (0x80000000) игрок сможет снять "
                 "ауру правым кликом.")

    for index in (1, 2, 3):
        effect = int(fields.get("Effect_%d" % index) or 0)
        aura = int(fields.get("EffectAura_%d" % index) or 0)
        if effect == APPLY_AURA and not aura:
            err("Эффект %d: APPLY_AURA без выбранной ауры." % index)
        if aura and effect != APPLY_AURA:
            warn("Эффект %d: аура задана, но Effect не APPLY_AURA — "
                 "ядро её проигнорирует." % index)
        if effect and not int(fields.get("ImplicitTargetA_%d" % index) or 0):
            warn("Эффект %d: не задана цель A — эффект обычно не сработает."
                 % index)

    if not any(int(fields.get("Effect_%d" % i) or 0) for i in (1, 2, 3)):
        err("Ни одного эффекта — спелл ничего не делает.")

    for slot in range(1, 9):
        reagent = int(fields.get("Reagent_%d" % slot) or 0)
        count = int(fields.get("ReagentCount_%d" % slot) or 0)
        if reagent and not count:
            warn("Реагент %d задан без количества — ядро его не спишет."
                 % slot)
        if count and not reagent:
            warn("У реагента %d есть количество, но не задан предмет." % slot)

    if not (fields.get("Name_Lang_ruRU") or "").strip():
        warn("Пустое русское название.")
    if not icon_texture.strip():
        # Пустое поле ещё не значит «без значка»: у спелла, который завела не
        # панель, иконка записана в Spell_custom.csv или в SpellIconID, и
        # клиент её рисует. Ругаться стоит, только если её правда нет.
        if not resolved_icon_texture(spell_id,
                                     int(fields.get("SpellIconID") or 0)):
            warn("Не задана иконка — в клиенте спелл будет без значка.")
    else:
        from . import spelldex
        try:
            known = spelldex.icon_id_of(icon_texture)
        except Exception:
            known = -1          # каталог недоступен, судить не о чем
        if known == 0:
            warn("Иконки «%s» нет ни в SpellIcon.dbc, ни в "
                 "SpellIcon_custom.csv — «Экспорт в клиент» оставит "
                 "заглушку." % icon_texture.strip())

    return problems


# --- writes ---------------------------------------------------------------

STUB_ICON_ID = 1


def _apply_icon_id(fields: dict[str, Any], icon_texture: str) -> None:
    """Turn the picked texture into the id `export_client` writes to the CSV.

    The operator chooses a picture; the client's Spell.dbc stores a
    `SpellIconID`. Without this the workshop showed the chosen icon while the
    exported client row kept the placeholder 1 — a wrench on every hand-made
    spell. Only a stub is overwritten, so an id typed on purpose survives.
    """
    if not icon_texture:
        return
    if _as_int(fields.get("SpellIconID")) not in (0, STUB_ICON_ID):
        return
    from . import spelldex
    try:
        icon_id = spelldex.icon_id_of(icon_texture)
    except Exception:
        return
    if icon_id:
        fields["SpellIconID"] = icon_id


def save_spell(payload: SpellIn, creating: bool) -> int:
    fields = _clean_fields(payload.fields)
    _apply_icon_id(fields, payload.icon_texture)
    spell_id = int(payload.id)

    cols = ["`ID`"] + ["`%s`" % c for c in fields]
    marks = ["%s"] * (len(fields) + 1)
    args: list[Any] = [spell_id] + list(fields.values())

    if creating:
        sql = ("INSERT INTO `%s` (%s) VALUES (%s)"
               % (TABLE, ", ".join(cols), ", ".join(marks)))
    else:
        sets = ", ".join("`%s` = %%s" % c for c in fields)
        sql = "UPDATE `%s` SET %s WHERE `ID` = %%s" % (TABLE, sets)
        args = list(fields.values()) + [spell_id]

    with world_cursor(commit=True) as cur:
        cur.execute(sql, tuple(args))

    save_meta(spell_id, payload.module, payload.icon_texture, payload.notes,
              payload.author)
    return spell_id


def delete_spell(spell_id: int) -> bool:
    with world_cursor(commit=True) as cur:
        cur.execute("DELETE FROM `%s` WHERE `ID` = %%s" % TABLE, (spell_id,))
        deleted = cur.rowcount > 0
    delete_meta(spell_id)
    return deleted


# --- pending restart ------------------------------------------------------

# `.server info` answers e.g. "Server uptime: 1 hour(s) 41 minute(s) 59
# second(s)". Each unit is matched on its own: a single regex with every group
# optional would happily match the empty string and report zero.
UPTIME_UNITS = ((r"(\d+)\s*day", 86400), (r"(\d+)\s*hour", 3600),
                (r"(\d+)\s*minute", 60), (r"(\d+)\s*second", 1))


def _uptime_seconds() -> int | None:
    """Worldserver uptime via SOAP `.server info`, or None if unavailable."""
    try:
        text = soap.execute("server info", timeout=8.0)
    except Exception:
        return None
    line = re.search(r"uptime[^\r\n]*", text, re.I)
    if not line:
        return None
    total = 0
    for pattern, multiplier in UPTIME_UNITS:
        match = re.search(pattern, line.group(0), re.I)
        if match:
            total += int(match.group(1)) * multiplier
    return total or None


def pending_restart() -> dict:
    """Spells saved since the worldserver started — they are not live yet.

    Derived from the server's own uptime rather than a flag the panel sets, so
    it cannot get stuck showing a restart that already happened.
    """
    ensure_meta()
    uptime = _uptime_seconds()
    if uptime is None:
        return {"known": False, "count": 0,
                "reason": "SOAP недоступен — не могу узнать аптайм PTR."}
    started = _dt.datetime.now() - _dt.timedelta(seconds=uptime)
    with board.cursor() as cur:
        cur.execute("SELECT COUNT(*) AS n FROM spell_meta WHERE updated_at >= %s",
                    (started,))
        row = cur.fetchone()
    return {"known": True, "count": int(row["n"]) if row else 0,
            "started_at": started.isoformat(sep=" ", timespec="seconds")}


# --- export ---------------------------------------------------------------

def _sql_literal(value: Any) -> str:
    if isinstance(value, str):
        return "'%s'" % value.replace("\\", "\\\\").replace("'", "''")
    # Floats keep their fraction: `int()` here used to turn a 0.6 coefficient
    # into 0 in the exported migration.
    if isinstance(value, float):
        return repr(round(value, 6))
    return str(int(value))


def export_sql(block: str | None = None) -> dict:
    """Write the custom spell rows to a pending migration, like the rules are."""
    blocks = [BLOCK_BY_ID[block]] if block and block in BLOCK_BY_ID else BLOCKS
    lines = [
        "-- Кастомные спеллы — выгружено админ-панелью (Мастерская).",
        "-- Источник правды — acore_world_ptr.spell_dbc; правьте в панели, "
        "не здесь.",
        "-- spell_dbc читается только при старте worldserver: после применения "
        "нужен рестарт.",
        "",
    ]
    total = 0
    cols = ", ".join("`%s`" % c for c in COLUMNS)
    for blk in blocks:
        rows = query("SELECT %s FROM `%s` WHERE `ID` BETWEEN %%s AND %%s "
                     "ORDER BY `ID`" % (cols, TABLE), (blk.lo, blk.hi))
        if not rows:
            continue
        lines.append("-- %s (%d): %d-%d" % (blk.name, len(rows), blk.lo, blk.hi))
        for row in rows:
            values = ", ".join(_sql_literal(row[c]) for c in COLUMNS)
            lines.append("REPLACE INTO `spell_dbc` (%s)\n  VALUES (%s);"
                         % (cols, values))
            total += 1
        lines.append("")

    path = os.path.join(os.path.dirname(config.SEED_SQL),
                        "admin_panel_spells.sql")
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")
    os.replace(tmp, path)
    return {"path": path, "spells": total}


# Column indices inside .claude/dbc/Spell_custom.csv. Taken from the module's
# gen_spell_custom.py, which was verified against a known-good row: ruRU sits
# at enUS+8 in DATA rows, NOT at the position its header claims.
CSV_ID, CSV_ATTR, CSV_ICON = 0, 4, 131
CSV_NAME_EN, CSV_NAME_RU = 134, 142
CSV_DESC_COLS = [168, 176, 179, 185, 193, 196]


def export_client(template_id: int = 107000) -> dict:
    """Patch the workshop's spells into .claude/dbc/Spell_custom.csv.

    A known-good row is cloned as the structural template so all 232 columns
    (masks, hidden trailing fields) stay in place; only id, attributes, icon,
    name and description are overwritten. Rebuilding the MPQ from this CSV
    remains a manual step.
    """
    import csv

    path = config.SPELL_CUSTOM_CSV
    if not os.path.isfile(path):
        raise FileNotFoundError(
            "Не найден %s — примонтируйте .claude/dbc в контейнер." % path)

    with open(path, encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle))
    if len(rows) < 2:
        raise ValueError("Spell_custom.csv пуст или без заголовка.")

    header, data = rows[0], rows[1:]
    template = next((r for r in data if r and r[CSV_ID] == str(template_id)), None)
    if template is None:
        raise ValueError("В CSV нет строки-шаблона %d." % template_id)

    ensure_meta()
    with board.cursor() as cur:
        cur.execute("SELECT spell_id, icon_texture FROM spell_meta")
        icons = {int(r["spell_id"]): r["icon_texture"] for r in cur.fetchall()}

    wanted = sorted(icons)
    if not wanted:
        return {"path": path, "written": 0, "note": "нет спеллов с иконками"}

    marks = ",".join(["%s"] * len(wanted))
    db_rows = {int(r["ID"]): r for r in query(
        "SELECT `ID`, `Attributes`, `SpellIconID`, `Name_Lang_enUS`, "
        "`Name_Lang_ruRU`, `Description_Lang_ruRU` FROM `%s` WHERE `ID` IN (%s)"
        % (TABLE, marks), tuple(wanted))}

    by_id = {r[CSV_ID]: i for i, r in enumerate(data) if r}
    written = 0
    for spell_id in wanted:
        source = db_rows.get(spell_id)
        if not source:
            continue
        row = list(template)
        row[CSV_ID] = str(spell_id)
        row[CSV_ATTR] = str(int(source["Attributes"] or 0))
        row[CSV_ICON] = str(int(source["SpellIconID"] or 1))
        row[CSV_NAME_EN] = source["Name_Lang_enUS"] or ""
        row[CSV_NAME_RU] = source["Name_Lang_ruRU"] or ""
        for column in CSV_DESC_COLS:
            if column < len(row):
                row[column] = source["Description_Lang_ruRU"] or ""
        key = str(spell_id)
        if key in by_id:
            data[by_id[key]] = row
        else:
            data.append(row)
        written += 1

    data.sort(key=lambda r: int(r[CSV_ID]) if r and r[CSV_ID].isdigit() else 0)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(header)
        writer.writerows(data)
    os.replace(tmp, path)
    return {"path": path, "written": written}


def catalog() -> dict:
    return {
        "enums": enums(),
        "refs": refs(),
        "groups": FIELD_GROUPS,
        "effect_fields": EFFECT_FIELDS,
        "blocks": block_usage(),
        "modules": module_choices(),
        "text_columns": sorted(TEXT_COLUMNS),
        "float_columns": sorted(FLOAT_COLUMNS),
    }
