-- mod-world-items: основа гуубер-копий под модель по номеру (#152).
-- Копии заводятся в блоке 900000-909998 и получают свою модель (displayId).

DELETE FROM `gameobject_template` WHERE `entry` = 909999;
INSERT INTO `gameobject_template` (`entry`, `type`, `displayId`, `name`, `IconName`, `castBarCaption`, `unk1`, `size`, `ScriptName`, `VerifiedBuild`) VALUES
(909999, 10, 0, 'Модель', '', '', '', 1, '', 0);
