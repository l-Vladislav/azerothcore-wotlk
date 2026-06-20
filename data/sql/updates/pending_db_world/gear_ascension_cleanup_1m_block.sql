-- ============================================================================
-- mod-gear-ascension -- ID block migration: DELETE old 1,000,000-1,099,999 rows
-- Removes all tier-copy entries from the old 1M block that were replaced by the
-- 300,000-399,999 block (owner decision 2026-06-18).
-- item_upgrade_chain rows for these bases are also removed (re-inserted by the
-- regenerated gear_ascension_proto.sql which follows).
-- PTR ONLY (acore_world_ptr). Safe to apply multiple times.
-- ============================================================================

-- Clean up old 1M block tier copies
DELETE FROM item_template_locale WHERE ID BETWEEN 1000000 AND 1099999 AND locale = 'ruRU';
DELETE FROM item_template WHERE entry BETWEEN 1000000 AND 1099999;

-- Clean up chain rows that referenced the old 1M entries
-- (The generator deletes by origin_entry, but guard here too by entry range)
DELETE FROM item_upgrade_chain WHERE entry BETWEEN 1000000 AND 1099999;
DELETE FROM item_upgrade_chain WHERE next_entry BETWEEN 1000000 AND 1099999;
DELETE FROM item_upgrade_chain WHERE prev_entry BETWEEN 1000000 AND 1099999;
