-- ============================================================================
-- Nemesis Familiar System — Tier 1 (consolidated, fixed to avoid
-- collision with StatBooster's spell_dbc IDs 100050-100052).
--
-- Previous IDs:   summon spells 100050/100051/100052
-- New IDs:        summon spells 100120/100121/100122
--
-- Reason: StatBooster's statbooster_pool3_base.sql defines 100050 (+5 Arcane
-- Spell Damage), 100051 (+5 Holy), 100052 (+7 Fire) and its enchants
-- 90110/90111/90112 point to them via EffectArg_1. Our earlier migration
-- overwrote those rows with summon spells, which silently broke the
-- StatBooster enchants on re-equip (they'd try to cast a summon on enchant
-- trigger instead of applying a damage aura).
--
-- Scope:
--   spell_dbc 100120/100121/100122   — new summon spells (pure SUMMON,
--                                      MiscB=41, TargetA=32, Attr=262416)
--   spell_dbc 100050/100051/100052   — RESTORED to StatBooster pool3 values
--                                      (PASSIVE + HIDDEN_CLIENTSIDE stat
--                                      auras; matches statbooster_pool3_base.sql)
--   spell_dbc 101100/101101/101102   — passive owner-aura spells (unchanged)
--   creature_template 190010/011/012 — Critter + FollowerAI (unchanged)
--   item_template    100030/031/032  — companion scrolls (spellid_2 remapped
--                                      from 100050-100052 to 100120-100122)
--   npc_vendor       190000          — 3 scroll rows (unchanged)
--
-- Player-side: any existing characters who already learned 100050/100051/100052
-- via our scrolls are migrated to the new IDs via `character_spell` update.
-- ============================================================================

-- ============================================================================
-- STEP 1: Summon spells (new safe range 100120-100122)
-- ============================================================================

DELETE FROM `spell_dbc` WHERE `ID` IN (100120, 100121, 100122);
REPLACE INTO `spell_dbc` (`ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `RangeIndex`, `EquippedItemClass`, `Effect_1`, `EffectMiscValue_1`, `EffectMiscValueB_1`, `ImplicitTargetA_1`, `SchoolMask`, `SpellIconID`, `Name_Lang_enUS`) VALUES
(100120, 262416, 1, 21, 1, -1, 28, 190010, 41, 32, 1, 1582, 'Summon Familiar: Guardian Wolf Cub'),
(100121, 262416, 1, 21, 1, -1, 28, 190011, 41, 32, 1, 1582, 'Summon Familiar: Falcon Chick'),
(100122, 262416, 1, 21, 1, -1, 28, 190012, 41, 32, 1, 1582, 'Summon Familiar: Raven Fledgling');

-- ============================================================================
-- STEP 2: Restore StatBooster spells at 100050/100051/100052
-- Values pulled directly from data/sql/updates/pending_db_world/statbooster_pool3_base.sql:36-39
-- Attributes 192 = PASSIVE + HIDDEN_CLIENTSIDE (item-passive stat aura).
-- EffectAura 13 = SPELL_AURA_MOD_DAMAGE_DONE; MiscValue = school mask.
-- ============================================================================

DELETE FROM `spell_dbc` WHERE `ID` IN (100050, 100051, 100052);
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `EquippedItemClass`, `CastingTimeIndex`, `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValue_1`, `SchoolMask`, `Name_Lang_enUS`) VALUES
(100050, 192, -1, 1, 6, 13, 4, 1, 64, 64, '+5 Arcane Spell Damage'),
(100051, 192, -1, 1, 6, 13, 4, 1, 2,  2,  '+5 Holy Spell Damage'),
(100052, 192, -1, 1, 6, 13, 6, 1, 4,  4,  '+7 Fire Spell Damage');

-- ============================================================================
-- STEP 3: Owner-aura spells (101100/101101/101102)
-- Attributes=2147483648 (0x80000000 = SPELL_ATTR0_NO_AURA_CANCEL) — player
-- cannot right-click the buff off; only the C++ hook removes it on familiar
-- despawn. NOT SPELL_ATTR0_PASSIVE (64) — passive routes triggered CastSpell
-- through a "learned-only" path and silently no-ops (see memory
-- feedback_familiar_aura_uncancellable.md).
-- DurationIndex=21 — PERMANENT (SpellDuration.dbc row 21 = -1/-1/-1 on
-- 3.3.5a). Earlier "30 min, matches companion lifetime" comment was wrong;
-- duration is unlimited, the C++ hook is what removes the aura at despawn.
-- ProcChance=101 required: without it APPLY_AURA effects get discarded on
-- creation (see memory/feedback_spell_dbc_aura_fields.md and implementation
-- log bug #13). Applied/removed by C++ hook in NemesisSystemAllCreatureScript.
-- ============================================================================

-- EffectDieSides_1=1 is REQUIRED: aura amount = EffectBasePoints + DieRoll(1..DieSides),
-- so BasePoints=0 + DieSides=0 yields amount=0 → aura applies but does nothing.
-- BasePoints=0 + DieSides=1 yields amount=1 → +1% (matches design).
DELETE FROM `spell_dbc` WHERE `ID` IN (101100, 101101, 101102);
REPLACE INTO `spell_dbc` (`ID`, `Attributes`, `DurationIndex`, `ProcChance`, `RangeIndex`, `EquippedItemClass`, `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`, `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `SpellIconID`, `Name_Lang_enUS`, `Description_Lang_enUS`) VALUES
(101100, 2147483648, 21, 101, 1, -1, 6, 101, 0, 1, 1, 1, 1, 1582, 'Familiar Aura: Guardian Wolf Cub', 'Increases your armor by 1%.'),
-- EffectAura 290 = SPELL_AURA_MOD_CRIT_PCT (unified crit: melee+ranged+spell).
-- Raven moved to MOD_DAMAGE_PERCENT_DONE (79) with MiscValue=126 (all magic
-- schools mask: holy+fire+nature+frost+shadow+arcane). Falcon is the crit pet,
-- Raven is the spell-damage pet — roles no longer overlap.
(101101, 2147483648, 21, 101, 1, -1, 6, 290, 0, 1, 0,   1, 1, 1582, 'Familiar Aura: Falcon Chick',      'Increases your critical strike chance by 1%.'),
(101102, 2147483648, 21, 101, 1, -1, 6, 79,  0, 1, 126, 1, 1, 1582, 'Familiar Aura: Raven Fledgling',   'Increases your magical damage done by 1%.');

-- ============================================================================
-- STEP 4: Familiar creatures (unchanged)
-- ============================================================================

DELETE FROM `creature_template_locale` WHERE `entry` IN (190010, 190011, 190012);
DELETE FROM `creature_template_model` WHERE `CreatureID` IN (190010, 190011, 190012);
DELETE FROM `creature_template` WHERE `entry` IN (190010, 190011, 190012);

REPLACE INTO `creature_template` (`entry`, `name`, `subname`, `minlevel`, `maxlevel`, `faction`, `unit_class`, `type`, `family`, `npcflag`, `AIName`) VALUES
(190010, 'Guardian Wolf Cub', '', 1, 1, 35, 1, 7, 0, 0, ''),
(190011, 'Falcon Chick',      '', 1, 1, 35, 1, 7, 0, 0, ''),
(190012, 'Raven Fledgling',   '', 1, 1, 35, 1, 7, 0, 0, '');

-- Display IDs picked to match the familiar names:
--   9563 = Worg Pup (classic AV "Worg Carrier" companion-pet model — small,
--          dog-sized, follows nicely)
--   6299 = Hawk Owl (stock non-combat pet model — small hawk-like owl)
--   6435 = Raven (creature 7605 — actual raven model)
-- Earlier values 903 / 6573 / 15533 were wrong models entirely
-- (903=Mangy Wolf adult, 6573=Ravenholdt Guard human, 15533=Vekniss insect).
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(190010, 0, 9563, 1, 1, 0),
(190011, 0, 6299, 1, 1, 0),
(190012, 0, 6435, 1, 1, 0);

INSERT INTO `creature_template_locale` (`entry`, `locale`, `Name`, `Title`) VALUES
(190010, 'ruRU', 'Волчонок-Страж', ''),
(190011, 'ruRU', 'Соколёнок',       ''),
(190012, 'ruRU', 'Вороненок',       '');

-- ============================================================================
-- STEP 5: Teach scrolls — spellid_2 updated to new summon IDs (100120-100122)
-- ============================================================================

DELETE FROM `item_template_locale` WHERE `ID` IN (100030, 100031, 100032) AND `locale` = 'ruRU';
DELETE FROM `item_template` WHERE `entry` IN (100030, 100031, 100032);

REPLACE INTO `item_template` (`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`, `Flags`, `BuyPrice`, `SellPrice`, `InventoryType`, `AllowableClass`, `ItemLevel`, `RequiredLevel`, `MaxCount`, `stackable`, `spellid_1`, `spelltrigger_1`, `spellcharges_1`, `spellid_2`, `spelltrigger_2`, `spellcharges_2`, `bonding`, `description`, `Material`) VALUES
(100030, 15, 2, 'Scroll of Summoning: Guardian Wolf Cub', 20629, 3, 64, 0, 100, 0, -1, 1, 1, 0, 1, 55884, 0, -1, 100120, 6, 0, 1, 'Teaches you to summon a Guardian Wolf Cub familiar.', 4),
(100031, 15, 2, 'Scroll of Summoning: Falcon Chick',      20629, 3, 64, 0, 100, 0, -1, 1, 1, 0, 1, 55884, 0, -1, 100121, 6, 0, 1, 'Teaches you to summon a Falcon Chick familiar.',      4),
(100032, 15, 2, 'Scroll of Summoning: Raven Fledgling',   20629, 3, 64, 0, 100, 0, -1, 1, 1, 0, 1, 55884, 0, -1, 100122, 6, 0, 1, 'Teaches you to summon a Raven Fledgling familiar.',   4);

INSERT INTO `item_template_locale` (`ID`, `locale`, `Name`, `Description`) VALUES
(100030, 'ruRU', 'Свиток призыва: Волчонок-Страж', 'Обучает вас призывать фамильяра — Волчонка-Стража.'),
(100031, 'ruRU', 'Свиток призыва: Соколёнок',       'Обучает вас призывать фамильяра — Соколёнка.'),
(100032, 'ruRU', 'Свиток призыва: Вороненок',       'Обучает вас призывать фамильяра — Вороненка.');

-- ============================================================================
-- STEP 6: Vendor rows (unchanged)
-- ============================================================================

DELETE FROM `npc_vendor` WHERE `entry` = 190000 AND `item` IN (100030, 100031, 100032);
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`) VALUES
(190000, 100, 100030, 0, 0, 100001, 0),
(190000, 101, 100031, 0, 0, 100001, 0),
(190000, 102, 100032, 0, 0, 100001, 0);

-- ============================================================================
-- Cleanup of stale rows from earlier drafts (safe no-ops if absent).
-- IMPORTANT: Do NOT delete 100050/100051/100052 here — those are now
-- restored StatBooster spells. Earlier cleanup line removed.
-- ============================================================================

DELETE FROM `spell_dbc` WHERE `ID` IN (100070, 100071, 100072, 100100, 100101, 100102);
DELETE FROM `smart_scripts` WHERE `entryorguid` IN (190010, 190011, 190012) AND `source_type` = 0;
