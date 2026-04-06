# Server-Side vs Client-Side Capabilities (WoW 3.3.5a / AzerothCore)

What you can and can't do with only server changes (no client/MPQ/DBC patches).

---

## FULLY SERVER-SIDE (No Client Changes Needed)

### Items
- **New items** — YES. The client sends `CMSG_ITEM_QUERY_SINGLE` for unknown items and the server responds with full item data. New items work as long as you use an **existing DisplayID** (icon + 3D model that already exists in the client).
- **Custom stats, effects, required level, item level** — all defined server-side in `item_template`.
- **Limitations**: Can't add new item icons or new 3D weapon/armor models. Must reuse existing `displayid` values from the client.

### NPCs / Creatures
- **New NPCs** — YES, using existing `modelid` values from `CreatureDisplayInfo.dbc` (client-side models).
- **Custom gossip menus** — YES, fully server-side. This is how features like reforging, transmogrification, teleporters, buffer NPCs, etc. are implemented.
- **Vendors with custom items** — YES.
- **SmartAI / Scripted behaviors** — YES, via `smart_scripts` table or C++ `CreatureScript`.
- **Trainers** — YES, but can only teach existing spells (spells the client knows about).

### Quests
- **New quests** — YES. Quest title, text, objectives text are all sent from server to client via `SMSG_QUEST_QUERY_RESPONSE`. Works without client patches.
- **Kill/collect/escort/event objectives** — YES.
- **Limitations**: Quest tracker objective text (the short summary in the tracker) uses client-cached data and can sometimes be quirky. Quest POI (map markers) need `QuestPOI` entries.

### Spells (Modifications Only)
- **Modify existing spell effects** — YES (damage values, healing, proc chances, targets, cooldowns, range). Done via `spell_dbc` table or C++ `SpellScript` overrides.
- **Repurpose unused spell IDs** — YES. Many unused spell entries exist in the client's `Spell.dbc`. You can assign new server-side effects to these, and they'll use whatever icon/name/visual the client already has for that ID.
- **Custom spell scripts** — YES (e.g., make a spell trigger custom logic on hit).

### Game Systems via Gossip/NPC Menus
These are custom server features built using gossip NPCs — no client changes:
- **Transmogrification** — change item appearance (using existing appearances)
- **Reforging** — redistribute stats on gear
- **Teleporter NPCs** — custom teleport menus
- **Buffer NPCs** — apply buffs via menu
- **Guild house systems** — instance-based guild areas (using existing maps)
- **Gambling / lottery NPCs**
- **Custom token/currency exchange** — trade items via NPC
- **Stat reroll / enchant NPCs** (like your StatBooster module)
- **Transmog sets / outfit saving**

### Loot
- **All loot tables** — fully server-side (`creature_loot_template`, `item_loot_template`, `reference_loot_template`, etc.)
- **Drop rates, loot groups, conditions** — all server-side.

### World & Gameplay Tuning
- **XP rates, reputation rates, drop rates** — config or DB.
- **Creature stats (HP, damage, armor, resistances)** — `creature_template`.
- **Dungeon/raid difficulty scaling** — server-side (mod-autobalance).
- **Honor/arena point rates** — server config.
- **Respawn timers** — server-side.

### Instance & Boss Scripts
- **Custom boss mechanics** — YES, via C++ `InstanceMapScript` / `CreatureScript`. Can create entirely new fight phases, abilities (using existing spells), triggers, and events.
- **Modify existing dungeon/raid scripts** — YES.
- **Cannot** add new maps/instances (see below), but can heavily modify existing ones.

### Events & Conditions
- **Game events** (holidays, custom timed events) — `game_event` tables.
- **Conditions system** — extensive server-side condition framework for quests, gossip, loot, etc.
- **World state variables** — server-side tracking.

### Chat & Commands
- **Custom `.commands`** — YES, via C++ `CommandScript`.
- **Custom chat filters / hooks** — YES.
- **Server announcements, MOTD** — server-side.

### PlayerBots
- **All bot behaviors** — fully server-side (your `mod-playerbots` module).

### Achievements (Partial)
- **Trigger/complete existing achievements** — YES, server-side.
- **Cannot** add new achievements (see below).

---

## REQUIRES CLIENT MODIFICATION (DBC/MPQ Patches)

### New Spells
- **New spell entries** — Need `Spell.dbc` on the client. Defines: name, description, icon, visual effect, cast animation, cast time display, range display, power cost display.
- Without client DBC: the spell "works" mechanically if you write server code, but the client won't show name, icon, cast bar, or visual effects properly.
- **Workaround**: Repurpose existing unused spell IDs — the client already has their visual data.

### New Classes
- **Hardcoded in the client** binary. Class IDs, power types (mana/rage/energy/runic power), base stats UI, character creation screen — all client-side.
- **Hero classes** (like DK starting experience) — client expects specific class IDs.

### New Races
- **Hardcoded in the client**. Character models, creation screen, racial UI — all client-side.
- Cannot even add them to character creation without client patches.

### New Professions / Skills
- **Profession list is hardcoded** in the client UI. The profession panel, skill-up visuals, and recipe learning UI expect specific skill IDs from `SkillLine.dbc`.
- **Workaround**: You CAN teach existing profession recipes to NPCs, and you can create custom "pseudo-professions" via gossip menus (e.g., an NPC that tracks your "custom skill" via a hidden quest or item count).

### New Talent Trees / Talents
- **Talent UI** reads from `Talent.dbc` and `TalentTab.dbc` on the client.
- Cannot add new talent trees or talent icons without client patches.
- **Can** modify what existing talents DO (server-side spell effects), but not how they appear.

### New Maps / Zones / Continents
- **Map geometry** (ADT terrain files, WDT definitions) is entirely client-side.
- **New instances/battlegrounds/arenas** need client map data.
- **Workaround**: Repurpose existing unused maps/areas. GM Island, test maps, and unused instance IDs exist.

### New 3D Models / Textures
- **Creature models, weapon models, armor models** — M2/WMO/BLP files in client MPQs.
- Cannot add new visual appearances without adding assets to client.
- Server can only reference `DisplayID` values that the client already has.

### New Icons
- **Item icons, spell icons, ability icons** — BLP texture files in client MPQs.
- Must reuse existing icons for server-only changes.

### New Achievements
- **Achievement definitions** — `Achievement.dbc` and `Achievement_Criteria.dbc` on client.
- Client renders achievement name, description, icon, and criteria from these DBCs.
- **Workaround**: Can reuse/modify behavior of existing achievement IDs server-side.

### UI Changes
- **Action bars, unit frames, bags, character panel** — client-side Lua/XML.
- **Custom UI panels** — require client addons (players install these themselves; doesn't need MPQ patching).
- **Workaround**: Addons are player-side and don't need MPQ edits — you can distribute an addon that players install in their `Interface/AddOns/` folder. The server can communicate with addons via addon messages (`SMSG_MESSAGECHAT` with addon channel).

### Loading Screens / Music / Cinematics
- All client-side assets in MPQ archives.

### Emotes / Animations
- Animation data is in client M2 model files and `AnimationData.dbc`.

---

## GRAY AREA / CREATIVE WORKAROUNDS

### Spell Modifications (Hybrid)
- You CAN change what a spell does (damage, heal, apply aura, teleport, summon) purely server-side.
- You CANNOT change what it looks like (cast animation, projectile visual, impact effect) without client DBC.
- **Common trick**: Find an existing spell with the visual you want, create a server-side copy of its effects but change the mechanic. Players see the right visual, and your custom logic runs.

### Custom Enchant Visuals
- Enchant visual effects on weapons are in `SpellItemEnchantment.dbc` (client-side).
- You can apply existing enchant visuals to items server-side, but can't create new visual effects.

### Fake Profession via Items/Gossip
- Can't add a real profession, but you can simulate one:
  - Track "skill level" using a hidden item count or custom DB table
  - Use a gossip NPC as the "crafting interface"
  - "Recipes" are gossip options that check materials and skill level
  - This is fully server-side but won't show in the profession UI

### Custom Currency
- Can't add new currency types to the currency tab (client UI), but:
  - Use items as tokens (e.g., Badge of Justice, custom items)
  - Track via hidden player variables
  - Exchange via NPC gossip menus

### Phasing
- WoW 3.3.5a supports phasing (same zone, different visible content per player).
- Fully server-side. Can create dramatically different experiences in the same map.

### Vehicle System
- Vehicle mechanics are partially server-side. Can create custom vehicle encounters using existing vehicle spell IDs.

### Arena / Battleground Modifications
- Can modify existing BG/arena scripts (win conditions, scoring, NPC spawns).
- Cannot add entirely new BG maps without client data.
- **Workaround**: Repurpose existing arena/BG maps with new rules.

---

## SUMMARY QUICK REFERENCE

| Feature | Server-Only? | Notes |
|---|---|---|
| New items | YES | Must use existing icons/models |
| New NPCs | YES | Must use existing creature models |
| New quests | YES | Full quest chains work |
| Gossip menus (reforge, transmog, etc.) | YES | Primary way to add custom features |
| Modify spell effects | YES | Change what spells DO |
| New spell visuals/icons | NO | Need client DBC |
| New spells (fully new) | NO | Need client Spell.dbc |
| Boss/instance scripts | YES | Using existing maps and spells |
| Loot tables | YES | Fully server-side |
| XP/drop/honor rates | YES | Config or DB |
| New classes | NO | Hardcoded in client |
| New races | NO | Hardcoded in client |
| New professions | NO | Client UI hardcoded |
| New talent trees | NO | Need client DBC |
| New maps/zones | NO | Need client terrain data |
| New 3D models/icons | NO | Need client MPQ assets |
| New achievements | NO | Need client DBC |
| Custom UI panels | PARTIAL | Via player-installed addons |
| Phasing | YES | Built-in 3.3.5a feature |
| PlayerBots | YES | Fully server-side module |
| Custom commands | YES | C++ CommandScript |
