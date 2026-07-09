# Master packet fan-out perf fix (2026-07-09)

## Root cause (found via main-thread instrumented lag hunt on live, 1800 bots)

`WorldSession::SendPacket` (core, `src/server/game/Server/WorldSession.cpp:296`)
calls `sScriptMgr->OnPlayerbotPacketSent` for **every** outgoing packet to a real
player. `WorldSession::OnPacketReceived`-style hook does the same for incoming
packets. In `modules/mod-playerbots/src/Script/Playerbots.cpp` these funnel into
`PlayerbotMgr::HandleMasterIncomingPacket`/`HandleMasterOutgoingPacket`
(`src/Bot/PlayerbotMgr.cpp`), which had **two unconditional loops**: one over the
master's own owned bots, one over **all** `sRandomPlayerbotMgr` bots (~1800 on
live), doing a `GET_PLAYERBOT_AI` (map find + `dynamic_cast`) per bot on every
single packet — even chat/movement/casts that no master handler cares about.
`PacketHandlingHelper::AddPacket` already no-ops for unregistered opcodes, but
you still pay for the O(bots) scan to reach that no-op. Measured: one player
chat command (~21 SMSG_MESSAGECHAT fanned out by an addon) cost ~450ms.

## Fix

Added an opcode-membership pre-check before the loops, so unregistered opcodes
skip the O(bots) scan entirely:

- `PacketHandlingHelper::GetOpcodes() const` (`PlayerbotAI.h`/`.cpp`) — returns
  just the registered opcode keys, deliberately **not** the queue (queue is
  per-bot state, must never be shared statically).
- `PlayerbotAI::masterIncomingOpcodeCache` / `masterOutgoingOpcodeCache` (static
  `std::set<uint16>`) + `masterOpcodeCacheReady` bool — populated once, from
  whichever `PlayerbotAI(Player*)` is constructed first, since **every** bot
  (owned or random) registers the exact same fixed opcode set in the
  constructor (verified: no other call site anywhere in the module calls
  `masterIncomingPacketHandlers.AddHandler`/`masterOutgoingPacketHandlers.AddHandler`
  outside that one constructor — grep before touching this again).
- `PlayerbotAI::IsMasterIncomingOpcodeRegistered(uint16)` /
  `IsMasterOutgoingOpcodeRegistered(uint16)` — O(1) lookup against the cache.
- `PlayerbotMgr::HandleMasterIncomingPacket` — wraps **only the two loops** in
  `if (PlayerbotAI::IsMasterIncomingOpcodeRegistered(...))`. The `switch` on
  `CMSG_LOGOUT_REQUEST`/`CMSG_LOGOUT_CANCEL` at the bottom of that function
  **must stay unconditional** — those two opcodes are handled by that switch
  directly and are NOT in `masterIncomingPacketHandlers` at all. An earlier
  draft of this fix as a blanket early `return` would have silently broken
  bot logout-on-master-logout. Watch for this if refactoring further.
- `PlayerbotMgr::HandleMasterOutgoingPacket` — nothing follows the loops here,
  so a plain early `return` is exact and simpler.

Behavior is 100% identical to before (registered opcodes still hit the loops;
unregistered ones were already effectively no-ops downstream) — this is purely
removing wasted O(bots) work, not a heuristic.

No `playerbots.conf.dist` key was added — this is an always-on internal perf
fix, not a tunable feature.

## Verification

`docker compose build ac-worldserver` — full clean recompile succeeded
(`PlayerbotAI.cpp.o`, `PlayerbotMgr.cpp.o` built with zero warnings from our
changes; only pre-existing unrelated warnings elsewhere — `NextAction` copy-
assign deprecation, sign-compare in Naxxramas/MovementActions — same as
before this change). Image built and tagged; live `ac-worldserver-v2`
container was **not** restarted/recreated (still running the old image after
the build — `docker compose build` never touches running containers).

## Files

- `modules/mod-playerbots/src/Bot/PlayerbotAI.h`
- `modules/mod-playerbots/src/Bot/PlayerbotAI.cpp`
- `modules/mod-playerbots/src/Bot/PlayerbotMgr.cpp`

## Aside: pre-existing uncommitted fixes in this working tree

At the time of this fix, `modules/mod-playerbots` (standalone git clone, see
`reference_mod_playerbots_fork.md`) already had **uncommitted** modifications
in `WaitForAttackAction.cpp`, `StuckTriggers.cpp`, `RandomPlayerbotFactory.cpp`,
`TravelMgr.cpp` — these are the known post-sync compile fixes documented in
`feedback_playerbots_sync_gotchas.md` (missing `IVMapMgr.h` include,
`MapCollisionData.h` not present in this core, `sAccountMgr` singleton vs
namespace). Not touched by this session; mentioned here only so a future
session doesn't mistake them for part of this perf fix's diff.
