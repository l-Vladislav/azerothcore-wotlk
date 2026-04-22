-- ============================================================================
-- Fortune Pool T2 — iLvl 26-45 (33 enchants)
-- Source of truth: .claude/statBoosterItems/pools/fortune_pool/fortune_T2.md
-- Rows ordered by primary slot (first bit in ItemTypeMask); ItemClassFilter groups: 0, 2, 4, 6
-- ============================================================================

DELETE FROM `statbooster_enchant_template` WHERE `PoolGroup` = 4 AND `iLvlMin` = 26 AND `iLvlMax` = 45;

INSERT INTO `statbooster_enchant_template` (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `Description`, `Note`, `PoolGroup`, `ItemClassFilter`) VALUES
-- Head (primary slot)
(90007, 26, 45, 0, 0, 0, 2       , 'Stealth Detect +5'         , 'Head+Wrists'                           , 4, 0),
(90009, 26, 45, 0, 0, 0, 1122286 , '+10 All Magic Resist'      , 'Armor no shield'                       , 4, 0),
(90011, 26, 45, 0, 0, 0, 1138670 , '+10 HP5 in Combat'         , 'Armor+shield'                          , 4, 0),
(90012, 26, 45, 0, 0, 0, 1122282 , '+2% Threat'                , 'Armor no Neck/Shield'                  , 4, 0),
(90018, 26, 45, 0, 0, 0, 1052650 , '-4% Threat'                , 'No Neck/Trinket/Back/Shield'           , 4, 0),
(90023, 26, 45, 0, 0, 0, 1138670 , '+6 Mana per 5'             , 'Any gear'                              , 4, 0),
(90024, 26, 45, 0, 0, 0, 1122286 , '+15 All Magic Resist'      , 'Armor no shield'                       , 4, 0),
(90025, 26, 45, 0, 0, 0, 1138670 , '+14 HP5 in Combat'         , 'Armor+shield'                          , 4, 0),
(90026, 26, 45, 0, 0, 0, 1138670 , '+10% Health Regen Rate'    , 'Armor+shield'                          , 4, 0),
(90077, 26, 45, 0, 0, 0, 4098    , 'Water Breathing'           , 'Head+Trinket'                          , 4, 0),

-- Neck (primary slot)
(90001, 26, 45, 0, 0, 0, 1122284 , '+5% Movement Speed'        , 'No Head/Shield'                        , 4, 0),
(90003, 26, 45, 0, 0, 0, 260     , 'Water Walk'                , 'Neck+Feet'                             , 4, 0),
(90005, 26, 45, 0, 0, 0, 70596   , '+3% Mounted Speed'         , 'Neck+Waist+Legs+Feet+Wrists+Trinket+Back', 4, 0),

-- Feet (primary slot)
(90004, 26, 45, 0, 0, 0, 1280    , '+15% Swim Speed'           , 'Feet+Hands'                            , 4, 0),

-- Finger (primary slot)
(90016, 26, 45, 0, 0, 0, 137216  , '+30 Attack Power'          , 'No Head/Neck/Shield'                   , 4, 0),
(90020, 26, 45, 0, 0, 0, 137216  , '+21 Spell Power'           , 'No shield'                             , 4, 0),
(90029, 26, 45, 0, 0, 0, 71680   , '+10% Reputation Gain'      , 'Finger+Trinket+Back'                   , 4, 0),
(90087, 26, 45, 0, 0, 0, 6144    , 'Blood Pact'                , 'Finger+Trinket'                        , 4, 0),

-- 1H Weapon (primary slot)
(90015, 26, 45, 0, 0, 0, 6299648 , '+22 Attack Power'          , 'No Head/Neck/Shield'                   , 4, 0),
(90019, 26, 45, 0, 0, 0, 6299648 , '+11 Spell Power'           , 'No shield'                             , 4, 0),

-- Back/Cloak (primary slot)
(90034, 26, 45, 0, 0, 0, 65536   , 'Feather Fall'              , 'Back only'                             , 4, 0),
(90083, 26, 45, 0, 0, 0, 65536   , 'Immolate'                  , 'Back'                                  , 4, 0),

-- Weapons (ItemClassFilter=2)
(90036, 26, 45, 0, 0, 0, 0       , '+16 Damage on Hit'         , 'Weapons'                               , 4, 2),
(90037, 26, 45, 0, 0, 0, 0       , 'Fire Damage Proc'          , 'Weapons'                               , 4, 2),
(90040, 26, 45, 0, 0, 0, 0       , 'Fiery Weapon'              , 'Weapons'                               , 4, 2),
(90041, 26, 45, 0, 0, 0, 0       , 'Lifestealing'              , 'Weapons'                               , 4, 2),
(90042, 26, 45, 0, 0, 0, 0       , 'Icy Chill'                 , 'Weapons'                               , 4, 2),
(90043, 26, 45, 0, 0, 0, 0       , 'Unholy Weapon'             , 'Weapons'                               , 4, 2),
(90076, 26, 45, 0, 0, 0, 0       , 'Arcane Burst'              , 'Weapons, AoE proc'                     , 4, 2),
(90078, 26, 45, 0, 0, 0, 0       , 'Frost Ring'                , 'Weapons'                               , 4, 2),

-- Armor non-shield (ItemClassFilter=4)
(90031, 26, 45, 0, 0, 0, 1132522 , 'Thorns (18 damage)'        , 'Armor+shield'                          , 4, 4),

-- Shield (ItemClassFilter=6)
(90013, 26, 45, 0, 0, 0, 16384   , '+20 Block Value'           , 'Shield'                                , 4, 6),
(90081, 26, 45, 0, 0, 0, 16384   , 'Frost Armor'               , 'Shield'                                , 4, 6);
