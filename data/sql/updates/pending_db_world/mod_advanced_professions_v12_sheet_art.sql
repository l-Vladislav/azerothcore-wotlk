-- mod-advanced-professions: имя чертежа у типа предмета.
--
-- Чертёж - это рисунок на пергаменте в правой половине окна: то, что куётся.
-- До сих пор аддон выбирал файл сам, таблицей «класс + подкласс → item-sword»,
-- и поменять соответствие можно было только правкой Lua. Рисунки делались
-- руками, и какой файл какому оружию отвечает - вопрос содержания, а не кода:
-- художник вправе назвать их иначе или нарисовать новый.
--
-- Поэтому имя переезжает в строку типа и правится в панели. Файл по-прежнему
-- едет с аддоном (это оформление, §7), сервер шлёт только имя без пути и
-- расширения: `item-sword` → `Interface\AddOns\AdvProfUI\textures\item-sword.tga`.
-- Пусто - аддон берёт своё умолчание по классу, как раньше.
--
-- Дизайн: .claude/advanced-professions/DESIGN.md §5.4, §7
SET @add := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
             WHERE `TABLE_SCHEMA` = DATABASE()
               AND `TABLE_NAME` = 'ap_item_type'
               AND `COLUMN_NAME` = 'sheet_art');

SET @sql := IF(@add = 0,
  'ALTER TABLE `ap_item_type` ADD COLUMN `sheet_art` VARCHAR(48) NOT NULL DEFAULT ''''
     COMMENT ''Имя файла чертежа в textures аддона, без пути и расширения''
     AFTER `displayid`',
  'DO 0');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Умолчания - ровно то соответствие, что было зашито в аддоне таблицей
-- ITEM_ART. Так после миграции ничего не меняется на вид, а разъехавшиеся
-- рисунки владелец переставляет в панели, не трогая ни Lua, ни файлы.
UPDATE `ap_item_type` SET `sheet_art` = CASE `code`
    WHEN 'sword'   THEN 'item-sword'
    WHEN 'sword2h' THEN 'item-sword2h'
    WHEN 'dagger'  THEN 'item-dagger'
    WHEN 'axe'     THEN 'item-axe'
    WHEN 'axe2h'   THEN 'item-axe2h'
    WHEN 'mace'    THEN 'item-mace'
    WHEN 'mace2h'  THEN 'item-mace2h'
    WHEN 'polearm' THEN 'item-polearm'
    WHEN 'shield'  THEN 'item-shield'
    ELSE `sheet_art`
  END
  WHERE `sheet_art` = '';
