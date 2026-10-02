-- mod-world-items: группа добычи в содержимом контейнера.

SET @has_group := (SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mod_world_items_content'
      AND COLUMN_NAME = 'group_id');

SET @sql := IF(@has_group = 0,
    'ALTER TABLE `mod_world_items_content`
       ADD COLUMN `group_id` TINYINT UNSIGNED NOT NULL DEFAULT 0
         COMMENT ''0 - строка бросается сама; >0 - из группы выпадает не больше одного предмета'' AFTER `item_entry`',
    'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

ALTER TABLE `mod_world_items_content`
  MODIFY `chance` FLOAT NOT NULL DEFAULT 100
    COMMENT 'процент; 100 - всегда. В группе 0 - равная доля остатка группы';
