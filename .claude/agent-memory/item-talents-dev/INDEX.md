# item-talents-dev memory index

Specialist for mod-item-talents (per-item 5-row awakening tree + ItemTalentUI addon).
Project-level design/history: `project_item_talents.md` (auto-memory) + `.claude/item-talents/DESIGN.md`.

## Docs in this folder
- `INDEX.md` (this file) — quick state + pointers.

## Load-bearing facts
- **Repo:** modules/mod-item-talents is its OWN git repo (gitignored in parent). Commit inside it, Conventional Commits, no AI trailers.
- **DB id ranges:** row-5 procs spell_dbc 108000-108092; row-3 auras spell_dbc 108900-108914; blacksmith-kit GA display 70001-70003 (icons INV_Hammer_23/05/06). Storage: `item_talents` + `item_talent_rolls` (characters DB), defs in `item_talent_def`/`item_talent_procs`/`item_talent_named` (world DB).
- **Addon protocol:** `.itemtalent` SAY commands → `ITALENT:` SYSTEM replies. Since v0.16 info/list are BATCHED as `ITALENT:B:<a>\t<b>...` (≤250 chars) via `ChunkedSender` in ItemTalentsScripts.cpp; addon splits on `\t`. Keep it lean (packet count matters under bot load).
- **Perk-hash:** login `.itemtalent sync <hash>` verifies the addon's cached trees (ComputePerkHash = FNV-1a of worn slot+guid+level+rows, kills excluded). Mismatch → full `list`.

## Perf work (2026-07-09 lag hunt) — item-talents was NOT the culprit
- The felt "item-perk click freeze" (up to 3.4s) was **mod-playerbots**, not item-talents: every outgoing packet to a real player scanned all ~1800 random bots (O(bots) fan-out). item-talents' ~21-message info reply merely amplified it. Fixed in playerbots (opcode-filter gate) + this module's `ChunkedSender` batching (21→~3 packets). Branch `perf/info-protocol-batching`.
- SendItemInfo/EnsureState (equipped items) are cache hits, <40ms — fast. Don't add synchronous DB on the info/click path.
- Lesson: a chatty addon protocol is cheap in isolation but expensive under the playerbots per-master-packet fan-out — minimise SysMessages per command.
- Same 2026-07-09 postmortem CLEARED item-talents of the original 2026-07-07 lag suspicion → re-enabled `OnPlayerDurabilityPointsLoss` (DURA_SAVE), see entry below.

## DURA_SAVE durability hook (re-enabled 2026-07-09, branch `feat/reenable-dura-save-bot-gated`)
- `ItemTalentsScripts.cpp` `ItemTalents_Player::OnPlayerDurabilityPointsLoss` was commented out 2026-07-07 (fired ~18x per taken-hit for every online player incl. ~1800 bots). 2026-07-09 lag postmortem found the real tax was playerbots fan-out / chat protocols / nemesis-bootstrap (all fixed already), not this hook — so it was safe to bring back.
- Re-enabled WITH a bot gate as the very first statement: `if (!player || sItemTalentsMgr->ShouldIgnorePlayer(player)) return;` before calling `sItemTalentsMgr->HandleDurabilityLoss(player, item, points)` — same pattern as `OnAuraApply`/`OnAuraRemove` in `ItemTalents_Unit`.
- `ShouldIgnorePlayer(Player*)` (`ItemTalentsMgr.cpp:442`) is a **bot-only** gate: `if (!_ignoreBots || !player) return false; return PlayerbotsMgr::instance().GetPlayerbotAI(player) != nullptr;`. It does NOT check whether the player owns any DURA_SAVE perk — perkless real players still fall through to `HandleDurabilityLoss`, which itself does a cheap `GetPerks`+map-lookup miss and returns fast, so this is acceptable (no "global any-online-DURA_SAVE" gate was added — not needed given the bot-skip removes the ~1800-bot volume that caused the original tax).
- Commit `ff86dad` on branch `feat/reenable-dura-save-bot-gated` (module's own repo), branched off `perf/info-protocol-batching`.

## Related memories
[[project-item-talents]] [[feedback_iteminventory_link_transmog]] [[project_mod_transmog]] [[project-gear-ascension]] [[feedback_spell_dbc_aura_fields]] [[feedback_sql_pending_path]] [[reference_cdn_addon_deployer]] [[feedback_no_claude_commit_authorship]]
