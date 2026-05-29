# StatBooster live runtime config

**Source of truth:** `env/dist/etc/modules/statbooster.conf` (live) and `env/dist/etc-ptr/modules/statbooster.conf` (PTR). These are the files the Docker worldserver actually reads.

**Do not trust:** `modules/StatBooster/conf/statbooster.conf.dist` — that's the bundled module template, ships with `Enable = 0`. See [template-vs-runtime.md](template-vs-runtime.md).

## Current live values (verified 2026-05-26)

**PTR audit scope:** Only `Enable` was checked against PTR (= 1). Other keys assumed to match live unless noted, since this fork's convention is **PTR-first**: every change ships to PTR before live. If a key matters for a specific task, re-grep `env/dist/etc-ptr/modules/statbooster.conf` before relying on it.

| Key | Live | PTR | Notes |
|---|---|---|---|
| `StatBooster.Enable` | **1** | **1** | Module is ON |
| `StatBooster.VerboseEnable` | 0 | (check) | Debug spam off |
| `StatBooster.OnLoginEnable` | 1 | — | Login message shown |
| `StatBooster.OnLoginMessage` | `"This server is running the StatBooster module."` | — | English |
| `StatBooster.OnLootItemEnable` | 1 | — | Boost loot drops |
| `StatBooster.OnQuestRewardItemEnable` | 1 | — | Boost quest rewards |
| `StatBooster.OnCraftItemEnable` | 1 | — | Boost crafted items |
| `StatBooster.LootItemChance` | **25** | — | 25% — NOT 100% as old doc claimed |
| `StatBooster.QuestRewardChance` | **25** | — | 25% |
| `StatBooster.CraftItemChance` | **25** | — | 25% |
| `StatBooster.MinQuality` | **1** (Common) | — | NOT 2 |
| `StatBooster.MaxQuality` | **5** (Legendary) | — | NOT 4 |
| `StatBooster.PlaySoundEnable` | 1 | — | |
| `StatBooster.SoundId` | **37** | — | NOT 120 |
| `StatBooster.SoulbindOnEnchantRoll` | 0 | — | All soulbind flags disabled |
| `StatBooster.SoulbindOnEnchantLoot` | 0 | — | |
| `StatBooster.SoulbindOnEnchantQuest` | 0 | — | |
| `StatBooster.SoulbindOnEnchantCraft` | 0 | — | |
| `StatBooster.AnnounceBoostEnable` | 1 | — | Per-player chat announces |
| `StatBooster.OverwriteEnchantEnable` | 1 | — | Uses BONUS_ENCHANTMENT_SLOT, overwrites |
| `StatBooster.Reroll.VisualId` | 62015 | — | Test visual |
| `StatBooster.Reroll.AllowOwnedItemsOnly` | 1 | — | Can only reroll own items |
| `StatBooster.Reroll.AllowBoostedItemsOnly` | 1 | — | (legacy — code now uses per-item-type logic) |

## Scroll-pool mappings (live)

Every scroll item is mapped to a pool group + iLvl band. **Format:**
```
StatBooster.ScrollPool.<itemId>   = <poolGroup>
StatBooster.ScrollMinILvl.<itemId> = <int>
StatBooster.ScrollMaxILvl.<itemId> = <int>
```

| Item | Pool | iLvl band | Profession tier |
|---|---|---|---|
| 100001 Runed Whetstone | 1 (Battle) | 1-25 | BS T1 |
| 100002 Tempered Whetstone | 1 | 26-45 | BS T2 |
| 100003 Honed Whetstone | 1 | 46-65 | BS T3 |
| 100004 Masterwork Whetstone | 1 | 66-92 | BS T4 |
| 100005 Runed Armor Patch | 2 (Warding) | 1-25 | LW T1 |
| 100006 Tempered Armor Patch | 2 | 26-45 | LW T2 |
| 100007 Hardened Armor Patch | 2 | 46-65 | LW T3 |
| 100008 Masterwork Armor Patch | 2 | 66-92 | LW T4 |
| 100009 Minor Arcane Vellum | 3 (Arcana) | 1-25 | Ench T1 |
| 100010 Arcane Vellum | 3 | 26-45 | Ench T2 |
| 100011 Greater Arcane Vellum | 3 | 46-65 | Ench T3 |
| 100012 Superior Arcane Vellum | 3 | 66-92 | Ench T4 |
| 100013 Minor Glyph of Fortune | 4 (Fortune) | 1-25 | Insc T1 |
| 100014 Glyph of Fortune | 4 | 26-45 | Insc T2 |
| 100015 Major Glyph of Fortune | 4 | 46-65 | Insc T3 |
| 100016 Grand Glyph of Fortune | 4 | 66-92 | Insc T4 |

**Note:** iLvl bands here (1-25 / 26-45 / 46-65 / 66-92) differ from the original 2026-03 CHANGELOG which had 1-35 / 30-60 / 55-80 / 75-200. The runtime is current truth.

## To change config

1. Edit `env/dist/etc/modules/statbooster.conf` (and `etc-ptr/...` for PTR).
2. Restart worldserver: `docker compose restart ac-worldserver` (or `ac-worldserver-ptr`).
3. Do **not** edit `modules/StatBooster/conf/statbooster.conf.dist` — that's the template, won't affect runtime.
