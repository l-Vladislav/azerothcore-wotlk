-- ============================================================================
-- mod-ollama-chat: bot daily journal table.
-- Stores a large JSON document (keyed by date) representing the personal
-- bot's daily journal entries. One row per bot, keyed by bot_name (stable
-- across wipes, matches the config addressing scheme).
-- journal_json: arbitrary JSON with day-partitioned Russian text; LONGTEXT to
--   accommodate unbounded growth over many days.
-- updated_at: auto-updated on every REPLACE/UPDATE — no manual touch needed.
-- Charset/collation matches all other mod_ollama_chat_* tables:
--   ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
-- Idempotent: CREATE TABLE IF NOT EXISTS; safe to re-apply.
-- Targets: acore_characters / acore_characters_ptr (DB-agnostic).
-- Companion C++: mod-ollama-chat bot journal subsystem.
-- ============================================================================

CREATE TABLE IF NOT EXISTS `mod_ollama_chat_bot_journal` (
  `bot_name`     VARCHAR(64) NOT NULL,
  `journal_json` LONGTEXT NOT NULL,
  `updated_at`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`bot_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
