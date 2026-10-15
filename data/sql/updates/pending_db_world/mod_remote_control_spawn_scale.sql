-- mod-remote-control: масштаб закреплённых объектов (#189).

CREATE TABLE IF NOT EXISTS `mod_remote_control_spawn_scale` (
  `guid`  INT UNSIGNED NOT NULL COMMENT 'gameobject.guid',
  `scale` FLOAT NOT NULL,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
