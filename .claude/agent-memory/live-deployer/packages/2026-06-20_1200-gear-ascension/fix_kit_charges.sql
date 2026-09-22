-- Fix double-consume: kits must NOT be core-expendable (spellcharges_1=-1 makes the
-- core remove 1 on cast via Spell::TakeCastItem, while the script also removes 1 -> 2).
-- Consumption is owned by GearAscensionScript (DestroyItemCount). Set slot-1 charges to 0.
UPDATE item_template SET spellcharges_1=0 WHERE entry BETWEEN 200000 AND 200020;
