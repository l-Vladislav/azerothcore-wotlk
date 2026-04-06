# Nemesis System - Pending Changes Summary

## Server-Side (NemesisSystem.cpp) — Needs Rebuild

### Already Applied (current running build)
- Damage multiplier decoupled from health (1.25x-2.50x)
- Gold level multiplier (`level / 80`)
- Mail fallback for full inventory (AddItemOrMail with proper transaction)
- Runtime GUID in addon messages
- Russian title generator (40x40x25 = 40,000 combos)
- `creature->SetName(title)` in ApplyNemesisState
- Name restore in ResetCreatureToBaseState
- Russian `[Немезида]` prefix on announcements
- RevengeRewardItem/BountyRewardItem set to 0 (disabled)
- HandleAddonBootstrap sends ALL nemeses (includeAll = true)

### Pending Rebuild
- `FindBaseNonInstanceMap` — searches creature's actual map for runtimeGuid (not just player's map)
- `#include "MapMgr.h"` added
- Chunk ID uses static counter instead of GameTime (fixes duplicate chunk IDs causing lost data)
- Chunk size increased from 220 to 450 bytes
- BroadcastNemesisMessage always server-wide (no zone filtering)
- Nemesis creation push only sends to killed player (not all players on map)
- Performance: removed DoForAllPlayers loop on nemesis creation

## Client Addon (WorldMap.lua, Core.lua) — Copy + Restart WoW

### WorldMap.lua Changes
- `findNemesisByUnit(unit)` — strict matching: runtimeGuid then nemesisTitle
- `findNemesisByUnitLoose(unit)` — adds entry+zone fallback for tooltips
- Portrait icon: skull at top center of target frame, rank-colored, no text
- Portrait name override: `TargetFrameTextureFrameName:SetText(nemesisTitle)` when targeting nemesis
- Portrait restore: calls `TargetFrame_Update(TargetFrame)` for non-nemesis targets
- Tooltip hook: uses `findNemesisByUnitLoose`, replaces first line with nemesisTitle, shows rank/affixes/threat/hunts/reward
- NOTE: Tooltip hooks require full WoW restart to update (HookScript persists across /reload)
- All UI text in Russian: Немезиды panel title, Немезида minimap tooltip
- `[Немезида]` prefix removed from tooltips (was showing raw hex on first attempt)
- World map pins: fixed size 16px, selected 32px with yellow glow
- Uses `WorldMapTooltip` for fullscreen map
- Zone matching: locale-independent via `GetMapInfo()` file names
- Player zone cached via `updatePlayerZoneCache()` to avoid infinite loop
- List defaults to "This Zone", sorts player zone first
- Click navigates to nemesis zone via `SetMapZoom`
- `buildMapFileToZoom()` builds reverse lookup from map files to continent+zone index
- Minimap removed (blips)
- Icon buttons (skull/scroll) for toggling pins/list independently

### Core.lua Changes
- `ShouldHideNemesis` always returns false
- `GetVisibilityAlpha` always returns 1.0
- Parses `runtimeGuid` at startIndex+22, `nemesisTitle` at startIndex+23
- Peer sync messages include runtimeGuid and nemesisTitle
- Auto-sync every 300 seconds (5 min)
- Zone change triggers bootstrap after 3s delay
- Chat message trigger: syncs when `[Nemesis]` or `Немезида` seen in CHAT_MSG_SYSTEM
- `ZONE_CHANGED_NEW_AREA` event registered
- WorldMap refresh on upsert/remove
- Uses `.nemesis addon bootstrap` (SEC_PLAYER, not SEC_GAMEMASTER sync)

## Config (mod_nemesis_system.conf)
- MaxRank = 6
- PromotionLevelDiffMax = 9
- RevengeRewardItem = 0 (disabled, was 1 = crash)
- BountyRewardItem = 0 (disabled, was 1 = crash)
- RevengeRewardGold = 13333 (1g/rank at lvl 60)
- RevengeRewardGoldPerRankBonus = 13333
- BountyRewardGold = 3333
- BountyRewardGoldPerRankBonus = 3333
- BonusDrop.ChancePerRank = 25.0
- VisualAuraSpell = 0
- AddonBootstrapMaxEntries = 1000
- Synced to etc-ptr

## Known Issues
1. **Tooltip hook requires WoW restart** — `/reload` doesn't update `HookScript` on `GameTooltip`
2. **runtimeGuid empty for many nemeses** — only populated when creature is on a loaded map during bootstrap. Pending rebuild with `FindBaseNonInstanceMap` should fix most cases.
3. **SetName doesn't update client nameplate** — 3.3.5 client caches creature names by entry ID. `UnitName("target")` returns cached localized name, not the SetName'd title. Only works for creatures not yet cached by the client.
4. **Portrait matching** — works via runtimeGuid (when populated) or nemesisTitle match (when client shows SetName'd name). Not 100% reliable due to issues #2 and #3.
5. **Tooltip matching** — uses loose entry+zone fallback, may show nemesis info on wrong creature of same type in same zone.
