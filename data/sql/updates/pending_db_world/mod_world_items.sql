-- mod-world-items: предметы, лежащие в мире.
--
-- Одна строка - одно РАЗМЕЩЕНИЕ, а не предмет. Различие принципиальное: один
-- и тот же шаблон предмета может лежать в десятке мест, и «кто что подобрал»
-- считается по размещению. Иначе, подобрав меч в одной точке, игрок потерял бы
-- его во всех остальных.
--
-- Отсюда же `id AUTO_INCREMENT`: он уникален на весь мир и переживает
-- перезапуск, в отличие от GUID объекта в памяти, который меняется при каждом
-- перемещении (клиент 3.3.5a кэширует удалённые объекты по GUID, поэтому
-- двигать их приходится пересозданием).

CREATE TABLE IF NOT EXISTS `mod_world_items` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,

  -- Что лежит и во что оно завёрнуто.
  `item_entry`    INT UNSIGNED NOT NULL
                  COMMENT 'item_template.entry — что получит игрок',
  `item_count`    INT UNSIGNED NOT NULL DEFAULT 1,
  `go_entry`      INT UNSIGNED NOT NULL DEFAULT 2843
                  COMMENT 'gameobject_template.entry — видимая оболочка',

  -- Ссылка на настоящий спавн в таблице `gameobject`. Спавн, грид-логику,
  -- респавн и выгрузку делает ядро - переизобретать это в модуле означало бы
  -- получить объект, который исчезает при выгрузке грида и не переживает
  -- рестарт. Модуль только перехватывает использование.
  -- NULL, а не 0: уникальный ключ ниже допускает сколько угодно NULL, но лишь
  -- одну строку с нулём, и «ещё не размещено» перестало бы быть возможным
  -- больше одного раза.
  `go_guid`       INT UNSIGNED NULL DEFAULT NULL
                  COMMENT 'gameobject.guid — NULL, пока размещение не закреплено',

  -- Где лежит.
  `map`           SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  `zone`          INT UNSIGNED NOT NULL DEFAULT 0
                  COMMENT 'справочно, для панели и фильтров',
  `x`             FLOAT NOT NULL DEFAULT 0,
  `y`             FLOAT NOT NULL DEFAULT 0,
  `z`             FLOAT NOT NULL DEFAULT 0,
  `o`             FLOAT NOT NULL DEFAULT 0,
  `tilt_y`        FLOAT NOT NULL DEFAULT 0,
  `tilt_x`        FLOAT NOT NULL DEFAULT 0,
  `scale`         FLOAT NOT NULL DEFAULT 1,
  `phase_mask`    INT UNSIGNED NOT NULL DEFAULT 1,

  -- Поведение.
  `one_per_char`  TINYINT UNSIGNED NOT NULL DEFAULT 1
                  COMMENT '1 — после подбора исчезает у этого персонажа навсегда',
  `respawn_secs`  INT UNSIGNED NOT NULL DEFAULT 0
                  COMMENT '0 — лежит всегда; иначе через столько секунд снова доступен',
  `enabled`       TINYINT UNSIGNED NOT NULL DEFAULT 1,

  -- Кто поставил. Полезнее, чем кажется: расставляют несколько человек, и
  -- через месяц «зачем тут сундук» отвечается только этим полем.
  `comment`       VARCHAR(255) NOT NULL DEFAULT '',
  `created_by`    VARCHAR(32) NOT NULL DEFAULT '',
  `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_go_guid` (`go_guid`),
  KEY `idx_map` (`map`, `enabled`),
  KEY `idx_item` (`item_entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
