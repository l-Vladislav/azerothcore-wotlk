# Nemesis Familiar System — Design Plan

Status: design, not implemented
Depends on: nemesis rank system, bounty vendor (innkeeper gossip), StatBooster (for enchant context only — these are independent)

## Goal

Reward nemesis ranks with **familiars** — non-combat companion pets that cast a passive aura on their owner. Three archetypes (tank / damage / mage) × five tiers = 15 familiars. Each tier's familiar casts a **compound aura** that stacks the effects of all lower tiers in its family ("Option A" from the design discussion).

## Design principles

1. **Flavor first, power second.** StatBooster scrolls remain the main power reward; familiars add small stat bonuses + cosmetic presence.
2. **Additive, never game-changing.** Aura values are 1–2 % range, additive to existing class/raid buffs.
3. **Pick your archetype.** A player unlocks each tier across all three families simultaneously, but summons one familiar at a time — role choice stays meaningful.
4. **Tier 5 feels special.** Uses a unique stacking mechanic tied to nemesis kills (thematic payoff for reaching Легенда Охоты).
5. **Minimal client changes.** Auras, gating, and summons are all server-side; creatures reuse stock display IDs; gossip gates unlocks by rank. The only client-side change is optional custom icons added to `SpellIcon.dbc` via the existing ruRU MPQ patch (so each familiar's buff can show that pet's own icon). Everything else lives in `spell_dbc` / `creature_template` / `npc_vendor` / `gossip_menu`.
6. **Owner-only aura (single-target, never area).** The aura applies to the summoning player only — not party, raid, or nearby allies. This keeps the familiar a personal buff and prevents it from becoming a stackable group power source. See the "Owner-only aura — implementation" section below for the specific patterns.

## Rank-to-tier mapping

| Rank | Unlocks | Items visible at innkeeper |
|---|---|---|
| 1 Послушник | Tier 1 | 3 summon items (tank / dmg / mage) |
| 2 Охотник | Tier 2 | +3 tier-2 items |
| 3 Следопыт | Tier 3 | +3 tier-3 items |
| 4 Ветеран | Tier 4 | +3 tier-4 items |
| 5 Легенда | Tier 5 | +3 tier-5 items |

Token cost suggestion (reuses existing `itemextendedcost_dbc` IDs 100001–100005): T1=10, T2=15, T3=20, T4=25, T5=50.

## Families & aura ladder

### Family 1: Стражи (Tank line)

Theme: wolves → hounds → bears → spectral guardians.

| Tier | Familiar (RU) | Display hint | Compound aura on owner |
|---|---|---|---|
| 1 | Волчонок-Страж | small wolf pup | +1 % armor |
| 2 | Верный Пёс | guard dog | +1 % armor, +1 % stamina |
| 3 | Матёрый Медвежонок | young bear | +1 % armor, +1 % stamina, +1 % avoidance (dodge+parry+block split) |
| 4 | Призрачный Медведь | spectral bear | +2 % armor, +1 % stamina, +1 % avoidance, -1 % physical damage taken |
| 5 | Бессмертный Страж | ancient shade bear | +2 % armor, +2 % stamina, +1 % avoidance, -1 % all damage taken, **+scaling threat** per nemesis killed in last hour (cap +20 %) |

### Family 2: Охотники (Damage line)

Theme: falcons → cats → wolves → spectral predators.

| Tier | Familiar (RU) | Display hint | Compound aura on owner |
|---|---|---|---|
| 1 | Соколёнок | hawk chick | +1 % crit |
| 2 | Боевой Сокол | adult falcon | +1 % crit, +1 % AP |
| 3 | Рысь-Следопыт | lynx | +1 % crit, +1 % AP, +1 % haste |
| 4 | Волк-Охотник | wolf | +1 % crit, +1 % AP, +1 % haste, +1 % physical damage done |
| 5 | Призрачная Пантера | spectral panther | +2 % crit, +2 % AP, +1 % haste, +1 % damage done, **stacking "Клеймо Охотника"** +0.5 % damage per nemesis kill (max 5 stacks, 1h decay) |

### Family 3: Заклинатели (Mage/caster line)

Theme: ravens → owls → shades → phantoms.

| Tier | Familiar (RU) | Display hint | Compound aura on owner |
|---|---|---|---|
| 1 | Вороненок | raven fledgling | +1 % spell crit |
| 2 | Ворон-Послушник | adult raven | +1 % spell crit, +2 mp5 |
| 3 | Зачарованная Сова | owl | +1 % spell crit, +3 mp5, +1 % spell haste |
| 4 | Тёмный Ворон | shadow raven | +1 % spell crit, +4 mp5, +1 % spell haste, +1 % spell damage done |
| 5 | Призрак-Чтец | phantom reader | +2 % spell crit, +5 mp5, +1 % spell haste, +1 % spell damage, **scaling** — every nemesis killed refreshes a 10-min +1 % spell damage buff (cap +5 %) |

### Balance check

Compared to stock 3.3.5a raid buffs (Blessing of Kings ~10 %, Mark of the Wild, Power Word: Fortitude, Arcane Brilliance):

- Single-tier additive effects at 1–2 % are well below class buff levels — won't displace existing raid comp logic.
- Tier-5 scaling mechanics add variance (+5 to +20 %), still bounded, still opt-in.
- Three archetypes summed never stack on one player (one pet out at a time).
- Familiar auras re-apply periodically from the pet, so leaving the pet unattended doesn't give permanent power.

## Owner-only aura — implementation

The aura **must only apply to the summoning player**, never to party, raid, or nearby allies. **The cleanest 3.3.5a approach is to merge the aura into the summon spell as a second effect** — validated during Phase 2 prototyping.

### Canonical pattern: summon + aura in one spell

The summon spell carries both the `SUMMON` and `APPLY_AURA` effects. When the player casts it:
- Effect 1 summons the pet at the caster's location.
- Effect 2 applies the aura **to the caster** (who is the explicit "self" target of the spell), with a duration matching the summon.
- When the summon expires (pet dismissed, zone change, 30 min timer), the aura effect **also** expires — bound to the same Spell aura lifetime.

```
spell_dbc row for each summon:
  Effect_1            = 28   (SPELL_EFFECT_SUMMON)
  ImplicitTargetA_1   = 18   (TARGET_DEST_CASTER — spawn point)
  EffectMiscValue_1   = <creature entry>
  EffectMiscValueB_1  = 64   (SummonProperties.dbc row id — minipet)

  Effect_2            = 6    (SPELL_EFFECT_APPLY_AURA)
  ImplicitTargetA_2   = 1    (TARGET_UNIT_CASTER — the player)
  EffectAura_2        = 143  (MOD_RESISTANCE_PCT, or whichever aura fits the tier)
  EffectBasePoints_2  = 0, EffectDieSides_2 = 1 → +1
  EffectMiscValue_2   = <aura-specific misc value, e.g. 1 for physical armor>

  DurationIndex       = 21   (30 min — standard minipet lifetime)
  CastingTimeIndex    = 1    (instant; Worg Pup uses 5 = 1.5s cast, either works)
  Attributes          = 327680  (0x50000 = ABILITY | DONT_AFFECT_SHEATH_STATE)
  RangeIndex          = 1    (self)
  EquippedItemClass   = -1   (no equipment requirement)
```

**One spell, one DBC row per familiar.** No SAI, no separate aura spell.

### Why not SAI

An earlier draft proposed `creature_template.AIName = 'SmartAI'` + a SAI script that periodically casts the aura on `SMART_TARGET_OWNER_OR_SUMMONER` (16). That works for owner-only targeting, **but** it has three drawbacks versus the merged-spell approach:

1. **SAI overrides FollowerAI.** Minipets get FollowerAI installed automatically when summoned under `SummonProperties` row 64. Setting `AIName='SmartAI'` blocks that, so the pet stands still instead of following. You would have to add a `SMART_ACTION_FOLLOW` row to restore follow behavior.
2. **More moving parts.** Two spells + SAI script + DB row per tier, vs. one spell.
3. **Harder to reason about timing.** SAI re-casts the aura on a tick — if the owner is out of range briefly, the aura drops and re-applies in a visible flicker.

Use SAI only if the familiar needs to **do something else** besides buff (e.g., periodic emote, ability casting, area effects). For a pure buff companion, merged summon+aura is simpler, more reliable, and integrates cleanly with the minipet Pet-menu UI.

### Rejected: Pattern A (`creature_template.auras` + `TARGET_UNIT_MASTER`)

Originally this doc proposed using `ImplicitTargetA = 57` (`TARGET_UNIT_MASTER`) on a separate aura spell bound via the `creature_template.auras` column. **This does not work.** AzerothCore's creature aura loader (`LoadCreaturesAddon` / `AddAura`) applies auras **directly to the creature** via an `AddAura` path that bypasses `Spell::Effect` target resolution. Because the implicit target is never evaluated, the aura lands on the pet, not the master. Don't use this channel for owner-targeted auras.

### What not to use

| ❌ Don't | Why |
|---|---|
| `SPELL_AURA_AREA_*` (`AREA_AURA_PARTY`, `AREA_AURA_FRIEND`) | Broadcasts to allies in a radius — gives the familiar's effects to the whole party. |
| `creature_template.auras` for owner auras | Direct `AddAura` bypasses `Spell::Effect` resolution; `TARGET_UNIT_MASTER` doesn't redirect. Aura lands on the pet. |
| `ImplicitTargetA = TARGET_UNIT_CASTER_AREA_PARTY` (60) or similar party variants | Party-targeted by design; defeats the owner-only rule. |
| Non-zero `EffectRadiusIndex` | Creates an AoE footprint even on a single-target apply-aura. |
| `AIName = 'SmartAI'` without `SMART_ACTION_FOLLOW` | Minipet's default FollowerAI is suppressed → pet stands still when summoned. |

### What **not** to use

| ❌ Don't | Why |
|---|---|
| `SPELL_AURA_AREA_*` (e.g. `AREA_AURA_PARTY`, `AREA_AURA_FRIEND`) | These are designed to hit allies in a radius — gives all familiar effects to the entire party. |
| `creature_template.auras` for owner auras | Loader path bypasses `Spell::Effect` resolution (direct `AddAura`), so implicit targets like `TARGET_UNIT_MASTER` don't redirect — aura lands on the pet. Also: if the spell has an area-aura type, this channel will broadcast it to allies. Use SAI (Pattern B) instead. |
| `ImplicitTargetA = TARGET_UNIT_CASTER_AREA_PARTY` (60) or similar party variants | Party-targeted by design; defeats the owner-only rule. |
| Spells with a non-zero `EffectRadiusIndex` pointing to a `SpellRadius.dbc` row > 0 yards | Creates an AoE footprint even on a single-target apply-aura. |

### Verification checklist (during Phase 2 prototype)

- Summon pet while in party. Confirm the aura shows up on the owner's buff bar **only** — not on party members.
- Dismiss pet. Confirm aura falls off within the expected tick (re-cast interval from SAI or natural duration).
- Invite a second player who also has a familiar out. Confirm each player's buff bar shows only their own familiar's aura.
- Tier-5 scaling mechanic: stacks apply to the owner's buff bar only, even when a party member lands the killing blow on a nemesis.

## Buff presentation (owner's buff bar)

Each familiar's aura shows as a **standard buff** on the owner's buff bar — same UI as any class or raid buff. Properties:

- **One unique icon per tier = the pet's own icon** (15 icons total). The same icon is used in three places: the summon-spell icon, the aura buff on the owner's buff bar, and the reward item icon. Seeing the buff = seeing the pet's face.
  - Pets with a direct stock analog reuse that icon (e.g., a wolf cub familiar borrows the "Call Pet: Wolf" / Hunter beast icon; an owl familiar borrows an existing owl-themed icon).
  - Pets that need a dedicated image (especially T5 shades/phantoms and any custom-themed mob) get a **custom `SpellIcon.dbc` entry** added through the existing ruRU MPQ patch workflow (see `.claude/guide_mpq_patching.md`). Icon art is a 64×64 BLP authored from the pet's model screenshot or a stylized version.
- **Tooltip** lists the compound effects for that tier (e.g. Tier 3 damage: "+1 % crit, +1 % AP, +1 % haste — aura of Рысь-Следопыт").
- **Duration**: infinite while pet is summoned and in range; drops when pet dismissed, out of range (>40y), or on zone change that unsummons the companion.
- **Zero MPQ work**: icons come from existing `SpellIcon.dbc` rows; we just reference them in our custom `spell_dbc` rows.

### Tier-5 kill-stack — separate buff

For Tier-5 familiars only, the scaling mechanic lives in a **second, distinct buff** on the owner's buff bar — separate from the compound base aura:

- **Base aura buff** (shared with T1–T4 pattern): applied by the pet, infinite while summoned, carries the compound +crit / +AP / etc. effects.
- **Kill-stack buff** (new, T5 only): applied by a **server-side `OnCreatureKill` hook** whenever the owner kills (or gets credit for killing) a nemesis creature. Properties:
  - **Distinct icon** from the base aura so the player can tell them apart.
  - **Stackable** up to the family cap (tank: +20 % threat = 20 stacks at 1 % each; dmg: 5 stacks at 0.5 %; mage: 5 stacks at 1 %).
  - **Fixed timer** (e.g. 60 min). Timer is per-buff, not per-stack.
  - **Refresh behavior**: each nemesis kill refreshes the timer to the full window **and** bumps the stack count by one (up to the cap). A kill while already at cap still refreshes the timer but doesn't add a stack.
  - **Expiry**: when the timer elapses, the buff drops entirely — stacks reset to 0 the next time it's re-applied. No partial decay.
  - **Independent of pet presence**: the base aura drops if you dismiss the pet, but kill-stacks remain until their own timer runs out (keeps the kill-stack mechanic honest — you earned those stacks, dismissing the pet briefly doesn't wipe them).

This separation makes the T5 mechanic readable to the player (two icons, two tooltips) and simplifies the server logic (one static aura spell + one stackable proc spell).

### ID allocation addition

For Tier-5 kill-stack buffs, add three more spell IDs alongside the 15 base aura spells:

- **T5 kill-stack spells**: `100085–100087` (one per family — tank threat, damage stacking, mage spell-dmg refresh)

## Data model

### New SQL + client MPQ

**ID allocation** (check memory `project_statbooster.md` and `project_custom_items_mpq.md` for existing reservations — `100001–100017` are taken):

- **Reward items**: `100030–100044` (15 single-use "teach summon" scrolls)
- **Summon spells**: `100120–100134` (15 pure `SPELL_EFFECT_SUMMON` spells — one per familiar; must be single-effect to stay classifiable as companions). **Must NOT overlap with `100050–100063` which is claimed by StatBooster's pool3 stat-damage auras.**
- **Owner-aura spells**: `101100–101114` (15 passive aura spells — applied on summon / removed on dismiss by `NemesisSystemAllCreatureScript::OnCreatureAddWorld/Remove`). Separate range from the summon IDs so the aura is independently MPQ-manageable; kept out of the summon spell because `Effect_2 APPLY_AURA` breaks companion classification.
- **T5 kill-stack spells**: `100085–100087` (3 stackable proc buffs — one per family, applied by `OnCreatureKill` hook; distinct icon from the base summon)
- **Creature entries**: `190010–190024` (15 companion creature entries)
- **Gossip menu / npc_text**: extend bounty board menu (entry 190000)
- **ItemExtendedCost**: reuse existing `100001–100005` (T1–T5 token costs)

Slot convention within each range: T1 = offset +0..2 (tank / damage / mage), T2 = +3..5, T3 = +6..8, T4 = +9..11, T5 = +12..14.

### Client MPQ additions (last-loading ruRU patch)

For the familiars to appear in the Pet menu and for scrolls to work client-side, add to the **last-loading** patch MPQ (e.g. `patch-ruRU-B.MPQ` — later MPQ entries completely replace earlier ones):

| DBC | Rows to add | Purpose |
|---|---|---|
| `Spell.dbc` | 100120–100134 (15 summon spells) | Client needs these to classify learned spells as companions and render them in the Pet menu |
| `Spell.dbc` | 101100–101114 (15 owner-aura spells) | So the familiar's buff-bar icon/name renders correctly. Mechanics work without this row (server applies aura regardless) — purely cosmetic. |
| `Spell.dbc` | 100085–100087 (3 T5 kill-stack procs) | So the stacking buff has a proper client-side tooltip |
| `Item.dbc` | 100030–100044 (15 scrolls) | Client recognizes the item class/subclass so the Use action dispatches properly |
| `SpellIcon.dbc` | Up to 18 custom rows (optional) | Only if stock icons don't fit the pet theme. Reusing stock `SpellIconID` values is preferred — no custom BLP art needed. |

### Tables touched

| Table | What changes |
|---|---|
| `spell_dbc` | 33 new rows (15 summon spells + 15 owner-aura spells + 3 T5 kill-stack procs) |
| `Item.dbc` / `Spell.dbc` / `SpellIcon.dbc` (client MPQ) | See "Client MPQ additions" above |
| `creature_template` | 15 new rows; type 7 (critter), `AIName=''` so FollowerAI installs by default |
| `npc_vendor` (entry 190000) | 15 new rows, one per familiar scroll, gated by rank via gossip filter |
| `item_template` | 15 scroll items; class=15 subclass=2 (Miscellaneous / Companion Pet), `spelltrigger_1=6` (LEARN_SPELL_ID) — item auto-consumes on use and permanently teaches the summon spell |
| `item_template_locale` | ruRU names/descriptions (follow utf8mb4 import rule — see `feedback_sql_charset.md` in memory) |

### Confirmed values from Phase 2 prototyping

These are the "gotchas" learned during initial implementation. Pin them so later tiers don't repeat the research:

| Field | Correct value | Why / what fails otherwise |
|---|---|---|
| `Effect_1` for summon | **28** (`SPELL_EFFECT_SUMMON`) | 75 is `SPELL_EFFECT_HEAL_MECHANICAL` — silent no-op |
| `EffectMiscValueB_1` | **64** (row id into SummonProperties.dbc) | Row 64 is Type=MINIPET, Category=ALLY — exactly what the client's Pet menu looks for. Row 65 is the hunter-pet slot and silently fails for non-hunters. **This is a DBC row id, not a bitmask** |
| `ImplicitTargetA_1` for summon | **18** (`TARGET_DEST_CASTER`) | 1 (`TARGET_UNIT_CASTER`) doesn't populate `destTarget`, so the SummonCreature call no-ops |
| `RangeIndex` | **1** (self) | 0 is invalid → `SpellInfo::RangeEntry` stays null and `.cast` silently rejects |
| `Attributes` | **327680** (0x50000 = `ABILITY \| DONT_AFFECT_SHEATH_STATE`) | Without `DONT_AFFECT_SHEATH_STATE`, casting sheathes the player's weapon awkwardly |
| `DurationIndex` | **21** (30-min companion, matches stock) | Minipets in 3.3.5a persist via an infinite client cooldown pattern; 30-min server duration is fine |
| `CastingTimeIndex` | **1** (instant) or **5** (1.5s, matches Worg Pup) | Either works |
| `EquippedItemClass` | **-1** (no equipment requirement) | Default 0 means "requires item" → silent fail |
| `item_template.class`/`subclass` | **15 / 2** (Miscellaneous / Companion Pet) | NOT 0/8 (generic consumable) — the companion-pet subclass is what makes the stock client render "Use: Teaches you..." and dispatch the LEARN_SPELL_ID trigger cleanly |
| `item_template.spelltrigger_1` | **6** (`LEARN_SPELL_ID`) | Item auto-consumes on use, learns `spellid_1` permanently. No teach-wrapper spell needed. |
| `creature_template.type` | **7** (CRITTER) | Minimpet category expects critter type |
| `creature_template.family` | **0** | Non-zero → client tries to group under hunter-pet families, can crash tooltip |
| `creature_template.AIName` | **`''`** (empty) | Empty lets the summon path install FollowerAI automatically → pet follows. `'SmartAI'` suppresses FollowerAI. |
| `creature_template.npcflag` | **0** | Non-zero → gossip/quest markers hover over the pet |
| `creature_template.faction` | **35** (friendly-to-all) | Standard minipet faction |

Source traces: `src/server/game/Spells/SpellEffects.cpp:2349,2439-2466`; `src/server/shared/SharedDefines.h:794` (`SPELL_EFFECT_SUMMON = 28`); `src/server/game/AI/ScriptedAI/ScriptedFollowerAI.cpp`.

### Rank gating (gossip-based, no DBC faction)

Modify the bounty vendor gossip handler (`NemesisBountyVendorScript`) to:

1. Look up the player's nemesis rank from `NemesisReputation` (or wherever rep is stored).
2. Filter the vendor item list before showing — only display tier ≤ rank.
3. Show locked tiers as greyed-out gossip lines (informational only, e.g. `"[Требуется ранг 3: Следопыт]"`) so players see what they're working toward.

## Implementation phases

Suggested order (each phase independently testable):

1. **Schema freeze** — lock down spell/item/creature ID ranges, agree on aura values per tier.
2. **Prototype: Family 1 Tier 1 only** — one creature, one summon spell, one aura spell, one reward item. Hand-add to vendor. Verify: pet summons, aura applies, aura drops when pet dismissed.
3. **Family 1 all tiers** — scale the Tier 1 pattern up to 5. Compound auras layer via multiple `EffectAura_N` slots on the same spell (spells have 3 effect slots; T3+ may split into a second spell if needed).
4. **Families 2 & 3** — duplicate schema, swap display IDs and aura effect IDs.
5. **Rank gating** — wire gossip filter.
6. **Tier 5 unique mechanics** — implement scaling buffs via `OnCreatureKill` hook in the module, keyed off the same event that grants the Nemesis Bounty Token (so stacks scale with nemesis kill level/tier).
7. **Addon tweaks** — Хроника/Охота tabs show active familiar + its current aura stats (optional polish).

## Open questions / decisions for later

- **Should familiars resummon on login?** Stock WoW pets (companion slot) don't; players re-cast each session. Could add a login hook if desired.
No
- **Display ID choices** — which exact creature/model rows to reuse? Need a short prospecting list from `creature_template` / `creaturedisplayinfo`. Keep to stock 3.3.5a assets.

- **Tier 5 scaling storage** — transient buff stacks can live in spell stacking rules, or in a custom table if we want cross-session persistence. Transient is simpler and thematically fine ("the hunt keeps them hungry").
- **Non-combat pet vs. proper guardian** — non-combat pet is cleaner (no class pet conflicts, survives between zones), but loses some combat flavor. Going non-combat.
non-combat pet
- **Dual-family owners** — player can own summon items for all three families but only one pet active at a time (standard companion slot enforces this for free).
No, only one
- **Trophy system integration** — does the scaling tier-5 aura read from the Хроника kill list, or from a live kill counter in a new table? Decide before implementing T5.
from nemesis kill that gives the token (so, current lvl etc)

## References

- `.claude/nemesis/nemesis_system.md` — rank / rep storage details
- `.claude/nemesis/ticket_bounty_board.md` — bounty vendor context
- `modules/mod-nemesis-system/data/sql/db-world/base/nemesis_bounty_vendor.sql` — existing vendor entry 190000
- `modules/StatBooster/data/sql/db-world/` — example of module-local SQL layout (for patterning)
- Memory: `feedback_sql_charset.md` — always import Cyrillic-containing SQL with `--default-character-set=utf8mb4`
