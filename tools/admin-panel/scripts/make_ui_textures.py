#!/usr/bin/env python3
"""Рисует текстуры интерфейса панели: рамку-девятку и камень под панелями.

Почему кодом, а не картинкой: рамка должна ТОЧНО ложиться в `border-image`,
то есть её кромка обязана быть ровно той ширины, что указана в CSS, и
повторяться по стороне без шва. Подобрать это в рисовалке можно, но каждый
следующий подбор начинается сначала; здесь же ширины и цвета - параметры
вверху файла.

Что получается:

  * `frame-gold.png` - бронзовая кромка девяткой (`border-image-slice`).
    Кромка собрана слоями: чёрный кант снаружи, тёмная бронза, золотая
    полоса со светом сверху и тенью снизу, светлая нить внутри и чёрный кант
    к содержимому. В углах - накладка с заклёпкой: у игровых рамок угол
    всегда тяжелее стороны, без этого кромка читается как обычный бордюр.
    Середина прозрачная - фон панели рисует CSS, а не текстура.

  * `stone-panel.png` - тёмный камень под панелями, 256x256, бесшовный.
    Шум сглаживается на утроенном полотне и обрезается по центру - тогда
    противоположные края сходятся сами.

Запуск (нужен Pillow + numpy; в контейнере панели их нет - гоняем локально):

    python tools/admin-panel/scripts/make_ui_textures.py
"""

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "frontend", "public", "textures")

# --- рамка ---------------------------------------------------------------

# Ширина кромки в пикселях. Ровно это число идёт в CSS: `border-width` и
# `border-image-slice`. Середина 24 пикселя - её повторяют по стороне.
EDGE = 12
FRAME = EDGE * 2 + 24

# Цвета замерены с классических текстур игры (Gethe/wow-ui-textures, ветка
# classic): UI-DialogBox-Gold-Border даёт полосу #735921 со светом до #b5aa73,
# UI-DialogBox-Gold-Corner - накладку #bdaa73 с бликом #f7ebce. Золото там
# бурое и приглушённое: лимонное рядом с игровым окном видно сразу.
#
# Слои кромки снаружи внутрь: (толщина, цвет сверху, цвет снизу).
LAYERS = (
    (1, (0, 0, 0, 255), (0, 0, 0, 255)),
    (2, (16, 8, 0, 255), (8, 4, 0, 255)),
    (5, (181, 170, 115, 255), (88, 67, 27, 255)),
    (1, (199, 184, 124, 255), (58, 43, 17, 255)),
    (3, (8, 6, 4, 255), (8, 6, 4, 255)),
)

RIVET = (247, 235, 206, 255)
RIVET_EDGE = (30, 22, 8, 255)


def _blend(top, bottom, t):
    return tuple(int(round(a + (b - a) * t)) for a, b in zip(top, bottom))


def frame() -> Image.Image:
    """Кромка девяткой: слои рисуются прямоугольниками внутрь."""
    img = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    offset = 0
    for thickness, top, bottom in LAYERS:
        for step in range(thickness):
            line = offset + step
            # Свет сверху, тень снизу: цвет берётся по месту на полосе.
            shade = _blend(top, bottom, (step + 0.5) / thickness)
            draw.rectangle(
                [line, line, FRAME - 1 - line, FRAME - 1 - line],
                outline=shade,
            )
        offset += thickness

    # Угловая накладка: плашка со скошенным светом и ромбом посередине.
    # Рисуется в левом верхнем углу и разворачивается на остальные три -
    # иначе свет на них уедет не туда.
    corner = Image.new("RGBA", (EDGE, EDGE), (0, 0, 0, 0))
    mark = ImageDraw.Draw(corner)
    mark.rectangle([0, 0, EDGE - 1, EDGE - 1], fill=(118, 102, 54, 255),
                   outline=(0, 0, 0, 255))
    mark.rectangle([1, 1, EDGE - 3, EDGE - 3], fill=(189, 170, 115, 255))
    mark.line([1, 1, EDGE - 3, 1], fill=(247, 235, 206, 255))
    mark.line([1, 1, 1, EDGE - 3], fill=(247, 235, 206, 255))
    mark.line([2, EDGE - 2, EDGE - 2, EDGE - 2], fill=(40, 30, 12, 255))
    mid = EDGE // 2
    gem = 3
    mark.polygon([(mid, mid - gem), (mid + gem, mid), (mid, mid + gem),
                  (mid - gem, mid)], fill=RIVET, outline=RIVET_EDGE)

    img.paste(corner, (0, 0), corner)
    img.paste(corner.transpose(Image.FLIP_LEFT_RIGHT), (FRAME - EDGE, 0),
              corner.transpose(Image.FLIP_LEFT_RIGHT))
    img.paste(corner.transpose(Image.FLIP_TOP_BOTTOM), (0, FRAME - EDGE),
              corner.transpose(Image.FLIP_TOP_BOTTOM))
    turned = corner.transpose(Image.ROTATE_180)
    img.paste(turned, (FRAME - EDGE, FRAME - EDGE), turned)
    return img


# --- камень --------------------------------------------------------------

STONE = 256
# Тёмный тёплый камень: панель под текстом, поэтому разброс яркости узкий.
STONE_LOW = np.array([10, 10, 9], dtype=float)
STONE_HIGH = np.array([34, 31, 27], dtype=float)


def _seamless_noise(size: int, blur: float, seed: int) -> np.ndarray:
    """Шум, у которого сходятся противоположные края.

    Сглаживание размывает края внутрь, поэтому размываем утроенное полотно и
    берём середину: к её краям подмешан тот же шум, что и с другой стороны.
    """
    rng = np.random.default_rng(seed)
    base = rng.random((size, size))
    wide = np.tile(base, (3, 3))
    smooth = Image.fromarray((wide * 255).astype(np.uint8), "L")
    smooth = smooth.filter(ImageFilter.GaussianBlur(blur))
    middle = np.asarray(smooth, dtype=float)[size:size * 2, size:size * 2]
    lo, hi = middle.min(), middle.max()
    return (middle - lo) / (hi - lo if hi > lo else 1)


def stone() -> Image.Image:
    coarse = _seamless_noise(STONE, 9, 20260917)
    fine = _seamless_noise(STONE, 1.6, 7)
    grit = _seamless_noise(STONE, 0.6, 42)
    # Крупные пятна держат форму камня, мелкий шум - зерно, крупинки чуть
    # подсветляют. Веса подобраны так, чтобы текст поверх оставался читаемым.
    mix = np.clip(coarse * 0.62 + fine * 0.3 + (grit ** 3) * 0.18, 0, 1)
    rgb = STONE_LOW + (STONE_HIGH - STONE_LOW) * mix[..., None]
    return Image.fromarray(rgb.astype(np.uint8), "RGB")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    made = (("frame-gold.png", frame()), ("stone-panel.png", stone()))
    for name, image in made:
        path = os.path.normpath(os.path.join(OUT, name))
        image.save(path)
        print("%s  %dx%d" % (path, image.width, image.height))
    print("кромка: border-width %dpx, border-image-slice %d" % (EDGE, EDGE))


if __name__ == "__main__":
    main()
