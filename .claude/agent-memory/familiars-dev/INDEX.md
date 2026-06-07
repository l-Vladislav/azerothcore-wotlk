# familiars-dev memory — INDEX

Read this file at the start of every task. Then load only the sub-docs whose hooks match the current task.

## Sub-docs

- [id-ranges.md](id-ranges.md) — **CRITICAL**. Linear `(F−1)*10+(P−1)` formula and reserved spell/creature/item ranges. Load before assigning any new ID.
- [aura-template.md](aura-template.md) — **CRITICAL**. Exact `spell_dbc` row shape for owner-auras: Attributes (buff `2147483648` / debuff `2214592512` — debuff REQUIRES `AURA_IS_DEBUFF` for debuff-bar placement), DurationIndex, ProcChance, EffectDieSides. Load on any spell_dbc INSERT/REPLACE for familiar auras.
- [common-variants.md](common-variants.md) — Clean + «побитый» pair convention (shared DisplayID, name differs, +1−2% buff + −1% debuff). Load when adding/editing Common slots.
- [lifecycle.md](lifecycle.md) — Aura apply/remove flow (`OnCreatureAddWorld`/`OnCreatureRemoveWorld`), persistence trap on logout, login-side cleanup hook. Load when touching the C++ side or debugging "aura without pet" cases.
- [russian-text.md](russian-text.md) — **CRITICAL** for any Russian text. Stat abbreviation translation table (Int→инт./Sta→вын./Holy res→сопр. свету…), description format conventions, animate-accusative declension for pet names in «Призывает …», ASCII-only punctuation rule. Load whenever writing or editing ruRU names/descriptions.
- [model-sounds.md](model-sounds.md) — Loud looping ambient on pet models (fire crackle etc.): CDI.SoundID → CreatureSoundData.LoopSoundID, server can't control it. Fix ladder: quiet visual-twin display (server-only) → other model → custom CDI row (MPQ). **Check every new model for loops before applying.** Local CDI/CSD CSV exports in `.claude/dbc/`.
- [json-workflow.md](json-workflow.md) — **Source of truth is now per-family JSON** (`0X_<key>.json`), not the `.md` tables. Schema, owner input format (npc=/spell=/icon name), the `scripts/familiar-gen-sql.ps1` generator (SQL + `-Csv` DBC rows), and the PS5.1 UTF-8/BOM traps. Load before editing any family or generating SQL.
- [docs-map.md](docs-map.md) — Where each piece of info lives in `.claude/familiars/` (JSONs + все familiar_gacha_*-доки; переехали из `.claude/nemesis/` 2026-06-07). Load to orient before edits.
- [ptr-only.md](ptr-only.md) — Agent writes go to `*_ptr` DBs only; SQL must live in `data/sql/updates/pending_db_world/`. Load before any DB or SQL work.

## How to grow this memory

When you learn a durable fact during a task (new path, new convention, a gotcha that bit you), either:
- Update the relevant sub-doc above, OR
- Create a new sub-doc and add a one-line entry here.

Keep this INDEX under ~30 lines so it stays cheap to load.
