-- ============================================================================
-- mod-environmental-effects -- spell_dbc rows for all 17 environmental auras
-- DB: acore_world
-- IDs: 107000-107016
--
-- All spells share:
--   Effect_1 = 6  (SPELL_EFFECT_APPLY_AURA)
--   DurationIndex = 21  (permanent -- module removes on zone/weather leave)
--   ProcChance = 101
--   CastingTimeIndex = 1  (instant)
--   RangeIndex = 1  (self-only)
--   ImplicitTargetA_1 = 1  (TARGET_UNIT_CASTER)
--   EffectDieSides_1 = 1  (required alongside EffectBasePoints)
--   EquippedItemClass = -1  (no item req)
--
-- Attributes:
--   BUFF:   0x80000000 = 2147483648  (SPELL_ATTR0_NO_AURA_CANCEL)
--   DEBUFF: 0x84000000 = 2214592512  (NO_AURA_CANCEL | AURA_IS_DEBUFF)
--
-- EffectBasePoints = desired_percent - 1  (DBC convention: value = points + 1)
--   +5 -> 4, -5 -> -6, +3 -> 2, -3 -> -4, +2 -> 1, +10 -> 9
--
-- EffectAura constants (SPELL_AURA_*):
--   MOD_DAMAGE_PERCENT_TAKEN = 87   (debuff: more damage taken from school)
--   MOD_DAMAGE_PERCENT_DONE  = 79   (buff: more/less damage dealt to school)
--   MOD_DECREASE_SPEED       = 33   (debuff speed: negative BasePoints)
--   MOD_INCREASE_SPEED       = 31   (buff speed)
--   MOD_INCREASE_HEALTH_PCT  = 133  (buff max HP%)
--   MOD_HEALTH_REGEN_PERCENT = 88   (buff HP regen%)
--   MOD_POWER_REGEN_PERCENT  = 110  (buff mana regen%)
--   MOD_TOTAL_STAT_PERCENTAGE= 137  (buff all stats%; MiscValue -1 = all)
--
-- School masks (EffectMiscValue_1 for school-based auras):
--   Fire=4, Nature=8, Frost=16, Shadow=32, Arcane=64
--
-- Idempotent: DELETE + REPLACE INTO.
-- ============================================================================

DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 107000 AND 107016;

-- ============================================================================
-- DEBUFFS (Attributes = 2214592512 = 0x84000000)
-- ============================================================================

-- 107000 Иссушающий зной: MOD_DAMAGE_PERCENT_TAKEN, Fire(4), +5%
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107000, 2214592512, 1, 21, 101,
    1, -1,
    6, 87, 4, 1,
    4, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with real fire-heat icon
    'Иссушающий зной', 'Иссушающий зной',
    'Сопротивление огню снижено: вы получаете на 5% больше урона огнём.', 'Сопротивление огню снижено: вы получаете на 5% больше урона огнём.'
);

-- 107001 Ядовитая взвесь: MOD_DAMAGE_PERCENT_TAKEN, Nature(8), +5%
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107001, 2214592512, 1, 21, 101,
    1, -1,
    6, 87, 4, 1,
    8, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with real poison-spore icon
    'Ядовитая взвесь', 'Ядовитая взвесь',
    'Ядовитая пыль разъедает защиту: +5% получаемого урона от природы.', 'Ядовитая пыль разъедает защиту: +5% получаемого урона от природы.'
);

-- 107002 Сильная сырость: MOD_DAMAGE_PERCENT_DONE, Arcane(64), -5%
-- (negative BasePoints makes _IsPositiveEffect return false automatically,
--  but AURA_IS_DEBUFF is set explicitly for safe red-bar display)
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107002, 2214592512, 1, 21, 101,
    1, -1,
    6, 79, -6, 1,
    64, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with muted-arcane/wet icon
    'Сильная сырость', 'Сильная сырость',
    'Влага рассеивает чары: -5% наносимого урона тайной магией.', 'Влага рассеивает чары: -5% наносимого урона тайной магией.'
);

-- 107003 Трупный смрад: MOD_DAMAGE_PERCENT_TAKEN, Shadow(32), +5%
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107003, 2214592512, 1, 21, 101,
    1, -1,
    6, 87, 4, 1,
    32, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with plague-fog icon
    'Трупный смрад', 'Трупный смрад',
    'Чумные испарения ослабляют: +5% получаемого урона от тьмы.', 'Чумные испарения ослабляют: +5% получаемого урона от тьмы.'
);

-- 107004 Промозглый ливень: MOD_DECREASE_SPEED, no school, -3%
-- Note: MOD_DECREASE_SPEED cast on caster is positive by default in AC, but
-- SPELL_ATTR0_AURA_IS_DEBUFF (included in 0x84000000) overrides to debuff.
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107004, 2214592512, 1, 21, 101,
    1, -1,
    6, 33, -4, 1,
    0, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with grey-rain icon
    'Промозглый ливень', 'Промозглый ливень',
    'Намокшая земля сковывает шаг: -3% к скорости передвижения.', 'Намокшая земля сковывает шаг: -3% к скорости передвижения.'
);

-- 107005 Лютая стужа: MOD_DAMAGE_PERCENT_TAKEN, Frost(16), +5%
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107005, 2214592512, 1, 21, 101,
    1, -1,
    6, 87, 4, 1,
    16, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with frost-piercing icon
    'Лютая стужа', 'Лютая стужа',
    'Холод пробирает до костей: +5% получаемого урона от мороза.', 'Холод пробирает до костей: +5% получаемого урона от мороза.'
);

-- 107006 Сильный снегопад: MOD_DECREASE_SPEED, no school, -3%
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107006, 2214592512, 1, 21, 101,
    1, -1,
    6, 33, -4, 1,
    0, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with blizzard-snow icon
    'Сильный снегопад', 'Сильный снегопад',
    'Снежные заносы замедляют: -3% к скорости передвижения.', 'Снежные заносы замедляют: -3% к скорости передвижения.'
);

-- ============================================================================
-- BUFFS (Attributes = 2147483648 = 0x80000000)
-- ============================================================================

-- 107007 Жар недр: MOD_DAMAGE_PERCENT_DONE, Fire(4), +5%
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107007, 2147483648, 1, 21, 101,
    1, -1,
    6, 79, 4, 1,
    4, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with lava-flame icon
    'Жар недр', 'Жар недр',
    'Жар вулканических недр питает пламя: +5% наносимого урона огнём.', 'Жар вулканических недр питает пламя: +5% наносимого урона огнём.'
);

-- 107008 Эхо Высокорождённых: MOD_DAMAGE_PERCENT_DONE, Arcane(64), +5%
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107008, 2147483648, 1, 21, 101,
    1, -1,
    6, 79, 4, 1,
    64, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with arcane-rune icon
    'Эхо Высокорождённых', 'Эхо Высокорождённых',
    'Древняя тайная сила усиливает чары: +5% наносимого урона тайной магией.', 'Древняя тайная сила усиливает чары: +5% наносимого урона тайной магией.'
);

-- 107009 Скверная порча: MOD_DAMAGE_PERCENT_DONE, Shadow(32), +5%
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107009, 2147483648, 1, 21, 101,
    1, -1,
    6, 79, 4, 1,
    32, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with fel-corruption icon
    'Скверная порча', 'Скверная порча',
    'Скверна питает тёмную магию: +5% наносимого урона тенью.', 'Скверна питает тёмную магию: +5% наносимого урона тенью.'
);

-- 107010 Дыхание грозы: MOD_DAMAGE_PERCENT_DONE, Nature(8), +5%
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107010, 2147483648, 1, 21, 101,
    1, -1,
    6, 79, 4, 1,
    8, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with storm-lightning icon
    'Дыхание грозы', 'Дыхание грозы',
    'Грозовая энергия усиливает: +5% наносимого урона силами природы.', 'Грозовая энергия усиливает: +5% наносимого урона силами природы.'
);

-- 107011 Объятия вечной зимы: MOD_DAMAGE_PERCENT_DONE, Frost(16), +5%
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107011, 2147483648, 1, 21, 101,
    1, -1,
    6, 79, 4, 1,
    16, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with eternal-frost icon
    'Объятия вечной зимы', 'Объятия вечной зимы',
    'Вечный холод усиливает мороз: +5% наносимого урона морозом.', 'Вечный холод усиливает мороз: +5% наносимого урона морозом.'
);

-- 107012 Первородная мощь: MOD_INCREASE_HEALTH_PERCENT, no school, +3%
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107012, 2147483648, 1, 21, 101,
    1, -1,
    6, 133, 2, 1,
    0, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with earth-crystal icon
    'Первородная мощь', 'Первородная мощь',
    'Первозданная сила земли: +3% к максимальному запасу здоровья.', 'Первозданная сила земли: +3% к максимальному запасу здоровья.'
);

-- 107013 Вольные ветра: MOD_INCREASE_SPEED, no school, +5%
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107013, 2147483648, 1, 21, 101,
    1, -1,
    6, 31, 4, 1,
    0, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with wind-speed icon
    'Вольные ветра', 'Вольные ветра',
    'Открытые просторы придают прыти: +5% к скорости передвижения.', 'Открытые просторы придают прыти: +5% к скорости передвижения.'
);

-- 107014 Лесное благословение: Effect_1=MOD_HEALTH_REGEN_PERCENT +10,
--                               Effect_2=MOD_POWER_REGEN_PERCENT +10
-- Two effects on one spell. ImplicitTargetA for both = 1 (self).
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `Effect_2`, `EffectAura_2`, `EffectBasePoints_2`, `EffectDieSides_2`,
    `EffectMiscValue_2`, `ImplicitTargetA_2`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107014, 2147483648, 1, 21, 101,
    1, -1,
    6, 88, 9, 1,
    0, 1,
    6, 110, 9, 1,
    0, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with leaf-nature-regen icon
    'Лесное благословение', 'Лесное благословение',
    'Покой природы восстанавливает силы: ускоренное восстановление здоровья и маны.', 'Покой природы восстанавливает силы: ускоренное восстановление здоровья и маны.'
);

-- 107015 Сила дикой чащи: MOD_TOTAL_STAT_PERCENTAGE, all stats (-1), +2%
-- MiscValue = -1 targets all stats simultaneously.
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107015, 2147483648, 1, 21, 101,
    1, -1,
    6, 137, 1, 1,
    -1, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with wild-claw icon
    'Сила дикой чащи', 'Сила дикой чащи',
    'Дикая мощь чащи: +2% ко всем характеристикам.', 'Дикая мощь чащи: +2% ко всем характеристикам.'
);

-- 107016 Воля Плети: MOD_DAMAGE_PERCENT_TAKEN, Shadow(32), +5% (debuff, zonal)
REPLACE INTO `spell_dbc` (
    `ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `ProcChance`,
    `RangeIndex`, `EquippedItemClass`,
    `Effect_1`, `EffectAura_1`, `EffectBasePoints_1`, `EffectDieSides_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `SpellIconID`,
    `Name_Lang_enUS`, `Name_Lang_ruRU`,
    `Description_Lang_enUS`, `Description_Lang_ruRU`
) VALUES (
    107016, 2214592512, 1, 21, 101,
    1, -1,
    6, 87, 4, 1,
    32, 1,
    1, 1, -- PLACEHOLDER icon: replace SpellIconID=1 with Lich-King-skull icon
    'Воля Плети', 'Воля Плети',
    'Тлетворная воля Плети давит на живых: +5% получаемого урона от тьмы.', 'Тлетворная воля Плети давит на живых: +5% получаемого урона от тьмы.'
);
