# nemesis-dev memory index

- [worldmap-zone-matching.md](worldmap-zone-matching.md) — how addon
  zone/pin matching actually works (AreaID-primary since 2026-07-05), the
  MapData.lua tables' real role, and the AreaTable.csv column-offset trap.
  Load before touching anything zone/map-pin related.
- [bootstrap-perf-pacing.md](bootstrap-perf-pacing.md) — 2026-07-09 fix for
  the ~190ms main-thread block on `.nemesis addon bootstrap/sync`: server
  now paces `SendNemesisBootstrap`'s per-entry work across world ticks
  (`ProcessPendingBootstraps`, `NemesisSystem.AddonBootstrapEntriesPerTick`);
  addon debounces `RequestBootstrap` (45s cooldown + coalesced chat-keyword
  trigger). `includeAll=true` (send every world-wide nemesis) is intentional
  — don't "fix" this by filtering it down.

Full design docs: `.claude/nemesis/nemesis_system.md`,
`.claude/nemesis/pending_changes.md`, `.claude/nemesis/branch_private_changes.md`.
