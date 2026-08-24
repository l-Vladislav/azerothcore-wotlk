#!/usr/bin/env python3
"""Trace real zone outlines for a continent map out of the server's own data.

The weather map needs to know where a zone *is*, and the honest answer is not
in any table the panel already reads. `WorldMapArea.dbc` only has a bounding
box per zone, and boxes overlap badly on Kalimdor. The actual shapes live in
the terrain the worldserver loads: every `maps/{map:03}{gx:02}{gy:02}.map` file
carries a 16x16 grid of AreaTable ids (`map_areaHeader`, see
src/server/game/Grids/GridTerrainData.cpp). One grid is 533.33 yards, so an
area cell is 33.33 yards — fine enough that at 1002 px continent width a cell
is under one pixel.

Two coordinate facts, both verified against the core, that the whole file
rests on:

  * cell indexing is `16 * (32 - X / SIZE_OF_GRIDS)` for the row and the same
    for Y for the column (`GridTerrainData::getArea`). X grows north, Y grows
    west, so row increases southwards and column eastwards — exactly the
    orientation of the client's world map.
  * `WorldMapArea.dbc`'s continent row gives that map's rectangle in the same
    world coordinates: LocLeft/LocRight are Y, LocTop/LocBottom are X. For
    Kalimdor it is (17066.6, -19733.2, 12799.9, -11733.3), which converts to
    rows 128..864 and columns 0..1104 — 1104x736 cells, aspect 1.5, the exact
    aspect of the 1002x668 client map image. That agreement is the proof the
    conversion is right; if it ever stops holding, the math changed, not the
    art.

One more thing the client does and this has to copy: `WorldMapTransforms.dbc`.
The draenei starting isles physically sit on map 530 next to Outland, yet they
are drawn on the Kalimdor sheet — the transform row moves that corner of map
530 onto map 1 with a fixed offset. Without it Azuremyst, Bloodmyst and the
Exodar have art on the map and no outline under it.

Output is one JSON with an SVG path per zone in a 1104x736 viewBox, ready to
lay straight over the stitched map art. Outlines are traced on cell edges
(exact, no smoothing) and then merged along collinear runs, which costs
nothing visually and removes ~90% of the points.

Runs with the standard library only, because it is meant to be executed inside
the admin-panel container where the client-data volume is mounted:

    docker exec ac-admin-panel python //tmp/gen_zone_geometry.py --map 1
"""

import argparse
import json
import os
import struct
import sys
from collections import defaultdict

SIZE_OF_GRIDS = 533.3333
CELLS_PER_GRID = 16
GRIDS = 64
WORLD_CELLS = GRIDS * CELLS_PER_GRID          # 1024 x 1024

MAP_MAGIC = b"MAPS"
AREA_MAGIC = b"AREA"
LIQUID_MAGIC = b"MLIQ"
HEIGHT_MAGIC = b"MHGT"
MAP_AREA_NO_AREA = 0x0001
MAP_LIQUID_NO_TYPE = 0x0001
MAP_LIQUID_NO_HEIGHT = 0x0002
MAP_LIQUID_TYPE_OCEAN = 0x02
MAP_HEIGHT_NO_HEIGHT = 0x0001
MAP_HEIGHT_AS_INT16 = 0x0002
MAP_HEIGHT_AS_INT8 = 0x0004
FILE_HEADER = struct.Struct("<4sIIIIIIIIII")  # map_fileheader
AREA_HEADER = struct.Struct("<4sHH")          # map_areaHeader
LIQUID_HEADER = struct.Struct("<4sBBHBBBBf")  # map_liquidHeader
HEIGHT_HEADER = struct.Struct("<4sIff")       # map_heightHeader

# Разрешение мелких сеток внутри грида: высоты 129x129 (V9), жидкость 128x128.
# Одна area-ячейка накрывает 8 таких шагов.
MAP_RESOLUTION = 128
V9_SIDE = MAP_RESOLUTION + 1
FINE_PER_CELL = MAP_RESOLUTION // CELLS_PER_GRID

# Насколько глубже воды должен лежать рельеф, чтобы считать ячейку морем.
# Не ноль: у самого берега пробы высоты и уровня воды сходятся, и строгое
# сравнение выедало бы кромку суши.
OCEAN_DEPTH = 2.0

# Islands smaller than this are extraction noise or a single stray cell of a
# neighbouring zone; drawing them adds points and reads as dirt on the map.
MIN_ISLAND_CELLS = 24


# --- DBC ------------------------------------------------------------------

class Dbc:
    """Minimal WDBC reader. Fields are 4 bytes; strings index a blob."""

    def __init__(self, path: str):
        with open(path, "rb") as f:
            self.data = f.read()
        magic, self.records, self.fields, self.rec_size, _ = struct.unpack(
            "<4sIIII", self.data[:20])
        if magic != b"WDBC":
            raise SystemExit(f"{path}: not a WDBC file")
        self.base = 20
        self.strings = self.base + self.records * self.rec_size

    def uints(self, row: int) -> tuple:
        off = self.base + row * self.rec_size
        return struct.unpack(f"<{self.fields}I", self.data[off:off + self.rec_size])

    def floats(self, row: int) -> tuple:
        off = self.base + row * self.rec_size
        return struct.unpack(f"<{self.fields}f", self.data[off:off + self.rec_size])

    def string(self, offset: int) -> str:
        if not offset:
            return ""
        end = self.data.index(b"\0", self.strings + offset)
        return self.data[self.strings + offset:end].decode("utf-8", "replace")


# AreaTable.dbc 3.3.5a: ID, ContinentID, ParentAreaID, AreaBit, Flags, ...
# AreaName is the localized block at field 11 (enUS slot 0, ruRU slot 8 — the
# same offset quirk the CSV exporters hit, see app/dbc.py).
AREA_ID, AREA_PARENT, AREA_NAME = 0, 2, 11
LOCALE_RURU = 8

# WorldMapArea.dbc 3.3.5a: ID, MapID, AreaID, AreaName, Left, Right, Top, Bottom
WMA_MAP, WMA_AREA = 1, 2
WMA_LEFT, WMA_RIGHT, WMA_TOP, WMA_BOTTOM = 4, 5, 6, 7

# WorldMapTransforms.dbc 3.3.5a: ID, MapID, RegionMinX, RegionMinY, RegionMaxX,
# RegionMaxY, NewMapID, RegionOffsetX, RegionOffsetY, NewDungeonMapID
WMT_MAP, WMT_NEW_MAP = 1, 6
WMT_MIN_X, WMT_MIN_Y, WMT_MAX_X, WMT_MAX_Y = 2, 3, 4, 5
WMT_OFF_X, WMT_OFF_Y = 7, 8


def load_areas(dbc_dir: str) -> tuple[dict[int, int], dict[int, str]]:
    """area id -> top-level zone id, and zone id -> Russian name."""
    dbc = Dbc(os.path.join(dbc_dir, "AreaTable.dbc"))
    parent: dict[int, int] = {}
    names: dict[int, str] = {}
    for row in range(dbc.records):
        v = dbc.uints(row)
        aid = v[AREA_ID]
        parent[aid] = v[AREA_PARENT]
        names[aid] = (dbc.string(v[AREA_NAME + LOCALE_RURU])
                      or dbc.string(v[AREA_NAME]))

    def top(aid: int) -> int:
        seen = set()
        while parent.get(aid) and aid not in seen:
            seen.add(aid)
            aid = parent[aid]
        return aid

    return {aid: top(aid) for aid in parent}, names


def transforms(dbc_dir: str, map_id: int) -> list[dict]:
    """Corners of other maps that the client draws on this one.

    Only cross-map rows matter: the file also holds map-onto-itself rows for
    multi-floor dungeons, which have nothing to do with a continent sheet.
    """
    dbc = Dbc(os.path.join(dbc_dir, "WorldMapTransforms.dbc"))
    out = []
    for row in range(dbc.records):
        v = dbc.uints(row)
        if v[WMT_NEW_MAP] != map_id or v[WMT_MAP] == map_id:
            continue
        f = dbc.floats(row)
        out.append({
            "map": v[WMT_MAP],
            "min_x": f[WMT_MIN_X], "min_y": f[WMT_MIN_Y],
            "max_x": f[WMT_MAX_X], "max_y": f[WMT_MAX_Y],
            "off_x": f[WMT_OFF_X], "off_y": f[WMT_OFF_Y],
        })
    return out


def continent_rect(dbc_dir: str, map_id: int) -> tuple[float, float, float, float]:
    dbc = Dbc(os.path.join(dbc_dir, "WorldMapArea.dbc"))
    for row in range(dbc.records):
        v = dbc.uints(row)
        if v[WMA_MAP] == map_id and v[WMA_AREA] == 0:
            f = dbc.floats(row)
            return f[WMA_LEFT], f[WMA_RIGHT], f[WMA_TOP], f[WMA_BOTTOM]
    raise SystemExit(f"WorldMapArea.dbc has no continent row for map {map_id}")


# --- terrain --------------------------------------------------------------

def _heights(f, offset: int) -> list[float] | float:
    """The tile's V9 height grid (129x129), or one value if it is flat."""
    f.seek(offset)
    fourcc, flags, grid_height, grid_max = HEIGHT_HEADER.unpack(
        f.read(HEIGHT_HEADER.size))
    if fourcc != HEIGHT_MAGIC:
        return 0.0
    if flags & MAP_HEIGHT_NO_HEIGHT:
        return grid_height

    count = V9_SIDE * V9_SIDE
    if flags & MAP_HEIGHT_AS_INT16:
        step = (grid_max - grid_height) / 65535.0
        raw = struct.unpack(f"<{count}H", f.read(count * 2))
        return [grid_height + v * step for v in raw]
    if flags & MAP_HEIGHT_AS_INT8:
        step = (grid_max - grid_height) / 255.0
        raw = struct.unpack(f"<{count}B", f.read(count))
        return [grid_height + v * step for v in raw]
    return list(struct.unpack(f"<{count}f", f.read(count * 4)))


def read_tile(path: str) -> tuple[list[int] | int | None, list[bool] | bool]:
    """A tile's 16x16 area ids and, per cell, whether it is open sea.

    The area ids may collapse to a single value when the whole grid is uniform,
    which is how the extractor stores open ocean and solid inland tiles.
    Liquid flags are indexed exactly like area ids — `(x>>3)*16 + (y>>3)` in
    `GridTerrainData::GetLiquidData` is the same cell as `getArea`'s — so the
    two rasters line up without resampling.

    "Sea" is not the ocean flag on its own. Teldrassil taught that the hard
    way: the tree stands over ocean-flagged cells, so the flag alone hollowed
    the island out into a ring of coastline. A cell counts as sea only when the
    terrain under it actually lies below the water surface.
    """
    with open(path, "rb") as f:
        head = FILE_HEADER.unpack(f.read(FILE_HEADER.size))
        if head[0] != MAP_MAGIC:
            return None, False
        area_off, height_off, liquid_off = head[3], head[5], head[7]

        areas: list[int] | int | None = None
        if area_off:
            f.seek(area_off)
            fourcc, flags, grid_area = AREA_HEADER.unpack(f.read(AREA_HEADER.size))
            if fourcc == AREA_MAGIC:
                areas = (grid_area if flags & MAP_AREA_NO_AREA
                         else list(struct.unpack("<256H", f.read(512))))

        if not liquid_off:
            return areas, False

        f.seek(liquid_off)
        (fourcc, flags, global_flags, _entry,
         off_x, off_y, width, height, level) = LIQUID_HEADER.unpack(
            f.read(LIQUID_HEADER.size))
        if fourcc != LIQUID_MAGIC:
            return areas, False

        cell_flags: list[int] | int = global_flags
        if not (flags & MAP_LIQUID_NO_TYPE):
            f.seek(512, os.SEEK_CUR)       # liquidEntry: uint16[16][16]
            cell_flags = list(struct.unpack("<256B", f.read(256)))

        levels: list[float] | None = None
        if not (flags & MAP_LIQUID_NO_HEIGHT) and width and height:
            levels = list(struct.unpack(f"<{width * height}f",
                                        f.read(width * height * 4)))

        def flag_of(cell: int) -> int:
            return cell_flags if isinstance(cell_flags, int) else cell_flags[cell]

        # Ни одной океанской ячейки - высоты можно не читать вовсе.
        if all(not (flag_of(i) & MAP_LIQUID_TYPE_OCEAN) for i in range(256)):
            return areas, False

        terrain = _heights(f, height_off) if height_off else 0.0

        sea = [False] * 256
        for lr in range(CELLS_PER_GRID):
            for lc in range(CELLS_PER_GRID):
                cell = lr * CELLS_PER_GRID + lc
                if not (flag_of(cell) & MAP_LIQUID_TYPE_OCEAN):
                    continue

                fine_r, fine_c = lr * FINE_PER_CELL, lc * FINE_PER_CELL
                water = level
                if levels is not None:
                    lx, ly = fine_r - off_y, fine_c - off_x
                    if 0 <= lx < height and 0 <= ly < width:
                        water = levels[lx * width + ly]
                    else:
                        continue       # вода сюда не доходит - это суша

                ground = (terrain if isinstance(terrain, float)
                          else terrain[fine_r * V9_SIDE + fine_c])
                sea[cell] = water - ground > OCEAN_DEPTH

        return areas, sea


def cell_center(index: int) -> float:
    """World coordinate of a cell's middle, along either axis."""
    return (32 - (index + 0.5) / CELLS_PER_GRID) * SIZE_OF_GRIDS


def cell_of(coord: float) -> int:
    """Inverse of cell_center: which cell a world coordinate falls into."""
    return int(CELLS_PER_GRID * (32 - coord / SIZE_OF_GRIDS))


def build_raster(maps_dir: str, map_id: int, to_zone: dict[int, int],
                 drop_ocean: bool, moved: list[dict] | None = None
                 ) -> list[list[int]]:
    """World-wide 1024x1024 grid of top-level zone ids for one map.

    Cells that are open sea are dropped by default. AreaTable covers water too
    — every zone's area ids run out to the grid edge — so keeping them draws
    each coastal zone as a rectangular slab of ocean. What is left is the
    landmass, which is what a weather map is about.
    """
    grid = [[0] * WORLD_CELLS for _ in range(WORLD_CELLS)]
    _paint_map(grid, maps_dir, map_id, to_zone, drop_ocean, None)
    for move in moved or []:
        _paint_map(grid, maps_dir, move["map"], to_zone, drop_ocean, move)
    return grid


def _paint_map(grid: list[list[int]], maps_dir: str, map_id: int,
               to_zone: dict[int, int], drop_ocean: bool,
               move: dict | None) -> None:
    """Write one map's cells into the world raster, optionally shifted."""
    prefix = f"{map_id:03}"
    for name in os.listdir(maps_dir):
        if not name.startswith(prefix) or not name.endswith(".map"):
            continue
        stem = name[:-4]
        if len(stem) != 7:
            continue
        gx, gy = int(stem[3:5]), int(stem[5:7])
        areas, sea = read_tile(os.path.join(maps_dir, name))
        if areas is None:
            continue
        base_r, base_c = gx * CELLS_PER_GRID, gy * CELLS_PER_GRID
        for lr in range(CELLS_PER_GRID):
            for lc in range(CELLS_PER_GRID):
                cell = lr * CELLS_PER_GRID + lc
                if drop_ocean:
                    under_water = sea if isinstance(sea, bool) else sea[cell]
                    if under_water:
                        continue
                area = areas if isinstance(areas, int) else areas[cell]
                if not area:
                    continue

                r, c = base_r + lr, base_c + lc
                if move:
                    x, y = cell_center(r), cell_center(c)
                    if not (move["min_x"] <= x <= move["max_x"]
                            and move["min_y"] <= y <= move["max_y"]):
                        continue
                    r = cell_of(x + move["off_x"])
                    c = cell_of(y + move["off_y"])
                    if not (0 <= r < WORLD_CELLS and 0 <= c < WORLD_CELLS):
                        continue

                grid[r][c] = to_zone.get(area, 0)


def crop_to_map(grid: list[list[int]], rect: tuple[float, float, float, float]
                ) -> tuple[list[list[int]], int, int]:
    """Cut the world raster down to the rectangle the map image covers.

    The client map is allowed to reach past the terrain grid (Kalimdor's runs
    to column 1104 where the world ends at 1024); those columns simply stay
    empty, which is correct — there is no land there.
    """
    left, right, top, bottom = rect
    r0 = round(CELLS_PER_GRID * (32 - top / SIZE_OF_GRIDS))
    r1 = round(CELLS_PER_GRID * (32 - bottom / SIZE_OF_GRIDS))
    c0 = round(CELLS_PER_GRID * (32 - left / SIZE_OF_GRIDS))
    c1 = round(CELLS_PER_GRID * (32 - right / SIZE_OF_GRIDS))
    out = []
    for r in range(r0, r1):
        src = grid[r] if 0 <= r < WORLD_CELLS else None
        out.append([src[c] if src and 0 <= c < WORLD_CELLS else 0
                    for c in range(c0, c1)])
    return out, c1 - c0, r1 - r0


# --- outline tracing ------------------------------------------------------

def islands(cells: set[tuple[int, int]]) -> list[set[tuple[int, int]]]:
    """4-connected components, largest first."""
    out: list[set[tuple[int, int]]] = []
    todo = set(cells)
    while todo:
        seed = todo.pop()
        comp = {seed}
        stack = [seed]
        while stack:
            r, c = stack.pop()
            for nb in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
                if nb in todo:
                    todo.discard(nb)
                    comp.add(nb)
                    stack.append(nb)
        out.append(comp)
    out.sort(key=len, reverse=True)
    return out


def trace(cells: set[tuple[int, int]]) -> list[list[tuple[int, int]]]:
    """Closed loops along the outer cell edges of a set of cells.

    Every boundary edge is emitted once, then the edges are stitched into
    loops. A vertex touches at most four edges and always an even number of
    them, so walking always closes. Holes come out as their own loops, which
    an even-odd fill renders correctly without any nesting analysis.
    """
    edges: list[tuple[tuple[int, int], tuple[int, int]]] = []
    for r, c in cells:
        if (r - 1, c) not in cells:
            edges.append(((c, r), (c + 1, r)))
        if (r + 1, c) not in cells:
            edges.append(((c, r + 1), (c + 1, r + 1)))
        if (r, c - 1) not in cells:
            edges.append(((c, r), (c, r + 1)))
        if (r, c + 1) not in cells:
            edges.append(((c + 1, r), (c + 1, r + 1)))

    adj: dict[tuple[int, int], list[tuple[int, int]]] = defaultdict(list)
    for a, b in edges:
        adj[a].append(b)
        adj[b].append(a)

    loops = []
    for start in list(adj):
        while adj[start]:
            loop = [start]
            prev, cur = None, start
            while True:
                nxt = None
                # Prefer going straight: fewer, longer runs to merge later.
                if prev is not None:
                    d = (cur[0] - prev[0], cur[1] - prev[1])
                    straight = (cur[0] + d[0], cur[1] + d[1])
                    if straight in adj[cur]:
                        nxt = straight
                if nxt is None:
                    nxt = adj[cur][0]
                adj[cur].remove(nxt)
                adj[nxt].remove(cur)
                prev, cur = cur, nxt
                if cur == start:
                    break
                loop.append(cur)
            if len(loop) > 3:
                loops.append(loop)
    return loops


def merge_collinear(loop: list[tuple[int, int]]) -> list[tuple[int, int]]:
    out: list[tuple[int, int]] = []
    n = len(loop)
    for i in range(n):
        prv, cur, nxt = loop[i - 1], loop[i], loop[(i + 1) % n]
        if (cur[0] - prv[0]) * (nxt[1] - cur[1]) != (cur[1] - prv[1]) * (nxt[0] - cur[0]):
            out.append(cur)
    return out or loop


def to_path(loops: list[list[tuple[int, int]]]) -> str:
    parts = []
    for loop in loops:
        pts = merge_collinear(loop)
        parts.append("M" + " ".join(f"{x},{y}" for x, y in pts) + "Z")
    return "".join(parts)


def label_point(comp: set[tuple[int, int]]) -> tuple[float, float]:
    """A point well inside the shape — the cell furthest from any edge.

    A centroid lands outside crescent-shaped zones (Ashenvale, Feralas), so
    this is a cheap chamfer distance transform over the island instead.
    """
    dist: dict[tuple[int, int], int] = {}
    frontier = [cell for cell in comp
                if any(nb not in comp for nb in ((cell[0] - 1, cell[1]),
                                                 (cell[0] + 1, cell[1]),
                                                 (cell[0], cell[1] - 1),
                                                 (cell[0], cell[1] + 1)))]
    for cell in frontier:
        dist[cell] = 1
    step = 1
    while frontier:
        step += 1
        nxt = []
        for r, c in frontier:
            for nb in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
                if nb in comp and nb not in dist:
                    dist[nb] = step
                    nxt.append(nb)
        frontier = nxt
    best = max(dist, key=lambda k: dist[k])
    return best[1] + 0.5, best[0] + 0.5


# --- main -----------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", type=int, default=1, help="MapID (1 = Kalimdor)")
    ap.add_argument("--client-data", default="/client-data")
    ap.add_argument("--out", default="-", help="output JSON path, - for stdout")
    ap.add_argument("--keep-ocean", action="store_true",
                    help="do not clip zones to the landmass")
    args = ap.parse_args()

    dbc_dir = os.path.join(args.client_data, "dbc")
    maps_dir = os.path.join(args.client_data, "maps")

    to_zone, names = load_areas(dbc_dir)
    rect = continent_rect(dbc_dir, args.map)
    moved = transforms(dbc_dir, args.map)
    grid = build_raster(maps_dir, args.map, to_zone, not args.keep_ocean, moved)
    cropped, width, height = crop_to_map(grid, rect)

    by_zone: dict[int, set[tuple[int, int]]] = defaultdict(set)
    for r, row in enumerate(cropped):
        for c, zone in enumerate(row):
            if zone:
                by_zone[zone].add((r, c))

    zones = []
    for zone_id, cells in by_zone.items():
        comps = [i for i in islands(cells) if len(i) >= MIN_ISLAND_CELLS]
        if not comps:
            continue
        kept: set[tuple[int, int]] = set()
        for comp in comps:
            kept |= comp
        lx, ly = label_point(comps[0])
        zones.append({
            "id": zone_id,
            "name": names.get(zone_id, f"Зона {zone_id}"),
            "cells": len(kept),
            "label": [round(lx, 1), round(ly, 1)],
            "path": to_path(trace(kept)),
        })
    zones.sort(key=lambda z: -z["cells"])

    doc = {
        "map": args.map,
        "moved_from": sorted({m["map"] for m in moved}),
        "width": width,
        "height": height,
        "rect": [round(v, 2) for v in rect],
        "zones": zones,
    }
    text = json.dumps(doc, ensure_ascii=False, separators=(",", ":"))
    if args.out == "-":
        sys.stdout.write(text)
    else:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"{len(zones)} zones -> {args.out} ({len(text) // 1024} KB)",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
