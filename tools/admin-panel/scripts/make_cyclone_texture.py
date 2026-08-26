#!/usr/bin/env python3
"""Готовит текстуру вихря для карты погоды из готовой картинки.

Текстура лежит в `app/static/cyclone.png` и рисуется на карте под каждым
фронтом (`weather-map.js`). Скрипт нужен, чтобы её можно было перегенерировать
из исходника, а не подбирать заново руками.

Что делает:

  * режет квадрат вокруг самого вихря - по границам непрозрачных пикселей, а
    не по центру кадра: у рисованных исходников вихрь редко стоит ровно
    посередине;
  * уменьшает до SIZE. Уменьшение идёт по ПРЕДУМНОЖЕННОЙ альфе - иначе цвет
    прозрачных пикселей (у вырезанных картинок он обычно чёрный) затекает в
    кромку, и вокруг вихря появляется тёмный ободок, которого в исходнике нет;
  * если у исходника альфы нет вовсе, строит её из яркости: чёрный фон
    становится прозрачным.

Прозрачность текстуры на карте задаётся НЕ здесь, а в CSS
(`.wmap-cyclone-photo`): так её можно поменять, не трогая файл.

Запуск (нужен Pillow; в контейнере панели его нет - гоняем локально):

    python tools/admin-panel/scripts/make_cyclone_texture.py вихрь.png \\
        tools/admin-panel/app/static/cyclone.png
"""

import sys

import numpy as np
from PIL import Image

# Сторона готовой текстуры. На карте вихрь занимает около 210 пикселей в
# поперечнике, так что 320 хватает с запасом.
SIZE = 320

# Ниже этой альфы пиксель считаем фоном, когда ищем границы вихря.
EDGE_ALPHA = 8

# Порог для исходников БЕЗ альфы: ниже этой яркости считаем фоном.
KEY_FLOOR = 0.06


def load_rgba(path: str) -> np.ndarray:
    """Картинка как float RGBA 0..1. Альфы нет - строим её из яркости."""
    a = np.asarray(Image.open(path).convert("RGBA")).astype(float) / 255.0

    if a[..., 3].min() >= 1.0:
        lum = a[..., :3].max(axis=2)
        a[..., 3] = np.clip((lum - KEY_FLOOR) / (1.0 - KEY_FLOOR), 0.0, 1.0)

    return a


def square_around_vortex(a: np.ndarray) -> np.ndarray:
    """Квадратный вырез вокруг непрозрачной части."""
    solid = a[..., 3] > EDGE_ALPHA / 255.0
    if not solid.any():
        raise SystemExit("в картинке нет непрозрачных пикселей")

    ys, xs = np.where(solid)
    cy = (ys.min() + ys.max()) // 2
    cx = (xs.min() + xs.max()) // 2

    h, w = a.shape[:2]
    half = min(cy, cx, h - cy, w - cx)
    return a[cy - half:cy + half, cx - half:cx + half]


def resize_premultiplied(a: np.ndarray, size: int) -> np.ndarray:
    """Уменьшить, не затягивая цвет фона в кромку.

    Обычный resize по RGBA усредняет цвет вместе с прозрачными пикселями. У
    вырезанной картинки они чёрные, и по краю вихря появляется тёмный ободок -
    на карте он читается как обводка.
    """
    alpha = a[..., 3]
    pre = a[..., :3] * alpha[..., None]

    def shrink(chan: np.ndarray) -> np.ndarray:
        img = Image.fromarray((np.clip(chan, 0, 1) * 255).astype(np.uint8), "L")
        small = img.resize((size, size), Image.LANCZOS)
        return np.asarray(small).astype(float) / 255.0

    out_a = shrink(alpha)
    out_pre = np.stack([shrink(pre[..., i]) for i in range(3)], axis=2)

    # Обратно из предумноженного. Там, где почти прозрачно, цвет не важен, а
    # делить на такую альфу нельзя.
    safe = np.maximum(out_a, 1e-4)[..., None]
    out_rgb = np.clip(out_pre / safe, 0.0, 1.0)

    return np.dstack([out_rgb, out_a[..., None]])


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)

    src, dst = sys.argv[1], sys.argv[2]
    a = resize_premultiplied(square_around_vortex(load_rgba(src)), SIZE)

    out = (np.clip(a, 0.0, 1.0) * 255).astype(np.uint8)
    Image.fromarray(out, mode="RGBA").save(dst, optimize=True)

    solid = (out[..., 3] > EDGE_ALPHA).mean()
    print(f"{src} -> {dst}: {SIZE}x{SIZE}, непрозрачно {solid * 100:.0f}%")


if __name__ == "__main__":
    main()
