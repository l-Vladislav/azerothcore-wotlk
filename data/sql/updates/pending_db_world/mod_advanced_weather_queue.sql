-- mod-advanced-weather: очередь фронтов
--
-- Самозарождение хорошо тем, что мир живёт сам, но погода тогда каждый раз
-- новая: сценарий «сначала гроза над Штормградом, через десять минут метель в
-- Альтераке» им не выразить. Очередь и есть этот сценарий - список заготовок,
-- которые выпускаются по одной с паузой между ними
-- (AdvancedWeather.Cyclones.GapMinutes, по умолчанию 10 минут).
--
-- Очередь НЕ отменяет потолок AdvancedWeather.Cyclones.PerMap: он остаётся
-- ограничением сверху. Очередь задаёт содержимое, пауза - ритм. Что делать,
-- когда очередь кончилась, решает AdvancedWeather.Cyclones.QueueEnd:
-- 0 - начать сначала, 1 - вернуться к случайным фронтам, 2 - штиль.
--
-- ИСТОЧНИК ПРАВДЫ - админ-панель (страница «Фронты»): она правит эту таблицу
-- и просит сервер перечитать её командой ".aw queuereload". Поэтому таблица
-- заводится пустой: наполняет её человек, а не миграция.
--
-- НУЛИ В СТРОКЕ значат «как у самозародившегося фронта»: радиус из настроек,
-- ступень - самая сильная обычная у семейства, срок - пока фронт не пересечёт
-- карту, зона - случайная на этой карте. Так строка задаёт ровно то, что важно.

CREATE TABLE IF NOT EXISTS `mod_advanced_weather_queue` (
  `id`      INT UNSIGNED     NOT NULL AUTO_INCREMENT,
  `ord`     INT UNSIGNED     NOT NULL DEFAULT 0   COMMENT 'порядок в очереди',
  `map`     INT UNSIGNED     NOT NULL DEFAULT 0   COMMENT '0 ВК, 1 Калимдор, 530 Запределье, 571 Нордскол',
  `zone`    INT UNSIGNED     NOT NULL DEFAULT 0   COMMENT 'куда целиться; 0 - случайная зона карты',
  `family`  TINYINT UNSIGNED NOT NULL DEFAULT 1   COMMENT '1 дождь, 2 снег, 3 песчаная буря, 4 туман',
  `peak`    TINYINT UNSIGNED NOT NULL DEFAULT 0   COMMENT 'ступень в ядре; 0 - самая сильная обычная',
  `radius`  INT UNSIGNED     NOT NULL DEFAULT 0   COMMENT 'ярдов; 0 - из настроек модуля',
  `minutes` INT UNSIGNED     NOT NULL DEFAULT 0   COMMENT 'сколько жить; 0 - пока не пересечёт карту',
  `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `comment` VARCHAR(120)     NOT NULL DEFAULT ''  COMMENT 'зачем эта запись, для панели',
  PRIMARY KEY (`id`),
  KEY `idx_ord` (`ord`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='mod-advanced-weather: очередь заготовленных фронтов';
