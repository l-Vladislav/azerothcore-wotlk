# Familiar aura lifecycle — apply / remove / persistence

How owner-auras are attached, detached, and (importantly) cleaned up across server restarts and player relogs. C++ side lives in `modules/mod-nemesis-system/src/NemesisSystem.cpp`.

## Normal flow

1. Player uses scroll item → `item_template.spelltrigger_2 = 6 (LEARN_SPELL_USE)` adds the summon spell to `character_spell`.
2. Player clicks the spell in Pet → Companions → `CMSG_CAST_SPELL`.
3. Server resolves `Effect_1 = 28 SUMMON` + `SummonProperties row 41 (MINIPET)` → spawns the creature.
4. **`AllCreatureScript::OnCreatureAddWorld(creature)`** fires:
   - Resolves `entry` → `buff = 103000 + offset`, `debuff = 104000 + offset` (linear formula for `191000–191099`; T1 fallback for `190010–012`).
   - Resolves owner via `creature->ToTempSummon()->GetSummonerUnit()` (`GetOwner()` is usually null for MINIPET summons — important: do NOT rely on `GetOwner`).
   - Casts buff `103xxx` triggered, and debuff `104xxx` triggered if `sSpellMgr->GetSpellInfo` returns non-null (cast site guards the optional row).
5. Player dismisses pet (or zone change / mount / death) → creature despawns.
6. **`AllCreatureScript::OnCreatureRemoveWorld(creature)`** fires → `player->RemoveAurasDueToSpell()` for both `103xxx` and `104xxx`.

## Persistence trap — aura survives logout, pet does not

Owner-auras are **permanent + `NO_AURA_CANCEL`**, so they're written into `character_aura` by `Player::SaveToDB()` during logout. The pet despawn that triggers `OnCreatureRemoveWorld` happens *after* the save snapshot in the logout sequence — so the in-memory removal does not propagate to disk. On next login `Player::LoadFromDB()` re-applies the aura, but companions do **NOT** auto-summon, so the player sees buff/debuff plates with no active pet.

This was observed end-to-end on PTR 2026-05-29 with the test_5pets fixture: player logged out with Cracked Stone Pebble active → relogged → buff and debuff plates still on bars, pet gone.

### Fix in place — `PlayerScript::OnPlayerLogin`

`NemesisSystemPlayerScript::OnPlayerLogin` strips all familiar auras on every login:

```cpp
for (uint32 spellId = 103000; spellId <= 103099; ++spellId)
    player->RemoveAurasDueToSpell(spellId);
for (uint32 spellId = 104000; spellId <= 104099; ++spellId)
    player->RemoveAurasDueToSpell(spellId);
// T1 fallback while migration in flight
player->RemoveAurasDueToSpell(101100);
player->RemoveAurasDueToSpell(101101);
player->RemoveAurasDueToSpell(101102);
```

Safe because:
- On login the player has no active companion (companions don't persist across sessions).
- If the player re-summons the pet post-login, `OnCreatureAddWorld` re-applies both auras through the normal path.

Don't try to "fix" this on the logout side instead — by the time the pet despawn fires the save has already happened.

## Edge cases that DON'T need extra handling

- **Pet dies from damage** — impossible. Minipets are non-targetable / non-attackable per `SUMMON_TYPE_MINIPET` semantics. They despawn only on mount / zone / player death / manual dismiss / logout, all of which fire `OnCreatureRemoveWorld`.
- **Mount → dismount cycle** — pet despawns on mount, fires `OnCreatureRemoveWorld` → aura removed. Player must manually re-summon after dismount (vanilla behavior).
- **Stacking between two familiars** — only one minipet at a time (`SUMMON_SLOT_MINIPET`). Summoning B implicitly unsummons A → A's `OnCreatureRemoveWorld` → A's auras removed → B's `OnCreatureAddWorld` → B's auras applied. Order is fine.
