# -*- coding: utf-8 -*-
"""PNG -> TGA (32bpp, origin внизу) для герба профессии в медальоне окна.

Медальон в левом верхнем углу скина - это ДЫРКА: в арте там альфа 0, и сквозь
неё виден игровой мир. Аддон закрывает её гербом. Раньше туда клали иконку
клиента (`Trade_BlackSmithing`) - квадратную, поэтому её приходилось вписывать
в круг со стороной r*sqrt(2) и она занимала едва половину гнезда.

Свой герб рисуется круглым и кладётся в дырку целиком. Обрезка по кругу здесь
не украшательство, а необходимость: у гнезда нет ни рамки, ни фона, и любой
угол картинки повис бы поверх золотого кольца.

Сторона 128 - вдвое больше гнезда (66 условных единиц), с запасом на UI-масштаб:
при 1080p на единицу приходится около 1.4 точки, и текстура 64 в это гнездо
увеличивалась бы и мылила.

Запуск:
    python emblem2tga.py <исходный.png> [результат.tga]
"""
import os
import sys
from PIL import Image

SIZE = 128
FEATHER = 1.5          # точки, на которых край круга уходит в прозрачность

# Доля исходника, которая идёт в дело. У кузни нарисовано СВОЁ каменное кольцо,
# а гнездо в скине уже обрамлено золотым - вместе получалось три кольца подряд
# (золото, белая фаска скина, камень картинки). Отрезаем внешнюю кайму
# исходника и оставляем только сцену: её край как раз уходит под фаску.
CROP = 0.86

DST_DEFAULT = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    '..', '..', 'modules', 'mod-advanced-professions',
    'ClientAddon', 'AdvProfUI', 'textures', 'emblem.tga'))


def convert(src, dst):
    img = Image.open(src).convert('RGBA')
    side = min(img.size)
    inset = int(side * (1.0 - CROP) / 2.0)
    img = img.crop((inset, inset, img.size[0] - inset, img.size[1] - inset))
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    px = img.load()

    c = (SIZE - 1) / 2.0
    r = SIZE / 2.0 - 0.5
    for y in range(SIZE):
        for x in range(SIZE):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d <= r - FEATHER:
                continue
            t = 0.0 if d >= r else (r - d) / FEATHER
            cr, cg, cb, ca = px[x, y]
            px[x, y] = (cr, cg, cb, int(round(ca * t)))

    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    SIZE & 0xFF, (SIZE >> 8) & 0xFF,
                    SIZE & 0xFF, (SIZE >> 8) & 0xFF,
                    32, 8])
    body = bytearray()
    for y in range(SIZE - 1, -1, -1):
        for x in range(SIZE):
            cr, cg, cb, ca = px[x, y]
            body += bytes((cb, cg, cr, ca))
    with open(dst, 'wb') as f:
        f.write(header)
        f.write(body)
    print('%s  %dx%d  %d байт' % (dst, SIZE, SIZE, len(header) + len(body)))

    preview = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           'preview-emblem.png')
    img.save(preview)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else DST_DEFAULT)
