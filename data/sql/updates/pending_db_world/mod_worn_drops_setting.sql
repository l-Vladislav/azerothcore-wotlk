-- mod-worn-drops: настройки, заданные из админ-панели
--
-- Конфиг задаёт значения по умолчанию, строка таблицы их перебивает.
-- Строки заводит и удаляет сам модуль по команде ".wd cfg <имя> <значение|reset>".
-- Без таблицы модуль работает, но заданное значение действует только до рестарта.

CREATE TABLE IF NOT EXISTS `mod_worn_drops_setting` (
  `name`  VARCHAR(32) NOT NULL           COMMENT 'ключ настройки',
  `value` FLOAT       NOT NULL DEFAULT 0 COMMENT 'значение',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='mod-worn-drops: настройки, переживающие рестарт';
