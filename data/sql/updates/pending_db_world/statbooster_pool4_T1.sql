-- ============================================================================
-- Fortune Pool T1 — iLvl 1-25 (30 enchants)
-- Source of truth: .claude/statBoosterItems/pools/fortune_pool/fortune_T1.md
-- Rows ordered by primary slot (first bit in ItemTypeMask); ItemClassFilter groups: 0, 2, 4, 6
-- ============================================================================

DELETE FROM `statbooster_enchant_template` WHERE `PoolGroup` = 4 AND `iLvlMin` = 1 AND `iLvlMax` = 25;

INSERT INTO `statbooster_enchant_template` (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `Description`, `Note`, `PoolGroup`, `ItemClassFilter`) VALUES
-- Head (primary slot)
(90007,  1, 25, 0, 0, 0, 2       , 'Stealth Detect +5'         , 'Head+Wrists'                           , 4, 0),
(90008,  1, 25, 0, 0, 0, 1122286 , '+6 All Magic Resist'       , 'Armor no shield'                       , 4, 0),
(90010,  1, 25, 0, 0, 0, 1138670 , '+6 HP5 in Combat'          , 'Armor+shield'                          , 4, 0),
(90012,  1, 25, 0, 0, 0, 1138666 , '+2% Threat'                , 'Armor+shield no Neck'                  , 4, 0),
(90018,  1, 25, 0, 0, 0, 1122282 , '-4% Threat'                , 'No Neck/Trinket/Back/Shield'           , 4, 0),
(90022,  1, 25, 0, 0, 0, 1138670 , '+4 Mana per 5'             , 'Any gear'                              , 4, 0),
(90026,  1, 25, 0, 0, 0, 1138670 , '+10% Health Regen Rate'    , 'Armor+shield'                          , 4, 0),
(90050,  1, 25, 0, 0, 0, 3366894 , '+3 HP Periodic Heal'       , 'Any gear'                              , 4, 0),
(90054,  1, 25, 0, 0, 0, 1138670 , '+3 HP5 in Combat'          , 'Armor+shield'                          , 4, 0),
(90055,  1, 25, 0, 0, 0, 1138670 , '+2 All Magic Resist'       , 'Armor+shield'                          , 4, 0),
(90077,  1, 25, 0, 0, 0, 4098    , 'Water Breathing'           , 'Head+Trinket'                          , 4, 0),

-- Neck (primary slot)
(90001,  1, 25, 0, 0, 0, 1122284 , '+5% Movement Speed'        , 'No Head/Shield'                        , 4, 0),
(90029,  1, 25, 0, 0, 0, 6148    , '+10% Reputation Gain'      , 'Finger+Trinket+Back'                   , 4, 0),

-- Shoulder (primary slot)
(90030,  1, 25, 0, 0, 0, 67208   , 'Thorns (3 damage)'         , 'Armor+weapons'                         , 4, 0),
(90052,  1, 25, 0, 0, 0, 6431752 , '+5 Melee Damage'           , 'Shoulder+Hands+weapons'                , 4, 0),

-- Feet (primary slot)
(90003,  1, 25, 0, 0, 0, 256     , 'Water Walk'                , 'Neck+Feet'                             , 4, 0),
(90004,  1, 25, 0, 0, 0, 1280    , '+15% Swim Speed'           , 'Feet+Hands'                            , 4, 0),
(90005,  1, 25, 0, 0, 0, 4352    , '+3% Mounted Speed'         , 'Neck+Waist+Legs+Feet+Wrists+Trinket+Back', 4, 0),

-- Hands (primary slot)
(90015,  1, 25, 0, 0, 0, 136192  , '+22 Attack Power'          , 'No Head/Neck/Shield'                   , 4, 0),

-- Finger (primary slot)
(90086,  1, 25, 0, 0, 0, 6144    , 'Blood Pact'                , 'Finger+Trinket'                        , 4, 0),

-- Trinket (primary slot)
(90019,  1, 25, 0, 0, 0, 135168  , '+11 Spell Power'           , 'No shield'                             , 4, 0),

-- 1H Weapon (primary slot)
(90053,  1, 25, 0, 0, 0, 6430720 , '+7 Melee Damage'           , 'Shield+weapons'                        , 4, 0),

-- Back/Cloak (primary slot)
(90034,  1, 25, 0, 0, 0, 65536   , 'Feather Fall'              , 'Back only'                             , 4, 0),
(90082,  1, 25, 0, 0, 0, 65536   , 'Immolate'                  , 'Back'                                  , 4, 0),

-- Weapons (ItemClassFilter=2)
(90036,  1, 25, 0, 0, 0, 0       , '+16 Damage on Hit'         , 'Weapons'                               , 4, 2),
(90040,  1, 25, 0, 0, 0, 0       , 'Fiery Weapon'              , 'Weapons'                               , 4, 2),
(90041,  1, 25, 0, 0, 0, 0       , 'Lifestealing'              , 'Weapons'                               , 4, 2),
(90075,  1, 25, 0, 0, 0, 0       , 'Arcane Burst'              , 'Weapons, AoE proc'                     , 4, 2),

-- Armor non-shield (ItemClassFilter=4)
(90051,  1, 25, 0, 0, 0, 1132522 , '+5 Damage Shield'          , 'Armor+shield'                          , 4, 4),

-- Shield (ItemClassFilter=6)
(90013,  1, 25, 0, 0, 0, 16384   , '+20 Block Value'           , 'Shield'                                , 4, 6);
