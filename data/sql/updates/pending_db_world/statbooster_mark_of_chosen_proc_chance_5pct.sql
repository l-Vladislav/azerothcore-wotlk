-- StatBooster — bump Mark of the Chosen wrapper (100037) from 2% to 5%
-- Vanilla spell 21969 stays untouched at its native 2% (no override in spell_dbc / spell_proc).

UPDATE `spell_dbc` SET `ProcChance` = 5 WHERE `ID` = 100037;
