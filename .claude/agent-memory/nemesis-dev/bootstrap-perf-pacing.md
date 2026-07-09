# Addon bootstrap perf pacing (2026-07-09)

## Symptom (measured on live, not by this agent)

`.nemesis addon bootstrap` / `.nemesis addon sync` measured a stable
**~190ms of blocked main-thread time per invocation** on live (1596 bots),
via a timer wrapped around the chat-command invoker. Fixed cost, independent
of bot count — i.e. proportional to something world-state-sized, not
player-count-sized.

## Root cause

Both commands call `SendNemesisBootstrap(player, /*includeAll=*/true)`
(`NemesisSystem.cpp`). `includeAll=true` makes `CollectBootstrapSpawnIds`
return **every non-expired entry in `ActiveNemeses`** (the
`AddonBootstrapMaxEntries` cap only applies when `includeAll` is false — see
the `if (!includeAll && matches.size() > ...)` guard). This is intentional
existing behavior, documented in `branch_private_changes.md` /
`pending_changes.md`: *"HandleAddonBootstrap sends ALL nemeses
(includeAll = true)"* — the world map / journal are meant to show every
nemesis, not just ones related to the requesting player. **Do not flip this
back to filtered mode** — that would silently regress the "see everything"
feature that was deliberately added.

`ActiveNemeses` world-wide is kept near capacity by ambient generation
(`NemesisSystem.MaxPerZone = 20` per zone, refilled toward that cap whenever
a zone with "real player" presence — playerbots count, since they're real
`Player` objects — drops below ~50% fill). With ~1596 bots roaming, most
populated zones sit near the cap, so total active nemeses across the world
is plausibly in the many-hundreds-to-low-thousands range and roughly
constant regardless of bot count (explains the "fixed cost, not
bot-count-dependent" observation).

For every one of those entries, `SendNemesisBootstrap`'s loop called
`BuildAddonView` (title generation, localized name lookup, zone name lookup,
live-creature resolution, reputation/bounty lookups — each individually
cheap, O(1)-ish hash/map lookups) + `SendChunkedAddonPayload` (string
formatting + `WorldPacket` construction + session send) with **no DB
queries involved** (confirmed by the main-thread instrumentation — this
matches "not DB contention"). At an estimated ~0.15ms/entry, a few hundred
to ~1200 entries synchronously in one command handler call adds up to the
observed ~190ms. No single step is expensive; the loop itself, run
unpaced and synchronously inside one command invocation, is.

## Fix (server side): pace the drain across world ticks

`SendNemesisBootstrap` no longer builds/sends every entry inline. It now:
1. Computes the spawnId/tempGuid work list immediately (cheap: map
   iteration + a sort of a few thousand elements at most — not the
   bottleneck).
2. Sends `HELLO` + `BOOTSTRAP_BEGIN` immediately (addon progress bar starts).
3. Stores the work list in a `PendingBootstraps` map keyed by player GUID.

A new `ProcessPendingBootstraps()` is called unconditionally every world
tick from the existing `NemesisAmbientWorldScript::OnUpdate` (a global
`WorldScript`, already firing every tick for the ambient-generation timer —
reused rather than adding a second `WorldScript`). It drains up to
`NemesisSystem.AddonBootstrapEntriesPerTick` (default 50) entries **total,
shared across every player's in-flight queue that tick** — this is a global
budget, not per-player, so the worst-case added per-tick cost is bounded
regardless of how many players happen to be mid-bootstrap simultaneously.
Once a player's queue drains, `BOOTSTRAP_END` is sent and the queue entry is
erased. `tempGuids` (dungeon/temporary nemeses) are snapshotted as
`ObjectGuid` keys only — the live `Creature*` is re-resolved via
`ObjectAccessor::GetCreature` at actual drain time, never held across ticks,
since a creature can legitimately die/despawn during a multi-tick drain.

Wire protocol is byte-for-byte unchanged (same opcodes, same field layout,
same "send everything" content) — only the pacing of when entries go out
changed. Cold-start correctness holds: nothing is dropped, just spread over
more ticks; `BOOTSTRAP_END` always eventually fires after the true last
entry.

Single-threaded assumption: this file has no locks anywhere (chat command
handling and `WorldScript::OnUpdate` both run on the main world thread), so
`PendingBootstraps` needs no synchronization — consistent with every other
container in this file (`ActiveNemeses`, `ActiveTemporaryNemeses`, etc).

## Fix (addon side): stop re-triggering full bootstraps so often

`Core.lua`'s `RequestBootstrap()` gained a `force` parameter and an internal
cooldown guard (`BOOTSTRAP_COOLDOWN_SECONDS = 45`, dedicated
`self.data.lastBootstrapRequestAt` field — deliberately NOT reusing the
shared `lastSyncAt` field, which also gets bumped by unrelated peer-sync
traffic and would make the guard's semantics fuzzy):
- Skips silently if `self.data.bootstrapActive` (a bootstrap is currently
  draining — set by `BeginBootstrap`/cleared by `FinalizeBootstrap`) or if
  the last request was under 45s ago.
- `force=true` bypasses the guard entirely. Used ONLY by
  `PLAYER_ENTERING_WORLD` (login/reload/loading-screen/teleport/instance
  enter) — this event is inherently infrequent (loading screens, not chat
  spam) and is exactly when stale/missing data is most likely, so it should
  always get a fresh full bootstrap. This is also what guarantees cold-start
  correctness: first login/reload always forces through regardless of any
  leftover in-memory state (which in practice is always fresh anyway, since
  `/reload` fully resets the Lua VM and `NT.data`'s defaults reset
  `lastBootstrapRequestAt`/`bootstrapActive` to 0/false — but the explicit
  `force=true` makes this guaranteed rather than incidental).
- `ZONE_CHANGED_NEW_AREA` and `AutoSync` (300s repeating timer) call
  `RequestBootstrap()` un-forced — debounced like everything else. Zone
  changes were the second-worst spam source named in the report; now capped
  to at most once per cooldown window.

The **worst offender** named in the report — the chat-keyword trigger in
`CHAT_MSG_SYSTEM` (any system message containing "[Nemesis]"/"немезид"/
"ранг"/"обрёл"/"обрел"/"стал(а)"/"присутствие") — previously called
`self:ScheduleTimer(function() self:RequestBootstrap() end, 2)` on **every**
matching line with **no coalescing**: each matching chat line scheduled its
OWN independent 2s-delayed timer, none of which cancelled any prior pending
one. A burst of N nemesis-related bot-combat chat lines within a couple of
seconds queued up N overlapping `RequestBootstrap()` calls a couple seconds
later — this is the exact mechanism that produced "chains of 190ms
sub-lags" described in the ticket. Fixed with a small local
debounce/coalesce helper, `ScheduleChatTriggeredBootstrap()`: a
`pendingChatBootstrap` flag ensures only one 2s-delayed call can be pending
at a time; further matching chat lines while one is already pending are
no-ops. The single deferred call, when it fires, still goes through
`RequestBootstrap()`'s own cooldown guard as a second layer of protection.

## Files changed

- `modules/mod-nemesis-system/src/NemesisSystem.cpp` — `GetAddonBootstrapEntriesPerTick()`,
  `PendingBootstrap` struct + `PendingBootstraps` map, `SendNemesisBootstrap`
  rewritten to enqueue, new `ProcessPendingBootstraps()`, hooked into
  `NemesisAmbientWorldScript::OnUpdate`.
- `modules/mod-nemesis-system/conf/mod_nemesis_system.conf.dist` — new
  `NemesisSystem.AddonBootstrapEntriesPerTick` (default 50), documented next
  to the existing `AddonBootstrap*` options.
- `modules/mod-nemesis-system/ClientAddon/NemesisTracker/Core.lua` —
  `RequestBootstrap(force)` cooldown guard + `lastBootstrapRequestAt` data
  field, `ScheduleChatTriggeredBootstrap()` coalescing helper, updated the 4
  call sites (`PLAYER_ENTERING_WORLD` forced, `ZONE_CHANGED_NEW_AREA` /
  `AutoSync` / chat-keyword all debounced).
- `modules/mod-nemesis-system/ClientAddon/NemesisTracker/NemesisTracker.toc`
  — version bump 0.2.1 -> 0.2.2 (Lua changes require a full addon
  re-copy + `/reload` to reach players, same as every prior Lua-only fix in
  this module).

## Not touched / out of scope for this fix

- No SQL migration needed.
- Did not touch `mod-item-talents`, `mod-playerbots`, or any of the main
  thread's own "lag hunt"/SLOW TICK/SLOW SYNC/SLOW OPCODE/SLOW
  SESSION/IT-DBG/IT-INFO instrumentation — those are owned by the
  main/live-deployer thread's own perf investigation, not this module.
- No docker build, no live container restart, no CDN publish — deployment
  (worldserver rebuild + addon redistribution via the launcher CDN) is owned
  by the main thread per the task's constraints.
- Did not change what data gets sent (still literally every active
  nemesis world-wide on a full bootstrap) — only how often the addon asks
  for it and how the server paces building/sending it once asked.
