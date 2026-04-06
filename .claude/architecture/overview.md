# Project Overview

AzerothCore WotLK with PlayerBots - an open-source MMORPG server emulator for World of Warcraft patch 3.3.5a (Wrath of the Lich King).

## Tech Stack
- **Language:** C++ (C++17)
- **Build System:** CMake 3.16+
- **Database:** MySQL 8.4
- **Networking:** Boost.Asio (async I/O)
- **Pathfinding:** Recast/Detour navigation
- **Testing:** Google Test
- **Deployment:** Docker, Docker Compose, Nix
- **License:** GNU GPL v2

## Two Server Executables
1. **authserver** (port 3724) - Authentication, realm selection
2. **worldserver** (port 8085, SOAP 7878) - All gameplay logic

## Four Databases
1. **acore_auth** - Accounts, realm list, bans
2. **acore_characters** - Character data, inventories, progress
3. **acore_world** - Game content: creatures, items, quests, spells, loot
4. **playerbots** - Bot-specific persistence (added by mod-playerbots)

## Key Design Patterns
- Manager singletons (ObjectMgr, MapMgr, SpellMgr, BattlegroundMgr, etc.)
- Entity hierarchy: Object -> Unit -> Creature/Player
- Grid-based spatial partitioning for map objects
- Packet handler methods on WorldSession (one file per system)
- Hook-based scripting via ScriptMgr (CreatureScript, SpellScript, InstanceMapScript, etc.)
- Module system for pluggable extensions (modules/ directory)

## Repository Scale
- ~52 game subsystems in src/server/game/
- ~492 script files across 10+ content categories
- 8 installed modules
- 20+ bundled dependencies
- 45+ unit test files
