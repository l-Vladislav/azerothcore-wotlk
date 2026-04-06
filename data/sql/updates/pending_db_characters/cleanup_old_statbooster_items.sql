-- ============================================================================
-- Clean up deprecated StatBooster items from old iteration (17827-17896 range)
-- These items were replaced by custom IDs 100001-100016.
-- Remove any AH listings and item instances of the old items.
-- ============================================================================

-- Remove old items from auction house
DELETE ah FROM `auctionhouse` ah
INNER JOIN `item_instance` ii ON ah.`itemguid` = ii.`guid`
WHERE ii.`itemEntry` BETWEEN 17827 AND 17896;

-- Remove old item instances
DELETE FROM `item_instance` WHERE `itemEntry` BETWEEN 17827 AND 17896;
