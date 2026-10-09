"""Строки GameObjectDisplayInfo для моделей окружения клиента.

Модели World\\...\\*.m2 из архивов клиента, у которых нет строки в действующем
GameObjectDisplayInfo.dbc, получают строки в блоке FIRST_ID..LAST_ID. GeoBox -
шесть float по смещению 0xA0 заголовка MD20. Выход:

  .claude/dbc/GameObjectDisplayInfo_custom.csv  - оверлей клиентского патча
  data/sql/updates/pending_db_world/mod_remote_control_world_models.sql
                                                - серверная gameobjectdisplayinfo_dbc

Уже выданные id сохраняются: модель, бывшая в прошлом CSV, остаётся со своим id.

  python tools/client-patch/gen_world_models.py "E:\\torrent\\World of Warcraft"
"""

import csv
import os
import struct
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

import stormlib  # noqa: E402
from dbcfile import Dbc  # noqa: E402

FIRST_ID = 20000
LAST_ID = 29999
GEOBOX_OFFSET = 0xA0
SKIP_DIRS = ("world\\nodxt\\", "world\\environment\\", "world\\scale\\", "world\\arttest\\")
DBC_NAME = "DBFilesClient\\GameObjectDisplayInfo.dbc"
CSV_PATH = os.path.join(REPO, ".claude", "dbc", "GameObjectDisplayInfo_custom.csv")
SQL_PATH = os.path.join(REPO, "data", "sql", "updates", "pending_db_world",
                        "mod_remote_control_world_models.sql")
COLUMNS = ["ID", "ModelName", "GeoBoxMinX", "GeoBoxMinY", "GeoBoxMinZ",
           "GeoBoxMaxX", "GeoBoxMaxY", "GeoBoxMaxZ"]

# Порядок загрузки архивов клиента 3.3.5a ruRU: позднее перекрывает раннее.
ARCHIVES = [
    "common.MPQ", "common-2.MPQ", "expansion.MPQ", "lichking.MPQ",
    "ruRU\\locale-ruRU.MPQ", "ruRU\\expansion-locale-ruRU.MPQ", "ruRU\\lichking-locale-ruRU.MPQ",
    "patch.MPQ", "ruRU\\patch-ruRU.MPQ", "patch-2.MPQ", "ruRU\\patch-ruRU-2.MPQ",
    "patch-3.MPQ", "ruRU\\patch-ruRU-3.MPQ",
]


def stock_models(data, work):
    """Пути моделей действующего GameObjectDisplayInfo.dbc (без расширения)."""
    source = None
    for rel in ARCHIVES:
        with stormlib.Archive(os.path.join(data, rel)) as arc:
            if any(n.lower() == DBC_NAME.lower() for n, _, _ in arc.list()):
                source = rel
    path = os.path.join(work, "GameObjectDisplayInfo.dbc")
    with stormlib.Archive(os.path.join(data, source)) as arc:
        arc.extract(DBC_NAME, path)
    dbc = Dbc.load(path)
    models = set()
    for row in range(dbc.count):
        offset = struct.unpack_from("<I", dbc.record(row), 4)[0]
        models.add(dbc.string_at(offset).lower().rsplit(".", 1)[0])
    print("действующая таблица: %s, строк %d, max id %d" % (source, dbc.count, max(dbc.ids)))
    return models, max(dbc.ids)


def world_models(data):
    """{путь в нижнем регистре: (имя в архиве, архив)}; позднее перекрывает раннее."""
    found = {}
    for rel in ARCHIVES:
        with stormlib.Archive(os.path.join(data, rel)) as arc:
            for name, _, _ in arc.list():
                low = name.lower()
                if low.startswith("world\\") and low.endswith(".m2") \
                        and not low.startswith(SKIP_DIRS):
                    found[low] = (name, rel)
    return found


def geobox(data, work, name, rel):
    path = os.path.join(work, "model.m2")
    with stormlib.Archive(os.path.join(data, rel)) as arc:
        arc.extract(name, path)
    with open(path, "rb") as handle:
        blob = handle.read(GEOBOX_OFFSET + 24)
    if blob[:4] != b"MD20" or len(blob) < GEOBOX_OFFSET + 24:
        return None
    box = struct.unpack_from("<6f", blob, GEOBOX_OFFSET)
    if any(abs(v) > 10000 or v != v for v in box):
        return None
    return box


def previous_ids():
    ids = {}
    if os.path.isfile(CSV_PATH):
        with open(CSV_PATH, encoding="utf-8-sig", newline="") as handle:
            for row in csv.DictReader(handle):
                ids[row["ModelName"].lower().rsplit(".", 1)[0]] = int(row["ID"])
    return ids


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    data = os.path.join(sys.argv[1], "Data")
    work = tempfile.mkdtemp(prefix="world_models_")

    stock, stock_max = stock_models(data, work)
    if stock_max >= FIRST_ID:
        sys.exit("действующая таблица заходит в блок %d+" % FIRST_ID)

    models = world_models(data)
    known = previous_ids()
    next_id = max([FIRST_ID - 1] + list(known.values())) + 1

    rows = []
    skipped = 0
    for low in sorted(models):
        key = low.rsplit(".", 1)[0]
        if key in stock:
            continue
        name, rel = models[low]
        box = geobox(data, work, name, rel)
        if box is None:
            skipped += 1
            continue
        entry = known.get(key)
        if entry is None:
            entry = next_id
            next_id += 1
        if entry > LAST_ID:
            sys.exit("блок id %d-%d исчерпан" % (FIRST_ID, LAST_ID))
        rows.append((entry, name.rsplit(".", 1)[0] + ".mdx", box))
    rows.sort()

    with open(CSV_PATH, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, quoting=csv.QUOTE_ALL)
        writer.writerow(COLUMNS)
        for entry, model, box in rows:
            writer.writerow([entry, model] + ["%.6f" % v for v in box])

    with open(SQL_PATH, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("-- mod-remote-control: модели окружения клиента как модели объектов (#152).\n")
        handle.write("-- Генерируется tools/client-patch/gen_world_models.py; блок id %d-%d.\n\n"
                     % (FIRST_ID, LAST_ID))
        handle.write("DELETE FROM `gameobjectdisplayinfo_dbc` WHERE `ID` BETWEEN %d AND %d;\n"
                     % (FIRST_ID, LAST_ID))
        for start in range(0, len(rows), 500):
            handle.write("INSERT INTO `gameobjectdisplayinfo_dbc` (`ID`, `ModelName`, `GeoBoxMinX`, "
                         "`GeoBoxMinY`, `GeoBoxMinZ`, `GeoBoxMaxX`, `GeoBoxMaxY`, `GeoBoxMaxZ`) VALUES\n")
            chunk = rows[start:start + 500]
            handle.write(",\n".join(
                "(%d, '%s', %s)" % (entry, model.replace("\\", "\\\\").replace("'", "''"),
                                    ", ".join("%.6f" % v for v in box))
                for entry, model, box in chunk))
            handle.write(";\n")

    print("моделей окружения: %d, новых строк: %d, без заголовка MD20: %d"
          % (len(models), len(rows), skipped))
    print("id: %d-%d" % (rows[0][0], rows[-1][0]) if rows else "строк нет")


if __name__ == "__main__":
    main()
