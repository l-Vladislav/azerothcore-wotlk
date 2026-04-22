-- ============================================================================
-- Fortune Pool T4 — iLvl 66-92 (34 enchants)
-- Source of truth: .claude/statBoosterItems/pools/fortune_pool/fortune_T4.md
-- Rows ordered by primary slot (first bit in ItemTypeMask); ItemClassFilter groups: 0, 2, 4, 6
-- ============================================================================

DELETE FROM `statbooster_enchant_template` WHERE `PoolGroup` = 4 AND `iLvlMin` = 66 AND `iLvlMax` = 92;

INSERT INTO `statbooster_enchant_template` (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `Description`, `Note`, `PoolGroup`, `ItemClassFilter`) VALUES
-- Head (primary slot)
(90007, 66, 92, 0, 0, 0, 2       , 'Stealth Detect +5'         , 'Head+Wrists'                           , 4, 0),
(90012, 66, 92, 0, 0, 0, 1122282 , '+2% Threat'                , 'Armor no Neck/Shield'                  , 4, 0),
(90018, 66, 92, 0, 0, 0, 1052650 , '-4% Threat'                , 'No Neck/Trinket/Back/Shield'           , 4, 0),
(90024, 66, 92, 0, 0, 0, 1122286 , '+15 All Magic Resist'      , 'Armor no shield'                       , 4, 0),
(90025, 66, 92, 0, 0, 0, 1138670 , '+14 HP5 in Combat'         , 'Armor+shield'                          , 4, 0),
(90026, 66, 92, 0, 0, 0, 1138670 , '+10% Health Regen Rate'    , 'Armor+shield'                          , 4, 0),
(90027, 66, 92, 0, 0, 0, 1138666 , '-10% Fear Duration'        , 'Armor+shield no Neck'                  , 4, 0),
(90028, 66, 92, 0, 0, 0, 1138666 , '-10% Stun Duration'        , 'Armor+shield no Neck'                  , 4, 0),
(90046, 66, 92, 0, 0, 0, 1138670 , '+13 Mana per 5'            , 'Armor+shield'                          , 4, 0),
(90048, 66, 92, 0, 0, 0, 1122286 , '+20 All Magic Resist'      , 'Armor no shield'                       , 4, 0),
(90049, 66, 92, 0, 0, 0, 1138670 , '+16 HP5 in Combat'         , 'Armor+shield'                          , 4, 0),
(90077, 66, 92, 0, 0, 0, 4098    , 'Water Breathing'           , 'Head+Trinket'                          , 4, 0),

-- Neck (primary slot)
(90002, 66, 92, 0, 0, 0, 1122284 , '+8% Movement Speed'        , 'Armor no Head/Shield'                  , 4, 0),
(90003, 66, 92, 0, 0, 0, 260     , 'Water Walk'                , 'Neck+Feet'                             , 4, 0),
(90005, 66, 92, 0, 0, 0, 70596   , '+3% Mounted Speed'         , 'Neck+Waist+Legs+Feet+Wrists+Trinket+Back', 4, 0),

-- Feet (primary slot)
(90004, 66, 92, 0, 0, 0, 1280    , '+15% Swim Speed'           , 'Feet+Hands'                            , 4, 0),

-- Finger (primary slot)
(90017, 66, 92, 0, 0, 0, 6305792 , '+40 Attack Power'          , 'Armor no Head/Neck/Shield'             , 4, 0),
(90021, 66, 92, 0, 0, 0, 6305792 , '+35 Spell Power'           , 'Armor no shield'                       , 4, 0),
(90029, 66, 92, 0, 0, 0, 71680   , '+10% Reputation Gain'      , 'Finger+Trinket+Back'                   , 4, 0),
(90089, 66, 92, 0, 0, 0, 6144    , 'Blood Pact'                , 'Finger+Trinket'                        , 4, 0),

-- Back/Cloak (primary slot)
(90034, 66, 92, 0, 0, 0, 65536   , 'Feather Fall'              , 'Back only'                             , 4, 0),
(90085, 66, 92, 0, 0, 0, 65536   , 'Immolate'                  , 'Back'                                  , 4, 0),

-- 2H Weapon (primary slot)
(90045, 66, 92, 0, 0, 0, 131072  , '+43 Spell Power'           , 'Armor no shield'                       , 4, 0),
(90047, 66, 92, 0, 0, 0, 131072  , '+60 Attack Power'          , 'Armor no Head/Neck/Shield'             , 4, 0),

-- Weapons (ItemClassFilter=2)
(90044, 66, 92, 0, 0, 0, 0       , 'Crusader'                  , 'Weapons'                               , 4, 2),
(90070, 66, 92, 0, 0, 0, 0       , 'Lifeward'                  , 'Weapons'                               , 4, 2),
(90071, 66, 92, 0, 0, 0, 0       , 'Deathfrost'                , 'Weapons'                               , 4, 2),
(90072, 66, 92, 0, 0, 0, 0       , 'Executioner'               , 'Weapons'                               , 4, 2),
(90080, 66, 92, 0, 0, 0, 0       , 'Frost Ring'                , 'Weapons'                               , 4, 2),
(90090, 66, 92, 0, 0, 0, 0       , 'Arcane Burst'              , 'Weapons, AoE proc, T4'                 , 4, 2),

-- Armor non-shield (ItemClassFilter=4)
(90032, 66, 92, 0, 0, 0, 1132520 , 'Thorns (25 damage)'        , 'Armor+shield'                          , 4, 4),

-- Shield (ItemClassFilter=6)
(90014, 66, 92, 0, 0, 0, 16384   , '+27 Block Value'           , 'Shield'                                , 4, 6),
(90035, 66, 92, 0, 0, 0, 16384   , '1% Spell Reflect'          , 'Shield'                                , 4, 6),
(90081, 66, 92, 0, 0, 0, 16384   , 'Frost Armor'               , 'Shield'                                , 4, 6);
