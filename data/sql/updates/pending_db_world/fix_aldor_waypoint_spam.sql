-- ============================================================================
-- Remove the 12 custom Aldor guard spawns (guids 672001-672012; entries
-- 19153 "Aldor Neophyte", 19337 "Aldor Marksman", 19390 "Mounted Neophyte")
-- to permanently stop worldserver log-spam / repeated failed movement-init.
-- NOT related to recent server lag — this is purely a log-spam / wasted
-- repeated-failed-init cleanup.
--
-- Symptom:
--   WaypointMovementGenerator::DoInitialize: creature <Name> (...) doesn't
--   have waypoint path id: 0
--
-- History / why deletion instead of a config fix (SUPERSEDES the previous
-- version of this file, which is now obsolete and never merged):
--   An earlier version of this file re-asserted (idempotent no-op) the
--   already-correct path config: creature.MovementType=2, wander_distance=0,
--   creature_addon.path_id=guid*10, with matching waypoint_data rows
--   present. Source review confirmed `WaypointMovementGenerator::
--   DoInitialize` (WaypointMovementGenerator.cpp) resolves its path via
--   creature->GetWaypointPath() (Creature::m_path_id, set from
--   creature_addon.path_id in Creature::LoadCreaturesAddon) against
--   sWaypointMgr->GetPath() (WaypointMgr.cpp, backed by `waypoint_data`
--   keyed by `id`) -- i.e. the DB-side config for these 12 guids was
--   objectively correct for how this engine drives MovementType=2. The
--   separate `waypoints` table (PK `entry`) is entry-keyed and consumed only
--   by SmartWaypointMgr for smart_scripts; it is not read by
--   WaypointMovementGenerator and was never the mismatch.
--
--   That "no restart needed, data already correct" conclusion did NOT hold:
--   on a genuinely fresh worldserver boot (new runtime-assigned low GUIDs
--   each boot, e.g. 4604-4611), with creature_addon.path_id set and
--   waypoint_data populated exactly as expected, DoInitialize still resolved
--   path id 0 and logged the same error on every spawn/respawn of these 12
--   guids. So the correct DB-side config does not make the runtime actually
--   use it for these spawns -- root-causing the remaining discrepancy would
--   require a C++-level investigation, which is out of scope for a data-only
--   fix. Decision: since these are custom (672xxx range) spawns whose
--   authored patrol never worked at runtime anyway, delete them outright
--   rather than keep chasing the engine-side mismatch.
--
-- Referential fallout checked directly on both acore_world and
-- acore_world_ptr (guids 672001-672012 / path_ids 6720010-6720120) before
-- writing this file:
--   - pool_creature                      : 0 rows (not pooled)
--   - game_event_creature                : 0 rows (not event-gated)
--   - linked_respawn (guid or linkedGuid) : 0 rows (no linked respawns)
--   - creature_formations (leader/member) : 0 rows (no formations)
--   - acore_characters(.creature_respawn) : 0 rows (no pending respawn timer)
--   - creature_addon                      : 12 rows  -> deleted below
--   - waypoint_data (id 6720010-6720120)   : 158 rows total, and confirmed
--     these path_ids are NOT referenced by any other creature_addon row
--     (the custom guid*10 range is unique to these 12 spawns) -> safe to
--     delete as now-orphaned custom patrol data, deleted below.
--
-- Scope: EXACTLY guids 672001-672012 / entries 19153, 19337, 19390 and their
-- exclusive path_ids 6720010-6720120. No other creature is touched.
--
-- Effect on the CURRENTLY RUNNING worldserver: creature/creature_addon/
-- waypoint_data are cached in memory at startup, so any already-spawned
-- instances of these 12 guids remain in-world (and keep logging the error)
-- until the next worldserver restart -- this DB delete only prevents them
-- from loading on the NEXT startup. No restart is required solely for this
-- migration (purely cosmetic log-spam cleanup); it will take effect on the
-- next natural restart.
-- ============================================================================

DELETE FROM `creature_addon`
 WHERE `guid` IN (672001,672002,672003,672004,672005,672006,672007,672008,672009,672010,672011,672012);

DELETE FROM `creature`
 WHERE `guid` IN (672001,672002,672003,672004,672005,672006,672007,672008,672009,672010,672011,672012);

DELETE FROM `waypoint_data`
 WHERE `id` IN (6720010,6720020,6720030,6720040,6720050,6720060,6720070,6720080,6720090,6720100,6720110,6720120);
