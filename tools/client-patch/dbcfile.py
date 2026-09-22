"""Чтение, правка и запись бинарных DBC (формат WDBC, 3.3.5a).

Главное свойство, ради которого всё написано именно так: запись без правок
обязана дать байт в байт тот же файл. Поэтому записи и блок строк хранятся
сырыми, а не разбираются в питоновские объекты; правка трогает ровно те
четыре байта, которые изменились.

Второе свойство: одинаковый текст всегда получает один и тот же оффсет в
блоке строк. Индекс блока строится один раз при загрузке, и повторное
применение того же оверлея не растит файл и не меняет sha256 - иначе
лаунчер гонял бы игрокам «обновление», в котором ничего не поменялось.
"""

import struct

MAGIC = b"WDBC"
HEADER = struct.Struct("<4sIIII")
FIELD = 4


class DbcError(RuntimeError):
    pass


class Dbc:
    def __init__(self, blob, table=None, path="<память>"):
        self.path = path
        self.table = table
        magic, count, field_count, record_size, string_size = \
            HEADER.unpack_from(blob, 0)
        if magic != MAGIC:
            raise DbcError("%s: не WDBC (сигнатура %r)" % (path, magic))
        if record_size != field_count * FIELD:
            raise DbcError("%s: запись %d байт при %d полях"
                           % (path, record_size, field_count))
        if table is not None and table.field_count != field_count:
            raise DbcError(
                "%s: в файле %d полей, а определение %s описывает %d - "
                "раскладка не подходит, оверлей применять нельзя"
                % (path, field_count, table.name, table.field_count))

        self.field_count = field_count
        self.record_size = record_size
        data_at = HEADER.size
        strings_at = data_at + count * record_size
        self.records = bytearray(blob[data_at:strings_at])
        self.strings = bytearray(blob[strings_at:strings_at + string_size])
        if not self.strings:
            self.strings = bytearray(b"\0")

        self._id_index = None
        self._str_index = None

    # --- загрузка ---------------------------------------------------------

    @classmethod
    def load(cls, path, table=None):
        with open(path, "rb") as handle:
            return cls(handle.read(), table, path)

    def save(self, path):
        with open(path, "wb") as handle:
            handle.write(self.to_bytes())

    def to_bytes(self):
        head = HEADER.pack(MAGIC, self.count, self.field_count,
                           self.record_size, len(self.strings))
        return bytes(head) + bytes(self.records) + bytes(self.strings)

    # --- записи -----------------------------------------------------------

    @property
    def count(self):
        return len(self.records) // self.record_size

    def record(self, row):
        at = row * self.record_size
        return bytes(self.records[at:at + self.record_size])

    def set_record(self, row, blob):
        if len(blob) != self.record_size:
            raise DbcError("запись %d байт вместо %d"
                           % (len(blob), self.record_size))
        at = row * self.record_size
        self.records[at:at + self.record_size] = blob

    def append_record(self, blob):
        if len(blob) != self.record_size:
            raise DbcError("запись %d байт вместо %d"
                           % (len(blob), self.record_size))
        row = self.count
        self.records += blob
        if self._id_index is not None:
            self._id_index[self.id_at(row)] = row
        return row

    def id_at(self, row):
        return struct.unpack_from("<i", self.records,
                                  row * self.record_size)[0]

    @property
    def ids(self):
        if self._id_index is None:
            self._id_index = {self.id_at(row): row
                              for row in range(self.count)}
        return self._id_index

    def row_of(self, entry_id):
        return self.ids.get(entry_id)

    # --- строки -----------------------------------------------------------

    def string_at(self, offset):
        if offset <= 0 or offset >= len(self.strings):
            return ""
        end = self.strings.find(b"\0", offset)
        if end < 0:
            end = len(self.strings)
        return self.strings[offset:end].decode("utf-8", "replace")

    def _strings_index(self):
        if self._str_index is None:
            index = {}
            at = 0
            blob = self.strings
            while at < len(blob):
                end = blob.find(b"\0", at)
                if end < 0:
                    end = len(blob)
                text = blob[at:end].decode("utf-8", "replace")
                index.setdefault(text, at)
                at = end + 1
            index[""] = 0
            self._str_index = index
        return self._str_index

    def string_offset(self, text):
        """Оффсет текста: старый, если он уже в блоке, иначе новый."""
        if not text:
            return 0
        index = self._strings_index()
        found = index.get(text)
        if found is not None:
            return found
        offset = len(self.strings)
        self.strings += text.encode("utf-8") + b"\0"
        index[text] = offset
        return offset


# --- сборка записи из значений колонок ------------------------------------

def pack_record(dbc, values, base=None):
    """values: {имя колонки: значение из CSV} -> байты записи.

    Колонки, которых в values нет, берутся из base - записи, которая уже
    лежит в файле. Поэтому оверлей может состоять из столбца ID плюс тех
    полей, что реально меняются, и остальные 230 колонок Spell.dbc трогать
    не нужно. Для новой записи base = None, и незаданное поле - ноль.
    """
    table = dbc.table
    if table is None:
        raise DbcError("нет раскладки: нечем разложить значения по полям")
    blob = bytearray(base if base is not None else dbc.record_size)
    for col in table.columns:
        if col.name not in values:
            continue
        raw = values.get(col.name, "")
        at = col.field * FIELD
        if col.type in ("string", "locslot"):
            struct.pack_into("<I", blob, at,
                             dbc.string_offset((raw or "").strip()))
        elif col.type == "float":
            struct.pack_into("<f", blob, at, _as_float(raw))
        elif col.type == "ulong":
            struct.pack_into("<Q", blob, at,
                             _as_int(raw) & 0xFFFFFFFFFFFFFFFF)
        elif col.type == "uint":
            struct.pack_into("<I", blob, at, _as_int(raw) & 0xFFFFFFFF)
        else:
            struct.pack_into("<i", blob, at,
                             _as_signed(_as_int(raw) & 0xFFFFFFFF))
    return bytes(blob)


def _as_int(raw):
    raw = (raw or "").strip()
    if not raw:
        return 0
    try:
        return int(raw)
    except ValueError:
        return int(float(raw))


def _as_float(raw):
    raw = (raw or "").strip()
    if not raw:
        return 0.0
    return float(raw)


def _as_signed(value):
    return value - 0x100000000 if value >= 0x80000000 else value


def describe_record(dbc, blob):
    """Значения записи как словарь колонок - для отчёта о различиях."""
    out = {}
    for col in dbc.table.columns:
        at = col.field * FIELD
        if col.type in ("string", "locslot"):
            out[col.name] = dbc.string_at(
                struct.unpack_from("<I", blob, at)[0])
        elif col.type == "float":
            out[col.name] = struct.unpack_from("<f", blob, at)[0]
        elif col.type == "ulong":
            out[col.name] = struct.unpack_from("<Q", blob, at)[0]
        elif col.type == "uint":
            out[col.name] = struct.unpack_from("<I", blob, at)[0]
        else:
            out[col.name] = struct.unpack_from("<i", blob, at)[0]
    return out
