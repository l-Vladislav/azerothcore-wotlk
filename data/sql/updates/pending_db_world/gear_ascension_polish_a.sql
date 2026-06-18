-- ============================================================================
-- mod-gear-ascension -- Polish Pass A
-- Part A3: spell_dbc update for 105000 (2s cast, SCRIPT_EFFECT) + spell_script_names
-- PTR ONLY (acore_world_ptr). Idempotent.
-- Generated 2026-06-18 by gear-ascension-dev agent.
-- ============================================================================

-- Part A3: Update spell 105000 from instant + DISENCHANT to 2s cast + SCRIPT_EFFECT.
-- CastingTimeIndex=5 = 2000ms (same as Holy Fire 15262, Regrowth 8936).
-- Effect_1=77 = SPELL_EFFECT_SCRIPT_EFFECT (was 99 = SPELL_EFFECT_DISENCHANT).
-- spell_script_names links to SpellScript 'spell_gear_ascension_apply_kit'.
UPDATE spell_dbc
SET
    CastingTimeIndex = 5,
    Effect_1         = 77
WHERE id = 105000;

-- Register the SpellScript for spell 105000 (fired at cast completion).
DELETE FROM spell_script_names WHERE spell_id = 105000;
INSERT INTO spell_script_names (spell_id, ScriptName)
VALUES (105000, 'spell_gear_ascension_apply_kit');
