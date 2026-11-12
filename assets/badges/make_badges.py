"""
make_badges.py
生成仓库自用的 SVG 徽章（放 assets/badges/）。

为什么不用 shields.io：
  shields.io 在部分地区加载不稳定，README 上会出现"裂图"。
  本地 SVG 跟着仓库走，任何网络环境都能显示。

改版本号：改下面的 BADGES 列表，重新运行本脚本即可。
"""

import os
from PIL import ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE)

# (文件名, 左侧文字, 右侧文字, 右侧颜色)
BADGES = [
    ("version.svg",    "version",    "v1.0.0",  "#8B5CF6"),
    ("license.svg",    "license",    "MIT",     "#22C55E"),
    ("platform.svg",   "platform",   "Windows", "#0078D6"),
    ("powershell.svg", "PowerShell", "5.1",     "#5391FE"),
]

LEFT_BG = "#2D2D2D"
TEXT = "#FFFFFF"
FONT_SIZE = 11
PAD = 8            # 文字左右留白
HEIGHT = 20
RADIUS = 3

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\arial.ttf",
    r"C:\Windows\Fonts\segoeui.ttf",
    r"C:\Windows\Fonts\verdana.ttf",
]


def font():
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            return ImageFont.truetype(p, FONT_SIZE)
    return ImageFont.load_default()


def width_of(text, f):
    # +1 是为了兼容不同渲染器的字宽误差
    return int(f.getlength(text) + 0.5) + 1


def make(name, left, right, right_bg):
    f = font()
    lw = width_of(left, f)
    rw = width_of(right, f)

    left_w = lw + PAD * 2
    right_w = rw + PAD * 2
    total = left_w + right_w

    lx = left_w / 2
    rx = left_w + right_w / 2

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{total}" height="{HEIGHT}" role="img" aria-label="{left}: {right}">
  <title>{left}: {right}</title>
  <rect width="{total}" height="{HEIGHT}" rx="{RADIUS}" fill="{LEFT_BG}"/>
  <rect x="{left_w}" width="{right_w}" height="{HEIGHT}" rx="{RADIUS}" fill="{right_bg}"/>
  <rect x="{left_w}" width="{RADIUS * 2}" height="{HEIGHT}" fill="{right_bg}"/>
  <g fill="{TEXT}" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="{FONT_SIZE}" text-anchor="middle">
    <text x="{lx:.1f}" y="14">{left}</text>
    <text x="{rx:.1f}" y="14">{right}</text>
  </g>
</svg>
'''
    path = os.path.join(OUT, name)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(svg)
    print(f"  {name}  {total}x{HEIGHT}")


def main():
    os.makedirs(OUT, exist_ok=True)
    print("生成徽章：")
    for args in BADGES:
        make(*args)


if __name__ == "__main__":
    main()
