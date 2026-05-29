-- Revert previous attempt — restore ##SB## prefix in Description_Lang_zhTW
-- for spells 100028-100031 (Жертвенный огонь, 4 tiers).
--
-- Background: previous SQL `statbooster_sacrificial_fire_strip_sb_prefix.sql`
-- removed ##SB## to "fix" the addon's matching logic. Wrong root cause:
-- WoW client does NOT render enchant Name from SpellItemEnchantment.dbc for
-- type=3 (EQUIP_SPELL) enchants — it shows ONLY the triggered spell's
-- Description. So ##SB## in enchant Name is invisible to client; the ONLY
-- effective marker for type=3 enchants is in the spell Description.
--
-- Real fix is in the addon (DetectEnchantPool needs double-prefix-strip).
-- This SQL restores the data to its pre-fix state.

UPDATE `spell_dbc`
SET `Description_Lang_zhTW` = '##SB##Удача: Жертвенный огонь — При ударе наносит 5 ед. урона от огня атакующему.'
WHERE `ID` = 100028;

UPDATE `spell_dbc`
SET `Description_Lang_zhTW` = '##SB##Удача: Жертвенный огонь — При ударе наносит 12 ед. урона от огня атакующему.'
WHERE `ID` = 100029;

UPDATE `spell_dbc`
SET `Description_Lang_zhTW` = '##SB##Удача: Жертвенный огонь — При ударе наносит 20 ед. урона от огня атакующему.'
WHERE `ID` = 100030;

UPDATE `spell_dbc`
SET `Description_Lang_zhTW` = '##SB##Удача: Жертвенный огонь — При ударе наносит 30 ед. урона от огня атакующему.'
WHERE `ID` = 100031;
