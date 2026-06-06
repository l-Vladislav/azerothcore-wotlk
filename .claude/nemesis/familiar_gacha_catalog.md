# Каталог гача-петомцев Немезиды — 100 шт. (10×10)

Главный обзор гача-системы. **Детальные таблицы петомцев по семействам — в подпапке [.claude/familiars/](../familiars/)**, по одному файлу на стихию. Здесь — глобальные сведения: распределение редкостей, формулы ID-маппинга, drop-rates, сводка aura ID, история реорганизации.

Компаньон-файлы:
- [familiar_gacha_design.md](familiar_gacha_design.md) — общий дизайн (концепция, фазы, attribute-требования).
- [familiar_gacha_id_reservations.md](familiar_gacha_id_reservations.md) — диапазоны ID.
- [familiar_gacha_status.md](familiar_gacha_status.md) — статус фаз и последние правки.
- [.claude/familiars/README.md](../familiars/README.md) — индекс per-family файлов.

## Структура пула

| Семейство | Файл | Доминирующая роль |
|---|---|---|
| 1. Механический | [01_mech.json](../familiars/01_mech.json) | Танк (броня / Sta / блок) |
| 2. Огненный | [02_fire.json](../familiars/02_fire.json) | Magic DPS (Fire) |
| 3. Ледяной | [03_ice.json](../familiars/03_ice.json) | Magic DPS (Frost) |
| 4. Природный | [04_nature.json](../familiars/04_nature.json) | Хилер / Друид |
| 5. Светлый | [05_light.json](../familiars/05_light.json) | Healer + Resist Tank |
| 6. Теневой | [06_shadow.json](../familiars/06_shadow.json) | Shadow DoT / Debuff-res |
| 7. Тайный | [07_arcane.json](../familiars/07_arcane.json) | Arcane DPS |
| 8. Демонический | [08_demon.json](../familiars/08_demon.json) | TBD (бывш. Гроза) |
| 9. Зверь | [09_beast.md](../familiars/09_beast.md) | Phys DPS |
| 10. Дух | [10_spirit.md](../familiars/10_spirit.md) | Utility (XP / honor / rep) |

## Распределение редкостей

Каждое семейство = **6 Common + 3 Rare + 1 Epic** = 10 петомцев.

Common внутри семейства организован как **3 базовых темы × 2 варианта**:
- **Чистый** вариант: 1 положительный эффект, +1% или +2%.
- **Побитый** вариант (того же базового питомца, другое имя, **одинаковый `CreatureDisplayID`**): тот же +1–2% бафф **и** маленький −1% дебафф.

| Категория | Кол-во | Форма эффектов |
|---|---|---|
| Common (чистый) | 30 | 1 эффект, +1% или +2% |
| Common (побитый/тусклый/ржавый) | 30 | тот же положительный эффект + маленький −1% дебафф |
| Rare (чистый апгрейд) | 30 | 2 эффекта, без штрафа |
| Epic (комплекс + трейд-офф) | 10 | 3 баффа + 1–2 штрафа в overflow-ауре |
| **Итого** | **100** | |

## Линейное соответствие ID (10×10)

Для семейства `F` (1..10) и питомца `P` (1..10):

| Сущность | Формула | Диапазон |
|---|---|---|
| Сущность (creature entry) | `191000 + (F−1)*10 + (P−1)` | 191000–191099 |
| Призыв (summon spell) | `102000 + (F−1)*10 + (P−1)` | 102000–102099 |
| Позитивная аура (бафф-бар) | `103000 + (F−1)*10 + (P−1)` | 103000–103099 |
| Негативная аура (дебафф-бар) | `104000 + (F−1)*10 + (P−1)` (только у flawed Common и Epic со штрафами) | 104000–104099 |
| Свиток (item) | `110000 + (F−1)*10 + (P−1)` | 110000–110099 |
| Сундук стихии | `110100 + (F−1)` | 110100–110109 |

Универсальный сундук `110120` и токен таверны `110150` — без изменений. `110110–110119` свободны.

## Шансы выпадения

- **Универсальный сундук «Сундук Авантюриста»** (item 110120) — 1 жетон. Пул: все 100. **89% C / 10% R / 1% E**. На одного петомца: C 1.483%, R 0.333%, E 0.100%.
- **Сундук стихии «Сундук <Стихия>»** (110100–110109) — 3 жетона. Пул: 10 петомцев своей стихии. **70% C / 20% R / 10% E**. На одного петомца: C 11.67%, R 6.67%, E 10.00%.
- Сундук стихии даёт нужный Epic с вероятностью **10%** против **0.1%** в универсальном → соотношение **×100** за **×3** цены.

## Общие требования к аурам (spell_dbc)

Применимо ко всем 100 первичным аурам и 10 overflow-аурам:

```
Attributes        = 2147483648  (0x80000000 = SPELL_ATTR0_NO_AURA_CANCEL — игрок
                                 не может снять; снимает только C++-хук при де-спауне.
                                 НЕ passive — passive уводит triggered-cast в
                                 learned-only путь и аура no-op-ит.)
DurationIndex     = 21          (SpellDuration row 21 = -1/-1/-1 → permanent, без таймера)
ProcChance        = 101         (обязательно; иначе APPLY_AURA discarded)
RangeIndex        = 1           (self)
EquippedItemClass = -1
SchoolMask        = 1
SpellIconID       = TBD         (Фаза 2)
EffectDieSides_N  = 1           (обязательно; иначе amount=0)
ImplicitTargetA_N = 1           (на хозяина — caster)
```

См. [familiar_gacha_design.md](familiar_gacha_design.md) → «spell_dbc row shape», и memory `feedback_familiar_aura_uncancellable` + `feedback_spell_dbc_aura_fields`.

## Сводка используемых aura ID

| Aura ID | Константа | Семейства |
|---|---|---|
| 22 | MOD_RESISTANCE | 1, 2, 3, 4, 5, 6 |
| 31 | MOD_INCREASE_SPEED | 1, 3, 4, 5, 8, 9, 10 |
| 49 | MOD_DODGE_PERCENT | 1, 6, 8, 9, 10 |
| 51 | MOD_BLOCK_PERCENT | 1 |
| 57 | MOD_SPELL_CRIT_CHANCE | 2, 3, 6, 7 |
| 65 | MOD_CASTING_SPEED_NOT_STACK | 2, 3, 6, 7, 8 |
| 79 | MOD_DAMAGE_PERCENT_DONE | 2, 3, 5, 6, 7, 8, 9 |
| 101 | MOD_RESISTANCE_PCT | 1, 8 |
| 110 | MOD_POWER_REGEN_PERCENT | 4, 7 |
| 118 | MOD_HEALING_PCT | 5 |
| 136 | MOD_HEALING_DONE_PERCENT | 4, 5 |
| 137 | MOD_TOTAL_STAT_PERCENTAGE | все |
| 156 | MOD_REPUTATION_GAIN | 10 |
| 166 | MOD_ATTACK_POWER_PCT | 4, 9 |
| 178 | MOD_DEBUFF_RESISTANCE | 6 |
| 192 | MOD_MELEE_RANGED_HASTE | 1, 8, 9, 10 |
| 200 | MOD_XP_PCT | 10 |
| 235 | MOD_DISPEL_RESIST | 6 |
| 280 | MOD_ARMOR_PENETRATION_PCT | 9 |
| 281 | MOD_HONOR_GAIN_PCT | 10 |
| 290 | MOD_CRIT_PCT | 1, 6, 8, 9 |

## Количество строк spell_dbc

- **100 призывов** (102000–102099) — фиксированный паттерн, summon-эффект.
- **100 positive-аур** (103000–103099) — APPLY_AURA только положительные эффекты, рендерятся на бафф-баре.
- **40 negative-аур** (104000–104099) — APPLY_AURA только отрицательные эффекты, рендерятся на дебафф-баре. Создаются для 30 flawed Common (1 эффект каждая) + 10 Epic (1–2 эффекта каждая).
- **Итого: 240 строк spell_dbc.**

См. `familiar_gacha_design.md` → «Aura effect encoding» — почему split-on-sign обязателен (клиент 3.3.5a классифицирует spell как positive/negative целиком, а не по эффектам).

## История реорганизации

| Дата | Переход | Замечания |
|---|---|---|
| 2026-04 | 3 ролей × 5 тиров | Только T1 (3 петомца) задеплоен. |
| 2026-05-18 | → 20 семейств × 5 петомцев | Первичный дизайн гачи, ID reservations. |
| 2026-05-22 | → **10 семейств × 10 петомцев** | Common развёрнут в 3 базовых × 2 варианта. Натуральные пары clean/побитый с общим DisplayID. Каталог разнесён по `.claude/familiars/*.md`. T1 SQL на PTR обновлён: `Attributes=2147483648` (NO_AURA_CANCEL). |

**Миграция трёх ранее задеплоенных T1-петомцев в новый пул** (Common slot 1 — clean variant):

| Старый entry | Новый entry | Семейство.Слот |
|---|---|---|
| 190010 Волчонок-Страж | 191000 | 1.1 Механический |
| 190011 Соколёнок | 191070 | 8.1 Демонический (слот переименован, бывш. Гроза) |
| 190012 Воронёнок | 191050 | 6.1 Тень |
