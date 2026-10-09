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

Запуск: python skin_kit.py
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


if __name__ == '__main__':
    main()
