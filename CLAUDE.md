# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AzerothCore is an open-source MMORPG server emulator for World of Warcraft patch 3.3.5a (Wrath of the Lich King). It's a C++ project built with CMake, using MySQL for data storage. Licensed under GNU GPL v2.

## Build Commands

### Configure and build (out-of-source build required)

- Skip building unless explicitly requested.

```bash
# Create build directory and configure
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/azeroth-server -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DSCRIPTS=static -DMODULES=static

# Build (use appropriate core count)
make -j$(nproc)
make install
```

### Key CMake options

- `SCRIPTS`: none, static, dynamic, minimal-static, minimal-dynamic (default: static)
- `MODULES`: none, static, dynamic (default: static)
- `APPS_BUILD`: none, all, auth-only, world-only (default: all)
- `TOOLS_BUILD`: none, all, db-only, maps-only (default: none)
- `BUILD_TESTING`: Enable unit tests (default: OFF)
- `USE_COREPCH` / `USE_SCRIPTPCH`: Precompiled headers (default: ON)

### Unit tests

```bash
# Configure with testing enabled
cmake .. -DBUILD_TESTING=ON
make -j$(nproc)

# Run tests
./src/test/unit_tests
# or
ctest
```

Tests use Google Test and live in `src/test/`. The test binary links against the `game` library.

## Architecture

### Two server executables
- **authserver** (`src/server/apps/authserver/`): Handles authentication and realm selection (port 3724)
- **worldserver** (`src/server/apps/worldserver/`): Main game server handling all gameplay (port 8085)

### Source layout (`src/`)

- **`src/common/`** - Shared libraries: networking (Asio), cryptography, configuration, logging, threading, collision detection, utilities
- **`src/server/game/`** - Core game logic (~52 subsystems), the heart of the worldserver
- **`src/server/scripts/`** - Content scripts (bosses, spells, commands, instances)
- **`src/server/database/`** - Database abstraction layer and schema updater
- **`src/server/shared/`** - Code shared between auth and world servers (packets, network, realm definitions)
- **`src/test/`** - Unit tests (Google Test)

### Key game subsystems (`src/server/game/`)

- **Entities/** - Core game objects: `Player`, `Creature`, `Unit`, `Item`, `GameObject`
- **Spells/** - Spell mechanics, aura system, spell effects
- **Maps/** - Map management, grid system, instancing
- **Handlers/** - Client packet handlers (one file per system: `MovementHandler.cpp`, `SpellHandler.cpp`, etc.). These are methods on `WorldSession`
- **AI/** - Creature AI framework
- **Scripting/** - Script system with typed base classes (`ScriptObject` subclasses: `CreatureScript`, `SpellScript`, `InstanceMapScript`, `GameObjectScript`, `CommandScript`, etc.)
- **Server/** - `WorldSession` (per-player connection), `World` (global state), opcode definitions

### Scripting system

Scripts follow a registration pattern:
1. Define a class inheriting from `SpellScript`, `CreatureScript`, etc.
2. Implement an `AddSC_*()` function that calls `RegisterSpellScript(ClassName)` (or similar)
3. The `AddSC_*()` is declared and called from the regional `*_script_loader.cpp`
4. Script loaders per region: `spells_script_loader.cpp`, `eastern_kingdoms_script_loader.cpp`, `northrend_script_loader.cpp`, etc.
5. Spell script files are organized by class: `spell_dk.cpp`, `spell_mage.cpp`, `spell_generic.cpp`, etc.

### Three databases
- **acore_auth** - Accounts, realm list, bans (`data/sql/base/db_auth/`)
- **acore_characters** - Character data, inventories, progress (`data/sql/base/db_characters/`)
- **acore_world** - Game content: creatures, items, quests, spells, loot (`data/sql/base/db_world/`)

- SQL updates go in `data/sql/updates/pending_*` with separate subdirectories per database until pull request is merged. Pending SQL files are assigned random names.
- SQL updates go in `data/sql/updates/` with separate subdirectories per database after their pull request is merged.
- SQL files outside the `data/sql/updates/pending_*` folders should never be updated.

### Module system

External modules are loaded from the `modules/` directory. Each module is a subdirectory with its own `CMakeLists.txt`. Disable specific modules with `-DDISABLED_AC_MODULES="mod1;mod2"`. Module skeleton: https://github.com/azerothcore/skeleton-module/

### Admin panel

`tools/admin-panel` is its own repository (`l-Vladislav/ac-admin-panel`), cloned in place like `modules/mod-*` and ignored here. Commits, branches and PRs for the panel go to that repository; `docker-compose.override.yml` still builds it from `./tools/admin-panel`.

### Dependencies

Bundled in `deps/`: boost, MySQL client, OpenSSL, zlib, recastnavigation (pathfinding), g3dlite (geometry), fmt, argon2, jemalloc, and others.

## Commit Message Format

Uses Conventional Commits:
```
Type(Scope/Subscope): Short description (max 50 chars)
```

- **Types**: feat, fix, refactor, style, docs, test, chore
- **Scopes**: Core (C++ changes), DB (SQL changes)
- **Examples**: `fix(Core/Spells): Fix damage calculation for Fireball`, `fix(DB/SAI): Missing spell to NPC Hogger`

## Code Style

- 4-space indentation for C++ (no tabs)
- 2-space indentation for JSON, YAML, shell scripts
- UTF-8 encoding, LF line endings
- Max 120 character line length (`.editorconfig`)
- No braces around single-line statements
- Use {} to parse variables into output instead of %u etc.
- CI enforces code style checks and compiles with `-Werror`

## Writing Style

Applies to code, comments, commit messages, documentation, SQL headers, UI
text and names.

- Names and definitions use formal domain terminology: one established term
  per concept, taken from the module's design document. No metaphors, slang or
  ad-hoc coinages; do not introduce a synonym for a term that already exists.
- Comments are minimal. Write one only for a constraint the code cannot
  express. Do not narrate what the code does, where it came from, or why a
  change is correct.
- Documentation states the current rules and structure concisely. History
  belongs in git, not in documents.
- Language: code comments, documentation and player-facing text in Russian;
  anything published to GitHub (commits, PRs, branch names) in English.

## Working Style

Deliver what was asked, at the scope intended. Make routine judgment calls;
ask only when different readings lead to materially different work. If the
request looks mistaken, say so in one sentence and proceed as asked. Report
completion only when the work is done; otherwise state what is missing.

## Environments

- **Live**: containers `ac-worldserver-v2`, `ac-authserver-v2`,
  `ac-database-v2`; databases `acore_world`, `acore_characters`. Do not start,
  stop or recreate live containers and do not write to live databases without
  the owner's explicit instruction. Changes reach live through a
  `live-deployer` package.
- **PTR**: container `ac-worldserver-ptr` (`--profile ptr`), databases
  `acore_world_ptr`, `acore_characters_ptr`, config `env/dist/etc-ptr/`. All
  development and verification happen here.

## PR Requirements

- **Pull requests go to the fork `origin` (github.com/l-Vladislav/azerothcore-wotlk)
  only — NEVER to `upstream` (azerothcore/azerothcore-wotlk).** No commits, no
  pushes and no PRs against upstream, whatever the change looks like. Base
  branch is `custom`, the production trunk.
- **Every commit references a board card** (`acore_admin.board_card`) as `[#N]`
  at the end of the subject; `(#N)` is reserved for PR numbers. Work without a
  card gets a card first. Branches are named `feat/<N>-<slug>`.
- **One commit per board card.** Squash before opening the PR: a card's work
  arrives as a single commit carrying `[#N]`.
- Commits carry no Claude authorship trailers (no `Co-Authored-By`, no
  `Claude-Session`).
- AI tool usage must be disclosed in PRs
- In-game testing expected
- Changes to generic code require regression testing of related systems

## Subagents

Specialized subagents live in `.claude/agents/`. Each file documents the
conventions of its system; read the matching file as reference before working
in that area.

Delegate to a subagent only for large, independent work (for example a wide
multi-file investigation) or when the owner asks. Do not delegate verification
or work that takes a handful of tool calls. Brief a subagent completely once
and do not redo its work afterwards.

- **sql-migration-writer** — SQL changes: `pending_db_*` placement, idempotency.
- **dbc-investigator** — read-only lookups in `.claude/dbc/*.csv`.
- **spell-editor** — custom spells, `spell_dbc`, SpellScript/AuraScript, spell texts.
- **familiars-dev** — familiar gacha (`.claude/familiars/`).
- **nemesis-dev** — Nemesis system, bounty board (`.claude/nemesis/`).
- **statbooster-dev** — fortune pools, scrolls, custom enchants (`.claude/statBoosterItems/`).
- **gear-ascension-dev** — `mod-gear-ascension` (item quality upgrade).
- **worn-drops-dev** — `mod-worn-drops` (NPC equipment drops).
- **item-talents-dev** — `mod-item-talents` and the ItemTalentUI addon.
- **playerbots-dev** — playerbots AI and configuration.
- **ollama-chat-dev** — `mod-ollama-chat` and the Ollama service.
- **cdn-addon-deployer** — publishing client addons to the launcher CDN.
- **live-deployer** — deployment packages for promoting PTR changes to live.
