-- ============================================================================
-- StatBooster Fortune Pool v2c — Passive Auras (Classic Tier, iLvl 1-92)
-- Replaces v1 proc-based Fortune pool with permanent passive auras.
-- Uses EQUIP_SPELL (type 3) with existing client spell IDs — no DBC patches.
-- No code changes needed — just SQL.
-- ============================================================================

-- ============================================================================
-- STEP 1: Clean old Fortune enchants (v1)
-- ============================================================================

DELETE FROM `spellitemenchantment_dbc` WHERE `ID` BETWEEN 90001 AND 90105;
DELETE FROM `statbooster_enchant_template` WHERE `Id` BETWEEN 90001 AND 90105;

-- ============================================================================
-- STEP 2: Create SpellItemEnchantment entries
-- Effect_1 = 3 means ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL
-- EffectArg_1 = passive aura spell ID (must exist in client Spell.dbc)
-- Server applies aura on equip, removes on unequip — fully automatic.
-- ============================================================================

INSERT INTO `spellitemenchantment_dbc` (`ID`, `Charges`, `Effect_1`, `Effect_2`, `Effect_3`, `EffectPointsMin_1`, `EffectPointsMin_2`, `EffectPointsMin_3`, `EffectPointsMax_1`, `EffectPointsMax_2`, `EffectPointsMax_3`, `EffectArg_1`, `EffectArg_2`, `EffectArg_3`, `Name_Lang_enUS`, `Name_Lang_Mask`, `ItemVisual`, `Flags`, `Src_ItemID`, `Condition_Id`, `RequiredSkillID`, `RequiredSkillRank`, `MinLevel`) VALUES
-- ── UTILITY: Movement & Travel (all roles) ──
(90001, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 22586, 0, 0, '+5% Movement Speed',              0, 0, 0, 0, 0, 0, 0, 0),
(90002, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 22587, 0, 0, '+8% Movement Speed',              0, 0, 0, 0, 0, 0, 0, 0),
(90003, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 10665, 0, 0, 'Water Walk',                      0, 0, 0, 0, 0, 0, 0, 0),
(90034, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 10729, 0, 0, 'Feather Fall',                    0, 0, 0, 0, 0, 0, 0, 0),
(90004, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 8747,  0, 0, '+15% Swim Speed',                 0, 0, 0, 0, 0, 0, 0, 0),
(90005, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 48777, 0, 0, '+3% Mounted Speed',               0, 0, 0, 0, 0, 0, 0, 0),
(90006, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 1860,  0, 0, 'Reduce Fall Damage',              0, 0, 0, 0, 0, 0, 0, 0),
-- ── UTILITY: Detection (all roles) ──
(90007, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 58985, 0, 0, 'Stealth Detect',                  0, 0, 0, 0, 0, 0, 0, 0),
-- ── DEFENSIVE: All Resist (tank) ──
(90008, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 18677, 0, 0, '+6 All Magic Resist',             0, 0, 0, 0, 0, 0, 0, 0),
(90009, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 18681, 0, 0, '+10 All Magic Resist',            0, 0, 0, 0, 0, 0, 0, 0),
-- ── DEFENSIVE: HP5 in Combat (tank) ──
(90010, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21348, 0, 0, '+6 HP5 in Combat',               0, 0, 0, 0, 0, 0, 0, 0),
(90011, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21349, 0, 0, '+10 HP5 in Combat',              0, 0, 0, 0, 0, 0, 0, 0),
-- ── DEFENSIVE: Threat & Block (tank) ──
(90012, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 25063, 0, 0, '+2% Threat',                     0, 0, 0, 0, 0, 0, 0, 0),
(90013, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 23172, 0, 0, '+20 Block Value',                0, 0, 0, 0, 0, 0, 0, 0),
(90014, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 23515, 0, 0, '+27 Block Value',                0, 0, 0, 0, 0, 0, 0, 0),
-- ── OFFENSIVE: Attack Power (phys DPS) ──
(90015, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9332,  0, 0, '+22 Attack Power',               0, 0, 0, 0, 0, 0, 0, 0),
(90016, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9336,  0, 0, '+30 Attack Power',               0, 0, 0, 0, 0, 0, 0, 0),
(90017, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 14049, 0, 0, '+40 Attack Power',               0, 0, 0, 0, 0, 0, 0, 0),
-- ── OFFENSIVE: Threat Reduction (phys DPS) ──
(90018, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 25070, 0, 0, '-4% Threat',                     0, 0, 0, 0, 0, 0, 0, 0),
-- ── CASTER: Spell Power (spell) ──
(90019, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9416,  0, 0, '+11 Spell Power',                0, 0, 0, 0, 0, 0, 0, 0),
(90020, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 14248, 0, 0, '+21 Spell Power',                0, 0, 0, 0, 0, 0, 0, 0),
(90021, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 14055, 0, 0, '+35 Spell Power',                0, 0, 0, 0, 0, 0, 0, 0),
-- ── CASTER: MP5 (spell) ──
(90022, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21361, 0, 0, '+4 Mana per 5',                  0, 0, 0, 0, 0, 0, 0, 0),
(90023, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21363, 0, 0, '+6 Mana per 5',                  0, 0, 0, 0, 0, 0, 0, 0),
-- ── HYBRID ──
(90024, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 18686, 0, 0, '+15 All Magic Resist',           0, 0, 0, 0, 0, 0, 0, 0),
(90025, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 21350, 0, 0, '+14 HP5 in Combat',              0, 0, 0, 0, 0, 0, 0, 0),
(90026, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20555, 0, 0, '+10% Health Regen Rate',         0, 0, 0, 0, 0, 0, 0, 0),
-- ── CC RESISTANCE (all roles) ──
(90027, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 55357, 0, 0, '-10% Fear Duration',             0, 0, 0, 0, 0, 0, 0, 0),
(90028, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 55358, 0, 0, '-10% Stun Duration',             0, 0, 0, 0, 0, 0, 0, 0),
-- ── REPUTATION (all roles) ──
(90029, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20599, 0, 0, '+10% Reputation Gain',           0, 0, 0, 0, 0, 0, 0, 0),
-- ── THORNS: Damage to Attackers (tank) ──
(90030, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 467,   0, 0, 'Thorns (3 damage)',              0, 0, 0, 0, 0, 0, 0, 0),
(90031, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9910,  0, 0, 'Thorns (18 damage)',             0, 0, 0, 0, 0, 0, 0, 0),
(90032, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 26992, 0, 0, 'Thorns (25 damage)',             0, 0, 0, 0, 0, 0, 0, 0),
-- ── SPELL REFLECT (tank, shields) ──
(90035, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 11818, 0, 0, '1% Spell Reflect',               0, 0, 0, 0, 0, 0, 0, 0),
-- ── WEAPON PROCS: Damage (phys DPS) ──
(90040, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 43929, 0, 0, 'Fiery Weapon',                   0, 0, 0, 0, 0, 0, 0, 0),
(90041, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20004, 0, 0, 'Lifestealing',                   0, 0, 0, 0, 0, 0, 0, 0),
(90042, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20005, 0, 0, 'Icy Chill',                      0, 0, 0, 0, 0, 0, 0, 0),
(90043, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20006, 0, 0, 'Unholy Weapon',                  0, 0, 0, 0, 0, 0, 0, 0),
-- ── WEAPON PROCS: Extra damage (phys DPS) ──
(90036, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9782,  0, 0, '+16 Damage on Hit',              0, 0, 0, 0, 0, 0, 0, 0),
(90037, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 9233,  0, 0, 'Fire Damage Proc',               0, 0, 0, 0, 0, 0, 0, 0),
(90038, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 29455, 0, 0, '+26 Damage on Hit',              0, 0, 0, 0, 0, 0, 0, 0),
-- ── WEAPON PROCS: Crusader (phys DPS, T4) ──
(90044, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20007, 0, 0, 'Crusader',                       0, 0, 0, 0, 0, 0, 0, 0),
-- ── T4 EXCLUSIVES ──
(90045, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 17280, 0, 0, '+43 Spell Power',                0, 0, 0, 0, 0, 0, 0, 0),
(90046, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 20959, 0, 0, '+13 Mana per 5',                 0, 0, 0, 0, 0, 0, 0, 0),
(90047, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 14052, 0, 0, '+60 Attack Power',               0, 0, 0, 0, 0, 0, 0, 0),
(90048, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 18691, 0, 0, '+20 All Magic Resist',           0, 0, 0, 0, 0, 0, 0, 0),
(90049, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 23210, 0, 0, '+16 HP5 in Combat',              0, 0, 0, 0, 0, 0, 0, 0);


-- ============================================================================
-- STEP 3: Add enchants to StatBooster Fortune pool (Pool 4)
-- RoleMask: 0=all, 1=tank, 2=phys, 4=hybrid, 8=spell
-- ItemTypeMask: 351535086 = all except shields/tabards
-- ItemClassFilter (via PoolGroup logic): 0=any, 2=weapon, 4=armor, 6=shield
--
-- Weak enchants are CAPPED by iLvlMax so higher tiers only roll upgrades.
-- ============================================================================

INSERT INTO `statbooster_enchant_template` (`Id`, `iLvlMin`, `iLvlMax`, `RoleMask`, `ClassMask`, `SubClassMask`, `ItemTypeMask`, `Description`, `Note`, `PoolGroup`, `ItemClassFilter`) VALUES
-- ── A1. Movement & Travel (RoleMask=0, all roles) ──
(90001,  1, 45, 0, 0, 0, 351535086, '+5% Movement Speed',              'ALL - T1-T2, replaced by +8% at T3',   4, 0),
(90002, 46, 92, 0, 0, 0, 351535086, '+8% Movement Speed',              'ALL - T3-T4 upgrade',                   4, 0),
(90003,  1, 92, 0, 0, 0, 351535086, 'Water Walk',                      'ALL - all tiers',                       4, 0),
(90034,  1, 92, 0, 0, 0, 351535086, 'Feather Fall',                   'ALL - all tiers',                       4, 0),
(90004,  1, 92, 0, 0, 0, 351535086, '+15% Swim Speed',                 'ALL - all tiers',                       4, 0),
(90005,  1, 92, 0, 0, 0, 351535086, '+3% Mounted Speed',               'ALL - all tiers',                       4, 0),
(90006, 26, 92, 0, 0, 0, 351535086, 'Reduce Fall Damage',              'ALL - T2+',                             4, 0),

-- ── A2. Detection (RoleMask=0, all roles) ──
(90007,  1, 92, 0, 0, 0, 351535086, 'Stealth Detect +5',              'ALL - all tiers',                       4, 0),

-- ── A3. Defensive Passives (RoleMask=1, tank) ──
(90008,  1, 25, 1, 0, 0, 351535086, '+6 All Magic Resist',            'TANK - T1 only',                        4, 0),
(90009, 26, 65, 1, 0, 0, 351535086, '+10 All Magic Resist',           'TANK - T2-T3, replaced by +20 at T4',   4, 0),
(90010,  1, 25, 1, 0, 0, 351535086, '+6 HP5 in Combat',              'TANK - T1 only',                        4, 0),
(90011, 26, 65, 1, 0, 0, 351535086, '+10 HP5 in Combat',             'TANK - T2-T3, replaced by +16 at T4',   4, 0),
(90012,  1, 92, 1, 0, 0, 351535086, '+2% Threat',                    'TANK - all tiers',                      4, 0),
(90013,  1, 45, 1, 0, 0, 351535086, '+20 Block Value',               'TANK - T1-T2, shields only',            4, 6),
(90014, 46, 92, 1, 0, 0, 351535086, '+27 Block Value',               'TANK - T3-T4, shields only',            4, 6),

-- ── A4. Offensive Passives — Physical (RoleMask=2, phys DPS) ──
(90015,  1, 25, 2, 0, 0, 351535086, '+22 Attack Power',              'PHYS - T1 only',                        4, 0),
(90016, 26, 45, 2, 0, 0, 351535086, '+30 Attack Power',              'PHYS - T2 only',                        4, 0),
(90017, 46, 65, 2, 0, 0, 351535086, '+40 Attack Power',              'PHYS - T3 only, replaced by +60 at T4', 4, 0),
(90018,  1, 92, 2, 0, 0, 351535086, '-4% Threat',                    'PHYS - all tiers',                      4, 0),

-- ── A5. Offensive Passives — Caster (RoleMask=8, spell) ──
(90019,  1, 25, 8, 0, 0, 351535086, '+11 Spell Power',               'SPELL - T1 only',                       4, 0),
(90020, 26, 45, 8, 0, 0, 351535086, '+21 Spell Power',               'SPELL - T2 only',                       4, 0),
(90021, 46, 65, 8, 0, 0, 351535086, '+35 Spell Power',               'SPELL - T3 only, replaced by +43 at T4',4, 0),
(90022,  1, 25, 8, 0, 0, 351535086, '+4 Mana per 5',                 'SPELL - T1 only',                       4, 0),
(90023, 26, 65, 8, 0, 0, 351535086, '+6 Mana per 5',                 'SPELL - T2-T3, replaced by +13 at T4',  4, 0),

-- ── A6. Hybrid (RoleMask=4) ──
(90024, 26, 92, 4, 0, 0, 351535086, '+15 All Magic Resist',          'HYBRID - T2+',                          4, 0),
(90025, 26, 92, 4, 0, 0, 351535086, '+14 HP5 in Combat',             'HYBRID - T2+',                          4, 0),
(90026,  1, 92, 4, 0, 0, 351535086, '+10% Health Regen Rate',        'HYBRID - all tiers',                    4, 0),

-- ── A7. CC Resistance (RoleMask=0, all roles) ──
(90027, 46, 92, 0, 0, 0, 351535086, '-10% Fear Duration',            'ALL - T3+',                              4, 0),
(90028, 46, 92, 0, 0, 0, 351535086, '-10% Stun Duration',            'ALL - T3+',                              4, 0),

-- ── A8. Reputation (RoleMask=0, all roles) ──
(90029,  1, 92, 0, 0, 0, 351535086, '+10% Reputation Gain',          'ALL - all tiers',                        4, 0),

-- ── B1. Thorns (RoleMask=1, tank, armor only) ──
(90030,  1, 25, 1, 0, 0, 351535086, 'Thorns (3 damage)',             'TANK - T1 only, armor only',             4, 4),
(90031, 26, 45, 1, 0, 0, 351535086, 'Thorns (18 damage)',            'TANK - T2 only, armor only',             4, 4),
(90032, 46, 92, 1, 0, 0, 351535086, 'Thorns (25 damage)',            'TANK - T3+, armor only',                 4, 4),

-- ── B2. Spell Reflect (RoleMask=1, tank, shields only, T4) ──
(90035, 66, 92, 1, 0, 0, 351535086, '1% Spell Reflect',             'TANK - T4 only, shields only',           4, 6),

-- ── C1. Weapon Procs — Damage (RoleMask=2, phys DPS, weapons only) ──
(90040,  1, 45, 2, 0, 0, 351535086, 'Fiery Weapon',                 'PHYS - T1-T2, weapons only',             4, 2),
(90041,  1, 92, 2, 0, 0, 351535086, 'Lifestealing',                 'PHYS - all tiers, weapons only',         4, 2),
(90042, 26, 92, 2, 0, 0, 351535086, 'Icy Chill',                    'PHYS - T2+, weapons only',               4, 2),
(90043, 26, 92, 2, 0, 0, 351535086, 'Unholy Weapon',                'PHYS - T2+, weapons only',               4, 2),

-- ── C2. Extra Damage (RoleMask=2, phys DPS, weapons only) ──
(90036,  1, 45, 2, 0, 0, 351535086, '+16 Damage on Hit',            'PHYS - T1-T2, weapons only',             4, 2),
(90037, 26, 65, 2, 0, 0, 351535086, 'Fire Damage Proc',             'PHYS - T2-T3, weapons only, 5% fire',    4, 2),
(90038, 46, 92, 2, 0, 0, 351535086, '+26 Damage on Hit',            'PHYS - T3-T4, weapons only',             4, 2),

-- ── C3. Crusader (RoleMask=2, phys DPS, weapons only, T4) ──
(90044, 66, 92, 2, 0, 0, 351535086, 'Crusader',                     'PHYS - T4 only, weapons only',           4, 2),

-- ── D. T4 Exclusives ──
(90045, 66, 92, 8, 0, 0, 351535086, '+43 Spell Power',              'SPELL - T4 only',                        4, 0),
(90046, 66, 92, 8, 0, 0, 351535086, '+13 Mana per 5',               'SPELL - T4 only',                        4, 0),
(90047, 66, 92, 2, 0, 0, 351535086, '+60 Attack Power',             'PHYS - T4 only',                         4, 0),
(90048, 66, 92, 1, 0, 0, 351535086, '+20 All Magic Resist',         'TANK - T4 only',                         4, 0),
(90049, 66, 92, 1, 0, 0, 351535086, '+16 HP5 in Combat',            'TANK - T4 only',                         4, 0);
