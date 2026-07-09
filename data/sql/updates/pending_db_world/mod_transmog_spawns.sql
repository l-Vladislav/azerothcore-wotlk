-- ============================================================================
-- LIVE-ONLY: World spawns for the mod-transmog Warpweaver NPC (entry 190010).
-- Source: `SELECT * FROM acore_world_ptr.creature WHERE id1 = 190010` (3 rows,
-- verified 2026-07-04) — exact position/orientation copy from PTR, where a GM
-- placed these spawns during testing (2026-07-02..04).
--
-- GUIDs 5300725 / 5300728 / 5300731 were verified FREE on live acore_world
-- (live MAX(guid) = 5300678 at generation time), so the PTR guids are reused
-- verbatim — no remapping needed.
--
-- PREREQUISITE: apply AFTER nemesis_t1_retire.sql + mod_transmog_install.sql
-- (creature_template 190010 must already be the Warpweaver, not the retired
-- Guardian Wolf Cub).
--
-- DO NOT APPLY TO PTR — acore_world_ptr already has these exact spawns from
-- GM placement; re-running this file there would just be a harmless no-op
-- (DELETE+re-INSERT of identical rows) but is unnecessary. This file is
-- LIVE-only by design and is not expected to show up as "pending on PTR".
--
-- Idempotent: DELETE by guid, then INSERT.
-- ============================================================================

DELETE FROM `creature` WHERE `guid` IN (5300725, 5300728, 5300731);

INSERT INTO `creature`
  (`guid`, `id1`, `id2`, `id3`, `map`, `zoneId`, `areaId`, `spawnMask`, `phaseMask`,
   `equipment_id`, `position_x`, `position_y`, `position_z`, `orientation`,
   `spawntimesecs`, `wander_distance`, `currentwaypoint`, `curhealth`, `curmana`,
   `MovementType`, `npcflag`, `unit_flags`, `dynamicflags`, `ScriptName`,
   `VerifiedBuild`, `CreateObject`, `Comment`)
VALUES
  (5300725, 190010, 0, 0, 0, 0, 0, 1, 1, 0, -8841.09, 637.145, 95.0508, 2.31021,
   300, 0, 0, 12600, 0, 0, 0, 0, 0, '', NULL, 0, 'Warpweaver - live promotion from PTR GM spawn'),
  (5300728, 190010, 0, 0, 0, 0, 0, 1, 1, 0, -8941.97, 778.907, 89.8481, 4.5538,
   300, 0, 0, 12600, 0, 0, 0, 0, 0, '', NULL, 0, 'Warpweaver - live promotion from PTR GM spawn'),
  (5300731, 190010, 0, 0, 0, 0, 0, 1, 1, 0, -11346.5, -217.08, 75.2798, 0.663931,
   300, 0, 0, 12600, 0, 0, 0, 0, 0, '', NULL, 0, 'Warpweaver - live promotion from PTR GM spawn');
