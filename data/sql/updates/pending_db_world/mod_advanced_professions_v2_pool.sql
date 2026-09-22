-- mod-advanced-professions: пул id и числа крафта.
--
-- Пул - это ПУСТЫЕ заготовки item_template в отведённом блоке. Они обязаны
-- существовать к моменту старта мира: хранилище шаблонов предметов у ядра -
-- вектор по entry, и расширять его на живом сервере нельзя, а править уже
-- загруженную строку - можно. Модуль занимает свободный id при первом крафте
-- комбинации и заполняет его шаблон в памяти (см. AdvancedProfessionsMgr.cpp).
--
-- Заготовки помечены ITEM_FLAG_DEPRECATED (0x10) - «нельзя надеть и нельзя
-- использовать». Если такая строка каким-то образом окажется у игрока, она
-- будет мусором в сумке, а не работающим предметом. При выдаче модуль флаг
-- снимает.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §4

-- Ключ комбинации хранится читаемым ("b2:q5:s3:m774,818"), а не хешем: по нему
-- сразу видно, что за предмет. Пяти материалам в 40 символов уже тесно.
ALTER TABLE `ap_generated_item` MODIFY `combo_hash` VARCHAR(64) NOT NULL;

-- Числа, которых не было в v1.
INSERT IGNORE INTO `ap_config` (`name`, `value`, `comment`) VALUES
('skill_per_craft',  '2',   'Прибавка навыка за выкованную основу'),
('skill_per_insert', '1',   'Прибавка навыка за вставку материала'),
('tier_ceiling',     '100', 'Потолок обучения от материала: тир x это число');

-- MVP-пул: 5 000 заготовок. Блок в ap_config зарезервирован до 179999, но
-- засеивается ровно столько, сколько нужно сейчас: пустые строки в
-- item_template стоят памяти на каждом старте. Расширять - такой же вставкой
-- с другими границами.
UPDATE `ap_config` SET `value` = '134999' WHERE `name` = 'pool_hi';

SET SESSION cte_max_recursion_depth = 100000;

INSERT IGNORE INTO `item_template`
  (`entry`, `class`, `subclass`, `name`, `displayid`, `Quality`,
   `Flags`, `InventoryType`, `Stackable`, `MaxCount`, `Material`, `Sheath`)
WITH RECURSIVE `seq` (`n`) AS (
  SELECT 130000
  UNION ALL
  SELECT `n` + 1 FROM `seq` WHERE `n` < 134999
)
SELECT `n`, 2, 7, CONCAT('[заготовка верстака ', `n`, ']'), 3855, 0,
       16, 21, 1, 0, 1, 1
FROM `seq`;
