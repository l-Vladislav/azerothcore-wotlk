# Fortune Pool v2 — Single Generic Enchant + Server-Side Aura System

## Problem

Current design requires one `SpellItemEnchantment.dbc` entry per pool effect in the client MPQ.
Adding/changing pool spells means rebuilding the MPQ and redistributing to all players.
Currently ~96 entries (90010–90105), growing to 160+.

## Solution

One generic client-side enchant per category. All proc logic handled server-side via hidden auras.

---

## Client Side (one-time MPQ patch, never needs updating)

### SpellItemEnchantment.dbc — only 3 entries

| ID | Name (ruRU) | Effect_1 | EffectArg_1 | Notes |
|----|-------------|----------|-------------|-------|
| 90000 | Удача: Оружие | 0 | 0 | Cosmetic label for weapons |
| 90001 | Удача: Доспех | 0 | 0 | Cosmetic label for armor |
| 90002 | Удача: Щит | 0 | 0 | Cosmetic label for shields |

CSV format:
```
"90000","0","0","0","0","0","0","0","0","0","0","0","0","0","","","","","","","","","Удача: Оружие","","","","","","","","16712190","0","0","0","0","0","0","0"
"90001","0","0","0","0","0","0","0","0","0","0","0","0","0","","","","","","","","","Удача: Доспех","","","","","","","","16712190","0","0","0","0","0","0","0"
"90002","0","0","0","0","0","0","0","0","0","0","0","0","0","","","","","","","","","Удача: Щит","","","","","","","","16712190","0","0","0","0","0","0","0"
```

Effect_1=0 means the enchant itself does nothing. It is a visual label only.

---

## Server Side

### 1. SQL: `spellitemenchantment_dbc` — matching server entries

```sql
DELETE FROM `spellitemenchantment_dbc` WHERE `ID` IN (90000, 90001, 90002);
INSERT INTO `spellitemenchantment_dbc`
    (`ID`,`Charges`,`Effect_1`,`Effect_2`,`Effect_3`,
     `EffectPointsMin_1`,`EffectPointsMin_2`,`EffectPointsMin_3`,
     `EffectPointsMax_1`,`EffectPointsMax_2`,`EffectPointsMax_3`,
     `EffectArg_1`,`EffectArg_2`,`EffectArg_3`,
     `Name_Lang_enUS`,`Name_Lang_zhTW`,`Name_Lang_Mask`,
     `ItemVisual`,`Flags`,`Src_ItemID`,`Condition_Id`,
     `RequiredSkillID`,`RequiredSkillRank`,`MinLevel`)
VALUES
(90000,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 'Fortune: Weapon','Удача: Оружие',16712190, 0,0,0,0, 0,0,0),
(90001,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 'Fortune: Armor','Удача: Доспех',16712190, 0,0,0,0, 0,0,0),
(90002,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0, 'Fortune: Shield','Удача: Щит',16712190, 0,0,0,0, 0,0,0);
```

### 2. SQL: New table `statbooster_fortune_data`

Stores the actual proc spell per item instance.

```sql
DROP TABLE IF EXISTS `statbooster_fortune_data`;
CREATE TABLE `statbooster_fortune_data` (
    `item_guid`     INT UNSIGNED NOT NULL COMMENT 'Item instance GUID',
    `spell_id`      INT UNSIGNED NOT NULL COMMENT 'Actual proc spell from Spell.dbc',
    `pool_entry_id` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'statbooster_enchant_template.Id that was rolled',
    `enchant_id`    INT UNSIGNED NOT NULL DEFAULT 90000 COMMENT 'Visual enchant ID (90000/90001/90002)',
    PRIMARY KEY (`item_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Fortune pool: maps item instances to their rolled proc spells';
```

### 3. SQL: `statbooster_enchant_template` — pool entries reference spell IDs

The pool template table stays the same structure. Each row defines a possible roll outcome.
The `Id` column no longer needs to match a SpellItemEnchantment ID — it is just a unique key.
A new column `SpellId` stores the actual proc spell to apply.

```sql
ALTER TABLE `statbooster_enchant_template`
    ADD COLUMN `SpellId` INT UNSIGNED NOT NULL DEFAULT 0
    COMMENT 'Actual proc spell ID from Spell.dbc'
    AFTER `Id`;
```

Example pool entries (no client DBC needed per entry):
```sql
-- WEAPON T1
INSERT INTO `statbooster_enchant_template`
    (`Id`,`SpellId`,`iLvlMin`,`iLvlMax`,`PoolGroup`,`ItemClassFilter`,`Description`,`Note`)
VALUES
(90010, 34939, 1, 35, 4, 2, 'Backlash', 'W-T1'),
(90011, 34917, 1, 35, 4, 2, 'Vampiric Touch', 'W-T1'),
(90012, 34657, 1, 35, 4, 2, 'Deadly Poison', 'W-T1'),
-- ... etc. Adding a new effect = just one INSERT here.

-- ARMOR T3
(90058, 64999, 55, 80, 4, 4, 'Meteoric Inspiration', 'A-T3'),
(90059, 64700, 55, 80, 4, 4, 'Magma Splash', 'A-T3'),

-- SHIELD T4
(90098, 75497, 75, 200, 4, 6, 'Zalazane Shield', 'S-T4'),
(90099, 72590, 75, 200, 4, 6, 'Fortitude', 'S-T4');
```

---

## Server Code Changes (StatBooster module only)

### Flow: Scroll Used → Roll → Store → Apply Visual Enchant

In `StatBoostMgr::BoostItemFromPool()`:

```cpp
// 1. Roll a pool entry (existing logic)
const EnchantPool* pool = GetPool(poolGroup, item, player);
if (!pool)
    return false;

auto entry = pool->Roll(item->GetTemplate()->ItemLevel, ...);
if (!entry)
    return false;

// 2. Determine visual enchant ID by item class
uint32 visualEnchantId;
if (item->GetTemplate()->Class == ITEM_CLASS_WEAPON)
    visualEnchantId = 90000; // "Fortune: Weapon"
else if (item->GetTemplate()->Class == ITEM_CLASS_ARMOR
         && item->GetTemplate()->SubClass == ITEM_SUBCLASS_ARMOR_SHIELD)
    visualEnchantId = 90002; // "Fortune: Shield"
else
    visualEnchantId = 90001; // "Fortune: Armor"

// 3. Apply cosmetic enchant to item (client sees the label)
EnchantItem(player, item, visualEnchantId, slot);

// 4. Store the actual proc spell in DB
CharacterDatabase.Execute(
    "REPLACE INTO statbooster_fortune_data (item_guid, spell_id, pool_entry_id, enchant_id) "
    "VALUES ({}, {}, {}, {})",
    item->GetGUID().GetCounter(), entry->SpellId, entry->Id, visualEnchantId);

// 5. If item is currently equipped, apply the aura now
if (player->IsEquipmentPos(item->GetBagSlot(), item->GetSlot()))
    ApplyFortuneAura(player, item);
```

### Flow: Item Equipped → Lookup → Apply Aura

New hook `OnPlayerEquipItem` (or integrate into existing equip flow):

```cpp
void StatBoostScript::OnPlayerEquipItem(Player* player, Item* item, ...)
{
    // Check if this item has a fortune effect
    uint32 guid = item->GetGUID().GetCounter();

    QueryResult result = CharacterDatabase.Query(
        "SELECT spell_id FROM statbooster_fortune_data WHERE item_guid = {}", guid);

    if (!result)
        return;

    uint32 spellId = (*result)[0].Get<uint32>();
    if (spellId && !player->HasAura(spellId))
        player->CastSpell(player, spellId, true); // triggered = hidden
}
```

### Flow: Item Unequipped → Remove Aura

```cpp
void StatBoostScript::OnPlayerUnequipItem(Player* player, Item* item, ...)
{
    uint32 guid = item->GetGUID().GetCounter();

    QueryResult result = CharacterDatabase.Query(
        "SELECT spell_id FROM statbooster_fortune_data WHERE item_guid = {}", guid);

    if (!result)
        return;

    uint32 spellId = (*result)[0].Get<uint32>();
    if (spellId)
        player->RemoveAurasDueToSpell(spellId);
}
```

### Flow: Player Login → Re-apply All Fortune Auras

```cpp
void StatBoostScript::OnPlayerLogin(Player* player)
{
    // Query all fortune effects on currently equipped items
    QueryResult result = CharacterDatabase.Query(
        "SELECT f.spell_id FROM statbooster_fortune_data f "
        "INNER JOIN item_instance ii ON ii.guid = f.item_guid "
        "WHERE ii.owner_guid = {} AND ii.guid IN ("
        "  SELECT item FROM character_inventory ci "
        "  WHERE ci.guid = {} AND ci.slot < {}"
        ")",
        player->GetGUID().GetCounter(),
        player->GetGUID().GetCounter(),
        EQUIPMENT_SLOT_END);

    if (!result)
        return;

    do {
        uint32 spellId = (*result)[0].Get<uint32>();
        if (spellId && !player->HasAura(spellId))
            player->CastSpell(player, spellId, true);
    } while (result->NextRow());
}
```

### Flow: Item Deleted → Cleanup

```cpp
void StatBoostScript::OnItemRemove(Player* /*player*/, Item* item)
{
    CharacterDatabase.Execute(
        "DELETE FROM statbooster_fortune_data WHERE item_guid = {}",
        item->GetGUID().GetCounter());
}
```

---

## Performance Considerations

- **Cache fortune data in memory**: Load `statbooster_fortune_data` into an `std::unordered_map<uint32 /*guid*/, uint32 /*spellId*/>` on server start and on changes. Avoids DB queries on every equip/unequip.
- **Login query**: Single JOIN query per login, not per item.
- **Aura stacking**: If a player has two fortune items with the same spell, `CastSpell` with triggered=true won't double-stack most auras. May want to track via a set to avoid redundant calls.

---

## Player Experience

1. Player uses Fortune Scroll on their sword
2. Item tooltip shows: **"Удача: Оружие"** (Fortune: Weapon)
3. Player equips the item
4. In combat, a proc fires — buff icon appears with the real spell name and icon
   (e.g., "Ледяной молот" / Frozen Mallet with its original icon from Spell.dbc)
5. The "mystery" of what you rolled adds gameplay interest

---

## Adding/Changing Effects (DBA workflow)

### Add a new fortune effect:
```sql
-- Just one INSERT, no client rebuild:
INSERT INTO `statbooster_enchant_template`
    (`Id`,`SpellId`,`iLvlMin`,`iLvlMax`,`PoolGroup`,`ItemClassFilter`,`Description`,`Note`)
VALUES (90106, 55078, 55, 80, 4, 2, 'New Fire Proc', 'W-T3');
-- Reload: .reload statbooster
```

### Remove a fortune effect:
```sql
DELETE FROM `statbooster_enchant_template` WHERE `Id` = 90106;
-- Existing items with that spell keep working (spell is in Spell.dbc)
```

### Change a fortune effect's spell:
```sql
-- Careful: only affects future rolls. Existing items keep old spell.
UPDATE `statbooster_enchant_template` SET `SpellId` = 55079 WHERE `Id` = 90106;
```

### Reroll an existing item (GM command):
```sql
-- Update the stored spell for an item instance
UPDATE `statbooster_fortune_data` SET `spell_id` = 72998 WHERE `item_guid` = 12345;
-- Player needs to re-equip or relog for new aura
```

---

## Migration from v1

If v1 fortune enchants (90010–90105 in SpellItemEnchantment) were already deployed:

```sql
-- Migrate existing fortune items to v2 system
INSERT INTO `statbooster_fortune_data` (`item_guid`, `spell_id`, `pool_entry_id`, `enchant_id`)
SELECT
    ie.guid,
    sie.EffectArg_1,          -- the proc spell from old enchant
    ie.enchantments & 0xFFFF, -- extract enchant ID (depends on storage format)
    CASE
        WHEN it.class = 2 THEN 90000
        WHEN it.class = 4 AND it.subclass = 6 THEN 90002
        ELSE 90001
    END
FROM item_instance ie
JOIN item_template it ON it.entry = ie.itemEntry
JOIN spellitemenchantment_dbc sie ON sie.ID = (ie.enchantments & 0xFFFF)
WHERE (ie.enchantments & 0xFFFF) BETWEEN 90010 AND 90105;
-- Then update all those items to use generic enchant IDs (90000/90001/90002)
```

---

## Comparison: v1 vs v2

| Aspect | v1 (current) | v2 (this design) |
|--------|-------------|-------------------|
| Client DBC entries | ~96 now, 160+ planned | 3 (fixed forever) |
| Add new pool effect | SQL + rebuild MPQ | SQL only |
| Remove pool effect | SQL + rebuild MPQ | SQL only |
| Item tooltip | Shows specific effect name | Shows "Fortune: Weapon/Armor/Shield" |
| Proc visibility | Tooltip before equip | Buff icon on proc (discovery) |
| Server code changes | None (uses standard enchant) | New equip/unequip/login hooks |
| DB tables | statbooster_enchant_template | + statbooster_fortune_data |
| Server rebuild | No | Yes (one-time for new hooks) |

---

## Files to Modify

### One-time client MPQ:
- `SpellItemEnchantment.dbc` — replace 96 entries with 3

### Server SQL:
- New table: `statbooster_fortune_data`
- Update `spellitemenchantment_dbc`: replace entries with 3 generic ones
- Add `SpellId` column to `statbooster_enchant_template`
- Update pool entries with SpellId values

### Server C++ (StatBooster module):
- `StatBoostMgr.cpp` — modify `BoostItemFromPool()` to use generic enchant + store spell
- `StatBoost.cpp` — add OnPlayerEquipItem, OnPlayerUnequipItem hooks
- `StatBoost.cpp` — extend OnPlayerLogin to re-apply fortune auras
- `StatBoostCfgMgr.cpp` — load SpellId from pool template, cache fortune data
- `StatBoostCfgMgr.h` — add SpellId to EnchantEntry struct, add fortune cache
