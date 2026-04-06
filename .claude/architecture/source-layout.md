# Source Code Layout

## Top-Level Directories
```
azerothcore-wotlk/
├── apps/           # Docker, CI/CD, compiler configs, tools, startup scripts
├── bin/            # Shell launcher scripts (acore, acore-compiler, etc.)
├── conf/dist/      # Default configuration (config.cmake, config.sh, docker env)
├── data/sql/       # Database schemas and migrations
├── deps/           # Bundled dependencies (boost, mysql, openssl, fmt, etc.)
├── doc/            # Documentation (ConfigPolicy.md, Logging.md, changelog/)
├── env/            # Environment configuration
├── modules/        # Pluggable modules (mod-playerbots, mod-autobalance, etc.)
├── src/            # All source code
├── tools/          # Dev utility scripts
└── var/            # Runtime variable files
```

## Source Tree (src/)
```
src/
├── cmake/                  # CMake build configuration
│   ├── compiler/           # Per-compiler configs (clang, gcc, msvc, mingw, icc)
│   ├── macros/             # 17 CMake macros (AutoCollect, FindMySQL, etc.)
│   └── platform/           # Platform-specific settings (unix, win)
│
├── common/                 # Shared utility libraries
│   ├── Asio/               # Async networking
│   ├── Collision/          # Collision detection (VMap, MMap)
│   ├── Configuration/      # Config file parsing
│   ├── Cryptography/       # ARC4, SHA, BigNumber, SRP6
│   ├── DataStores/         # DBC file loading
│   ├── Debugging/          # Debug utilities
│   ├── Dynamic/            # Dynamic module loading
│   ├── Encoding/           # Character encoding (UTF-8)
│   ├── IPLocation/         # GeoIP
│   ├── Logging/            # Log system (Appenders, Loggers)
│   ├── Metric/             # Performance metrics
│   ├── Navigation/         # Recast/Detour pathfinding
│   ├── Platform/           # OS abstraction
│   ├── Threading/          # Thread pool, synchronization primitives
│   └── Utilities/          # EventMap, TaskScheduler, StringFormat, etc.
│
├── server/
│   ├── apps/
│   │   ├── authserver/     # Login server binary (Main.cpp, AuthSession, AuthCodes)
│   │   └── worldserver/    # Game server binary (Main.cpp, ACSoap, CLI, RemoteAccess)
│   ├── database/           # DB abstraction layer
│   │   ├── Database/       # MySQLConnection, QueryResult, Transaction
│   │   │   └── Implementation/ # CharacterDB, LoginDB, WorldDB, PlayerbotsDB
│   │   ├── Logging/        # DB logging
│   │   └── Updater/        # Schema migration (DBUpdater)
│   ├── game/               # Core game logic (44+ subsystems, see game-subsystems.md)
│   ├── scripts/            # Content scripts (see scripts-layout.md)
│   └── shared/             # Shared between auth/world servers
│       ├── DataStores/     # DBC loading (DBCStore, DBCStructure)
│       ├── Network/        # AsyncAcceptor, NetworkThread, Socket, SocketMgr
│       ├── Packets/        # ByteBuffer serialization
│       ├── Realms/         # Realm, RealmList
│       └── Secrets/        # SecretMgr
│
├── test/                   # Unit tests (Google Test)
│   ├── common/             # Common lib tests
│   ├── mocks/              # Test doubles (AuraStub, UnitStub, TestCreature, etc.)
│   └── server/game/        # Game logic tests (Spells, Combat, Battlegrounds, etc.)
│
└── tools/                  # Extraction/generation tools
    ├── dbimport/           # Database import
    ├── map_extractor/      # Map data extraction from client
    ├── mmaps_generator/    # Navigation mesh generation
    ├── vmap4_assembler/    # Visual map assembly
    └── vmap4_extractor/    # Visual map extraction from client
```
