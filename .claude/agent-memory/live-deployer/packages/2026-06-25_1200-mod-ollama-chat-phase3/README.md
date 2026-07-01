# mod-ollama-chat Phase 3 — Live Deployment Instructions

**Date prepared:** 2026-06-25
**Live server status at package creation:** ac-worldserver-v2 STOPPED (only PTR up)

This is the complete checklist. Complete steps in order. Steps 1-2 are automated via script;
steps 3-5 are manual.

---

## Step 0 — Verify module is on the correct commit

From the project root:

```powershell
cd modules\mod-ollama-chat
git log --oneline -1
```

Expected output: `bfef7f9` as the first word (feat/ollama-chat-llm tip).
If you see a different commit, switch branches:

```powershell
git checkout feat/ollama-chat-llm
```

Then return to the project root.

---

## Step 1 — Apply DB migrations (automated)

From the project root:

```powershell
pwsh .claude\agent-memory\live-deployer\packages\2026-06-25_1200-mod-ollama-chat-phase3\apply.ps1
```

What it does:
- Takes a gzip snapshot of acore_characters to `pre-deploy-snapshot.sql.gz` in this package dir
- Applies 4 SQL files to acore_characters (live)
- Verifies the two new tables exist

Expected duration: ~1 minute (snapshot + 4 tiny CREATE/REPLACE statements).

If it fails at any SQL: run rollback.ps1 (see below).

---

## Step 2 — Edit live config

Open this file in your text editor:
```
env\dist\etc\modules\mod_ollama_chat.conf
```

Apply all changes listed in `config-diff.md` (in this same package directory).

Summary of what changes:
1. `OllamaChat.Model` = `gemma4:12b`  (was `qwen2.5:14b`)
2. `OllamaChat.NumPredict` = `80`  (was `60`)
3. `OllamaChat.Temperature` = `0.3`  (was `0.4`)
4. `OllamaChat.TopP` = `0.9`  (was `0.95`)
5. `OllamaChat.RepeatPenalty` = `1.15`  (was `1.1`)
6. `OllamaChat.NumCtx` = `8192`  (was `0`)
7. `OllamaChat.MaxConcurrentQueries` = `2`  (was `3`)
8. `OllamaChat.SystemPrompt` — small text fix (see config-diff.md for exact new value)
9. NEW BLOCK after `EnableRPPersonalities = 1`: all the Phase 1/2/3 feature keys
10. `OllamaChat.ChatPromptTemplate` — add `{bot_memory} {bot_journal}` placeholders

See `config-diff.md` for exact values. Do not guess — copy from there.

---

## Step 3 — Rebuild live worldserver image

From the project root:

```powershell
docker compose build ac-worldserver
```

This rebuilds the worldserver binary with the updated mod-ollama-chat C++ code.
Expected duration: 5-15 minutes.

Note: The `ac-worldserver` service in `docker-compose.override.yml` has a `build:` section
pointing to the same `apps/docker/Dockerfile` with `target: worldserver` — same Dockerfile
as PTR. The resulting image is tagged `azerothcore-wotlk-ac-worldserver` locally.

---

## Step 4 — Start live worldserver

```powershell
docker compose up -d ac-worldserver
```

This starts `ac-worldserver-v2` (per override container name) with the new image.
It will run AC's built-in DB updater on startup (for acore_world / acore_auth / acore_characters).
The two new tables were already created in Step 1, so the updater will not re-apply them
(they are not in the `updates` table tracked path for acore_characters — they're module base SQL).

Wait ~30 seconds for the server to finish loading, then check logs:
```powershell
docker logs --tail 50 ac-worldserver-v2
```

Look for: `[mod-ollama-chat]` log lines confirming the module loaded.
Look for: No errors about missing tables or config keys.

---

## Step 5 — Smoke test

1. Log in with a character
2. Whisper any playerbot: `Привет, что делаешь?`
3. Verify a response is received (check `docker logs -f ac-worldserver-v2`)
4. Verify the log shows the model name `gemma4:12b` in the request
5. After 10+ messages with a bot, check memory:
   ```
   docker exec ac-database-v2 mysql -uroot -ppassword acore_characters -e "SELECT * FROM mod_ollama_chat_memory LIMIT 5;"
   ```
6. Check bot journal for named bots (568=Chmone, 566=Lvgrbm):
   ```
   docker exec ac-database-v2 mysql -uroot -ppassword acore_characters -e "SELECT bot_name, LEFT(journal_json,200) FROM mod_ollama_chat_bot_journal;"
   ```

---

## Rollback (if needed)

Only needed if Step 1 (DB apply) caused a problem. Config and code issues are reverted manually.

```powershell
pwsh .claude\agent-memory\live-deployer\packages\2026-06-25_1200-mod-ollama-chat-phase3\rollback.ps1
```

The rollback:
- Prompts for confirmation ("YES")
- Stops ac-worldserver-v2 if running
- Drops and restores acore_characters from `pre-deploy-snapshot.sql.gz`
- Does NOT revert config or image — do those manually

---

## Notes / Warnings

- **Ollama:** No action needed. `gemma4:12b` is already loaded. flash-attention and
  num_parallel are set in `docker-compose.override.yml` (gitignored, already applied).

- **characters.json path:** `/azerothcore/modules/mod-ollama-chat/data/characters.json`
  is valid for both live and PTR containers (same bind-mount path `./modules:/azerothcore/modules`).

- **Guild 24:** Confirmed to exist in live acore_characters (rendered as ???? in terminal
  due to charset display issue, but row confirmed). ExtendedMemoryGuildId = 24 is valid.

- **Characters 566 / 568:** Confirmed: GUID 566 = Lvgrbm, GUID 568 = Chmone.
  ExtendedMemoryBots = 568,566 references GUIDs, which exist on live.

- **manual_only column:** Already present on live from a previous deploy. The guarded ALTER
  in `2025_11_01_personality_manual_only.sql` will be a no-op. Safe.

- **Live server was already down** when this package was prepared. No maintenance window needed
  for the DB step. The server will come back up after Step 4 with the new code + config.
