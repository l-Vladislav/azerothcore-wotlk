# Entity Class Hierarchy

## Core Inheritance Chain
```
Object (src/server/game/Entities/Object/)
├── WorldObject
│   ├── Unit (src/server/game/Entities/Unit/)
│   │   ├── Player (src/server/game/Entities/Player/)
│   │   ├── Creature (src/server/game/Entities/Creature/)
│   │   │   ├── Pet (src/server/game/Entities/Pet/)
│   │   │   ├── Totem (src/server/game/Entities/Totem/)
│   │   │   └── TempSummon
│   │   └── Vehicle integration (mixin, not inheritance)
│   ├── GameObject (src/server/game/Entities/GameObject/)
│   ├── DynamicObject (src/server/game/Entities/DynamicObject/)
│   ├── Corpse (src/server/game/Entities/Corpse/)
│   └── Transport (src/server/game/Entities/Transport/)
└── Item (src/server/game/Entities/Item/)
    └── Bag/Container (src/server/game/Entities/Item/Container/)
```

## Key Classes

### Object
- ObjectGuid - Unique identifier (type + entry + low GUID)
- UpdateData/UpdateMask - Client update field system
- Position (X, Y, Z, Orientation)

### Unit
- Health, power (mana/rage/energy/runic power)
- Aura system (buffs/debuffs)
- Spell casting
- Combat state, threat
- Movement (MotionMaster)
- Stats (strength, agility, etc.)

### Player
- Inventory management
- Quest tracking
- Talent system
- Social (friends, ignore)
- Achievement tracking
- Mail
- Group/guild membership
- WorldSession reference (network connection)

### Creature
- creature_template data binding
- AI binding (CreatureAI*)
- Loot generation
- Gossip/vendor/trainer
- Respawn management
- Formation system

### GameObject
- gameobject_template binding
- State machine (open/closed/destroyed)
- Quest interaction
- Trap/chest/door mechanics

## AI Hierarchy
```
CreatureAI (base)
├── AggressorAI - Always aggressive
├── ReactorAI - Only fights back
├── GuardAI - Zone guards
├── PetAI - Player pet behavior
├── NullCreatureAI - No AI
├── ScriptedAI - Boss/scripted encounters
│   └── BossAI - Raid/dungeon boss base
├── SmartAI - Database-driven AI (SAI)
└── GameObjectAI - GameObject scripts
```

## Update Flow
1. Map::Update() called each tick (~50ms)
2. Grid visitors iterate over all objects in active grids
3. Object::Update() -> Unit::Update() -> Player/Creature::Update()
4. MotionMaster processes movement generators
5. Spell system processes active spells
6. Aura system ticks periodic effects
7. AI system calls UpdateAI() on creatures
8. UpdateData sent to nearby players
