-- ============================================================================
-- T1 familiar retirement — character-side migration (phase 3c).
-- Remap learned T1 summon spells to their gacha successors per
-- .claude/familiars/familiar_gacha_id_reservations.md:
--   100120 (Guardian Wolf Cub) -> 102000 (Mech 1.1 clean)
--   100121 (Falcon Chick)      -> 102070 (its family slot 1.1 clean)
--   100122 (Raven Fledgling)   -> 102050 (its family slot 1.1 clean)
-- UPDATE IGNORE skips characters that already know the successor (PK
-- guid+spell); the follow-up DELETE drops any such leftovers. Idempotent.
-- ============================================================================

UPDATE IGNORE `character_spell` SET `spell` = 102000 WHERE `spell` = 100120;
UPDATE IGNORE `character_spell` SET `spell` = 102070 WHERE `spell` = 100121;
UPDATE IGNORE `character_spell` SET `spell` = 102050 WHERE `spell` = 100122;
DELETE FROM `character_spell` WHERE `spell` IN (100120, 100121, 100122);

-- Action bar buttons pointing at the old summons (type 0 = spell)
UPDATE `character_action` SET `action` = 102000 WHERE `action` = 100120 AND `type` = 0;
UPDATE `character_action` SET `action` = 102070 WHERE `action` = 100121 AND `type` = 0;
UPDATE `character_action` SET `action` = 102050 WHERE `action` = 100122 AND `type` = 0;

-- Safety: strip persisted owner auras of the retired pets (spells are being
-- deleted from spell_dbc; orphan rows would just be skipped on load, but
-- clean them anyway)
DELETE FROM `character_aura` WHERE `spell` IN (101100, 101101, 101102);
