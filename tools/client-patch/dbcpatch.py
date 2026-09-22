"""Дельта между двумя версиями одного .dbc - формат DBCP1.

Зачем свой формат, а не bsdiff. Сборщик и так знает, что поменялось: он
сам правил записи. Считать бинарный дифф общего вида незачем, а применять
его в лаунчере пришлось бы отдельной библиотекой. DBC - записи постоянной
длины плюс блок строк, поэтому дельта это «перезаписать вот эти строки по
номерам» и «дописать вот такой хвост в блок строк». Применение - полсотни
строк кода на любом языке, и никаких зависимостей у лаунчера.

Раскладка файла, всё little-endian:

    0    4   "DBCP"
    4    4   версия = 1
    8    4   fieldCount        - должен совпасть с исходным файлом
    12   4   recordSize        - тоже
    16   4   oldCount          - записей в исходном файле
    20   4   newCount          - записей в результате
    24   4   stringPrefixLen   - сколько байт старого блока строк оставить
    28   4   stringTailLen     - сколько байт дописать после них
    32   4   writeCount        - сколько записей перезаписывается
    36   32  fromSha256        - sha256 исходного файла целиком
    68   32  toSha256          - sha256 результата целиком
    100  ..  хвост блока строк (stringTailLen байт)
         ..  writeCount раз: номер записи (4 байта) + сама запись

Блок строк почти всегда только растёт: сборщик переиспользует оффсеты уже
имеющихся строк и дописывает новые в конец. Тогда stringPrefixLen равен
длине старого блока, а хвост - несколько десятков байт. Но если оверлей
убрали, а другой добавили, конец блока может отличаться - формат это
переживает: prefixLen становится длиной общего начала, а в хвост уезжает
остаток. Всё равно это единицы килобайт, а не сорок мегабайт.
"""

import hashlib
import struct

MAGIC = b"DBCP"
VERSION = 1
HEADER = struct.Struct("<4sIIIIIIII32s32s")
DBC_HEADER = struct.Struct("<4sIIII")


class PatchError(RuntimeError):
    pass


def _split(blob):
    """Разобрать .dbc на (fieldCount, recordSize, записи, блок строк)."""
    magic, count, field_count, record_size, string_size = \
        DBC_HEADER.unpack_from(blob, 0)
    if magic != b"WDBC":
        raise PatchError("не WDBC: %r" % magic)
    data_at = DBC_HEADER.size
    strings_at = data_at + count * record_size
    return (field_count, record_size,
            blob[data_at:strings_at],
            blob[strings_at:strings_at + string_size])


def _common_prefix(a, b):
    limit = min(len(a), len(b))
    step = 1 << 16
    at = 0
    while at < limit:
        end = min(at + step, limit)
        if a[at:end] != b[at:end]:
            break
        at = end
    while at < limit and a[at] == b[at]:
        at += 1
    return at


def make(old_blob, new_blob):
    """Дельта old -> new. None, если дельта не имеет смысла."""
    old_fields, old_size, old_records, old_strings = _split(old_blob)
    new_fields, new_size, new_records, new_strings = _split(new_blob)
    if old_fields != new_fields or old_size != new_size:
        return None            # раскладка сменилась - только файл целиком

    old_count = len(old_records) // old_size
    new_count = len(new_records) // new_size

    writes = []
    for row in range(new_count):
        at = row * new_size
        chunk = new_records[at:at + new_size]
        if row < old_count and old_records[at:at + old_size] == chunk:
            continue
        writes.append((row, chunk))

    prefix = _common_prefix(old_strings, new_strings)
    tail = new_strings[prefix:]

    payload = bytearray()
    payload += tail
    for row, chunk in writes:
        payload += struct.pack("<I", row)
        payload += chunk

    head = HEADER.pack(MAGIC, VERSION, new_fields, new_size, old_count,
                       new_count, prefix, len(tail), len(writes),
                       hashlib.sha256(old_blob).digest(),
                       hashlib.sha256(new_blob).digest())
    return bytes(head) + bytes(payload)


def apply(old_blob, patch_blob):
    """Применить дельту. Проверяет sha и на входе, и на выходе."""
    if len(patch_blob) < HEADER.size:
        raise PatchError("дельта короче заголовка")
    (magic, version, field_count, record_size, old_count, new_count,
     prefix, tail_len, write_count, from_sha, to_sha) = \
        HEADER.unpack_from(patch_blob, 0)
    if magic != MAGIC:
        raise PatchError("не DBCP: %r" % magic)
    if version != VERSION:
        raise PatchError("версия дельты %d, я знаю %d" % (version, VERSION))
    if hashlib.sha256(old_blob).digest() != from_sha:
        raise PatchError("дельта не от этого файла")

    have_fields, have_size, records, strings = _split(old_blob)
    if have_fields != field_count or have_size != record_size:
        raise PatchError("раскладка не совпала: %d/%d против %d/%d"
                         % (have_fields, have_size, field_count, record_size))
    if len(records) // record_size != old_count:
        raise PatchError("записей %d, дельта ждёт %d"
                         % (len(records) // record_size, old_count))
    if prefix > len(strings):
        raise PatchError("prefixLen больше блока строк")

    at = HEADER.size
    tail = patch_blob[at:at + tail_len]
    if len(tail) != tail_len:
        raise PatchError("дельта обрезана на блоке строк")
    at += tail_len

    out_records = bytearray(records)
    if new_count > old_count:
        out_records += bytes((new_count - old_count) * record_size)
    else:
        del out_records[new_count * record_size:]

    step = 4 + record_size
    for _ in range(write_count):
        if at + step > len(patch_blob):
            raise PatchError("дельта обрезана на записях")
        row = struct.unpack_from("<I", patch_blob, at)[0]
        chunk = patch_blob[at + 4:at + step]
        if row >= new_count:
            raise PatchError("номер записи %d вне результата (%d)"
                             % (row, new_count))
        out_records[row * record_size:(row + 1) * record_size] = chunk
        at += step

    out_strings = bytes(strings[:prefix]) + bytes(tail)
    head = DBC_HEADER.pack(b"WDBC", new_count, field_count, record_size,
                           len(out_strings))
    result = bytes(head) + bytes(out_records) + out_strings
    if hashlib.sha256(result).digest() != to_sha:
        raise PatchError("результат не сошёлся с ожидаемым sha256")
    return result
