# Deployment Manifest — mod-ollama-chat Phase 3

**Package:** `.claude/agent-memory/live-deployer/packages/2026-06-25_1200-mod-ollama-chat-phase3/`
**Prepared:** 2026-06-25
**Module repo branch:** `feat/ollama-chat-llm` (tip: `bfef7f9`) — pushed to fork `l-Vladislav/mod-ollama-chat`
**Main repo branch:** `feat/ollama-chat-llm` (tip: `9ae8ca9bf`) — pushed to `origin` (l-Vladislav fork)
**Target:** `acore_characters` (live) + image rebuild of `ac-worldserver-v2`
**PTR test status:** Tested on `ac-worldserver-ptr` / `acore_characters_ptr`. Both new tables present. Module loaded cleanly. Features verified: gemma4:12b responses, named personas, news feed, long-term memory, bot journal.

---

## Pre-flight check results

| Check | Result |
|---|---|
| SQL files exist in pending_db_characters | PASS — both files present |
| mod_ollama_chat_memory.sql: forbidden DDL (DROP/TRUNCATE) | PASS — none found |
| mod_ollama_chat_bot_journal.sql: forbidden DDL | PASS — none found |
| 2025_05_31_personality_template.sql: forbidden DDL | PASS — REPLACE INTO only |
| 2025_11_01_personality_manual_only.sql: forbidden DDL | PASS — guarded ALTER, no DROP |
| Both migration files applied to PTR (acore_characters_ptr) | PASS — mod_ollama_chat_memory and mod_ollama_chat_bot_journal tables confirmed present |
| mod_ollama_chat_memory already on live | NOT PRESENT (new table, safe) |
| mod_ollama_chat_bot_journal already on live | NOT PRESENT (new table, safe) |
| manual_only column on live personality_templates | ALREADY PRESENT — guarded ALTER is no-op, safe to re-run |
| personality_templates REPLACE INTO | Safe — idempotent by PRIMARY KEY |
| Guild id 24 on live acore_characters | CONFIRMED — guild exists (name showed as ????, possibly UTF8 rendering in terminal but row returned) |
| Character GUID 566 on live | CONFIRMED — name: Lvgrbm |
| Character GUID 568 on live | CONFIRMED — name: Chmone |
| Live worldserver ac-worldserver-v2 currently running | NOT RUNNING — only PTR is up; safe to rebuild without downtime concern |

---

## What this deploy contains

### 1. SQL migrations to live `acore_characters` (4 files, all idempotent)

**File A** — `data/sql/updates/pending_db_characters/mod_ollama_chat_memory.sql`
- Creates `mod_ollama_chat_memory` (bot_guid + player_guid PK, memory_blob TEXT, updated_at auto-timestamp)
- Phase 3 long-term memory: compact per-(bot,player) summary text persisted across sessions
- Risk: LOW — CREATE TABLE IF NOT EXISTS, no data loss possible

**File B** — `data/sql/updates/pending_db_characters/mod_ollama_chat_bot_journal.sql`
- Creates `mod_ollama_chat_bot_journal` (bot_name PK, journal_json LONGTEXT, updated_at)
- Bot daily journal keyed by bot_name, stores day-partitioned Russian text entries
- Risk: LOW — CREATE TABLE IF NOT EXISTS, no data loss possible

**File C** — `modules/mod-ollama-chat/data/sql/characters/base/2025_05_31_personality_template.sql`
- REPLACE INTO mod_ollama_chat_personality_templates for 33 personality rows
- Included because the PTR version changed from INSERT IGNORE to REPLACE (idempotent upsert)
- Live already has the table and the column; the REPLACE will refresh any stale rows to match PTR
- Risk: LOW — only overwrites prompt text for built-in personalities; manual_only=0 for all, preserving custom rows untouched

**File D** — `modules/mod-ollama-chat/data/sql/characters/base/2025_11_01_personality_manual_only.sql`
- Guarded ALTER TABLE to add manual_only TINYINT column
- Pre-flight confirmed: column already exists on live (added in an earlier deploy)
- The guard (IF @col_exists = 0) makes this a no-op
- Included for completeness / audit trail; completely safe

### 2. Code rebuild (live worldserver image)

The module code at `modules/mod-ollama-chat/` (feat/ollama-chat-llm branch, commit `bfef7f9`) has been updated with all Phase 3 C++ changes. The modules directory is bind-mounted read-only into the container (`./modules:/azerothcore/modules:ro`), meaning the **source files are live on disk already** — but the worldserver binary was compiled at image build time. A rebuild is required to compile the new C++ against the new sources.

**Current live image:** `acore/ac-wotlk-worldserver:master` (base), overridden by `docker-compose.override.yml` which adds the `build:` section for `ac-worldserver` with `target: worldserver` and `dockerfile: apps/docker/Dockerfile`.

**Build command (same Dockerfile, same target as PTR):**

```
docker compose build ac-worldserver
```

Run from the project root (`D:\Projects\Wow\v2\azerothcore-wotlk-playerbots\azerothcore-wotlk`). This rebuilds the `ac-worldserver` service image (which overrides/re-tags the `acore/ac-wotlk-worldserver:master` image with a freshly compiled binary including the updated module).

After rebuild, recreate the container:

```
docker compose up -d --no-build ac-worldserver
```

Note: `ac-worldserver-v2` is currently stopped (only PTR and authserver are running). The rebuild can happen while the server is down. When you run `up -d`, it will start the container with the new image.

Note: `feat/ollama-chat-llm` branch must be checked out (or merged into `custom`) in the main repo before building, so the module source at `modules/mod-ollama-chat/` is at commit `bfef7f9`. Confirm with:
```
cd modules/mod-ollama-chat && git log --oneline -1
```
Expected output should show commit `bfef7f9`.

### 3. Config update: `env/dist/etc/modules/mod_ollama_chat.conf`

The live config must be manually edited. The `apply.ps1` script does NOT write this file (live config writes are out of scope per policy — human edits manually). The exact diff is documented in the `config-diff.md` file in this package.

### 4. Ollama / docker-compose.override.yml

No action required. `gemma4:12b` is already loaded in the shared `ollama` container. The `OLLAMA_FLASH_ATTENTION=1` and `OLLAMA_NUM_PARALLEL=2` env vars are already set via `docker-compose.override.yml` (gitignored, shared). No Ollama changes needed.

### 5. characters.json

Path configured as `/azerothcore/modules/mod-ollama-chat/data/characters.json`.
The file is at `modules/mod-ollama-chat/data/characters.json` on the host, which is bind-mounted as `./modules:/azerothcore/modules:ro` in both live and PTR containers.
The absolute container path `/azerothcore/modules/mod-ollama-chat/data/characters.json` is **identical for both live and PTR**. No path change needed in live config.

---

## Deployment order

1. Confirm `modules/mod-ollama-chat` is at commit `bfef7f9` (feat/ollama-chat-llm tip)
2. Run `apply.ps1` — takes DB snapshot, applies 4 SQL files to `acore_characters`
3. Edit `env/dist/etc/modules/mod_ollama_chat.conf` per `config-diff.md`
4. Run `docker compose build ac-worldserver` (takes 5-15 min)
5. Run `docker compose up -d ac-worldserver` (starts ac-worldserver-v2 with new binary)
6. Smoke test: log in, whisper a bot, verify response uses gemma4:12b personality; check bot journal after a few minutes

---

## Risk assessment

| Risk | Severity | Notes |
|---|---|---|
| DB migration fails | LOW | All CREATE TABLE IF NOT EXISTS; snapshot allows instant rollback |
| Memory/journal tables empty at first startup | NONE | Expected; populated by module as players interact |
| Config key missing (module uses default) | LOW | Module has defaults for all new keys; worst case a feature is off |
| Image rebuild fails | MEDIUM | If Docker build fails, server stays down; PTR was built successfully with same Dockerfile |
| guild id 24 name rendered as ???? | INFO | Terminal rendering issue; row exists, guildid=24 confirmed |
| Characters 566/568 are named bots (Lvgrbm, Chmone) | CONFIRMED | ExtendedMemoryBots = 568,566 references their GUIDs, which exist on live |

---

## Rollback

If DB apply fails: run `rollback.ps1` — restores `acore_characters` from pre-deploy snapshot.
If code/config issue: revert config manually; rebuild from previous git state; restart container.
The two new tables (`mod_ollama_chat_memory`, `mod_ollama_chat_bot_journal`) are empty at deploy time, so data loss risk from rollback is zero.
