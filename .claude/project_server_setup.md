---
name: Server Setup & Configuration
description: Complete WoW server setup - Docker, Ollama, modules, bot configs, and all customizations made
type: project
---

## Docker Setup

- Docker Desktop on Windows 11 with WSL2
- GPU: NVIDIA RTX 4070 Super (12GB VRAM), nvidia runtime available in Docker
- All containers on network `ac-network-v2`

### Containers (container_name → service name)
The `-v2` suffix is in `container_name:` via the override file. **Service names** (what `docker compose` commands use) do NOT have the `-v2` suffix.

| Container name    | Service name          | Purpose                                |
|-------------------|-----------------------|----------------------------------------|
| ac-worldserver-v2 | `ac-worldserver`      | main game server (port 8085)           |
| ac-worldserver-ptr| `ac-worldserver-ptr`  | PTR, uses `--profile ptr`              |
| ac-authserver-v2  | `ac-authserver`       | auth server (port 3724)                |
| ac-database-v2    | `ac-database`         | MySQL 8.4, cnf at `conf/mysql-custom.cnf` |
| ollama            | `ollama`              | LLM server with GPU passthrough (11434)|
| ac-db-import-v2   | `ac-db-import`        | recurring SQL migration issues         |
| ac-client-data-init-v2 | `ac-client-data-init` | one-shot client data init         |

### Docker Compose Files
- `docker-compose.yml` — base
- `docker-compose.override.yml` — v2 overrides (different container names, volumes, network name `ac-network-v2`, ollama service with GPU)

### Rebuild Commands (use service name, NOT container name)
```bash
# Rebuild worldserver from scratch (wipe cache), then restart
docker compose build --no-cache ac-worldserver
docker compose up -d ac-worldserver --no-deps

# Incremental rebuild (cached, faster) after C++ changes
docker compose build ac-worldserver && docker compose up -d ac-worldserver --no-deps
```
`--no-deps` skips restarting `ac-db-import` and other dependent services (which have known migration issues).

### Volumes
- `ac-database-v2` — MySQL data
- `ac-client-data-v2` — map/client data
- `ollama-data` — Ollama models

### Known Issues
- `ac-db-import` fails on duplicate columns/indexes from old DB migration. Fixed SQL files: `2025_07_24_00.sql` (auth Flags), `2025_09_03_00.sql` (petition_id), `2026_02_24_00.sql` (quest_tracker index), `2025_11_01_personality_manual_only.sql` (manual_only column), `2025_05_31_personality_template.sql` (REPLACE INTO)
- Worldserver can be started with `--no-deps` to skip db-import
- `AC_UPDATES_ENABLE_DATABASES=0` on worldserver, so it doesn't run migrations itself

## Ollama Setup

- Model: `qwen2.5:7b` (4.7GB) — best balance of Russian quality, speed, and VRAM usage
- Previously tried: llama3.2:3b, llama3.1:8b, qwen2.5:14b (14b caused server crashes from long response times)
- GPU passthrough enabled via `deploy.resources.reservations.devices` in docker-compose
- Accessible from worldserver as `http://ollama:11434/api/generate`

## Installed Modules

### mod-ollama-chat
- Russian-localized chat for playerbots via Ollama LLM
- All prompts translated to native Russian (system, random chatter, events, guild, environment comments, event types)
- Config: `env/dist/etc/modules/mod_ollama_chat.conf`
- Key settings: Model=qwen2.5:7b, MaxConcurrentQueries=3, MinRandomInterval=120, MaxRandomInterval=600, RandomChatterRealPlayerDistance=60, RandomChatterMaxBotsPerPlayer=1, EnableWhisperReplies=1, EnableRPPersonalities (33 personality types in DB)
- Sentiment tracking disabled

### mod-ollama-bot-buddy
- AI-controlled party companion bot via Ollama LLM
- Bot name: Chmone (configurable via `OllamaBotControl.BotNames`)
- Currently DISABLED (`OllamaBotControl.Enable = 0`) — was crashing server (SIGSEGV exit code 139)
- Thread safety fix applied: pending results queue pattern (bg thread only queues, main thread processes)
- Prompts moved to external text files (editable without rebuild):
  - `env/dist/etc/modules/bot_buddy_system_prompt.txt` — behavior rules
  - `env/dist/etc/modules/bot_buddy_command_format.txt` — JSON format, commands, communication
  - `env/dist/etc/modules/bot_buddy_player_patterns.txt` — bilingual command patterns (EN/RU)
- Config: `env/dist/etc/modules/mod_ollama_bot_buddy.conf`
- Code changes made: handler.h/cpp (OnPlayerBeforeSendChatMessage), loop.cpp (thread safety, TravelNodeMap fix, party member target info, file-based prompts), config.h/cpp (BotNames, NumPredict, prompt file loading), Dockerfile (libcurl4-openssl-dev, nlohmann-json3-dev, libcurl4 runtime)

### mod-playerbots
- Min/Max bots: 1400/2800 (reduced 30% from 2000/4000)
- ProbTeleToBankers: 0.10 (reduced from 0.25)
- TeleportInterval: 1800-7200s (more frequent moves)
- Chat features disabled for ollama-chat compatibility: RandomBotTalk=0, RandomBotSuggestDungeons=0, GuildFeedback=0, EnableBroadcasts=0, EnableGreet=0, RandomBotSayWithoutMaster=0
- IndividualProgression.DisableRDF = 1

### Other Modules
- mod-autobalance, mod-ah-bot-plus, mod-aoe-loot, mod-individual-progression, mod-junk-to-gold, mod-player-bot-level-brackets, StatBooster

## Accounts
- ADMIN (id 389) — gmlevel 3
- DED (id 60, char Magicarp) — gmlevel 3 (set during this session)
- Chmone (GUID 568) — bot-buddy controlled bot, Troll Shaman (Race 8, Class 7)

## Key Config Changes from Defaults
- `worldserver.conf`: Corpse.Decay.NORMAL = 300 (5 min instead of 1 min)
- Dockerfile modified: added libcurl4-openssl-dev, nlohmann-json3-dev (build), libcurl4 (runtime)

## StatBooster Module
- Enchant effects defined in DB table `statbooster_enchant_template` (acore_world)
- Scoring in `statbooster_enchant_scores` — mod_type 0=item stats, 1=spell auras
- New effects can be added via SQL only (no rebuild needed)
- Currently has: Str, Agi, Int, Sta, Spi, Spell Power enchants for iLvl ranges 1-80
