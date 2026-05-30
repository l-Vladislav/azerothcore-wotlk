# Common — clean + «побитый» pair convention

6 Common slots per family = **3 base pets × 2 variants**.

## Slot layout per family

| Slot | Variant | Effect shape |
|---|---|---|
| F.1 | clean | 1 effect, +1% or +2% |
| F.2 | flawed «побитый» of F.1 | same +1−2% buff + small −1% debuff |
| F.3 | clean | 1 effect, +1% or +2% |
| F.4 | flawed of F.3 | same buff + −1% debuff |
| F.5 | clean | 1 effect, +1% or +2% |
| F.6 | flawed of F.5 | same buff + −1% debuff |

## Visual identity

**Same `CreatureDisplayID` for clean ↔ flawed pair.** Players see one model, the buff-bar differs only by spell name and the small debuff. The pair-with-debuff slot uses a thematic adjective by element:

- Механический: «Ржавая», «Треснувшая», «Побитый» — rusted/cracked
- Огонь: «Тлеющий», «Подкопчёный» — smouldering
- Лёд: «Талый», «Подтаявший» — melting
- Природа: «Поблёкший», «Увядший» — wilted
- Свет: «Тусклый», «Помутневший» — dimmed
- Тень: «Полинявший», «Истончённый» — faded
- Тайна: «Помутневший», «Туманный» — clouded
- Гроза: «Грозовой» (опалённый разрядом), «Опалённый»
- Зверь: «Облезлый», «Тощий» — mangy
- Дух: «Ржавый», «Заевший» — rusted

Exact adjective list lives in each family's `.claude/familiars/0X_<element>.md` header.

## Why this design

- Pool feels organic — duplicates of a familiar pet model with slight stat variance, not literal repeats.
- Collectible value preserved: completing both clean+flawed of all 3 base pets = 6 distinct entries to chase.
- Net power slightly lower on flawed → no inflation from 60 commons.

## Implementation notes

- Both variants share `CreatureDisplayID`. Don't reserve a separate one.
- Separate `creature_template` entries (different `entry`), separate `creature_template_locale` row, separate scrolls/spells/auras (entries `F.1` and `F.2` are 2 distinct IDs in every range).
- The buff lives in `103000+idx` (positive-only, lands on buff bar). The debuff for a flawed variant lives in a **separate** `104000+idx` row (negative-only, lands on debuff bar). See [aura-template.md](aura-template.md) → «Split positive / negative».
- Clean and flawed pets each have their own `103xxx` row (identical content for the +buff). Only the flawed has a `104xxx` row.
