-- StatBooster — strip ##SB## prefix from Жертвенный огонь spell descriptions
-- Spells 100028-100031 (Fortune pool, custom proc spell with 4 damage tiers)
--
-- Root cause: client prepends "Использование:" (Use:) to the description line.
-- Resulting tooltip line: "Использование: ##SB##Удача: Жертвенный огонь — ..."
-- Addon's DetectEnchantPool sees ##SB##, strips only ONE prefix → displayName
-- still has "Удача:" prefix → match against EnchantNames["Жертвенный огонь"]
-- fails because the enchant name is no longer at byte 1 of displayName.
--
-- Fix: remove ##SB## from Description_Lang_zhTW. Other custom proc spells
-- (Шипы, Морозный доспех, etc.) already follow this convention — only the
-- enchant Name in SpellItemEnchantment.dbc keeps the ##SB## tag.
-- Long description text is preserved; only the marker is removed.
--
-- Source CSV: .claude/dbc/Spell_custom.csv rows 100028-100031

UPDATE `spell_dbc`
SET `Description_Lang_zhTW` = 'Удача: Жертвенный огонь — При ударе наносит 5 ед. урона от огня атакующему.'
WHERE `ID` = 100028;

UPDATE `spell_dbc`
SET `Description_Lang_zhTW` = 'Удача: Жертвенный огонь — При ударе наносит 12 ед. урона от огня атакующему.'
WHERE `ID` = 100029;

UPDATE `spell_dbc`
SET `Description_Lang_zhTW` = 'Удача: Жертвенный огонь — При ударе наносит 20 ед. урона от огня атакующему.'
WHERE `ID` = 100030;

UPDATE `spell_dbc`
SET `Description_Lang_zhTW` = 'Удача: Жертвенный огонь — При ударе наносит 30 ед. урона от огня атакующему.'
WHERE `ID` = 100031;
