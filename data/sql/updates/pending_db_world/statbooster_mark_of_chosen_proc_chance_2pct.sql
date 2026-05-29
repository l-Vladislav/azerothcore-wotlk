-- StatBooster — production tune for Mark of the Chosen wrapper (100037)
-- Changes ProcChance from 100 (testing) → 2 (matches original vanilla trinket 17774 rate).
-- Vanilla spell 21969 already at 2% via binary DBC (no override in spell_dbc / spell_proc).

UPDATE `spell_dbc` SET `ProcChance` = 2 WHERE `ID` = 100037;
