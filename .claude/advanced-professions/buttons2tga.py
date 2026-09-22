# -*- coding: utf-8 -*-
"""Нарезка полосы кнопок режима (кнопки.png) на шесть TGA.

В исходнике шесть кнопок: слева горящие (выбранная вкладка), справа погасшие,
по строке на режим. Подписи ВПЕЧАТАНЫ в арт, поэтому своей надписи поверх не
рисуем - иначе она легла бы на нарисованную.

Две вещи, из-за которых нельзя резать по границам самих кнопок:

* горящая кнопка ШИРЕ погасшей (773 против 732 - у неё крупнее золотые углы).
  Режь каждую по её же рамке, и вкладка прыгала бы в размере при переключении.
  Поэтому все шесть берутся ОДНИМ размером, каждая - по своему центру;
* холст обязан быть степенью двойки, а 780x190 - нет. Кладём в 512x128,
  предварительно ужав: на экране кнопка выходит примерно 174x42 настоящих точек
  (124x30 условных при UI-масштабе 1.4), так что 512 - с запасом, а полный
  размер занял бы 1 МБ на кнопку вместо 262 КБ.

Запуск (путь к исходнику - аргумент, в репозиторий он не копируется):
    python buttons2tga.py <кнопки.png>
"""
import os
import sys
from PIL import Image

DST = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    '..', '..', 'modules', 'mod-advanced-professions',
    'ClientAddon', 'AdvProfUI', 'textures'))

# Центры шести кнопок, снятые по альфе исходника.
CENTERS = {
    'tab-craft-on':  (485, 196),
    'tab-craft':     (1324, 196),
    'tab-inlay-on':  (483, 442),
    'tab-inlay':     (1323, 442),
    'tab-merge-on':  (484, 699),
    'tab-merge':     (1324, 699),
}
BOX_W, BOX_H = 780, 190          # общий размер выреза, по самой крупной кнопке
TEX_W, TEX_H = 512, 128          # холст степени двойки
FIT_W = 512
FIT_H = int(round(BOX_H * FIT_W / float(BOX_W)))   # 125


def write_tga(img, path):
    w, h = img.size
    px = img.load()
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    w & 0xFF, (w >> 8) & 0xFF,
                    h & 0xFF, (h >> 8) & 0xFF,
                    32, 8])
    body = bytearray()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            r, g, b, a = px[x, y]
            body += bytes((b, g, r, a))
    with open(path, 'wb') as f:
        f.write(header)
        f.write(body)
    return len(header) + len(body)


def main(src):
    art = Image.open(src).convert('RGBA')
    print('-- координаты для Lua:')
    for name, (cx, cy) in sorted(CENTERS.items()):
        piece = art.crop((cx - BOX_W // 2, cy - BOX_H // 2,
                          cx + BOX_W // 2, cy + BOX_H // 2))
        piece = piece.resize((FIT_W, FIT_H), Image.LANCZOS)
        canvas = Image.new('RGBA', (TEX_W, TEX_H), (0, 0, 0, 0))
        canvas.paste(piece, (0, 0))
        size = write_tga(canvas, os.path.join(DST, name + '.tga'))
        piece.save(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                'preview-%s.png' % name))
        print('    ["%s"] = { %.6f, %.6f },   -- %dx%d, %d байт' %
              (name, FIT_W / float(TEX_W), FIT_H / float(TEX_H),
               FIT_W, FIT_H, size))


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
