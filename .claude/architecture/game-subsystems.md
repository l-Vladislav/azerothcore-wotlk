# Game Subsystems (src/server/game/)

44+ subsystems organized by function. File counts are approximate.

## Core Entity Systems

### Entities/ (~83 files)
The heart of the object model. Class hierarchy: Object -> WorldObject -> Unit -> Player/Creature.

| Subdirectory | Description |
|---|---|
| Object/ | Base Object class, ObjectGuid, UpdateData, UpdateMask |
| Unit/ | Combat-capable entity base (health, mana, auras, spells) |
| Player/ | Player character (21 files - inventory, talents, achievements, social) |
| Creature/ | NPCs and monsters (12 files - AI binding, loot, gossip) |
| Item/ | Equipment and inventory items, Container (bags) |
| GameObject/ | Interactive world objects (doors, chests, quest objects) |
| Pet/ | Player-owned creatures (hunter pets, warlock demons) |
| Totem/ | Shaman totems |
| Vehicle/ | Vehicle/mount system |
| Transport/ | Ships, zeppelins, elevators |
| Corpse/ | Dead player/creature bodies |
| DynamicObject/ | Temporary area effects (consecration, blizzard) |

### AI/ (~40 files)
| Subdirectory | Description |
|---|---|
| CoreAI/ | Basic AI behaviors (AggressorAI, GuardAI, ReactorAI, PetAI) |
| ScriptedAI/ | ScriptedAI base class for boss/creature scripts |
| SmartScripts/ | SmartAI - database-driven AI system (SAI) |

### Maps/ (~16 files)
Map, MapInstanced, MapMgr, MapUpdater, TransportMgr, AreaBoundary, ZoneScript

### Grids/ (~18 files)
Spatial partitioning: GridCell, GridDefines, GridObjectLoader, MapGrid, Notifiers

### Movement/ (~43 files)
| Subdirectory | Description |
|---|---|
| MovementGenerators/ | Chase, follow, home, random, waypoint, flight, confused, fleeing |
| Spline/ | Smooth path interpolation |
| Waypoints/ | Waypoint path management |

## Game Mechanics

### Spells/ (~16 files)
Spell.cpp (execution), SpellEffects.cpp (150+ effects), SpellInfo (DB data), SpellMgr, SpellScript (scripting hooks), Auras/ subdirectory

### Combat/ (4 files)
CombatManager (enter/leave combat), ThreatManager (aggro/threat table)

### Loot/ (4 files)
LootMgr (loot tables, rolls, distribution), LootItemStorage

### Conditions/ (4 files)
ConditionMgr (conditional logic for quests, gossip, loot, SAI), DisableMgr

### Skills/ (4 files)
SkillDiscovery (recipe discovery), SkillExtraItems (crafting procs)

## Social Systems

| Subsystem | Files | Description |
|---|---|---|
| Accounts/ | 2 | Account data management |
| Achievements/ | 2 | Achievement criteria and completion tracking |
| Calendar/ | 2 | In-game calendar events |
| Chat/ | 18 | Chat system, Channels, ChatCommands (GM commands) |
| Groups/ | 7 | Party/raid group management |
| Guilds/ | 4 | Guild data, ranks, bank |
| Mails/ | 4 | In-game mail system |
| Petitions/ | 2 | Guild/arena team creation petitions |
| Reputation/ | 2 | Faction reputation tracking |
| Tickets/ | 2 | GM ticket system |

## Game Features

| Subsystem | Files | Description |
|---|---|---|
| AuctionHouse/ | 2 | Auction house buy/sell/bid |
| Battlegrounds/ | 46 | BG system, Arena, queue, zones (AB, AV, WSG, EotS, SotA, IoC) |
| Battlefield/ | varies | Wintergrasp and outdoor battles |
| DungeonFinding/ | 12 | LFG/LFD system (queue, matching, rewards) |
| Events/ | 4 | GameEventMgr, HolidayDateCalculator |
| Instances/ | 4 | InstanceSaveMgr, InstanceScript |
| OutdoorPvP/ | varies | Outdoor PvP zone controllers |
| Pools/ | 2 | Spawn pooling (random creature/GO spawns) |
| Quests/ | 3 | QuestDef (quest structure and tracking) |
| Weather/ | 4 | Zone weather system |

## Infrastructure

| Subsystem | Files | Description |
|---|---|---|
| Handlers/ | 36 | Packet handlers (WorldSession methods, one file per system) |
| Server/ | 51 | WorldSession, WorldSocket, World singleton, Packets/, Protocol/ |
| Scripting/ | 108 | ScriptMgr, ScriptObject, ScriptDefines/ (generated hook definitions) |
| DataStores/ | 5 | DBCStores (client data), M2Stores (model data) |
| Globals/ | 6 | ObjectAccessor, ObjectMgr (master data manager), WorldGlobals |
| Warden/ | 13 | Anti-cheat system (Warden client module) |
| Modules/ | varies | Module integration hooks |
| Cache/ | varies | Data caching |
| Texts/ | varies | Creature/broadcast text management |
| Time/ | varies | GameTime utilities |
| Misc/ | varies | Miscellaneous utilities |
| Miscellaneous/ | 3 | Formulas.cpp (XP, honor, damage formulas), Language.h |

## Key Handler Files (src/server/game/Handlers/)

Each file handles packets for one game system. All are methods on WorldSession:

| Handler | Purpose |
|---|---|
| CharacterHandler.cpp | Character creation, login, enum |
| MovementHandler.cpp | Player movement packets |
| SpellHandler.cpp | Spell casting |
| CombatHandler.cpp | Attack start/stop |
| ItemHandler.cpp | Item use, equip, swap, destroy |
| QuestHandler.cpp | Quest accept, complete, abandon |
| ChatHandler.cpp | Chat messages |
| TradeHandler.cpp | Player trading |
| GroupHandler.cpp | Party invite, leave, loot method |
| GuildHandler.cpp | Guild operations |
| AuctionHouseHandler.cpp | AH operations |
| LFGHandler.cpp | Dungeon finder |
| BattleGroundHandler.cpp | BG join, leave |
| LootHandler.cpp | Looting |
| MailHandler.cpp | Mail send, receive |
| NPCHandler.cpp | NPC interaction (vendor, trainer, gossip) |
| PetHandler.cpp | Pet commands |
| VehicleHandler.cpp | Vehicle control |
| MiscHandler.cpp | Miscellaneous (who, ping, time, etc.) |
