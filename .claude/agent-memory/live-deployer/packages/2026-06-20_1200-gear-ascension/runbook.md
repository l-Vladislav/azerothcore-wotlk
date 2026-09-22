# Gear Ascension — Live Promotion Runbook
**Package:** `2026-06-20_1200-gear-ascension`
**Date:** 2026-06-20

This is the ordered checklist for the full promotion. Steps are grouped by what
can be parallelized vs what must be sequential. The DB apply and image build are
the only two hard sequential constraints (image build before restart).

---

## Pre-conditions (confirm before starting)

- [ ] PTR smoke test signed off by owner (done 2026-06-19)
- [ ] No live players actively playing (or at minimum no one currently using the kit mechanic — it's new so this is moot for first deploy)
- [ ] You have the package directory open: `.claude\agent-memory\live-deployer\packages\2026-06-20_1200-gear-ascension\`
- [ ] `ac-database-v2` container is running

---

## Step 1 — DB Apply (human runs apply.ps1)

This is safe to run with the live worldserver up. The new rows are inert until the
worldserver restarts with the new image.

```powershell
pwsh "D:\Projects\Wow\v2\azerothcore-wotlk-playerbots\azerothcore-wotlk\.claude\agent-memory\live-deployer\packages\2026-06-20_1200-gear-ascension\apply.ps1"
```

The script will:
1. Run pre-flight collision checks
2. Take a full `acore_world` snapshot (several minutes — do not skip)
3. CREATE `item_upgrade_chain` table
4. Apply 6 SQL files in order
5. Print verification counts
6. Optionally run the image build (see Step 2)

**Expected wall time:** 10-15 minutes total (most of it is the snapshot dump and the
gear_ascension_proto.sql which is 181k lines).

---

## Step 2 — Build live worldserver image (C++ module required)

The `mod-gear-ascension` C++ module must be compiled into the image. This can be
done before or after the DB apply but must happen before the restart.

**Before building:** Stop `ac-worldserver-ptr` to free WSL2 RAM:
```
docker stop ac-worldserver-ptr
```

**Build command** (from repo root, or confirm inside apply.ps1 at Step 6 prompt):
```
docker compose build ac-worldserver
```

Branch: `feat/wow-ak-1-gear-ascension`

This step is prompted inside apply.ps1. If you answered "skip" there, run it manually.

---

## Step 3 — AHBot configuration (manual, human-only — agent cannot touch env/dist/etc/)

Edit `env\dist\etc\modules\mod_ahbot.conf` before restarting:

```
AuctionHouseBot.ListedItemIDRestrict.Enabled = 1
AuctionHouseBot.MaxItemID = 199999
```

Without this, AHBot may attempt to list tier-copy items (300001-345833) in the
auction house, which is not intended. The restriction keeps AHBot to the original
item pool (entries <= 199999).

---

## Step 4 — Client MPQ distribution (human, separate process)

Players need updated DBC files in their client patch MPQ before the upgrade
mechanic works on their screen. The server already has the patched `Item.dbc`
in the shared volume `ac-client-data-v2` (54,739 records validated on PTR).

Client patch contents required:
- `DBFilesClient\Item.dbc` — source: `.claude\dbc\patched\Item.dbc` (54,739 recs)
- `DBFilesClient\ItemExtendedCost.dbc` — must include IEC 100008 (30x token)
- `DBFilesClient\Spell.dbc` — must include spell 105000

This step is the owner's manual MPQ build + distribution process.

---

## Step 5 — Live worldserver restart (DEFERRED per owner)

Only run this after Steps 2, 3, and 4 are complete (image built, conf edited, MPQ distributed).

```
docker compose up -d ac-worldserver   (from repo root)
```

**Note:** Once the server starts with the new image and the new DB rows, Gear Ascension
is live. There is no feature flag to toggle it.

---

## Step 6 — Smoke tests (after restart)

Run these SQL queries on live:
```sql
SELECT COUNT(*) FROM acore_world.item_template WHERE entry BETWEEN 300001 AND 345833;
-- expected 8480
SELECT COUNT(*) FROM acore_world.item_upgrade_chain;
-- expected 8480
SELECT COUNT(*) FROM acore_world.npc_vendor WHERE entry IN (190101,190102,190103) AND item BETWEEN 200000 AND 200020;
-- expected 21
```

In-game:
1. Log in as a low-rank player (rank 1-2). Talk to the Nemesis innkeeper.
   Rank-2 submenu should offer 7 Tier I kits.
2. Acquire a Crude Blacksmith's Kit (or use `.additem 200000`).
3. Use the kit targeting a white plate item. Verify 2-second cast bar fires.
4. Verify the resulting item is green quality with +10% stats vs the base.
5. Check vendor 190103 (rank-4) shows 7 Tier III kits priced at 30 tokens (IEC 100008).

---

## Rollback procedure (if smoke tests fail)

```powershell
pwsh "D:\Projects\Wow\v2\azerothcore-wotlk-playerbots\azerothcore-wotlk\.claude\agent-memory\live-deployer\packages\2026-06-20_1200-gear-ascension\rollback.ps1"
```

Type `rollback` at the confirmation prompt. The script will:
1. Stop `ac-worldserver-v2`
2. Drop and restore `acore_world` from the pre-deploy snapshot
3. Optionally restart the container (but warn that the new image has mod-gear-ascension — you need the old image)

After rollback, append a `## Rollback notes` section to `manifest.md` with the reason.

---

## Post-deploy logging

After confirming successful apply + smoke tests, tell the agent:
> "Gear ascension apply confirmed"

The agent will append to `deployments.log`.
