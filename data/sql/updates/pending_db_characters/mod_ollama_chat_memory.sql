-- ============================================================================
-- mod-ollama-chat Phase 3: long-term memory table.
-- Stores a compact per-(bot, player) summary text written by the LLM so the
-- bot can recall context across sessions without loading the full history.
-- memory_blob: free-form Russian text, up to ~65 KB (TEXT).
-- updated_at: auto-updated on every REPLACE/UPDATE — no manual touch needed.
-- Charset/collation matches all other mod_ollama_chat_* tables:
--   ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
-- Idempotent: CREATE TABLE IF NOT EXISTS; safe to re-apply.
-- Companion C++: mod-ollama-chat memory subsystem (Phase 3).
-- ============================================================================

CREATE TABLE IF NOT EXISTS `mod_ollama_chat_memory` (
  `bot_guid`    BIGINT UNSIGNED NOT NULL,
  `player_guid` BIGINT UNSIGNED NOT NULL,
  `memory_blob` TEXT NOT NULL,
  `updated_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`bot_guid`, `player_guid`),
  INDEX `idx_player_guid` (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
