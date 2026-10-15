-- mod-remote-control: избранное пульта по папкам (#189).

CREATE TABLE IF NOT EXISTS `mod_remote_control_favorite_folder` (
  `id`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(60) NOT NULL,
  `sort` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mod_remote_control_favorite` (
  `entry`     INT NOT NULL
              COMMENT 'gameobject_template.entry; отрицательное - номер модели GameObjectDisplayInfo',
  `folder_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'mod_remote_control_favorite_folder.id; 0 - корень',
  `name`      VARCHAR(60) NOT NULL DEFAULT '' COMMENT 'пусто - имя шаблона или файла модели',
  `sort`      INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`entry`),
  KEY `idx_folder` (`folder_id`, `sort`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `mod_remote_control_favorite_folder` (`id`, `name`, `sort`) VALUES
(1, 'Сундуки и ящики', 1),
(2, 'Бочки', 2),
(3, 'Ремесло', 3);

INSERT IGNORE INTO `mod_remote_control_favorite` (`entry`, `folder_id`, `name`, `sort`) VALUES
(2843,   1, '', 1),
(2850,   1, '', 2),
(1560,   1, '', 3),
(179498, 1, '', 4),
(3660,   1, '', 5),
(3662,   1, '', 6),
(176224, 1, '', 7),
(3658,   2, '', 1),
(3705,   2, '', 2),
(175335, 3, '', 1),
(2728,   3, '', 2),
(1744,   3, '', 3);
