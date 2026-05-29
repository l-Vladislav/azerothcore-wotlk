-- ⚠️ TESTING ONLY — 100% proc rate for spell 21969 (Mark of the Chosen)
--
-- Purpose: verify that enchant 90138 (StatBooster Fortune T4 trinket) actually
-- procs in-game. Vanilla item 17774 Mark of the Chosen sets the proc rate at
-- the item level (item_template.spellppmRate_1 = 2.00), so when spell 21969 is
-- applied as an ENCHANT (via SpellItemEnchantment.Effect=3 → EffectArg=21969),
-- it has no proc rate of its own and never fires.
--
-- This override forces the spell to proc on ANY damage taken, 100% chance,
-- no cooldown. Affects ALSO vanilla trinket 17774 — but that's OK on PTR.
--
-- TO REVERT:  DELETE FROM `spell_proc` WHERE `SpellId` = 21969;
-- Or use the natural ProcsPerMinute = 2.0 by changing Chance/PPM fields.

DELETE FROM `spell_proc` WHERE `SpellId` = 21969;

INSERT INTO `spell_proc`
  (`SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0`, `SpellFamilyMask1`, `SpellFamilyMask2`,
   `ProcFlags`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`,
   `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`)
VALUES
  (21969, 0, 0, 0, 0, 0,
   1048576,  -- PROC_FLAG_TAKEN_DAMAGE (0x00100000) — taken any damage
   0, 0, 0, 0, 0,
   0,        -- ProcsPerMinute = 0 (use Chance instead)
   100,      -- Chance = 100% per trigger event
   0,        -- Cooldown = no internal cooldown
   0);       -- Charges = 0 (infinite, doesn't consume)
