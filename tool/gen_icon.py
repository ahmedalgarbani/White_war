"""Draws the White War launcher icon (original artwork) at every size we ship."""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), '..')
N = 1024


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw_icon(full_bleed=True):
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    top, bottom = (58, 140, 230), (12, 38, 86)
    for y in range(N):
        d.line([(0, y), (N, y)], fill=lerp(top, bottom, y / N) + (255,))
    # soft aurora band
    aur = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    ad = ImageDraw.Draw(aur)
    for i in range(6):
        ad.ellipse([-200 + i * 40, 120 + i * 18, N + 200 - i * 40, 520 - i * 10], outline=(120, 255, 210, 26), width=40)
    img = Image.alpha_composite(img, aur.filter(ImageFilter.GaussianBlur(18)))
    d = ImageDraw.Draw(img)
    # snowflake
    cx, cy = N / 2, N / 2 - 30
    for k in range(6):
        a = k * math.pi / 3 - math.pi / 2
        ex, ey = cx + math.cos(a) * 400, cy + math.sin(a) * 400
        d.line([(cx, cy), (ex, ey)], fill=(205, 238, 255, 255), width=46)
        for t, ln in ((0.55, 120), (0.8, 80)):
            bx, by = cx + math.cos(a) * 400 * t, cy + math.sin(a) * 400 * t
            for s in (-1, 1):
                b = a + s * math.pi / 4
                d.line([(bx, by), (bx + math.cos(b) * ln, by + math.sin(b) * ln)], fill=(205, 238, 255, 255), width=34)
        d.ellipse([ex - 30, ey - 30, ex + 30, ey + 30], fill=(205, 238, 255, 255))
    # hero face: red hood, white fur, face
    hx, hy = cx, cy + 80
    d.ellipse([hx - 270, hy - 270, hx + 270, hy + 270], fill=(150, 30, 26, 255))
    d.ellipse([hx - 255, hy - 262, hx + 255, hy + 248], fill=(226, 72, 61, 255))
    d.ellipse([hx - 205, hy - 190, hx + 205, hy + 205], fill=(247, 244, 238, 255))
    d.ellipse([hx - 160, hy - 140, hx + 160, hy + 170], fill=(246, 207, 176, 255))
    for s in (-1, 1):
        ex = hx + s * 62
        d.ellipse([ex - 22, hy - 10, ex + 22, hy + 52], fill=(30, 34, 56, 255))
        d.ellipse([ex - 8, hy + 2, ex + 6, hy + 16], fill=(255, 255, 255, 255))
        bx = hx + s * 108
        d.ellipse([bx - 30, hy + 70, bx + 30, hy + 100], fill=(255, 140, 150, 170))
    d.arc([hx - 40, hy + 70, hx + 40, hy + 120], 20, 160, fill=(120, 50, 40, 255), width=10)
    # scarf
    d.rounded_rectangle([hx - 230, hy + 225, hx + 230, hy + 300], radius=36, fill=(255, 201, 60, 255))
    # golden fish badge
    fx, fy = cx + 300, cy + 410
    d.ellipse([fx - 150, fy - 80, fx + 150, fy + 80], fill=(255, 255, 255, 255))
    d.ellipse([fx - 120, fy - 60, fx + 120, fy + 60], fill=(242, 183, 5, 255), outline=(255, 245, 160, 255), width=10)
    d.polygon([(fx - 100, fy), (fx - 175, fy - 60), (fx - 160, fy), (fx - 175, fy + 60)], fill=(209, 142, 0, 255))
    d.ellipse([fx + 52, fy - 26, fx + 82, fy + 4], fill=(255, 255, 255, 255))
    d.ellipse([fx + 60, fy - 18, fx + 76, fy - 2], fill=(30, 34, 56, 255))
    if not full_bleed:
        mask = Image.new('L', (N, N), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, N, N], radius=220, fill=255)
        img.putalpha(mask)
    return img


def save(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path)


if __name__ == '__main__':
    square = draw_icon(True)
    rounded = draw_icon(False)
    res = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
    for folder, size in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        save(rounded, os.path.join(res, f'mipmap-{folder}', 'ic_launcher.png'), size)
    web = os.path.join(ROOT, 'web')
    save(rounded, os.path.join(web, 'favicon.png'), 64)
    save(rounded, os.path.join(web, 'icons', 'Icon-192.png'), 192)
    save(rounded, os.path.join(web, 'icons', 'Icon-512.png'), 512)
    save(square, os.path.join(web, 'icons', 'Icon-maskable-192.png'), 192)
    save(square, os.path.join(web, 'icons', 'Icon-maskable-512.png'), 512)
    save(rounded, os.path.join(ROOT, 'assets', 'icon.png'), 512)
    print('icons written')
