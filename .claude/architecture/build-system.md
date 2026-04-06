# Build System

## CMake Configuration

### Key Options
| Option | Values | Default |
|---|---|---|
| CMAKE_BUILD_TYPE | Debug, Release, RelWithDebInfo | RelWithDebInfo |
| SCRIPTS | none, static, dynamic, minimal-static, minimal-dynamic | static |
| MODULES | none, static, dynamic | static |
| APPS_BUILD | none, all, auth-only, world-only | all |
| TOOLS_BUILD | none, all, db-only, maps-only | none |
| BUILD_TESTING | ON/OFF | OFF |
| USE_COREPCH | ON/OFF | ON |
| USE_SCRIPTPCH | ON/OFF | ON |

### Build Commands
```bash
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/azeroth-server \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DSCRIPTS=static -DMODULES=static
make -j$(nproc)
make install
```

### CMake Macros (src/cmake/macros/)
- AutoCollect.cmake - Source file auto-discovery
- ConfigureApplications.cmake - Auth/world server targets
- ConfigureModules.cmake - Module loading
- ConfigureScripts.cmake - Script linking
- ConfigureTools.cmake - Tool targets
- ConfigureBaseTargets.cmake - Core compile targets
- FindMySQL.cmake, FindOpenSSL.cmake - Dependency detection
- GroupSources.cmake - IDE source grouping

### Compiler Support
- GCC (src/cmake/compiler/gcc.cmake)
- Clang (src/cmake/compiler/clang.cmake)
- MSVC (src/cmake/compiler/msvc.cmake)
- MinGW (src/cmake/compiler/mingw.cmake)
- ICC (src/cmake/compiler/icc.cmake)

## Dependencies (deps/)
| Library | Purpose |
|---|---|
| boost | Core utilities, networking, containers |
| mysql | Database driver |
| openssl | TLS, cryptography |
| zlib, bzip2 | Compression |
| recastnavigation | Pathfinding/navigation meshes |
| g3dlite | 3D geometry |
| fmt | String formatting |
| argon2 | Password hashing |
| jemalloc | Memory allocator |
| SFMT | Random number generation |
| gsoap | SOAP interface |
| libmpq | MPQ archive reading |
| fkYAML | YAML parsing |
| jsonpath | JSON queries |
| utf8cpp | UTF-8 string handling |
| readline | CLI input |

## Docker Deployment
Services defined in docker-compose.yml:
- ac-database (MySQL 8.4, port 3306)
- ac-db-import (schema initialization)
- ac-worldserver (port 8085 game, 7878 SOAP)
- ac-authserver (port 3724)
- ac-client-data-init (client data setup)
- ac-tools (extraction tools, profile: tools)
- ac-dev-server (dev mode with live code binding, profile: dev)

## Extraction Tools (src/tools/)
Run against WoW 3.3.5a client to extract:
- map_extractor - World map data
- vmap4_extractor + vmap4_assembler - Visual/collision maps
- mmaps_generator - Navigation meshes for pathfinding
- dbimport - Database import utility
