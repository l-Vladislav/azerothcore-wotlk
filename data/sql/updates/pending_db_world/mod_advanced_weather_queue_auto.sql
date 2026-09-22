-- mod-advanced-weather: очередь пополняется сама
--
-- Очередь, которую наполняет только человек, живёт ровно до конца написанного:
-- дальше мир снова сочиняет погоду на ходу, и знать наперёд нечего. Поэтому
-- модуль держит на каждой карте запас готовых заготовок
-- (AdvancedWeather.Cyclones.QueueFill, по умолчанию 10) и дописывает новую,
-- как только предыдущая ушла в небо.
--
-- Отсюда и колонка: заготовку, собранную жребием, расходуют насовсем - она
-- затем и заведена, чтобы уступить место следующей. Написанную рукой не
-- удаляет никто: её восстановить неоткуда, и после выпуска она либо уходит в
-- хвост очереди, либо ждёт выключенной - смотря что сказано в
-- AdvancedWeather.Cyclones.QueueEnd.

SET @add := (
  SELECT COUNT(*) = 0 FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'mod_advanced_weather_queue'
    AND column_name = 'auto_made');

SET @sql := IF(@add,
  'ALTER TABLE `mod_advanced_weather_queue`
     ADD COLUMN `auto_made` TINYINT UNSIGNED NOT NULL DEFAULT 0
     COMMENT ''1 - заготовка собрана жребием и расходуется насовсем''
     AFTER `enabled`',
  'DO 0');

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
