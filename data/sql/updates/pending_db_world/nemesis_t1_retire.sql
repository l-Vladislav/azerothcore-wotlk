-- ============================================================================
-- Retire old T1 familiars (Guardian Wolf Cub / Falcon Chick / Raven Fledgling)
-- per .claude/familiars/familiar_gacha_id_reservations.md "Retired ranges"
-- (phase 3c). Their gacha successors are Common starters 191000/191070/191050
-- (summon spells 102000/102070/102050). Learned character spells are remapped
-- in pending_db_characters/nemesis_t1_retire_characters.sql.
--
-- Entries 190010/190011 are reused by mod-transmog (Warpweaver / Ethereal
-- Warpweaver) — APPLY THIS FILE BEFORE mod_transmog_install.sql.
-- Creature deletions are name-guarded so a re-run after the transmog install
-- cannot delete the transmog NPCs.
-- ============================================================================

-- Scrolls no longer sold by the nemesis vendor
DELETE FROM `npc_vendor` WHERE `entry` = 190000 AND `item` IN (100030, 100031, 100032);

-- Teach scrolls
DELETE FROM `item_template_locale` WHERE `ID` IN (100030, 100031, 100032);
DELETE FROM `item_template` WHERE `entry` IN (100030, 100031, 100032);

-- Summon spells (100120-22) and owner auras (101100-02)
DELETE FROM `spell_dbc` WHERE `ID` IN (100120, 100121, 100122, 101100, 101101, 101102);

-- Stale SAI rows from earlier drafts (no-op if absent; transmog NPCs use
-- ScriptName, not SAI, so this stays safe post-install)
DELETE FROM `smart_scripts` WHERE `entryorguid` IN (190010, 190011, 190012) AND `source_type` = 0;

-- World spawns of the old critters (name-guarded; must run before the
-- template deletion below)
DELETE ca FROM `creature_addon` ca
  JOIN `creature` c ON c.`guid` = ca.`guid`
  JOIN `creature_template` ct ON ct.`entry` = c.`id`
 WHERE ct.`entry` IN (190010, 190011, 190012)
   AND ct.`name` IN ('Guardian Wolf Cub', 'Falcon Chick', 'Raven Fledgling');
DELETE c FROM `creature` c
  JOIN `creature_template` ct ON ct.`entry` = c.`id`
 WHERE ct.`entry` IN (190010, 190011, 190012)
   AND ct.`name` IN ('Guardian Wolf Cub', 'Falcon Chick', 'Raven Fledgling');

-- Creature templates (name-guarded)
DELETE ctm FROM `creature_template_model` ctm
  JOIN `creature_template` ct ON ct.`entry` = ctm.`CreatureID`
 WHERE ct.`entry` IN (190010, 190011, 190012)
   AND ct.`name` IN ('Guardian Wolf Cub', 'Falcon Chick', 'Raven Fledgling');
DELETE ctl FROM `creature_template_locale` ctl
  JOIN `creature_template` ct ON ct.`entry` = ctl.`entry`
 WHERE ct.`entry` IN (190010, 190011, 190012)
   AND ct.`name` IN ('Guardian Wolf Cub', 'Falcon Chick', 'Raven Fledgling');
DELETE FROM `creature_template`
 WHERE `entry` IN (190010, 190011, 190012)
   AND `name` IN ('Guardian Wolf Cub', 'Falcon Chick', 'Raven Fledgling');
