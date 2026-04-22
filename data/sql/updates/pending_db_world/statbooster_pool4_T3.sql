-- ============================================================================
-- Fortune Pool T3 — iLvl 46-65 (35 enchants)
-- Source of truth: .claude/statBoosterItems/pools/fortune_pool/fortune_T3.md
-- Rows ordered by primary slot (first bit in ItemTypeMask); ItemClassFilter groups: 0, 2, 4, 6
-- ============================================================================

DELETE FROM `statbooster_enchant_template` WHERE `PoolGroup` = 4 AND `iLvlMin` = 46 AND `iLvlMax` = 65;

INSERT INTO `statbooster_enchant_template` (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `Description`, `Note`, `PoolGroup`, `ItemClassFilter`) VALUES
-- Head (primary slot)
(90007, 46, 65, 0, 0, 0, 2       , 'Stealth Detect +5'         , 'Head+Wrists'                           , 4, 0),
(90009, 46, 65, 0, 0, 0, 1122286 , '+10 All Magic Resist'      , 'Armor no shield'                       , 4, 0),
(90011, 46, 65, 0, 0, 0, 1138670 , '+10 HP5 in Combat'         , 'Armor+shield'                          , 4, 0),
(90012, 46, 65, 0, 0, 0, 1122282 , '+2% Threat'                , 'Armor no Neck/Shield'                  , 4, 0),
(90018, 46, 65, 0, 0, 0, 1052650 , '-4% Threat'                , 'No Neck/Trinket/Back/Shield'           , 4, 0),
(90023, 46, 65, 0, 0, 0, 1138670 , '+6 Mana per 5'             , 'Any gear'                              , 4, 0),
(90024, 46, 65, 0, 0, 0, 1122286 , '+15 All Magic Resist'      , 'Armor no shield'                       , 4, 0),
(90025, 46, 65, 0, 0, 0, 1138670 , '+14 HP5 in Combat'         , 'Armor+shield'                          , 4, 0),
(90026, 46, 65, 0, 0, 0, 1138670 , '+10% Health Regen Rate'    , 'Armor+shield'                          , 4, 0),
(90027, 46, 65, 0, 0, 0, 1138670 , '-10% Fear Duration'        , 'Armor+shield no Neck'                  , 4, 0),
(90028, 46, 65, 0, 0, 0, 1138670 , '-10% Stun Duration'        , 'Armor+shield no Neck'                  , 4, 0),
(90077, 46, 65, 0, 0, 0, 4098    , 'Water Breathing'           , 'Head+Trinket'                          , 4, 0),

-- Neck (primary slot)
(90002, 46, 65, 0, 0, 0, 1122284 , '+8% Movement Speed'        , 'Armor no Head/Shield'                  , 4, 0),
(90003, 46, 65, 0, 0, 0, 260     , 'Water Walk'                , 'Neck+Feet'                             , 4, 0),
(90005, 46, 65, 0, 0, 0, 70596   , '+3% Mounted Speed'         , 'Neck+Waist+Legs+Feet+Wrists+Trinket+Back', 4, 0),

-- Feet (primary slot)
(90004, 46, 65, 0, 0, 0, 1280    , '+15% Swim Speed'           , 'Feet+Hands'                            , 4, 0),

-- Finger (primary slot)
(90017, 46, 65, 0, 0, 0, 137216  , '+40 Attack Power'          , 'Armor no Head/Neck/Shield'             , 4, 0),
(90021, 46, 65, 0, 0, 0, 137216  , '+35 Spell Power'           , 'Armor no shield'                       , 4, 0),
(90029, 46, 65, 0, 0, 0, 71680   , '+10% Reputation Gain'      , 'Finger+Trinket+Back'                   , 4, 0),
(90088, 46, 65, 0, 0, 0, 6144    , 'Blood Pact'                , 'Finger+Trinket'                        , 4, 0),

-- 1H Weapon (primary slot)
(90016, 46, 65, 0, 0, 0, 6299648 , '+30 Attack Power'          , 'No Head/Neck/Shield'                   , 4, 0),
(90020, 46, 65, 0, 0, 0, 6299648 , '+21 Spell Power'           , 'No shield'                             , 4, 0),

-- Back/Cloak (primary slot)
(90034, 46, 65, 0, 0, 0, 65536   , 'Feather Fall'              , 'Back only'                             , 4, 0),
(90084, 46, 65, 0, 0, 0, 65536   , 'Immolate'                  , 'Back'                                  , 4, 0),

-- Weapons (ItemClassFilter=2)
(90037, 46, 65, 0, 0, 0, 0       , 'Fire Damage Proc'          , 'Weapons'                               , 4, 2),
(90042, 46, 65, 0, 0, 0, 0       , 'Icy Chill'                 , 'Weapons'                               , 4, 2),
(90043, 46, 65, 0, 0, 0, 0       , 'Unholy Weapon'             , 'Weapons'                               , 4, 2),
(90070, 46, 65, 0, 0, 0, 0       , 'Lifeward'                  , 'Weapons'                               , 4, 2),
(90071, 46, 65, 0, 0, 0, 0       , 'Deathfrost'                , 'Weapons'                               , 4, 2),
(90073, 46, 65, 0, 0, 0, 0       , 'Giant Slayer'              , 'Weapons'                               , 4, 2),
(90074, 46, 65, 0, 0, 0, 0       , 'Arcane Burst'              , 'Weapons, AoE proc'                     , 4, 2),
(90079, 46, 65, 0, 0, 0, 0       , 'Frost Ring'                , 'Weapons'                               , 4, 2),

-- Armor non-shield (ItemClassFilter=4)
(90032, 46, 65, 0, 0, 0, 1132520 , 'Thorns (25 damage)'        , 'Armor+shield'                          , 4, 4),

-- Shield (ItemClassFilter=6)
(90014, 46, 65, 0, 0, 0, 16384   , '+27 Block Value'           , 'Shield'                                , 4, 6),
(90081, 46, 65, 0, 0, 0, 16384   , 'Frost Armor'               , 'Shield'                                , 4, 6);
