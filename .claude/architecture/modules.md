# Module System

Modules are loaded from modules/ directory. Each is a git submodule with its own CMakeLists.txt.
Disable specific modules: `-DDISABLED_AC_MODULES="mod1;mod2"`

## Module Loading
- modules/CMakeLists.txt auto-discovers subdirectories
- ModulesLoader.cpp.in.cmake generates loader code
- ModulesScriptLoader.h provides script registration
- Module skeleton: https://github.com/azerothcore/skeleton-module/

## Installed Modules

### mod-playerbots (PRIMARY - largest module)
AI-controlled player bots that join groups, do dungeons/raids, PvP, and level up.

**Structure:**
```
mod-playerbots/
├── conf/           # Bot configuration
├── data/           # SQL data, bot profiles
├── apps/           # Application integration
└── src/
    ├── Ai/         # AI subsystems
    │   ├── Base/   # Core AI (PlayerbotAI, Action, Trigger, Strategy)
    │   ├── Class/  # Per-class strategies (DK, Druid, Hunter, Mage, etc.)
    │   ├── Dungeon/ # Dungeon-specific strategies
    │   ├── Raid/   # Raid-specific strategies
    │   └── World/  # World/leveling AI
    ├── Bot/        # Bot lifecycle management
    ├── Db/         # Database operations
    ├── Mgr/        # Manager classes
    ├── Script/     # Script hooks
    └── Util/       # Utilities
```

### mod-autobalance
Automatically adjusts dungeon/raid difficulty based on group size and level.

### mod-ah-bot-plus
Enhanced auction house bot - populates AH with items for realistic economy.

### mod-aoe-loot
Area-of-effect looting - loot all nearby corpses at once.

### mod-individual-progression
Individual character progression system with optional features.

### mod-junk-to-gold
Converts junk items to gold automatically.

### mod-player-bot-level-brackets
Level bracket system for player bots.

### StatBooster
Character stat boosting functionality.
