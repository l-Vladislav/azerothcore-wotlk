-- ============================================================================
-- Arcane Vellum Pool T3 — iLvl 46-65 (8 enchants: 6 school dmg +7, +9 Int, +9 Spirit)
-- Source: .claude/statBoosterItems/pools/arcane_vellum_pool/arcane_vellum_T3.md
-- ItemTypeMask 7569390 = armor + weapons + shield
-- ============================================================================

DELETE FROM `statbooster_enchant_template` WHERE `PoolGroup` = 3 AND `iLvlMin` = 46 AND `iLvlMax` = 65;

INSERT INTO `statbooster_enchant_template` (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `Description`, `Note`, `PoolGroup`, `ItemClassFilter`) VALUES
(90112, 46, 65, 0, 0, 0, 7569390, '+7 Fire Spell Damage',   'T3, armor+weapons+shield', 3, 0),
(90113, 46, 65, 0, 0, 0, 7569390, '+7 Frost Spell Damage',  'T3, armor+weapons+shield', 3, 0),
(90114, 46, 65, 0, 0, 0, 7569390, '+7 Nature Spell Damage', 'T3, armor+weapons+shield', 3, 0),
(90115, 46, 65, 0, 0, 0, 7569390, '+7 Shadow Spell Damage', 'T3, armor+weapons+shield', 3, 0),
(90116, 46, 65, 0, 0, 0, 7569390, '+7 Arcane Spell Damage', 'T3, armor+weapons+shield', 3, 0),
(90117, 46, 65, 0, 0, 0, 7569390, '+7 Holy Spell Damage',   'T3, armor+weapons+shield', 3, 0),
(90132, 46, 65, 0, 0, 0, 7569390, '+9 Intellect',           'T3, armor+weapons+shield', 3, 0),
(90136, 46, 65, 0, 0, 0, 7569390, '+9 Spirit',              'T3, armor+weapons+shield', 3, 0);
