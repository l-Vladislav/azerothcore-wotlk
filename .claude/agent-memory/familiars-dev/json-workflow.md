# Familiar JSON workflow + SQL/CSV generator

Since 2026-05-30 each family's source of truth is a structured JSON, not a markdown
table. The `.md` per-family files are deprecated baseline; migrate-on-touch.

## Source of truth

- `.claude/familiars/0X_<key>.json` — one per family. Migrated so far: **01_mech** (Механический; 2026-05-30, family 1 was renamed from «Камень»/stone).
- The old `.md` tables are removed as each family migrates. README + `familiar_gacha_catalog.md`
  point at the `.json` for migrated families.

## JSON schema (per pet)

```json
{ "family":1, "key":"mech", "name":"Механический", "role":"Танк", "chestItem":110100,
  "pets":[ {
    "fp":"1.2", "rarity":"C", "name":"Побитый Волчонок",
    "status":"confirmed",            // draft = baseline carried over; confirmed = owner-reviewed
    "displayId":4124, "scale":0.8,
    "icon":{ "spellIconId":1573, "name":null, "fileDataId":null, "sourceSpell":24604 },
    "ids":{ "creature":191001,"summon":102001,"buffAura":103001,"debuffAura":104001,"scroll":110001 },
    "sources":{ "modelNpc":1817 },
    "effects":{ "positive":[{"code":"101/1","value":1,"text":"+1% броня"}],
                "negative":[{"code":"31","value":-1,"text":"-1% скорость движения"}] } } ] }
```

- `ids` are FORMULA-derived from fp (creature 191000+off, summon 102000+off,
  buffAura 103000+off, scroll 110000+off, debuffAura 104000+off only when negatives exist).
- `code` = aura index or `aura/misc` (e.g. `137/2` Sta, `137/4` Spi, `137/3` Int, `101/1` armor,
  `51` block, `192` haste, `31` move, `49` dodge, `166` AP, `290` crit, `22/126` all-magic-resist).
- `value` = percent; sign decides buff(103xxx) vs debuff(104xxx).

## Owner input format (what the owner sends per pet)

```
<fp> | <name> | npc=<id> | scale <n> | spell=<id>  (or icon name) | buff: <effects> | debuff: <effects>
```
- `npc=` → resolve to CreatureDisplayID via `ptr-query` (creature_template_model). Items/itemid do NOT
  give creature models. WebFetch can't read displayId off wowhead (JS) — use ptr-query.
- `spell=` → resolve SpellIconID from local `.claude/dbc/Spell.csv` (Import-Csv, by ID). This is the
  real small SpellIconID (e.g. 1573).
- icon **name** (e.g. `inv_misc_statue_06`) → store in `icon.name`, keep `spellIconId:1582` placeholder.
  A wowhead `icon=NNNN` / FileDataID is NOT a SpellIconID (no SpellIcon.dbc locally to convert) — store
  name, resolve real SpellIconID at MPQ time.
- Effects are free text; map to `code` using the catalog aura table.
- Unicode minus `−` in input → store ASCII `-` (client lacks U+2212 glyph; memory feedback_client_glyph_set).

## Generator — `scripts/familiar-gen-sql.ps1`

```
pwsh scripts/familiar-gen-sql.ps1 -Json .claude/familiars/01_mech.json        # SQL only
pwsh scripts/familiar-gen-sql.ps1 -Json .claude/familiars/01_mech.json -Csv    # also append client DBC rows
```
- Emits `data/sql/updates/pending_db_world/nemesis_familiars_gacha_<key>.sql`
  (summon + buff 103xxx + debuff 104xxx spell_dbc, creature_template+_model+_locale, item_template+_locale).
- `-Csv` appends summon+aura rows to `.claude/dbc/Spell_custom.csv` for the MPQ build (idempotent by ID;
  ruRU = enUS+8 offset — the generator is the sole CSV writer now).
- Encoding it bakes in: amount = BasePoints+1 (DieSides=1) ⇒ BP = value-1; buff Attr=2147483648
  (0x80000000), debuff Attr=2214592512 (0x84000000 NO_AURA_CANCEL|AURA_IS_DEBUFF), DurationIndex=21,
  ProcChance=101, Effect=6, ImplicitTargetA=1, SchoolMask=1. Summon: Attr=262416, Effect=28, MiscValueB=41,
  ImplicitTargetA=32.
- **PS 5.1 encoding traps (both bit me, both fixed):** the script file MUST be saved with a UTF-8 BOM or
  PS5.1 reads its Cyrillic literals as ANSI and the parser dies. The Edit tool strips the BOM — re-add it
  after any edit: `$t=[IO.File]::ReadAllText($p,[Text.UTF8Encoding]::new($false)); [IO.File]::WriteAllText($p,$t,[Text.UTF8Encoding]::new($true))`.
  And read the JSON with explicit UTF-8 (`[IO.File]::ReadAllText(path, UTF8Encoding($false))`), NOT
  `Get-Content` (defaults to ANSI → mojibake names). Generated SQL uses unquoted identifiers (no backticks)
  to dodge the `\`"` escape trap.

## Apply + test loop

1. `scripts/ptr-sql-apply.ps1 -IKnow data/sql/updates/pending_db_world/nemesis_familiars_gacha_<key>.sql`
2. `scripts/ptr-restart.ps1` (server loads new spell_dbc rows).
3. Verify with ptr-query (buff fields, attrs, counts, HEX charset, displayIds).
4. Client visuals (icons/names/Companions/aura plates) need the **MPQ** — manual external-tool step:
   merge `Spell_custom.csv` into binary Spell.dbc (WDBX), package into last-loading `patch-ruRU-X.MPQ`
   at `DBFilesClient/Spell.dbc`, drop in client `Data/ruRU/`, clear `WDB/`. No converter/packer in repo.

## C++ — no changes needed per family

`OnCreatureAddWorld` resolves entry→buff/debuff by formula for 191000–191099, so any new pet in range
works without code changes (see lifecycle.md).
