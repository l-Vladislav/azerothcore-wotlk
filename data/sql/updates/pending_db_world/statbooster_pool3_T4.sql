-- ============================================================================
-- Arcane Vellum Pool T4 — iLvl 66-92 (8 enchants: 6 school dmg +10, +12 Int, +12 Spirit)
-- Source: .claude/statBoosterItems/pools/arcane_vellum_pool/arcane_vellum_T4.md
-- ItemTypeMask 7569390 = armor + weapons + shield
-- ============================================================================

DELETE FROM `statbooster_enchant_template` WHERE `PoolGroup` = 3 AND `iLvlMin` = 66 AND `iLvlMax` = 92;

INSERT INTO `statbooster_enchant_template` (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `Description`, `Note`, `PoolGroup`, `ItemClassFilter`) VALUES
(90118, 66, 92, 0, 0, 0, 7569390, '+10 Fire Spell Damage',   'T4, armor+weapons+shield', 3, 0),
(90119, 66, 92, 0, 0, 0, 7569390, '+10 Frost Spell Damage',  'T4, armor+weapons+shield', 3, 0),
(90120, 66, 92, 0, 0, 0, 7569390, '+10 Nature Spell Damage', 'T4, armor+weapons+shield', 3, 0),
(90121, 66, 92, 0, 0, 0, 7569390, '+10 Shadow Spell Damage', 'T4, armor+weapons+shield', 3, 0),
(90122, 66, 92, 0, 0, 0, 7569390, '+10 Arcane Spell Damage', 'T4, armor+weapons+shield', 3, 0),
(90123, 66, 92, 0, 0, 0, 7569390, '+10 Holy Spell Damage',   'T4, armor+weapons+shield', 3, 0),
(90133, 66, 92, 0, 0, 0, 7569390, '+12 Intellect',           'T4, armor+weapons+shield', 3, 0),
(90137, 66, 92, 0, 0, 0, 7569390, '+12 Spirit',              'T4, armor+weapons+shield', 3, 0);
