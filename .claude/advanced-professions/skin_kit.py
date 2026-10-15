# -*- coding: utf-8 -*-
"""Набор элементов оформления AdvProfUI, снятый с макетов mockups/.

Макеты - картинки целиком, без слоёв, и в два раза крупнее окна в игре:

* рамки панелей вырезаны из mockup-4.png как есть: четыре угла в один атлас,
  верхний и нижний край - в одну текстуру, левый и правый - в другую. Клиент
  3.3.5 текстуру не повторяет (координаты больше единицы тянут крайние точки)
  и при растяжении смазывает её, поэтому кусок кромки повторён внутри самой
  текстуры до длины EDGE_TEX, а панель берёт из неё отрезок нужной длины;
* заливки - процедурный камень (шум нескольких масштабов и зерно) размером не
  меньше панели: панель берёт из текстуры свой кусок без растяжения;
* кнопки и поле ввода - концы, вырезанные по контуру, и средний столбец,
  усреднённый по чистому месту;
* кольцо медальона - в полярных координатах: шипы и стыки с рамой заменены
  соседними углами самого кольца.

Текстуры кладутся в textures/ аддона (BLP2, DXT5), превью - в previews/ рядом
со скриптом. Все текстуры хранятся вдвое крупнее, чем показываются.

Запуск: python skin_kit.py; шапка окна переплавки - python skin_kit.py smelt,
рисунок ткацкого станка - python skin_kit.py loom, дубильной рамы -
python skin_kit.py tanning, стола распыления - python skin_kit.py disenchant.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from tga2blp import write_blp  # noqa: E402

SRC = os.path.join(HERE, 'mockups', 'mockup-3.png')
FRAMES = os.path.join(HERE, 'mockups', 'mockup-4.png')
DST = os.path.normpath(os.path.join(
    HERE, '..', '..', 'modules', 'mod-advanced-professions',
    'ClientAddon', 'AdvProfUI', 'textures'))
PREVIEW = os.path.join(HERE, 'previews')

ART = np.asarray(Image.open(SRC).convert('RGB')).astype(np.float64)
CUT = np.asarray(Image.open(FRAMES).convert('RGB')).astype(np.float64)


def lum(c):
    c = np.asarray(c, dtype=np.float64)
    return c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114


def save(img, name):
    write_blp(img, os.path.join(DST, name + '.blp'))
    big = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
    big.save(os.path.join(PREVIEW, name + '.png'))
    print('%-22s %dx%d' % (name, img.width, img.height))


def to_img(arr):
    return Image.fromarray(np.clip(arr + 0.5, 0, 255).astype(np.uint8), 'RGBA')


def bilinear(img, x, y):
    x0 = np.floor(x).astype(int)
    y0 = np.floor(y).astype(int)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]

    def at(yy, xx):
        return img[np.clip(yy, 0, img.shape[0] - 1),
                   np.clip(xx, 0, img.shape[1] - 1)]
    return (at(y0, x0) * (1 - fx) * (1 - fy) + at(y0, x0 + 1) * fx * (1 - fy)
            + at(y0 + 1, x0) * (1 - fx) * fy + at(y0 + 1, x0 + 1) * fx * fy)


# --- рамки -----------------------------------------------------------------

def profile(x0, x1, y0, y1, axis):
    """Срез кромки: среднее по прямоугольнику вдоль оси axis (0 - вдоль y,
    срез идёт по x; 1 - вдоль x, срез идёт по y)."""
    return ART[y0:y1, x0:x1].mean(axis=axis)


def edge(metal, shadow, fill):
    """Профиль снаружи внутрь: металл непрозрачен, тень - чёрная с альфой,
    которая на заливке fill даёт тот же цвет, что в макете."""
    out = [np.r_[c, 255.0] for c in metal]
    base = max(lum(fill), 1.0)
    for c in shadow:
        a = min(max(1.0 - lum(c) / base, 0.0), 1.0)
        out.append(np.array([0.0, 0.0, 0.0, 255.0 * a]))
    return out


# --- рамки, вырезанные из макета ---------------------------------------------

def is_world(rgb):
    """Фон игрового мира за окном на макете - рыжий и тусклый: зелёный канал
    у него вдвое ниже красного. Проверяется только у самого контура угла -
    бронза рамки того же оттенка."""
    return (rgb[..., 0] - rgb[..., 2] > 20) & (rgb[..., 1] < 0.6 * rgb[..., 0])


EDGE_LEN = 256
EDGE_TEX = 2048


def tile_edge(strip, axis, seed=7):
    """Кусок кромки -> полоса EDGE_TEX: поперечный срез, усреднённый вдоль
    куска (линии рамы идут ровно), и лёгкое зерно металла вдоль полосы."""
    a = np.moveaxis(strip, axis, 0).astype(np.float64)
    profile = a.mean(axis=0)
    rng = np.random.default_rng(seed)
    grain = 1 + rng.normal(0, 0.06, (EDGE_TEX, 1, 1))
    line = profile[None, :, :].repeat(EDGE_TEX, 0)
    line[..., :3] = np.clip(line[..., :3] * grain, 0, 255)
    return np.moveaxis(line, 0, axis)


def cut_frame(name, box, m, t, edges, fill, core, top_from_bottom=False):
    """Рамка панели из макета. box - внешний контур (x0, y0, x1, y1), m - угол,
    t - толщина кромки, edges - места кусков краёв (top/bottom - x начала,
    left/right - y начала).

    Края - поперечный срез кромки, усреднённый вдоль куска. Углы строятся из
    тех же срезов со скосом под 45 градусов, поэтому линии угла и края
    совпадают точка в точку; поверх кладутся детали угла из макета: всё, что
    ближе core к вершине (заклёпка), и светлые завитки внутри рамки.
    Правые углы берут детали левых (на макете справа крестик и надписи);
    top_from_bottom - верхние тоже берут детали нижних, а верхний край -
    отражение нижнего (у окна верх закрывают медальон и крестик)."""
    x0, y0, x1, y1 = box
    n = EDGE_LEN

    def strip(rgb):
        return np.dstack([rgb, np.full(rgb.shape[:2], 255.0)])

    bottom = strip(CUT[y1 - t:y1, edges['bottom']:edges['bottom'] + n])
    top = (bottom[::-1] if top_from_bottom
           else strip(CUT[y0:y0 + t, edges['top']:edges['top'] + n]))
    left = strip(CUT[edges['left']:edges['left'] + n, x0:x0 + t])
    right = strip(CUT[edges['right']:edges['right'] + n, x1 - t:x1])

    # Срезы снаружи внутрь.
    p_top = top.mean(axis=1)
    p_bottom = bottom.mean(axis=1)[::-1]
    p_left = left.mean(axis=0)
    p_right = right.mean(axis=0)[::-1]

    def detail(cx, cy):
        """Угол макета в положении «левый верхний»: альфа - заклёпка у
        вершины и светлые завитки дальше кромки."""
        rgb = CUT[cy:cy + m, cx:cx + m]
        ys, xs = np.mgrid[0:m, 0:m] + 0.5
        dx = np.minimum(xs + cx - x0, x1 - cx - xs)
        dy = np.minimum(ys + cy - y0, y1 - cy - ys)
        a = np.where(np.hypot(dx, dy) < core, 1.0, 0.0)
        inner = (dx >= t) & (dy >= t)
        a = np.maximum(a, np.where(inner, np.clip(
            (lum(rgb) - lum(fill) - 8) / 30, 0, 1), 0))
        a[is_world(rgb) & (np.minimum(dx, dy) < 3)] = 0
        return np.dstack([rgb, a * 255.0])

    d_bl = detail(x0, y1 - m)[::-1]
    d_tl = d_bl if top_from_bottom else detail(x0, y0)

    def corner(p_h, p_v, det):
        out = np.zeros((m, m, 4))
        for y in range(m):
            for x in range(m):
                if y < t and y <= x:
                    out[y, x] = p_h[y]
                elif x < t:
                    out[y, x] = p_v[x]
        a = det[..., 3:4] / 255.0
        out[..., :3] = det[..., :3] * a + out[..., :3] * (1 - a)
        out[..., 3] = np.maximum(out[..., 3], det[..., 3])
        return out

    atlas = np.zeros((2 * m, 2 * m, 4))
    atlas[:m, :m] = corner(p_top, p_left, d_tl)
    atlas[:m, m:] = corner(p_top, p_right, d_tl)[:, ::-1]
    atlas[m:, :m] = corner(p_bottom, p_left, d_bl)[::-1]
    atlas[m:, m:] = corner(p_bottom, p_right, d_bl)[::-1, ::-1]
    size = 1 << (2 * m - 1).bit_length()
    save(to_img(pad(atlas, size, size)), name + '-corner')

    h = np.concatenate([tile_edge(top, 1), tile_edge(bottom, 1)], axis=0)
    v = np.concatenate([tile_edge(left, 0), tile_edge(right, 0)], axis=1)
    hh = 1 << (2 * t - 1).bit_length()
    save(to_img(pad(h, EDGE_TEX, hh)), name + '-h')
    save(to_img(pad(v, hh, EDGE_TEX)), name + '-v')


# --- заливки ---------------------------------------------------------------

def cracks(w, h, rng, count):
    """Тонкие трещины: ломаные из коротких отрезков со случайным поворотом."""
    img = Image.new('L', (w, h), 0)
    draw = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = rng.random() * w, rng.random() * h
        angle = rng.random() * 2 * math.pi
        for _ in range(int(rng.integers(8, 30))):
            angle += rng.normal(0, 0.45)
            step = rng.uniform(6, 18)
            nx, ny = x + math.cos(angle) * step, y + math.sin(angle) * step
            draw.line([(x, y), (nx, ny)], fill=int(rng.integers(90, 200)), width=1)
            x, y = nx, ny
    return np.asarray(img.filter(ImageFilter.GaussianBlur(0.6))) / 255.0


def stone(size, target, seed, contrast=0.5, grain=0.07, crack=0.25):
    """Процедурный камень size (w, h): шум семи масштабов - крупные пятна и
    мелкая фактура, - зерно в одну точку и редкие тёмные трещины; средний
    цвет - target."""
    w, h = size
    rng = np.random.default_rng(seed)
    v = np.zeros((h, w))
    for cells, weight in ((3, 1.0), (6, 0.7), (12, 0.5), (24, 0.35),
                          (48, 0.25), (96, 0.18), (192, 0.12)):
        grid = rng.random((max(2, cells * h // w + 1), cells + 1))
        layer = Image.fromarray((grid * 255).astype(np.uint8)).resize(
            (w, h), Image.BICUBIC)
        v += (np.asarray(layer) / 255.0 - 0.5) * weight
    v = v / np.abs(v).max()
    v = 1 + v * contrast + rng.normal(0, grain, (h, w))
    v -= cracks(w, h, rng, w * h // 60000) * crack
    rgb = np.asarray(target, dtype=np.float64)[None, None, :] * v[..., None]
    return to_img(np.dstack([rgb, np.full((h, w), 255.0)]))


def inner_shade(name, m=32, strength=0.8):
    """Внутренняя тень по краю картинки: чёрный, гаснущий от кромки внутрь на
    m точек атласа. Углы - атлас 2x2, края - полосы поперёк кромки."""
    d = np.arange(m) + 0.5
    edge = strength * (1 - d / m) ** 1.6
    ys, xs = np.mgrid[0:m, 0:m]
    a = 1 - (1 - edge[ys]) * (1 - edge[xs])
    corner = np.zeros((2 * m, 2 * m, 4))
    corner[:m, :m, 3] = a
    corner[:m, m:, 3] = a[:, ::-1]
    corner[m:, :m, 3] = a[::-1]
    corner[m:, m:, 3] = a[::-1, ::-1]
    corner[..., 3] *= 255
    save(to_img(pad(corner, 64, 64)), name + '-corner')
    hs = np.zeros((2 * m, 16, 4))
    hs[:m, :, 3] = edge[:, None] * 255
    hs[m:, :, 3] = edge[::-1, None] * 255
    save(to_img(pad(hs, 16, 64)), name + '-h')
    save(to_img(pad(np.transpose(hs, (1, 0, 2)), 64, 16)), name + '-v')


# --- кнопки ----------------------------------------------------------------

def octagon_mask(w, h, c):
    ys, xs = np.mgrid[0:h, 0:w] + 0.5
    dx = np.minimum(xs, w - xs)
    dy = np.minimum(ys, h - ys)
    d = np.minimum(np.minimum(dx, dy), (dx + dy - c) / math.sqrt(2))
    return np.clip(d, 0, 1)


def arrow_mask(w, h, tip):
    """Плашка с остриями по бокам: середина высоты выступает на tip."""
    ys, xs = np.mgrid[0:h, 0:w] + 0.5
    dy = np.minimum(ys, h - ys)
    dx = np.minimum(xs, w - xs)
    slope = abs(h / 2.0 - ys) * tip / (h / 2.0)
    d = np.minimum(dy, dx - slope)
    return np.clip(d, 0, 1)


def button(box, caps, middle, mask, mirror_left=False):
    """Три куска кнопки в одну полосу: левый конец, столбец середины (8 точек)
    и правый конец. box - контур кнопки в макете, caps - ширина концов,
    middle - диапазон x чистого места для столбца."""
    x0, y0, x1, y1 = box
    h = y1 - y0
    w = x1 - x0
    rgb = ART[y0:y1, x0:x1].copy()
    alpha = mask(w, h) * 255.0
    full = np.dstack([rgb, alpha])
    right = full[:, w - caps:]
    left = right[:, ::-1] if mirror_left else full[:, :caps]
    col = ART[y0:y1, middle[0]:middle[1]].mean(axis=1)
    col = np.dstack([col[:, None, :].repeat(8, 1), alpha[:, caps:caps + 1].repeat(8, 1)[..., None]])
    return np.concatenate([left, col, right], axis=1)


# --- кольца ----------------------------------------------------------------

def fit_circle(box, rmin, rmax, guess):
    """Центр и радиус золотой кромки кольца по точкам цвета бронзы."""
    x0, y0, x1, y1 = box
    sub = ART[y0:y1, x0:x1]
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    ys, xs = np.nonzero((r > 110) & (r - b > 60))
    xs = xs + x0
    ys = ys + y0
    cx, cy = guess
    d = np.hypot(xs - cx, ys - cy)
    keep = (d > rmin) & (d < rmax)
    xs, ys = xs[keep], ys[keep]
    rad = None
    for _ in range(4):
        a = np.c_[2 * xs, 2 * ys, np.ones(len(xs))]
        sol = np.linalg.lstsq(a, xs ** 2 + ys ** 2, rcond=None)[0]
        cx, cy = sol[0], sol[1]
        rad = math.sqrt(sol[2] + cx * cx + cy * cy)
        keep = np.abs(np.hypot(xs - cx, ys - cy) - rad) < 4
        xs, ys = xs[keep], ys[keep]
    return cx, cy, rad


def polar(cx, cy, rmax, steps_r, steps_t):
    rr = np.linspace(0, rmax, steps_r)[:, None]
    tt = np.linspace(-math.pi, math.pi, steps_t, endpoint=False)[None, :]
    return bilinear(ART, cx + rr * np.cos(tt), cy + rr * np.sin(tt))


def heal(p, bad):
    """Заменить испорченные углы (bad - список (от, до) в градусах) линейной
    подстановкой между чистыми краями, по каждому радиусу отдельно."""
    n = p.shape[1]
    good = np.ones(n, bool)
    deg = np.linspace(-180, 180, n, endpoint=False)
    for a, b in bad:
        good &= ~((deg >= a) & (deg <= b))
    idx = np.arange(n)
    gi = idx[good]
    out = p.copy()
    for ch in range(p.shape[2]):
        for r in range(p.shape[0]):
            out[r, :, ch] = np.interp(idx, np.r_[gi - n, gi, gi + n],
                                      np.tile(p[r, good, ch], 3))
    return out


def from_polar(p, rmax, size, r_in, r_out, soft=1.0, extent=None):
    """Развернуть полярную картинку (снятую до радиуса rmax) обратно в квадрат
    size, вписав в него круг радиуса extent; видимо только кольцо r_in..r_out
    (в точках макета), края растушёваны на soft."""
    ys, xs = np.mgrid[0:size, 0:size] + 0.5
    k = (extent or rmax) / (size / 2.0)
    r = np.hypot(xs - size / 2.0, ys - size / 2.0) * k
    t = np.arctan2(ys - size / 2.0, xs - size / 2.0)
    ri = r / rmax * (p.shape[0] - 1)
    ti = (t + math.pi) / (2 * math.pi) * p.shape[1]
    ti = np.mod(ti, p.shape[1])
    pw = np.concatenate([p, p[:, :1]], axis=1)
    rgb = bilinear(pw, ti, ri)
    a = np.clip((r - r_in) / soft + 0.5, 0, 1) * np.clip((r_out - r) / soft + 0.5, 0, 1)
    return to_img(np.dstack([rgb, a * 255.0]))


# --- значки и рисунки поверх фона ---------------------------------------------

def lift(box, bg, span, unblend=True):
    """Светлый рисунок на тёмном фоне -> рисунок с альфой: альфа растёт с
    превышением яркости над фоном. unblend восстанавливает цвет из смешения
    (для чётких значков); без него остаётся цвет макета (для тусклых рисунков,
    которые иначе выбеливаются)."""
    x0, y0, x1, y1 = box
    rgb = ART[y0:y1, x0:x1]
    bg = np.asarray(bg, dtype=np.float64)
    a = np.clip((lum(rgb) - lum(bg)) / span, 0, 1)
    col = rgb
    if unblend:
        safe = np.maximum(a, 1e-3)[..., None]
        col = (rgb - bg * (1 - a[..., None])) / safe
    return np.dstack([np.clip(col, 0, 255), a * 255.0])


def pad(arr, w, h, x=0, y=0):
    out = np.zeros((h, w, 4))
    out[y:y + arr.shape[0], x:x + arr.shape[1]] = arr
    return out


# ---------------------------------------------------------------------------

def main():
    os.makedirs(PREVIEW, exist_ok=True)

    fill_window = ART[78:150, 600:1000].reshape(-1, 3).mean(0)
    fill_inset = ART[600:750, 70:460].reshape(-1, 3).mean(0)
    fill_bronze = ART[650:830, 900:1300].reshape(-1, 3).mean(0)

    cut_frame('ui-frame', (47, 31, 1507, 973), 32, 14,
              {'top': 100, 'bottom': 100, 'left': 300, 'right': 300},
              fill_window, 18, top_from_bottom=True)
    cut_frame('ui-bronze', (518, 165, 1485, 887), 64, 16,
              {'top': 620, 'bottom': 620, 'left': 260, 'right': 260},
              fill_bronze, 18)
    cut_frame('ui-inset', (60, 176, 500, 932), 24, 12,
              {'top': 120, 'bottom': 120, 'left': 300, 'right': 600},
              fill_inset, 8)

    # Заливки - процедурный камень не меньше панели (в точках атласа):
    # окно 760x496, левая колонка 244x434, бронзовая панель 496x240.
    # Цвета - как в окне профессий клиента.
    window = stone((2048, 1024), (28, 22, 17), 1, contrast=0.8, crack=0.35)
    save(window, 'ui-fill-window')
    save(stone((512, 1024), (19, 15, 13), 2), 'ui-fill-inset')
    save(stone((1024, 512), (33, 25, 18), 3), 'ui-fill-bronze')

    # Угол заливки окна под медальоном: левый верхний квадрат 128x128 точек
    # экрана из той же заливки с прозрачным кругом под иконку. Центр и
    # радиус - в точках экрана от угла заливки; те же числа в AdvProfUI.lua.
    hole = np.asarray(window).astype(np.float64)[:256, :256].copy()
    ys, xs = np.mgrid[0:256, 0:256] + 0.5
    r = np.hypot(xs - 2 * 28, ys - 2 * 18)
    hole[..., 3] *= np.clip((r - 2 * 30) / 2.0, 0, 1)
    save(to_img(hole), 'ui-fill-window-hole')

    # Тень по краю листа чертежа.
    inner_shade('ui-shade', m=20, strength=0.6)

    # Разделитель - стальная линия под кнопками типов левой колонки, концы
    # растворены, чтобы линия не обрывалась ступенькой.
    rule = profile(100, 400, 350, 366, 1)
    shade = edge([], rule, fill_inset)
    for i, c in enumerate(rule):
        if lum(c) > lum(fill_inset) + 4:
            shade[i] = np.r_[c, 255.0]
    strip = np.array(shade)[:, None, :].repeat(64, 1)
    fade = np.clip(np.minimum(np.arange(64) + 0.5, 64 - np.arange(64) - 0.5) / 10, 0, 1)
    strip[..., 3] *= fade[None, :]
    save(to_img(pad(strip, 64, 16)), 'ui-rule')

    # Кнопки: четыре полосы по 64 строки - тёмная, горящая, главная, поле.
    sheet = np.zeros((256, 128, 4))
    rows = [
        button((1270, 90, 1457, 146), 22, (1338, 1352),
               lambda w, h: octagon_mask(w, h, 9)),
        button((1030, 88, 1256, 146), 22, (1226, 1233),
               lambda w, h: octagon_mask(w, h, 9)),
        button((1199, 901, 1477, 957), 40, (1250, 1290),
               lambda w, h: arrow_mask(w, h, 14)),
        button((145, 140, 421, 183), 22, (300, 390),
               lambda w, h: octagon_mask(w, h, 7), mirror_left=True),
    ]
    for i, part in enumerate(rows):
        sheet[i * 64:i * 64 + part.shape[0], :part.shape[1]] = part
        print('  btn row %d: %dx%d' % (i, part.shape[1], part.shape[0]))
    save(to_img(sheet), 'ui-button')

    # Медальон: кольцо без шипов, середина прозрачна под иконку.
    cx, cy, r = fit_circle((0, 0, 200, 200), 55, 80, (95, 97))
    print('  medallion center %.1f %.1f r %.1f' % (cx, cy, r))
    rmax = 82.0
    p = polar(cx, cy, rmax, 329, 1440)
    p = heal(p, [(-104, -76), (-180, -170), (170, 180), (-8, 8), (82, 98)])
    save(from_polar(p, rmax, 256, 57.0, 77.5), 'ui-ring')

    cx, cy, r = fit_circle((60, 440, 145, 520), 20, 40, (102, 478))
    print('  row ring center %.1f %.1f r %.1f' % (cx, cy, r))
    p = polar(cx, cy, 36.0, 145, 720)
    save(from_polar(p, 36.0, 64, 25.5, 34.5, 0.8), 'ui-ring-small')

    # Ячейки: обычная и выбранная, только рамка - иконку кладёт аддон.
    def slot(box, inset):
        x0, y0, x1, y1 = box
        rgb = ART[y0:y1, x0:x1]
        h, w = rgb.shape[:2]
        ys, xs = np.mgrid[0:h, 0:w] + 0.5
        d = np.minimum(np.minimum(xs, w - xs), np.minimum(ys, h - ys))
        a = np.clip(inset + 1 - d, 0, 1) * 255.0
        return np.dstack([rgb, a])
    cells = np.zeros((64, 128, 4))
    normal = slot((150, 202, 214, 266), 7)
    active = slot((76, 201, 140, 265), 9)
    # В правом нижнем углу выбранной ячейки рамку пересекает рукоять меча.
    active[:, 32:] = active[:, 31::-1]
    cells[:64, :64] = normal
    cells[:64, 64:128] = active
    save(to_img(cells), 'ui-slot')

    # Строка списка: выбранная (золото слева направо) и линия между строками.
    band = ART[372:437, 58:470]
    vert = ART[372:437, 300:460].mean(axis=1)
    horiz = lum(ART[379:389, 58:470].mean(axis=0))
    horiz[:140 - 58] = horiz[140 - 58]
    ref = horiz[300 - 58:460 - 58].mean()
    gain = (horiz / ref)[None, :, None]
    sel = np.clip(vert[:, None, :] * gain, 0, 255)
    base = np.asarray(fill_inset)
    a = np.clip((lum(sel) - lum(base)) / 40.0, 0, 1) * 0.5 + 0.5
    sel = np.dstack([sel, a * 255.0])
    img = to_img(sel).resize((256, 64), Image.LANCZOS)
    save(img, 'ui-row')
    del band

    # Значки поля поиска и фильтра.
    icons = np.zeros((64, 128, 4))
    dark = ART[150:175, 190:200].reshape(-1, 3).mean(0)
    def grey(icon):
        icon[..., :3] = lum(icon[..., :3])[..., None]
        return icon
    icons[0:33, 0:36] = grey(lift((149, 142, 185, 175), dark, 70))
    icons[0:30, 40:70] = grey(lift((442, 145, 472, 175), dark, 90))
    icons[0:18, 80:100] = lift((546, 149, 566, 167), dark, 70)
    save(to_img(icons), 'ui-icons')

    # Рисунки-наложения под списком (decor-*): 256x256, рисунок прижат к
    # левому нижнему углу.
    decor = lift((60, 752, 250, 940), fill_inset, 16, unblend=False)
    # На фактурном камне рисунок теряется: высветлен в полтора раза.
    decor[..., :3] = np.clip(decor[..., :3] * 1.5, 0, 255)
    save(to_img(pad(decor, 256, 256, 0, 256 - decor.shape[0])), 'decor-anvil')

    # Объём полосы навыка: блик сверху, тень снизу, светлая кромка у самого
    # верха. Кладётся поверх заливки обычным смешением.
    gy = (np.arange(64) + 0.5) / 64
    gloss = np.zeros((64, 16, 4))
    top_light = np.clip(1 - gy / 0.45, 0, 1) ** 1.5 * 0.38
    bottom_dark = np.clip((gy - 0.55) / 0.45, 0, 1) ** 1.3 * 0.45
    gloss[..., :3] = np.where((top_light > 0)[:, None, None], 255.0, 0.0)
    gloss[..., 3] = np.maximum(top_light, bottom_dark)[:, None] * 255
    gloss[2:4, :, :3] = 255
    gloss[2:4, :, 3] = 0.55 * 255
    save(to_img(gloss), 'ui-gloss')

    # Свечение работы на кнопке действия - нутро горящей кнопки, высветленное.
    glow = ART[97:137, 1100:1110].mean(axis=1)
    glow = np.clip(glow * 1.9 + 12, 0, 255)
    work = np.dstack([glow[:, None, :].repeat(16, 1), np.full((40, 16), 255.0)])
    save(to_img(pad(work, 16, 64)), 'ui-work')

    # Ползунок прокрутки - поперечный срез бронзы, вдоль однородный.
    bronze = profile(480, 516, 300, 480, 0)
    thumb = np.array(edge(bronze[10:25], [], fill_bronze))
    thumb = np.concatenate([thumb, thumb[::-1]])[None, :, :].repeat(64, 0)
    end = np.clip(np.minimum(np.arange(64) + 0.5, 64 - np.arange(64) - 0.5) / 3, 0, 1)
    thumb[..., 3] *= end[:, None]
    save(to_img(pad(thumb, 32, 64)), 'ui-thumb')


# --- шапка окна переплавки ----------------------------------------------------
# Макет mockup-smelt.png. Шапка - два слоя одного размера: арка (обод,
# навершия стыков, нижняя планка и стена внутри) общая для всех верстаков,
# рисунок верстака - свой у каждого вида. Тело окна под шапкой собирается из
# общих элементов. Рама тела макета - SMELT_BODY точек по ширине, окно - 280
# точек экрана.
SMELT = os.path.join(HERE, 'mockups', 'mockup-smelt.png')
SMELT_BODY = 622.0
WALL = os.path.join(HERE, 'mockups', 'wall-stone-panel.png')
# Арка: окружность внешней кромки, центр на нижней планке; ARCH_INNER -
# радиус проёма внутри обода.
ARCH = (495.3, 354.0, 274.5)
ARCH_INNER = 232.5
# Верхняя и нижняя кромки планки; ниже планки начинается тело окна.
BAR_TOP = 343
HEAD_BOTTOM = 357.5
# Навершие левого стыка; правое - оно же, отражённое относительно центра арки.
HEAD_CAP = [(233, 273), (224, 282), (196, 311), (172, 315), (172, 357.5),
            (246, 357.5), (246, 324), (241, 281)]
HEAD_BAR = [(180, BAR_TOP), (811, BAR_TOP), (811, 357.5), (180, 357.5)]
# Труба горна над ободом.
FORGE_CHIMNEY = [(600, 53), (555, 91), (558, 96), (572, 97), (572, 175),
                 (654, 175), (654, 138), (619, 128), (619, 97), (634, 96),
                 (640, 92)]
# Стена и пол, которые rembg принимает за рисунок: слева от пресса (выступы -
# концы перекладин), над перекладиной и между стойками пресса (выше и ниже
# тяги), справа от правой стойки и пол справа под основанием горна.
FORGE_WALL = [[(255, 100), (330, 100), (330, 180), (311, 180), (311, 209),
               (330, 209), (330, 269), (311, 269), (311, 300), (330, 300),
               (330, 346), (255, 346)],
              [(330, 112), (428, 112), (428, 152), (391, 167), (391, 153),
               (330, 152)],
              [(475, 112), (520, 112), (520, 158), (475, 172)],
              [(391, 186), (428, 176), (428, 190), (391, 201)],
              [(391, 212), (428, 198), (428, 234), (391, 234)],
              [(702, 290), (745, 290), (745, 346), (654, 346), (667, 334),
               (687, 318), (699, 297)]]
# Верёвка груза между стойками пресса - внутри выреза стены.
FORGE_ROPE = [(402, 199), (414, 197), (419, 215), (420, 234), (404, 234),
              (404, 215)]
# Свечение горна на стене: источник у устья, полуоси по горизонтали и
# вертикали, цвет и сила.
FORGE_GLOW = (ARCH[0], 343, 230, 135, (255, 105, 30), 0.45)
# Части рисунка, лежащие на ободе или теряемые rembg: верх левой стойки
# пресса, левые концы его перекладин, верхний конец наклонной балки у трубы.
FORGE_BEAMS = [[(331, 159), (334, 156), (386, 156), (390, 159), (390, 205),
                (331, 205)],
               [(311, 183), (335, 182), (335, 209), (311, 208)],
               [(311, 272), (358, 271), (358, 299), (311, 299)],
               [(535, 130), (574, 116), (580, 118), (580, 133), (535, 146)]]
FORGE_BOX = (250, 45, 745, 345)
# Размер шапки в атласе: вдвое крупнее показа (296x140 точек экрана).
HEAD_SIZE = (592, 280)


def wall_texture(w, h):
    """Стена проёма: тёмная текстура stone-panel из админ-панели
    (mockups/wall-stone-panel.png) в своём цвете, плиткой."""
    src = np.asarray(Image.open(WALL).convert('RGB')).astype(np.float64)
    reps = (h // src.shape[0] + 1, w // src.shape[1] + 1, 1)
    return np.tile(src, reps)[:h, :w]


def head_box():
    s = SMELT_BODY / 560.0
    w, h = HEAD_SIZE[0] * s, HEAD_SIZE[1] * s
    cx = ARCH[0]
    return (cx - w / 2, HEAD_BOTTOM - h, cx + w / 2, HEAD_BOTTOM)


def head_mask(shapes, k=4):
    """Маска фигур макета, сведённая к размеру шапки. shapes - список
    ('pie', r) или ('poly', точки) или ('cut', точки) - вычесть."""
    w, h = Image.open(SMELT).size
    mask = Image.new('L', (w * k, h * k), 0)
    draw = ImageDraw.Draw(mask)
    cx, cy, _ = ARCH
    for kind, arg in shapes:
        if kind == 'pie':
            draw.pieslice([(cx - arg) * k, (cy - arg) * k, (cx + arg) * k,
                           (cy + arg) * k], 180, 360, fill=255)
        else:
            draw.polygon([(x * k, y * k) for x, y in arg],
                         fill=0 if kind == 'cut' else 255)
    return mask, k


def to_head(arr, box):
    """Плоскость макета (h, w[, c]) в размер шапки."""
    if arr.ndim == 2:
        img = Image.fromarray(arr.astype(np.float32), 'F')
        return np.asarray(img.resize(HEAD_SIZE, Image.BOX, box=box))
    planes = [to_head(arr[..., i], box) for i in range(arr.shape[2])]
    return np.dstack(planes)


def mask_head(mask, k, box):
    return np.asarray(mask.resize(HEAD_SIZE, Image.BOX,
                                  box=tuple(v * k for v in box))) / 255.0


def atlas(rgba, name):
    out = np.zeros((512, 1024, 4))
    out[:rgba.shape[0], :rgba.shape[1]] = rgba
    save(to_img(out), name)


def forge_alpha(img):
    """Рисунок горна на макете: rembg (BiRefNet) по проёму арки, обод и
    стена закрашены заранее, затем ручные поправки FORGE_WALL."""
    from rembg import remove, new_session
    cx, cy, _ = ARCH
    keep, k = head_mask([('pie', ARCH_INNER), ('poly', FORGE_CHIMNEY)])
    keep = np.asarray(keep.resize(img.size, Image.BOX)) / 255.0
    keep[int(BAR_TOP):] = 0
    src = (np.asarray(img).astype(np.float64) * keep[..., None])
    src = Image.fromarray(src.astype(np.uint8)).crop(FORGE_BOX)
    cut = remove(src, session=new_session('birefnet-general'))
    alpha = np.zeros(keep.shape)
    x0, y0, x1, y1 = FORGE_BOX
    alpha[y0:y1, x0:x1] = np.asarray(cut)[..., 3] / 255.0
    wall, _ = head_mask([('poly', w) for w in FORGE_WALL]
                        + [('cut', FORGE_ROPE)], k=1)
    alpha *= 1 - np.asarray(wall) / 255.0
    beams, _ = head_mask([('poly', b) for b in FORGE_BEAMS])
    beams = np.asarray(beams.resize(img.size, Image.BOX)) / 255.0
    return np.maximum(alpha * keep, beams)


def smelt():
    os.makedirs(PREVIEW, exist_ok=True)
    img = Image.open(SMELT).convert('RGB')
    rgb = np.asarray(img).astype(np.float64)
    box = head_box()
    cx, cy, _ = ARCH

    # Рисунок верстака: цвет умножен на прозрачность до сжатия, иначе по
    # краю проступит стена.
    alpha = forge_alpha(img)
    a = to_head(alpha, box)
    c = to_head(rgb * alpha[..., None], box)
    c = c / np.maximum(a, 1e-4)[..., None]
    atlas(np.dstack([c, np.clip(a, 0, 1) * 255]), 'station-forge')

    # Арка: обод под трубой и балками - срезы обода по радиусу слева и справа
    # от предмета (медиана по углам вплотную к нему),
    # между ними - плавный переход.
    rim = rgb.copy()
    for poly in FORGE_BEAMS + [FORGE_CHIMNEY]:
        under, _ = head_mask([('poly', poly)], k=1)
        ys, xs = np.nonzero(np.asarray(under))
        r = np.hypot(xs - cx, cy - ys)
        t = np.arctan2(cy - ys, xs - cx)
        side = np.radians(np.arange(0.5, 2.5, 0.25))
        ring = np.round(r).astype(int)
        for rad in np.unique(ring):
            sel = ring == rad
            t0, t1 = t[sel].min(), t[sel].max()

            def profile(angles):
                return np.median(bilinear(rgb, cx + rad * np.cos(angles),
                                          cy - rad * np.sin(angles)), axis=0)
            f = ((t[sel] - t0) / max(t1 - t0, 1e-6))[:, None]
            rim[ys[sel], xs[sel]] = (profile(t0 - side) * (1 - f)
                                     + profile(t1 + side) * f)
    arch_rgb = to_head(rim, box)

    # Стена проёма: тёмная текстура панели, светлее к середине и темнее у
    # обода.
    inner, k = head_mask([('pie', ARCH_INNER)])
    wall_rgb = wall_texture(HEAD_SIZE[0], HEAD_SIZE[1])
    s = 560.0 / SMELT_BODY
    ys, xs = np.mgrid[0:HEAD_SIZE[1], 0:HEAD_SIZE[0]] + 0.5
    hx = (cx - box[0]) * s
    hy = (cy - box[1]) * s
    d = np.hypot(xs - hx, ys - hy) / (ARCH_INNER * s)
    light = 1.25 - 0.55 * d ** 2
    lip = np.clip((1 - d) * ARCH_INNER * s / 14.0, 0, 1) * 0.65 + 0.35
    wall = wall_rgb * (light * lip)[..., None]
    im = mask_head(inner, k, box)
    im[int(round((BAR_TOP - box[1]) * s)):] = 0
    arch_rgb = arch_rgb * (1 - im[..., None]) + wall * im[..., None]

    # Свечение горна: отдельный слой стены (наложение сложением), окно
    # меняет его прозрачность, как от огня.
    gx, gy, rx, ry, color, power = FORGE_GLOW
    g = np.exp(-((xs - (gx - box[0]) * s) / (rx * s)) ** 2
               - ((ys - (gy - box[1]) * s) / (ry * s)) ** 2) * power * im
    glow = np.dstack([np.broadcast_to(np.array(color, float), g.shape + (3,)),
                      g * 255])
    atlas(glow, 'station-forge-glow')

    # Искра: белое пятно, цвет задаёт окно.
    ey, ex = np.mgrid[0:32, 0:32] + 0.5
    spot = np.clip(1 - np.hypot(ex - 16, ey - 16) / 16, 0, 1) ** 2
    save(to_img(np.dstack([np.full((32, 32, 3), 255.0), spot * 255])),
         'ember')

    right = [(2 * cx - x, y) for x, y in HEAD_CAP]
    shape, k = head_mask([('pie', ARCH[2]), ('poly', HEAD_CAP),
                          ('poly', right), ('poly', HEAD_BAR)])
    ImageDraw.Draw(shape).rectangle([0, HEAD_BOTTOM * k, shape.width,
                                     shape.height], fill=0)
    atlas(np.dstack([arch_rgb, mask_head(shape, k, box) * 255]), 'ui-arch')


# --- рисунок ткацкого станка --------------------------------------------------
# Макет mockup-loom.png: арка и тело окна те же, что у макета горна, точка в
# точку; из макета берётся только рисунок станка. Каждая часть рисунка - свой
# проход rembg по своему окну: (окно, оставляемая область).
LOOM = os.path.join(HERE, 'mockups', 'mockup-loom.png')
LOOM_PARTS = [
    # станок; верх стоек и навой лежат на ободе
    ((250, 70, 745, 345), None),
    # корзина с клубками справа, без занавеси и стены за ней
    ((595, 220, 725, 343), [(608, 343), (608, 262), (622, 251), (645, 252),
                            (652, 240), (668, 232), (690, 232), (704, 242),
                            (708, 256), (716, 262), (718, 343)])]
LOOM_TOP = [(380, 76), (632, 76), (632, 165), (380, 165)]
# Обод между стойками над навоем, который rembg принимает за станок.
LOOM_RIM = [(423, 70), (581, 70), (581, 96), (423, 96)]
# Свет из окна на стене: полоса от верхнего левого края проёма вниз вправо, в
# точках шапки (296x140) - начало, конец, полуширина; цвет и сила.
LOOM_SHAFT = ((58, 30), (190, 136), 26, (255, 228, 170), 0.45)


def shaft(xs, ys, scale=1.0):
    """Сила света полосы LOOM_SHAFT в точке (в точках шапки * scale)."""
    (x0, y0), (x1, y1), half, _, _ = LOOM_SHAFT
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    px, py = xs / scale - x0, ys / scale - y0
    along = np.clip((px * dx + py * dy) / length ** 2, 0, 1)
    across = (px * dy - py * dx) / length / half
    return np.exp(-across ** 2) * (1 - 0.6 * along) * np.clip(along * 6, 0, 1)


def loom_alpha(img):
    from rembg import remove, new_session
    session = new_session('birefnet-general')
    keep, k = head_mask([('pie', ARCH_INNER), ('poly', LOOM_TOP)])
    keep = np.asarray(keep.resize(img.size, Image.BOX)) / 255.0
    keep[int(BAR_TOP):] = 0
    src = Image.fromarray((np.asarray(img).astype(np.float64)
                           * keep[..., None]).astype(np.uint8))
    alpha = np.zeros(keep.shape)
    for box, area in LOOM_PARTS:
        cut = np.asarray(remove(src.crop(box), session=session))[..., 3]
        part = np.zeros(keep.shape)
        x0, y0, x1, y1 = box
        part[y0:y1, x0:x1] = cut / 255.0
        if area:
            only, _ = head_mask([('poly', area)], k=1)
            part *= np.asarray(only) / 255.0
        alpha = np.maximum(alpha, part)
    rim, _ = head_mask([('poly', LOOM_RIM)], k=1)
    alpha *= 1 - np.asarray(rim) / 255.0
    return alpha * keep


def loom():
    os.makedirs(PREVIEW, exist_ok=True)
    img = Image.open(LOOM).convert('RGB')
    rgb = np.asarray(img).astype(np.float64)
    box = head_box()
    alpha = loom_alpha(img)
    a = to_head(alpha, box)
    c = to_head(rgb * alpha[..., None], box)
    c = c / np.maximum(a, 1e-4)[..., None]
    atlas(np.dstack([c, np.clip(a, 0, 1) * 255]), 'station-loom')

    # Свет на стене: слой сложением, как свечение горна; окно медленно меняет
    # его прозрачность.
    inner, k = head_mask([('pie', ARCH_INNER)])
    im = mask_head(inner, k, box)
    s = 560.0 / SMELT_BODY
    im[int(round((BAR_TOP - box[1]) * s)):] = 0
    ys, xs = np.mgrid[0:HEAD_SIZE[1], 0:HEAD_SIZE[0]] + 0.5
    color, power = LOOM_SHAFT[3], LOOM_SHAFT[4]
    g = shaft(xs, ys, HEAD_SIZE[0] / 296.0) * power * im
    glow = np.dstack([np.broadcast_to(np.array(color, float), g.shape + (3,)),
                      g * 255])
    atlas(glow, 'station-loom-glow')


# --- рисунки со снимков игры -------------------------------------------------
# Верстак со снимка из игры вырезается целиком и ставится по центру проёма
# арки. Подпись игры поверх рисунка закрашивается по столбцам между строками
# над и под ней. Высота рисунка - от планки до SNAP_TOP точек атласа шапки,
# умноженная на scale; низ уходит за планку на sink точек атласа и срезается
# по её верхней кромке; rise - насколько слой рисунка поднимается над шапкой
# (в окне - вдвое меньше, Smelt.lua STATIONS.rise). text - (x0, y0, x1, y1)
# полосы подписи на снимке.
SNAP_TOP = 8
SNAPSHOTS = {
    'tanning': dict(src='station-tanning-rack.png', text=(440, 480, 9999, 530),
                    scale=1.685, sink=181, rise=48),
    'disenchant': dict(src='station-disenchant-table.png',
                       text=(240, 555, 560, 605), scale=1.17, sink=55, rise=0),
}
# Синее свечение стены у стола распыления: ровный фон по проёму и пятно за
# столом (центр над планкой, полуоси), цвет.
DISENCHANT_GLOW = (0.15, 0.5, 120, 175, 135, (70, 140, 255))


def snapshot_cut(spec):
    """Снимок без подписи игры и прозрачность вырезанного верстака."""
    from rembg import remove, new_session
    path = os.path.join(HERE, 'mockups', spec['src'])
    rgb = np.asarray(Image.open(path).convert('RGB')).astype(np.float64)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    ys, xs = np.mgrid[0:rgb.shape[0], 0:rgb.shape[1]]
    x0, y0, x1, y1 = spec['text']
    text = ((r > 150) & (g > 120) & (b < 100) & (g / (r + 1) > 0.72)
            & (ys > y0) & (ys < y1) & (xs > x0) & (xs < x1))
    text = np.asarray(Image.fromarray((text * 255).astype(np.uint8))
                      .filter(ImageFilter.MaxFilter(7))) > 0
    clean = rgb.copy()
    for x in range(rgb.shape[1]):
        rows = np.nonzero(text[:, x])[0]
        if not len(rows):
            continue
        top, bottom = rows.min() - 1, rows.max() + 1
        t = ((np.arange(top + 1, bottom) - top) / (bottom - top))[:, None]
        clean[top + 1:bottom, x] = rgb[top, x] * (1 - t) + rgb[bottom, x] * t
    cut = remove(Image.fromarray(clean.astype(np.uint8)),
                 session=new_session('birefnet-general'))
    return clean, np.asarray(cut)[..., 3] / 255.0


def head_floor():
    """Пол проёма (верх планки) и центр арки в точках атласа шапки, маска
    проёма над планкой."""
    s = 560.0 / SMELT_BODY
    hbox = head_box()
    floor = (BAR_TOP - hbox[1]) * s
    cx = (ARCH[0] - hbox[0]) * s
    inner, k = head_mask([('pie', ARCH_INNER)])
    im = mask_head(inner, k, hbox)
    im[int(round(floor)):] = 0
    return floor, cx, im


def snapshot(name):
    os.makedirs(PREVIEW, exist_ok=True)
    spec = SNAPSHOTS[name]
    clean, alpha = snapshot_cut(spec)
    rows, cols = np.nonzero(alpha > 0.5)
    box = (cols.min(), rows.min(), cols.max() + 1, rows.max() + 1)
    floor, cx, _ = head_floor()
    h = int(round((floor - SNAP_TOP) * spec['scale']))
    k = h / (box[3] - box[1])
    w = int(round((box[2] - box[0]) * k))
    base = int(round(floor + spec['rise']))
    top = base + spec['sink'] - h

    def fit(plane):
        img = Image.fromarray(plane.astype(np.float32), 'F')
        return np.asarray(img.resize((w, h), Image.BOX, box=box))
    a = fit(alpha)
    c = np.dstack([fit(clean[..., i] * alpha) for i in range(3)])
    c = c / np.maximum(a, 1e-4)[..., None]
    out = np.zeros((HEAD_SIZE[1] + spec['rise'], HEAD_SIZE[0], 4))
    left = int(round(cx - w / 2))
    out[top:base, left:left + w] = np.dstack(
        [c, np.clip(a, 0, 1) * 255])[:base - top]
    atlas(out, 'station-' + name)


def glow_layer(g, color, name):
    atlas(np.dstack([np.broadcast_to(np.array(color, float), g.shape + (3,)),
                     g * 255]), name)


def tanning():
    snapshot('tanning')
    # Свет на стене - тот же, что у прядильного станка.
    _, _, im = head_floor()
    gy, gx = np.mgrid[0:HEAD_SIZE[1], 0:HEAD_SIZE[0]] + 0.5
    glow = shaft(gx, gy, HEAD_SIZE[0] / 296.0) * LOOM_SHAFT[4] * im
    glow_layer(glow, LOOM_SHAFT[3], 'station-tanning-glow')


def disenchant():
    snapshot('disenchant')
    floor, cx, im = head_floor()
    base, power, lift, rx, ry, color = DISENCHANT_GLOW
    gy, gx = np.mgrid[0:HEAD_SIZE[1], 0:HEAD_SIZE[0]] + 0.5
    spot = np.exp(-((gx - cx) / rx) ** 2 - ((gy - floor + lift) / ry) ** 2)
    glow_layer(np.clip(base + power * spot, 0, 1) * im, color,
               'station-disenchant-glow')


if __name__ == '__main__':
    if sys.argv[1:] == ['smelt']:
        smelt()
    elif sys.argv[1:] == ['loom']:
        loom()
    elif sys.argv[1:] == ['tanning']:
        tanning()
    elif sys.argv[1:] == ['disenchant']:
        disenchant()
    else:
        main()
