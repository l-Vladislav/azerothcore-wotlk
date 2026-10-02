# -*- coding: utf-8 -*-
"""TGA -> BLP2 (DXT5, с уровнями детализации) для текстур аддона AdvProfUI.

Клиент держит TGA в памяти несжатыми, 4 байта на точку; DXT5 - 1 байт.
Pillow пишет BLP только с палитрой, поэтому сжатие DXT5 сделано здесь.

Запуск:
    python tga2blp.py <папка textures>     - все *.tga папки, рядом *.blp
    python tga2blp.py <файл.tga> [...]
"""
import glob
import os
import struct
import sys

import numpy as np
from PIL import Image


def _to565(rgb):
    r = (rgb[..., 0] * 31 / 255 + 0.5).astype(np.uint16)
    g = (rgb[..., 1] * 63 / 255 + 0.5).astype(np.uint16)
    b = (rgb[..., 2] * 31 / 255 + 0.5).astype(np.uint16)
    return (r << 11) | (g << 5) | b


def _from565(c):
    r = ((c >> 11) & 31).astype(np.float32) * 255 / 31
    g = ((c >> 5) & 63).astype(np.float32) * 255 / 63
    b = (c & 31).astype(np.float32) * 255 / 31
    return np.stack([r, g, b], axis=-1)


def _blocks(rgba):
    h, w = rgba.shape[:2]
    ph, pw = (h + 3) // 4 * 4, (w + 3) // 4 * 4
    if (ph, pw) != (h, w):
        rgba = np.pad(rgba, ((0, ph - h), (0, pw - w), (0, 0)), mode='edge')
    b = rgba.reshape(ph // 4, 4, pw // 4, 4, 4).transpose(0, 2, 1, 3, 4)
    return b.reshape(-1, 16, 4).astype(np.float32)


def _color_part(px):
    rgb = px[..., :3]
    mean = rgb.mean(axis=1, keepdims=True)
    centered = rgb - mean
    cov = np.einsum('nki,nkj->nij', centered, centered)
    axis = np.ones((len(px), 3), np.float32)
    for _ in range(8):
        axis = np.einsum('nij,nj->ni', cov, axis)
        norm = np.linalg.norm(axis, axis=1, keepdims=True)
        axis = np.where(norm > 1e-6, axis / np.maximum(norm, 1e-6), 0.577)
    proj = np.einsum('nki,ni->nk', centered, axis)
    lo = rgb[np.arange(len(px)), proj.argmin(axis=1)]
    hi = rgb[np.arange(len(px)), proj.argmax(axis=1)]

    c0, c1 = _to565(hi), _to565(lo)
    swap = c0 < c1
    c0, c1 = np.where(swap, c1, c0), np.where(swap, c0, c1)

    e0, e1 = _from565(c0), _from565(c1)
    palette = np.stack([e0, e1, (2 * e0 + e1) / 3, (e0 + 2 * e1) / 3], axis=1)
    dist = ((rgb[:, :, None, :] - palette[:, None, :, :]) ** 2).sum(axis=-1)
    idx = dist.argmin(axis=2).astype(np.uint32)
    idx[c0 == c1] = 0

    bits = np.zeros(len(px), np.uint32)
    for i in range(16):
        bits |= idx[:, i] << (2 * i)
    return c0, c1, bits


def _alpha_part(px):
    a = px[..., 3]
    a0 = a.max(axis=1).round().astype(np.uint8)
    a1 = a.min(axis=1).round().astype(np.uint8)
    f0, f1 = a0.astype(np.float32), a1.astype(np.float32)
    steps = [f0, f1] + [((7 - k) * f0 + k * f1) / 7 for k in range(1, 7)]
    palette = np.stack(steps, axis=1)
    idx = np.abs(a[:, :, None] - palette[:, None, :]).argmin(axis=2).astype(np.uint64)
    idx[a0 == a1] = 0

    bits = np.zeros(len(px), np.uint64)
    for i in range(16):
        bits |= idx[:, i] << np.uint64(3 * i)
    return a0, a1, bits


def dxt5(rgba):
    px = _blocks(rgba)
    a0, a1, abits = _alpha_part(px)
    c0, c1, cbits = _color_part(px)
    out = np.zeros((len(px), 16), np.uint8)
    out[:, 0] = a0
    out[:, 1] = a1
    for i in range(6):
        out[:, 2 + i] = ((abits >> np.uint64(8 * i)) & np.uint64(0xFF)).astype(np.uint8)
    out[:, 8:10] = c0.astype('<u2').view(np.uint8).reshape(-1, 2)
    out[:, 10:12] = c1.astype('<u2').view(np.uint8).reshape(-1, 2)
    out[:, 12:16] = cbits.astype('<u4').view(np.uint8).reshape(-1, 4)
    return out.tobytes()


def mip_chain(img):
    # Уменьшение в премультиплицированной альфе: иначе по краям прозрачного
    # проступает цвет невидимых точек.
    levels = [img]
    cur = img.convert('RGBa')
    while cur.width > 1 or cur.height > 1:
        cur = cur.resize((max(1, cur.width // 2), max(1, cur.height // 2)), Image.LANCZOS)
        levels.append(cur.convert('RGBA'))
    return levels[:16]


def write_blp(img, path):
    img = img.convert('RGBA')
    w, h = img.size
    data = [dxt5(np.asarray(level)) for level in mip_chain(img)]

    header_size = 4 + 4 + 4 + 8 + 16 * 4 * 2 + 256 * 4
    offsets, sizes, pos = [], [], header_size
    for chunk in data:
        offsets.append(pos)
        sizes.append(len(chunk))
        pos += len(chunk)
    offsets += [0] * (16 - len(offsets))
    sizes += [0] * (16 - len(sizes))

    with open(path, 'wb') as f:
        # type 1, сжатие 2 (DXT), глубина альфы 8, тип альфы 7 (DXT5), есть мипы.
        f.write(b'BLP2' + struct.pack('<IBBBBII', 1, 2, 8, 7, 1, w, h))
        f.write(struct.pack('<16I', *offsets))
        f.write(struct.pack('<16I', *sizes))
        f.write(b'\0' * 1024)
        for chunk in data:
            f.write(chunk)
    return pos


def convert(src):
    dst = os.path.splitext(src)[0] + '.blp'
    size = write_blp(Image.open(src), dst)
    print('%-22s %8d -> %8d' % (os.path.basename(dst), os.path.getsize(src), size))


if __name__ == '__main__':
    args = sys.argv[1:]
    if len(args) == 1 and os.path.isdir(args[0]):
        args = sorted(glob.glob(os.path.join(args[0], '*.tga')))
    for path in args:
        convert(path)
