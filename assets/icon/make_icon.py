import math
from PIL import Image, ImageDraw

S = 1024          # 输出主尺寸
SS = 4            # 超采样倍数
N = S * SS

# ---------- 颜色 ----------
BLUE   = (37, 99, 235)     # #2563EB
INDIGO = (79, 70, 229)     # #4F46E5
PURPLE = (139, 92, 246)    # #8B5CF6

def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))

def gradient(size):
    """斜向蓝紫渐变，带一点点顶部高光"""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x * 0.55 + y * 0.45) / size
            # 三段连续插值，避免出现色带接缝
            if t < 0.5:
                c = lerp(BLUE, INDIGO, t / 0.5)
            else:
                c = lerp(INDIGO, PURPLE, (t - 0.5) / 0.5)
            # 左上角轻微提亮，避免死板
            glow = max(0.0, 1.0 - math.hypot(x / size - 0.15, y / size - 0.1) / 0.75)
            k = 1.0 + 0.10 * glow
            px[x, y] = tuple(min(255, int(v * k)) for v in c)
    return img

def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m

def draw_arrows(size):
    """两条反向箭头 = 切换"""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    stroke  = int(size * 0.096)
    y_top   = int(size * 0.395)
    y_bot   = int(size * 0.605)
    x_left  = int(size * 0.275)
    x_right = int(size * 0.725)
    head_len = int(size * 0.105)
    head_hw  = int(size * 0.088)
    r = stroke / 2.0

    def bar(x1, x2, y, alpha):
        d.line([(x1, y), (x2, y)], fill=(255, 255, 255, alpha), width=stroke)
        for x in (x1, x2):
            d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, alpha))

    def head(tip_x, y, direction, alpha):
        base_x = tip_x - direction * head_len
        d.polygon([(tip_x, y), (base_x, y - head_hw), (base_x, y + head_hw)],
                  fill=(255, 255, 255, alpha))

    # 上：向右
    bar(x_left, x_right - head_len + int(stroke * 0.35), y_top, 255)
    head(x_right, y_top, +1, 255)

    # 下：向左（略微降一点不透明度，增加层次）
    bar(x_left + head_len - int(stroke * 0.35), x_right, y_bot, 232)
    head(x_left, y_bot, -1, 232)

    return layer

# ---------- 合成 ----------
bg = gradient(N).convert("RGBA")
mask = rounded_mask(N, int(N * 0.225))
bg.putalpha(mask)

arrows = draw_arrows(N)
bg = Image.alpha_composite(bg, arrows)

# 内描边：让边缘在深色桌面上更清晰
edge = Image.new("RGBA", (N, N), (0, 0, 0, 0))
ed = ImageDraw.Draw(edge)
w = max(2, int(N * 0.006))
ed.rounded_rectangle([w, w, N - 1 - w, N - 1 - w], radius=int(N * 0.225),
                     outline=(255, 255, 255, 46), width=w)
bg = Image.alpha_composite(bg, edge)

master = bg.resize((S, S), Image.LANCZOS)

out_dir = r"E:\ppt\icon"
import os
os.makedirs(out_dir, exist_ok=True)

master.save(os.path.join(out_dir, "codex-switch-1024.png"))
master.resize((256, 256), Image.LANCZOS).save(os.path.join(out_dir, "codex-switch-256.png"))

master.save(os.path.join(out_dir, "codex-switch.ico"),
            sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (24, 24), (16, 16)])

print("ok")
