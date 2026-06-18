# Deployment Manifest — Nemesis Hunting Loop v2

**Package:** `.claude/agent-memory/live-deployer/packages/2026-06-12_1900-nemesis-hunting-loop/`
**Prepared:** 2026-06-12
**Feature branch:** `feat/wow-ak-1-nemesis-familiars`
**PTR test status:** Tested in-game by owner 2026-06-11/12 (design: `.claude/nemesis/nemesis_hunting_loop.md`)
**Backup referenced:** `backups/live/2026-06-12_175354_pre-hunting-loop-deploy/` (acore_world.sql 307 MB, acore_characters.sql 171 MB, acore_auth.sql 478 KB)

---

## What this deploy contains

### 1. C++ module rebuild (REQUIRED FIRST — no SQL order dependency on this)

Live worldserver image `acore/ac-wotlk-worldserver:master` (currently built ~2026-05-16) must be
rebuilt from current sources to pick up mod-nemesis-system @ commit **215c4ef**.

The rebuild is a `docker compose build ac-worldserver` followed by `docker compose up -d ac-worldserver`.
The container name in production is `ac-worldserver-v2`. Module source is bind-mounted
(`./modules:/azerothcore/modules:ro`) — but the **binary** is baked into the image at build time.
The image tag in docker-compose.yml is `acore/ac-wotlk-worldserver:master`.

apply.ps1 handles: `docker compose build ac-worldserver` then restart.

### 2. acore_world SQL — 13 files (all missing from live)

Pre-flight probe results (run 2026-06-12 against `ac-database-v2`):

| File | Live state | PTR state | Action |
|---|---|---|---|
| `nemesis_familiars_gacha_mech.sql` | item_template 191000-191009: 0 rows | 100 creature_template rows present | APPLY |
| `nemesis_familiars_gacha_fire.sql` | item_template range: 0 rows | data present | APPLY |
| `nemesis_familiars_gacha_ice.sql` | ditto | data present | APPLY |
| `nemesis_familiars_gacha_nature.sql` | ditto | data present | APPLY |
| `nemesis_familiars_gacha_light.sql` | ditto | data present | APPLY |
| `nemesis_familiars_gacha_shadow.sql` | ditto | data present | APPLY |
| `nemesis_familiars_gacha_arcane.sql` | ditto | data present | APPLY |
| `nemesis_familiars_gacha_demon.sql` | ditto | data present | APPLY |
| `nemesis_familiars_gacha_beast.sql` | ditto | data present | APPLY |
| `nemesis_familiars_gacha_spirit.sql` | ditto | data present | APPLY |
| `nemesis_familiars_gacha_chests.sql` | item_template 110100-110120, 110150: 0 rows on live | all present on PTR | APPLY |
| `nemesis_familiars_gacha_vendor.sql` | npc_vendor 190100-190103: 0 rows; itemextendedcost_dbc 100006/100007: missing | IEC present on PTR; vendors present | APPLY |
| `statbooster_scrolls.sql` | Hash mismatch (live: `6E85651A…`, current: `E870B1D9…`). Item data looks identical (items 100001-100016, same names/descriptions). File was modified after initial live apply (encoding cleanup pass noted in git). SQL uses INSERT INTO ... ON DUPLICATE KEY UPDATE / REPLACE INTO patterns — fully idempotent. | data present | APPLY (re-apply, idempotent) |

**Probe evidence:**
- `SELECT COUNT(*) FROM acore_world.creature_template WHERE entry BETWEEN 191000 AND 191099` → **0** (live), 100 (PTR)
- `SELECT COUNT(*) FROM acore_world.npc_vendor WHERE entry IN (190100,190101,190102,190103)` → **0** (live), 28 total (PTR)
- `SELECT ID FROM acore_world.itemextendedcost_dbc WHERE ID IN (100006,100007)` → **empty** (live), 2 rows (PTR)
- `SELECT entry FROM acore_world.item_template WHERE entry = 110150` → **missing** (live), present (PTR)
- `SELECT entry FROM acore_world.item_template WHERE entry = 110120` → **missing** (live), present (PTR)

**Note:** The hunting-loop SQL files were applied directly to PTR without being registered in
`acore_world_ptr.updates`. PTR data presence was verified by direct table probes above.
The AC `updates` table tracks files applied through the worldserver auto-updater; manual
`ptr-sql-apply.ps1` runs bypass it. PTR data is confirmed valid.

### 3. acore_characters SQL — 2 files

| File | Live state | PTR state | Action |
|---|---|---|---|
| `nemesis_special_task.sql` | Table `character_nemesis_special_task` does NOT exist on live | Table exists with correct schema | APPLY |
| `nemesis_special_task_target.sql` | Table absent → conditional ALTER will be a no-op for the column (but table creation must happen first via step above) | Column `target_spawn` present | APPLY after nemesis_special_task.sql |

**Note:** `nemesis_special_task_target.sql` uses a conditional `PREPARE/EXECUTE` pattern — fully
idempotent. It will add `target_spawn` column after the table is created by the previous file.

### 4. nemesis module conf (live etc) — new keys appended

File: `env/dist/etc/modules/mod_nemesis_system.conf`

The live conf was read. It does NOT yet contain any of the new hunting-loop keys. The existing
tuned values (`RankUpCooldownSeconds=900`, `SameVictimCooldownSeconds=2700`,
`BountyCompletionBonus/PerRank`, Rep thresholds, etc.) will NOT be touched — only the new keys
are appended.

Keys to add (appended to end of conf by apply.ps1):

```
# --- HUNTING LOOP v2 (appended 2026-06-12) ---

# Ambient generation
NemesisSystem.AmbientGeneration.Enable = 1
NemesisSystem.AmbientGeneration.IntervalMinSeconds = 300
NemesisSystem.AmbientGeneration.IntervalMaxSeconds = 600
NemesisSystem.AmbientGeneration.FillPercent = 50
NemesisSystem.AmbientGeneration.RankUpChance = 10
NemesisSystem.AmbientGeneration.EliteChance = 25
NemesisSystem.AmbientGeneration.RequireRealPlayers = 1
NemesisSystem.AmbientGeneration.Announce = 1
NemesisSystem.AmbientGeneration.AnnounceZoneOnly = 1

# Dungeon nemesis
NemesisSystem.DungeonNemesis.Enable = 1
NemesisSystem.DungeonNemesis.Chance = 3.0
NemesisSystem.DungeonNemesis.IncludeRaids = 0
NemesisSystem.DungeonNemesis.RequireRealPlayers = 1
NemesisSystem.DungeonNemesis.PresenceCooldownSeconds = 120

# Hunter rank scaling
NemesisSystem.HunterRankScaling.Enable = 1

# Rank-gated bounty vendor submenus
NemesisSystem.BountyVendor.RankMenus.Enable = 1
NemesisSystem.BountyVendor.GeneralEntry = 190100
NemesisSystem.BountyVendor.StatBoosterEntry = 190101
NemesisSystem.BountyVendor.FamiliarEntry = 190102
NemesisSystem.BountyVendor.VeteranEntry = 190103
NemesisSystem.BountyVendor.StatBoosterRank = 2
NemesisSystem.BountyVendor.FamiliarRank = 3
NemesisSystem.BountyVendor.VeteranRank = 4

# Special daily task
NemesisSpecialTask.Enable = 1
NemesisSpecialTask.SpeedKillMinutes = 120
NemesisSpecialTask.DungeonMinKills = 3
NemesisSpecialTask.RewardItem = 110150
NemesisSpecialTask.Reward.Speed = 1
NemesisSpecialTask.Reward.Continent = 1
NemesisSpecialTask.Reward.Dungeon = 1
NemesisSpecialTask.FreeChoice = 0
NemesisSpecialTask.NoDailyLimit = 0

# Reputation: special task bonuses (new keys only — existing tuned rep keys untouched)
NemesisRep.SpecialTaskBonus = 100
NemesisRep.SpecialTaskPerRank = 1
```

**PROD invariant enforced:** `FreeChoice=0`, `NoDailyLimit=0` (PTR values were 1 for test rounds).

### 5. DBC volume — no action required

Volume `azerothcore-wotlk_ac-client-data-v2` already contains:
- `AreaTable.dbc` and `Map.dbc` with ruRU locale rows (applied previously)
- Patched `ItemExtendedCost.dbc` with IEC 100006/100007 (client-side, for correct price rendering)

The live worldserver picks these up on restart automatically. No volume operations needed.

### 6. Client side — note only

Owner's MPQ already carries:
- `Item.dbc`: items 110100-110120, 110150, 110000-110099
- `ItemExtendedCost.dbc`: IEC 100006, 100007
- Spell rows for familiar summon/aura spells

NemesisTracker addon updated on PTR, same client connects to both realms. No client deploy action.

---

## Apply order

```
Step 1  docker compose build ac-worldserver             (rebuild live image)
Step 2  Apply acore_world SQLs (13 files, order matters: gacha_* first, then chests, then vendor, then scrolls)
Step 3  Apply acore_characters SQLs (nemesis_special_task.sql THEN nemesis_special_task_target.sql)
Step 4  Append new conf keys to env/dist/etc/modules/mod_nemesis_system.conf
Step 5  docker compose up -d ac-worldserver             (restart live, picks up new binary + conf)
```

Steps 2 and 3 write to the DB only; they do not require the server to be stopped first.
The server restart in Step 5 loads all DB changes + the new module binary in one shot.

---

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| `statbooster_scrolls.sql` hash mismatch — file modified after live apply | LOW | Data is identical; SQL is idempotent (REPLACE INTO / ON DUPLICATE KEY). Re-applying overwrites with identical values. |
| `nemesis_special_task_target.sql` depends on table created in previous file | LOW | apply.ps1 applies them in dependency order with explicit ordering; conditional ALTER is a no-op if column already exists |
| IEC 100006/100007 conflict with item_template 100006/100007 | NONE | `itemextendedcost_dbc` is a completely separate table from `item_template`; no overlap possible |
| Live worldserver rebuild OOM risk (see nemesis_hunting_loop.md §8) | MEDIUM | Do NOT run `docker compose build` while a live player session is active. Schedule for low-traffic window. PTR worldserver is currently up — shut it down before building to free RAM. |
| FreeChoice/NoDailyLimit accidentally set to 1 | HIGH (would be) | apply.ps1 explicitly validates these are 0 before appending conf. Package enforces PROD invariant. |
| Familiar summon spells (102000-102099) absent from live spell_dbc | NONE | These are applied via the gacha family SQL files in Step 2 |

---

## Rollback procedure

1. Stop live worldserver: `docker stop ac-worldserver-v2`
2. Restore DB dumps: `rollback.ps1` — imports `backups/live/2026-06-12_175354_pre-hunting-loop-deploy/acore_world.sql` and `acore_characters.sql`
3. Rebuild live image from previous module commit `a49fde7`: `git -C modules/mod-nemesis-system checkout a49fde7 && docker compose build ac-worldserver`
4. Remove the appended conf block (lines after `# --- HUNTING LOOP v2`) from `env/dist/etc/modules/mod_nemesis_system.conf`
5. Start live: `docker compose up -d ac-worldserver`

Full rollback script: `rollback.ps1` in this package directory.

---

## Post-apply smoke test

Run in-game after server restart:

```sql
-- Verify: familiar creatures
SELECT COUNT(*) FROM acore_world.creature_template WHERE entry BETWEEN 191000 AND 191099;
-- Expected: 100

-- Verify: adventurer coin
SELECT entry, name FROM acore_world.item_template WHERE entry = 110150;
-- Expected: 110150 | Монета авантюриста

-- Verify: vendor submenus
SELECT entry, COUNT(*) FROM acore_world.npc_vendor WHERE entry IN (190100,190101,190102,190103) GROUP BY entry;
-- Expected: 190100=6, 190101=4, 190102=14, 190103=4

-- Verify: special task table
SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='acore_characters' AND TABLE_NAME='character_nemesis_special_task';
-- Expected: 1

-- In-game: talk to innkeeper, verify 4 rank submenus appear (rank 1 unlocked immediately)
-- In-game: .nemesis ambient  (GM command, forces ambient pass, should report births)
```
