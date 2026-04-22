-- ============================================================================
-- Arcane Vellum Pool T2 — iLvl 26-45 (8 enchants: 6 school dmg +5, +6 Int, +6 Spirit)
-- Source: .claude/statBoosterItems/pools/arcane_vellum_pool/arcane_vellum_T2.md
-- ItemTypeMask 7569390 = armor + weapons + shield
-- ============================================================================

DELETE FROM `statbooster_enchant_template` WHERE `PoolGroup` = 3 AND `iLvlMin` = 26 AND `iLvlMax` = 45;

INSERT INTO `statbooster_enchant_template` (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `Description`, `Note`, `PoolGroup`, `ItemClassFilter`) VALUES
(90106, 26, 45, 0, 0, 0, 7569390, '+5 Fire Spell Damage',   'T2, armor+weapons+shield', 3, 0),
(90107, 26, 45, 0, 0, 0, 7569390, '+5 Frost Spell Damage',  'T2, armor+weapons+shield', 3, 0),
(90108, 26, 45, 0, 0, 0, 7569390, '+5 Nature Spell Damage', 'T2, armor+weapons+shield', 3, 0),
(90109, 26, 45, 0, 0, 0, 7569390, '+5 Shadow Spell Damage', 'T2, armor+weapons+shield', 3, 0),
(90110, 26, 45, 0, 0, 0, 7569390, '+5 Arcane Spell Damage', 'T2, armor+weapons+shield', 3, 0),
(90111, 26, 45, 0, 0, 0, 7569390, '+5 Holy Spell Damage',   'T2, armor+weapons+shield', 3, 0),
(90131, 26, 45, 0, 0, 0, 7569390, '+6 Intellect',           'T2, armor+weapons+shield', 3, 0),
(90135, 26, 45, 0, 0, 0, 7569390, '+6 Spirit',              'T2, armor+weapons+shield', 3, 0);
