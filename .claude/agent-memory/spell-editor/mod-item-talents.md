# mod-item-talents spell memory ("Пробуждение снаряжения")

## ID range

`108000-108099` reserved for row-5 ("Пробуждение", legendary awakening)
proc spells. Verified free at time of reservation except `108500` (env-effects
night debuff, unrelated module, does not collide).

- `108000-108042` — HIDDEN trigger-marker passives (Effect=6 APPLY_AURA DUMMY,
  permanent, `Attributes=2147483840` [NO_AURA_CANCEL+PASSIVE+DO_NOT_DISPLAY],
  `AttributesEx=268435456` [NO_AURA_ICON]). Server-only, **never add to
  `Spell_custom.csv`** — no client visibility needed or wanted.
- `108050-108092` — VISIBLE effect spells (buffs/debuffs/damage/heal/summon
  markers) triggered by the hidden passives via `CastCustomSpell` with a
  basepoints override. **These got client rows in `Spell_custom.csv` on
  2026-07-06** (43 rows).
- `108900-108914` — aura-perk ranks (row 3/4 "Заточка"/"Закалка" stat auras,
  5 ranks). Confirmed via `pending_db_world/mod_item_talents_aura_spells.sql`
  and `project_item_talents` user memory. **Not yet in `Spell_custom.csv`** as
  of 2026-07-06 — do this if asked for row 3/4 client visibility.

## Canonical spec

`.claude/item-talents/CUSTOM_SPELLS.md` — RU names/texts/APPROVED icon
filenames for the 43 visible spells, id-sorted, grouped by weapon archetype
(armor/melee/ranged/caster). Source of truth for text; SQL is source of truth
for numeric effect fields (Effect/Aura/DurationIndex/SchoolMask/EffectMiscValue
etc.) since server behavior must visually match.

Server DB seed: `data/sql/updates/pending_db_world/mod_item_talents_proc_spells.sql`
— already has `$s1`-substituted RU descriptions (client text should mirror
these verbatim, not re-derive from CUSTOM_SPELLS.md's `{N}` placeholders).

## Client CSV pattern used for 108050-108092 (2026-07-06)

Straight port of the SQL row's numeric fields into the 232-col
`Spell_custom.csv` layout (see `dbc-vs-sql.md` / verified column map in
`mod-environmental-effects.md` — same file, same offsets apply project-wide):

- `Attributes=0`/`AttributesEx=0` (NOT the hidden-trigger's NO_AURA_CANCEL
  bits — these are normal timed buffs/debuffs, not permanent markers).
- Name/Description/AuraDescription written **identically** into both the
  enUS slot and the real ruRU slot (enUS_index+8): 134/142, 168/176, 185/193.
  AuraDescription filled for ALL 43 rows uniformly (even instant-effect spells
  with no aura bar entry) — harmless when unused, guarantees buff-bar tooltip
  text is never missing for the ones that do have `Effect_1=6`.
  Header-nominal ruRU positions (145/179/196) left at default `'0'`, NOT
  filled — matches the "corrected" pattern in the env-effects 108500 row
  (its Name col shows this cleanly: 142 has text, 145 is blank; its
  Description col still has legacy leftover text at both 176 and 179 from
  before a fix — don't copy that leftover duplication, it's cruft not spec).
- `SpellIconID` resolved from `.claude/dbc/SpellIcon.csv` (name→id lookup,
  case-insensitive, matched by trailing path segment). Only **one**
  substitution needed: `Spell_Frost_ManaRecharges` (spell 108090, "Эхо маны")
  does not exist client-side — nearest/correct existing icon is
  `Spell_Frost_ManaRecharge` (singular, id **36**), almost certainly a typo
  in the original list, not a real reroute.
- `EquippedItemClass=-1` for all (matches SQL; not weapon-restricted).

Generator used (one-off, not committed as a script):
scratchpad `gen_it_spells.py`, hardcodes the 43 SQL tuples + icon map, appends
232-col rows via Python, LF line endings (file has no CRLF anywhere).

## Gotcha: id_mapping.json is NOT what it claims to be

See `custom-id-range.md` → "Caveat learned 2026-07-06". Don't try to register
mod-item-talents IDs there; it's some other agent's flat remap table, not a
reservation ledger.
