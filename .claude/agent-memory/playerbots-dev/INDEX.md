# playerbots-dev memory index

- [master-packet-fanout-perf.md](master-packet-fanout-perf.md) — 2026-07-09 perf
  fix: `PlayerbotMgr::HandleMasterIncomingPacket`/`HandleMasterOutgoingPacket`
  now skip their O(bots) fan-out loop for opcodes nobody registered a master
  handler for. Read before touching packet-handler registration or the
  `PacketHandlingHelper`/opcode-cache pattern again.

Also see `.claude/agent-memory/live-deployer/` for deploy-package conventions
and the root `~/.claude` user memory (`reference_mod_playerbots_fork.md`,
`feedback_playerbots_sync_gotchas.md`) for the standalone-clone workflow and
known post-sync compile breakages.
