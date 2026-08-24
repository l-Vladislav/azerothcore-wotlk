#!/usr/bin/env python3
"""Stitch a continent's world map art out of the game client.

The client keeps each continent map as twelve 256x256 BLP tiles laid out 4
across and 3 down, e.g. `Interface\\WorldMap\\Kalimdor\\Kalimdor1..12.blp`.
Only the top-left 1002x668 of the resulting 1024x768 sheet is real map — the
rest is padding the client never draws. That 1002x668 rectangle is what
`WorldMapArea.dbc`'s continent row describes, which is why the zone outlines
from gen_zone_geometry.py drop straight onto it.

On a localized client the whole `Interface` tree lives in the locale archive
(`Data/ruRU/locale-ruRU.MPQ`), not in common.MPQ — the maps carry engraved
place names, so they are translated. The script searches every archive it is
given and takes the last hit, matching MPQ load order.

Output is deliberately not committed: it is Blizzard art. Run this once after
a clone; see scripts/build-map-assets.ps1 for the full pipeline.

    python gen_map_art.py --client "E:/.../World of Warcraft" \
        --continent Kalimdor --out ../app/static/maps/kalimdor.jpg
"""

import argparse
import glob
import io
import os
import sys

try:
    from mpyq import MPQArchive
except ImportError:
    sys.exit("pip install mpyq")
try:
    from PIL import Image
except ImportError:
    sys.exit("pip install pillow")

TILE = 256
COLS, ROWS = 4, 3
# The part of the 1024x768 sheet the client actually shows.
MAP_W, MAP_H = 1002, 668

# MPQ load order: later archives win. Locale archives are searched last
# because that is where a localized client keeps its Interface art.
ARCHIVE_ORDER = [
    "Data/common.MPQ", "Data/common-2.MPQ", "Data/expansion.MPQ",
    "Data/lichking.MPQ", "Data/patch.MPQ", "Data/patch-2.MPQ",
    "Data/patch-3.MPQ",
]


def archives(client: str, locale: str) -> list[str]:
    out = [os.path.join(client, p) for p in ARCHIVE_ORDER]
    out += sorted(glob.glob(os.path.join(client, "Data", locale, "*.MPQ")))
    return [p for p in out if os.path.isfile(p)]


def find_tiles(paths: list[str], continent: str) -> dict[int, bytes]:
    """tile number -> BLP bytes, last archive wins."""
    want = {f"interface\\worldmap\\{continent.lower()}\\{continent.lower()}{i}.blp": i
            for i in range(1, COLS * ROWS + 1)}
    found: dict[int, bytes] = {}
    for path in paths:
        try:
            mpq = MPQArchive(path)
            listfile = mpq.read_file("(listfile)")
        except Exception:
            continue
        if not listfile:
            continue
        for name in listfile.decode("utf-8", "replace").splitlines():
            index = want.get(name.strip().lower())
            if index is None:
                continue
            data = mpq.read_file(name.strip())
            if data:
                found[index] = data
    return found


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--client", required=True, help="WoW 3.3.5a install folder")
    ap.add_argument("--continent", default="Kalimdor")
    ap.add_argument("--locale", default="ruRU")
    ap.add_argument("--out", required=True)
    ap.add_argument("--quality", type=int, default=88)
    args = ap.parse_args()

    paths = archives(args.client, args.locale)
    if not paths:
        sys.exit(f"no MPQ archives under {args.client}/Data")
    tiles = find_tiles(paths, args.continent)
    missing = [i for i in range(1, COLS * ROWS + 1) if i not in tiles]
    if missing:
        sys.exit(f"{args.continent}: tiles {missing} not found in any archive")

    sheet = Image.new("RGB", (COLS * TILE, ROWS * TILE))
    for index, data in tiles.items():
        tile = Image.open(io.BytesIO(data)).convert("RGB")
        col, row = (index - 1) % COLS, (index - 1) // COLS
        sheet.paste(tile, (col * TILE, row * TILE))

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    sheet.crop((0, 0, MAP_W, MAP_H)).save(
        args.out, quality=args.quality, optimize=True)
    print(f"{args.continent} -> {args.out} "
          f"({os.path.getsize(args.out) // 1024} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
