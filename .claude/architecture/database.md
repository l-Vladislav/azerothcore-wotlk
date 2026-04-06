# Database Architecture

## Database Layer (src/server/database/)

### Abstraction
- MySQLConnection.cpp/.h - MySQL driver wrapper
- MySQLPreparedStatement.cpp/.h - Prepared statement support
- MySQLThreading.cpp/.h - Thread-safe connections
- DatabaseWorkerPool.cpp/.h - Connection pooling (async + sync pools)
- QueryResult.cpp/.h - Result set handling
- Transaction.cpp/.h - Transaction support
- DatabaseEnv.cpp/.h - Environment/type definitions

### Implementations (src/server/database/Database/Implementation/)
Four database connection types:
- **CharacterDatabase** - Character data persistence
- **LoginDatabase** - Account/auth data
- **WorldDatabase** - Game content (read-heavy)
- **PlayerbotsDatabase** - Bot-specific data (added by mod-playerbots)

### Schema Updater (src/server/database/Updater/)
- DBUpdater.cpp/.h - Automatic schema migration
- Reads SQL files from data/sql/updates/ directories
- Tracks applied updates in `updates` table per database

## SQL File Organization (data/sql/)

```
data/sql/
├── base/                   # Full schema definitions
│   ├── db_auth/            # 18+ table definitions
│   ├── db_characters/      # Character tables
│   └── db_world/           # World content tables
├── updates/                # Merged incremental updates
│   ├── db_auth/
│   ├── db_characters/
│   └── db_world/
├── updates/pending_*/      # Unmerged updates (current PR work)
│   ├── pending_db_auth/
│   ├── pending_db_characters/
│   └── pending_db_world/
├── custom/                 # Custom user modifications
│   ├── db_auth/
│   ├── db_characters/
│   └── db_world/
├── archive/                # Archived old updates
├── old/                    # Deprecated scripts
└── create/                 # Database creation scripts
```

## Key Tables

### acore_auth
- account, account_access, account_banned, account_muted
- realmlist, realmcharacters
- autobroadcast, motd
- ip_banned, build_info
- secret_digest
- updates, updates_include

### acore_characters (selected)
- characters - Core character data
- character_inventory, character_equipmentsets
- character_spell, character_talent, character_aura
- character_queststatus, character_reputation
- character_social, character_skills
- guild, guild_member, guild_bank_tab
- arena_team, arena_team_member
- mail, mail_items
- instance, instance_reset

### acore_world (selected)
- creature_template, creature, creature_loot_template
- gameobject_template, gameobject
- item_template, item_loot_template
- quest_template, quest_offer_reward, quest_request_items
- spell_dbc (spell overrides)
- npc_vendor, npc_trainer, npc_text, gossip_menu
- smart_scripts (SAI)
- conditions
- waypoints, waypoint_data
- broadcast_text

## SQL Update Conventions
- Pending updates go in data/sql/updates/pending_* with random filenames
- After PR merge, they move to data/sql/updates/
- Never modify files outside pending_* directories
- Base schema files should not be updated directly
