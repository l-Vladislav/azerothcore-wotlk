-- mod-world-items: кто какое размещение уже подобрал.
--
-- Живёт в базе персонажей, а не мира, и это не вкусовщина: строки привязаны к
-- конкретным персонажам и обязаны умирать вместе с ними. В базе мира они
-- пережили бы удаление персонажа и остались бы мусором, на который никто уже
-- не сошлётся.
--
-- Ключ - пара (размещение, персонаж). Именно размещение, а не предмет: один
-- шаблон лежит во многих местах, и подобрать его надо в каждом.

CREATE TABLE IF NOT EXISTS `mod_world_items_loot` (
  `placement_id` INT UNSIGNED NOT NULL
                 COMMENT 'mod_world_items.id из базы мира',
  `guid`         INT UNSIGNED NOT NULL COMMENT 'characters.guid',
  `looted_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`placement_id`, `guid`),
  KEY `idx_guid` (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
