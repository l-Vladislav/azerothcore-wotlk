-- ============================================================================
-- mod-environmental-effects -- rule table creation and seed data
-- Module: mod-environmental-effects (custom)
-- DB:     acore_world
--
-- Creates the rule table that the module's loader queries on startup.
-- Each row describes one (zone, area, weather_state) -> spell_id binding.
-- The module skips rows whose spell_id is not present in the spell store,
-- so seeding spells 107000 and 107001 here is safe even though those spell
-- entries do not exist yet; they will be created in a later DBC phase.
--
-- Idempotency: the CREATE TABLE uses IF NOT EXISTS; seed rows are preceded
-- by a DELETE on the four explicit IDs, so re-running this file is safe.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Create rule table
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `mod_environmental_effects` (
    `id`               INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    `zone_id`          INT UNSIGNED     NOT NULL DEFAULT 0     COMMENT '0 = any zone',
    `area_id`          INT UNSIGNED     NOT NULL DEFAULT 0     COMMENT '0 = any sub-area',
    `weather_state`    INT UNSIGNED     NOT NULL DEFAULT 255   COMMENT 'WeatherState enum; 255 = ANY',
    `spell_id`         INT UNSIGNED     NOT NULL               COMMENT 'Aura applied while condition holds',
    `faction_mask`     TINYINT UNSIGNED NOT NULL DEFAULT 0     COMMENT '0 = both, 1 = Alliance, 2 = Horde',
    `require_outdoors` TINYINT UNSIGNED NOT NULL DEFAULT 1     COMMENT '1 = outdoors only',
    `enabled`          TINYINT UNSIGNED NOT NULL DEFAULT 1     COMMENT '1 = active',
    `comment`          VARCHAR(255)     NOT NULL DEFAULT ''    COMMENT 'Human-readable note',
    PRIMARY KEY (`id`),
    KEY `idx_zone` (`zone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='mod-environmental-effects rule table';

-- ----------------------------------------------------------------------------
-- STEP 2: Seed rows (idempotent -- delete by explicit ID before re-inserting)
-- ----------------------------------------------------------------------------
DELETE FROM `mod_environmental_effects` WHERE `id` IN (1, 2, 3, 4);

INSERT INTO `mod_environmental_effects`
    (`id`, `zone_id`, `area_id`, `weather_state`, `spell_id`, `faction_mask`, `require_outdoors`, `enabled`, `comment`)
VALUES
    (1, 440, 0, 41, 107000, 0, 1, 1, 'Tanaris sandstorm: Fire resist -5%'),
    (2, 440, 0, 42, 107000, 0, 1, 1, 'Tanaris sandstorm: Fire resist -5%'),
    (3, 490, 0,  4, 107001, 0, 1, 1, 'Ungoro rain: Arcane -5%'),
    (4, 490, 0,  5, 107001, 0, 1, 1, 'Ungoro rain: Arcane -5%');
