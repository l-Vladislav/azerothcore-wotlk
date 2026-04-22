-- ============================================================================
-- Arcane Vellum Pool T1 — iLvl 1-25 (8 enchants: 6 school dmg +3, +3 Int, +3 Spirit)
-- Source: .claude/statBoosterItems/pools/arcane_vellum_pool/arcane_vellum_T1.md
-- ItemTypeMask 7569390 = armor + weapons + shield
-- ============================================================================

DELETE FROM `statbooster_enchant_template` WHERE `PoolGroup` = 3 AND `iLvlMin` = 1 AND `iLvlMax` = 25;

INSERT INTO `statbooster_enchant_template` (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `Description`, `Note`, `PoolGroup`, `ItemClassFilter`) VALUES
(90100, 1, 25, 0, 0, 0, 7569390, '+3 Fire Spell Damage',   'T1, armor+weapons+shield', 3, 0),
(90101, 1, 25, 0, 0, 0, 7569390, '+3 Frost Spell Damage',  'T1, armor+weapons+shield', 3, 0),
(90102, 1, 25, 0, 0, 0, 7569390, '+3 Nature Spell Damage', 'T1, armor+weapons+shield', 3, 0),
(90103, 1, 25, 0, 0, 0, 7569390, '+3 Shadow Spell Damage', 'T1, armor+weapons+shield', 3, 0),
(90104, 1, 25, 0, 0, 0, 7569390, '+3 Arcane Spell Damage', 'T1, armor+weapons+shield', 3, 0),
(90105, 1, 25, 0, 0, 0, 7569390, '+3 Holy Spell Damage',   'T1, armor+weapons+shield', 3, 0),
(90130, 1, 25, 0, 0, 0, 7569390, '+3 Intellect',           'T1, armor+weapons+shield', 3, 0),
(90134, 1, 25, 0, 0, 0, 7569390, '+3 Spirit',              'T1, armor+weapons+shield', 3, 0);
