"""Reader for the client DBC files the worldserver itself loads.

The panel already had two sources of spell knowledge and neither can answer
"show me every spell": `spell_dbc` in the game database holds only custom rows
and module overrides, and `.claude/dbc/Spell.csv` is a hand-made export whose
locale columns are mislabelled. The authoritative set is the binary
`data/dbc/Spell.dbc` inside the client-data volume — 49 839 records, the exact
bytes the server reads at startup.

WDBC is a fixed-width format, so nothing is parsed up front: the file is
mmap'd and a record's field is unpacked on demand. That keeps a 49 MB
Spell.dbc usable inside a small container — only the pages actually touched
are read.

Layout notes that cost time if rediscovered:

  * a "field" is always 4 bytes. A uint64 column (Spell's shapeshift masks)
    occupies two of them, which is why the file has 234 fields where the
    column list has 232 names.
  * a localized string is 17 fields: 16 offsets into the string block plus a
    mask. In 3.3.5a the used slots are enUS 0, koKR 1, frFR 2, deDE 3,
    zhCN 4, zhTW 5, esES 6, esMX 7, **ruRU 8** — the Russian client fills slot
    8 and leaves 0 empty, which is exactly the "ruRU = enUS + 8" offset the
    CSV exporters run into.
"""

import mmap
import os
import struct
from typing import Iterator

MAGIC = b"WDBC"
HEADER = struct.Struct("<4sIIII")
FIELD = 4

LOCALE_SLOTS = 16
LOCALE_FIELDS = LOCALE_SLOTS + 1     # + the "which slots are set" mask
LOCALE_ENUS = 0
LOCALE_RURU = 8


class DBCError(RuntimeError):
    pass


class Column:
    """One named column: where it starts, how wide it is, how to read it."""

    __slots__ = ("name", "kind", "index", "fields")

    def __init__(self, name: str, kind: str, index: int, fields: int):
        self.name = name
        self.kind = kind          # i | u | f | s | u64 | loc
        self.index = index        # first field index
        self.fields = fields      # fields consumed


def layout(spec: list[tuple]) -> list[Column]:
    """Expand `(name, kind[, count])` triples into indexed columns.

    A count > 1 produces `Name_1 … Name_n`, matching how the same columns are
    named in `spell_dbc`, so a value read here can be compared with the
    database row without a translation table.
    """
    cols: list[Column] = []
    index = 0
    for entry in spec:
        name, kind = entry[0], entry[1]
        count = entry[2] if len(entry) > 2 else 1
        width = {"u64": 2, "loc": LOCALE_FIELDS}.get(kind, 1)
        for n in range(count):
            label = name if count == 1 else "%s_%d" % (name, n + 1)
            cols.append(Column(label, kind, index, width))
            index += width
    return cols


class DBC:
    """One .dbc file: header, records by index or id, string block by offset."""

    def __init__(self, path: str, columns: list[Column]):
        self.path = path
        self.columns = columns
        self.by_name = {c.name: c for c in columns}

        self._file = open(path, "rb")
        self._map = mmap.mmap(self._file.fileno(), 0, access=mmap.ACCESS_READ)

        magic, self.count, self.field_count, self.record_size, self.string_size = \
            HEADER.unpack(self._map[:HEADER.size])
        if magic != MAGIC:
            raise DBCError("%s: not a WDBC file (magic %r)" % (path, magic))
        if self.record_size != self.field_count * FIELD:
            raise DBCError("%s: record size %d is not %d fields"
                           % (path, self.record_size, self.field_count))

        expected = sum(c.fields for c in columns[-1:]) + \
            (columns[-1].index if columns else 0)
        if columns and expected != self.field_count:
            raise DBCError("%s: layout describes %d fields, file has %d"
                           % (path, expected, self.field_count))

        self._data = HEADER.size
        self._strings = self._data + self.count * self.record_size
        self._index: dict[int, int] | None = None

    # --- raw access -------------------------------------------------------

    def _offset(self, row: int, field: int) -> int:
        return self._data + row * self.record_size + field * FIELD

    def int_at(self, row: int, field: int) -> int:
        at = self._offset(row, field)
        return struct.unpack_from("<i", self._map, at)[0]

    def uint_at(self, row: int, field: int) -> int:
        at = self._offset(row, field)
        return struct.unpack_from("<I", self._map, at)[0]

    def float_at(self, row: int, field: int) -> float:
        at = self._offset(row, field)
        return struct.unpack_from("<f", self._map, at)[0]

    def string_at(self, offset: int) -> str:
        """Read a NUL-terminated UTF-8 string out of the string block."""
        if offset <= 0 or offset >= self.string_size:
            return ""
        start = self._strings + offset
        end = self._map.find(b"\0", start)
        if end < 0:
            return ""
        return self._map[start:end].decode("utf-8", "replace")

    # --- column access ----------------------------------------------------

    def value(self, row: int, name: str, locale: int = LOCALE_RURU):
        col = self.by_name.get(name)
        if col is None:
            raise KeyError(name)
        if col.kind == "f":
            return self.float_at(row, col.index)
        if col.kind == "u":
            return self.uint_at(row, col.index)
        if col.kind == "u64":
            lo = self.uint_at(row, col.index)
            hi = self.uint_at(row, col.index + 1)
            return (hi << 32) | lo
        if col.kind == "s":
            return self.string_at(self.uint_at(row, col.index))
        if col.kind == "loc":
            text = self.string_at(self.uint_at(row, col.index + locale))
            if not text and locale != LOCALE_ENUS:
                text = self.string_at(self.uint_at(row, col.index + LOCALE_ENUS))
            return text
        return self.int_at(row, col.index)

    def row_dict(self, row: int, locale: int = LOCALE_RURU) -> dict:
        return {c.name: self.value(row, c.name, locale) for c in self.columns}

    # --- id lookup --------------------------------------------------------

    @property
    def index(self) -> dict[int, int]:
        """id → row. Built once, on first use."""
        if self._index is None:
            self._index = {self.int_at(row, 0): row for row in range(self.count)}
        return self._index

    def row_of(self, entry_id: int) -> int | None:
        return self.index.get(entry_id)

    def ids(self) -> Iterator[int]:
        for row in range(self.count):
            yield self.int_at(row, 0)

    def close(self) -> None:
        self._map.close()
        self._file.close()


def open_dbc(directory: str, name: str, columns: list[Column]) -> DBC | None:
    """Open `<directory>/<name>.dbc`, or None when the volume is not mounted.

    Missing reference files degrade the catalogue (an index shows as a raw
    number instead of "8 сек") but must never take the panel down.
    """
    path = os.path.join(directory, name + ".dbc")
    if not os.path.isfile(path):
        return None
    try:
        return DBC(path, columns)
    except (OSError, DBCError):
        return None


# --- layouts --------------------------------------------------------------
# Spell.dbc, WotLK 3.3.5a (12340): 234 fields. Names match the `spell_dbc`
# columns wherever the same value exists there.

SPELL_COLUMNS = layout([
    ("ID", "i"),
    ("Category", "i"),
    ("DispelType", "i"),
    ("Mechanic", "i"),
    ("Attributes", "u"),
    ("AttributesEx", "u"),
    ("AttributesEx2", "u"),
    ("AttributesEx3", "u"),
    ("AttributesEx4", "u"),
    ("AttributesEx5", "u"),
    ("AttributesEx6", "u"),
    ("AttributesEx7", "u"),
    ("ShapeshiftMask", "u64"),
    ("ShapeshiftExclude", "u64"),
    ("Targets", "u"),
    ("TargetCreatureType", "u"),
    ("RequiresSpellFocus", "i"),
    ("FacingCasterFlags", "u"),
    ("CasterAuraState", "i"),
    ("TargetAuraState", "i"),
    ("ExcludeCasterAuraState", "i"),
    ("ExcludeTargetAuraState", "i"),
    ("CasterAuraSpell", "i"),
    ("TargetAuraSpell", "i"),
    ("ExcludeCasterAuraSpell", "i"),
    ("ExcludeTargetAuraSpell", "i"),
    ("CastingTimeIndex", "i"),
    ("RecoveryTime", "i"),
    ("CategoryRecoveryTime", "i"),
    ("InterruptFlags", "u"),
    ("AuraInterruptFlags", "u"),
    ("ChannelInterruptFlags", "u"),
    ("ProcTypeMask", "u"),
    ("ProcChance", "i"),
    ("ProcCharges", "i"),
    ("MaxLevel", "i"),
    ("BaseLevel", "i"),
    ("SpellLevel", "i"),
    ("DurationIndex", "i"),
    ("PowerType", "i"),
    ("ManaCost", "i"),
    ("ManaCostPerLevel", "i"),
    ("ManaPerSecond", "i"),
    ("ManaPerSecondPerLevel", "i"),
    ("RangeIndex", "i"),
    ("Speed", "f"),
    ("ModalNextSpell", "i"),
    ("CumulativeAura", "i"),
    ("Totem", "i", 2),
    ("Reagent", "i", 8),
    ("ReagentCount", "i", 8),
    ("EquippedItemClass", "i"),
    ("EquippedItemSubclass", "i"),
    ("EquippedItemInvTypes", "i"),
    ("Effect", "i", 3),
    ("EffectDieSides", "i", 3),
    ("EffectRealPointsPerLevel", "f", 3),
    ("EffectBasePoints", "i", 3),
    ("EffectMechanic", "i", 3),
    ("ImplicitTargetA", "i", 3),
    ("ImplicitTargetB", "i", 3),
    ("EffectRadiusIndex", "i", 3),
    ("EffectAura", "i", 3),
    ("EffectAuraPeriod", "i", 3),
    ("EffectMultipleValue", "f", 3),
    ("EffectChainTargets", "i", 3),
    ("EffectItemType", "i", 3),
    ("EffectMiscValue", "i", 3),
    ("EffectMiscValueB", "i", 3),
    ("EffectTriggerSpell", "i", 3),
    ("EffectPointsPerCombo", "f", 3),
    ("EffectSpellClassMaskA", "u", 3),
    ("EffectSpellClassMaskB", "u", 3),
    ("EffectSpellClassMaskC", "u", 3),
    ("SpellVisualID", "i", 2),
    ("SpellIconID", "i"),
    ("ActiveIconID", "i"),
    ("SpellPriority", "i"),
    ("Name", "loc"),
    ("NameSubtext", "loc"),
    ("Description", "loc"),
    ("AuraDescription", "loc"),
    ("ManaCostPct", "i"),
    ("StartRecoveryCategory", "i"),
    ("StartRecoveryTime", "i"),
    ("MaxTargetLevel", "i"),
    ("SpellClassSet", "i"),
    ("SpellClassMask", "u", 3),
    ("MaxTargets", "i"),
    ("DefenseType", "i"),
    ("PreventionType", "i"),
    ("StanceBarOrder", "i"),
    ("EffectChainAmplitude", "f", 3),
    ("MinFactionID", "i"),
    ("MinReputation", "i"),
    ("RequiredAuraVision", "i"),
    ("TotemCategory", "i", 2),
    ("RequiredAreasID", "i"),
    ("SchoolMask", "u"),
    ("RuneCostID", "i"),
    ("SpellMissileID", "i"),
    ("PowerDisplayID", "i"),
    ("EffectBonusMultiplier", "f", 3),
    ("SpellDescriptionVariableID", "i"),
    ("SpellDifficultyID", "i"),
])

SPELL_ICON_COLUMNS = layout([("ID", "i"), ("TextureFilename", "s")])

# ItemDisplayInfo.dbc, 3.3.5a: 25 полей. Каталогу предметов нужна из них ровно
# одна колонка - InventoryIcon_1, имя текстуры иконки; остальные перечислены,
# потому что смещения считаются по порядку и пропустить их нельзя.
ITEM_DISPLAY_INFO_COLUMNS = layout([
    ("ID", "i"),
    ("ModelName", "s", 2),
    ("ModelTexture", "s", 2),
    ("InventoryIcon", "s", 2),
    ("GeosetGroup", "i", 3),
    ("Flags", "i"),
    ("SpellVisualID", "i"),
    ("GroupSoundIndex", "i"),
    ("HelmetGeosetVis", "i", 2),
    ("Texture", "s", 8),
    ("ItemVisual", "i"),
    ("ParticleColorID", "i"),
])

# Item.dbc, 3.3.5a: 8 полей. Клиентская половина предмета - трёхмерный вид,
# ножны и материал. Тултип и иконку клиент спрашивает у сервера, а это - нет.
ITEM_COLUMNS = layout([
    ("ID", "i"),
    ("ClassID", "i"),
    ("SubclassID", "i"),
    ("Sound_Override_Subclassid", "i"),
    ("Material", "i"),
    ("DisplayInfoID", "i"),
    ("InventoryType", "i"),
    ("SheatheType", "i"),
])

SPELL_DURATION_COLUMNS = layout([
    ("ID", "i"), ("Duration", "i"), ("DurationPerLevel", "i"),
    ("MaxDuration", "i"),
])

SPELL_RANGE_COLUMNS = layout([
    ("ID", "i"), ("RangeMin_1", "f"), ("RangeMin_2", "f"),
    ("RangeMax_1", "f"), ("RangeMax_2", "f"), ("Flags", "i"),
    ("DisplayName", "loc"), ("DisplayNameShort", "loc"),
])

SPELL_CAST_TIMES_COLUMNS = layout([
    ("ID", "i"), ("Base", "i"), ("PerLevel", "i"), ("Minimum", "i"),
])

SPELL_RADIUS_COLUMNS = layout([
    ("ID", "i"), ("Radius", "f"), ("RadiusPerLevel", "f"), ("RadiusMax", "f"),
])

SPELL_CATEGORY_COLUMNS = layout([("ID", "i"), ("Flags", "i")])

SKILL_LINE_COLUMNS = layout([
    ("ID", "i"), ("CategoryID", "i"), ("SkillCostsID", "i"),
    ("DisplayName", "loc"), ("Description", "loc"), ("SpellIconID", "i"),
    ("AlternateVerb", "loc"), ("CanLink", "i"),
])

SKILL_LINE_ABILITY_COLUMNS = layout([
    ("ID", "i"), ("SkillLine", "i"), ("Spell", "i"), ("RaceMask", "i"),
    ("ClassMask", "i"), ("ExcludeRace", "i"), ("ExcludeClass", "i"),
    ("MinSkillLineRank", "i"), ("SupercededBySpell", "i"),
    ("AcquireMethod", "i"), ("TrivialSkillLineRankHigh", "i"),
    ("TrivialSkillLineRankLow", "i"), ("CharacterPoints_1", "i"),
    ("CharacterPoints_2", "i"),
])
