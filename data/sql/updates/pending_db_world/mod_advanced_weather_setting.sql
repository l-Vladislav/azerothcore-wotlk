-- mod-advanced-weather: настройки модуля
--
-- Пока в таблице живёт одна строка - переключатель режиссёра (кнопка на карте
-- в админ-панели и в аддоне RemoteControlUI). Конфиг `AdvancedWeather.Enable`
-- задаёт значение по умолчанию, строка отсюда его перебивает - иначе
-- выключенный вечером режиссёр просыпался бы сам после ночного рестарта.
--
-- Стартовой строки здесь НЕТ намеренно: пустая таблица означает «слушай
-- конфиг». Строку заводит сам модуль по команде ".aw enable 0|1", а
-- ".aw enable reset" её удаляет.
--
-- Таблицы может не быть вовсе: модуль это переживает, переключатель тогда
-- действует только до рестарта.

CREATE TABLE IF NOT EXISTS `mod_advanced_weather_setting` (
  `name`  VARCHAR(32) NOT NULL                COMMENT 'ключ настройки',
  `value` INT         NOT NULL DEFAULT 0      COMMENT 'значение; для enabled 0 или 1',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='mod-advanced-weather: настройки, переживающие рестарт';
