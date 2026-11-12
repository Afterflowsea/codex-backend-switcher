"""
make_social_preview.py
生成 GitHub 社交预览图（仓库右上角 Settings → Social preview，建议 1280x640）。

用于：把仓库链接分享到群/推特/微信时显示的封面。
"""

import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

W, H = 1280, 640

BLUE = (37, 99, 235)
INDIGO = (79, 70, 229)
PURPLE = (139, 92, 246)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def gradient(size=1):
    # 生成一条横向渐变再拉伸，比逐像素快
    strip = Image.new("RGB", (W, 1))
    px = strip.load()
    for x in range(W):
        t = x / (W - 1)
        c = lerp(BLUE, INDIGO, t / 0.55) if t < 0.55 else lerp(INDIGO, PURPLE, (t - 0.55) / 0.45)
        px[x, 0] = c
    return strip.resize((W, H), Image.BILINEAR)


def font(size, bold=False):
    for name in (r"C:\Windows\Fonts\msyhbd.ttc" if bold else r"C:\Windows\Fonts\msyh.ttc",
                 r"C:\Windows\Fonts\msyh.ttc"):
        if os.path.exists(name):
            return ImageFont.truetype(name, size, index=0)
    return ImageFont.load_default()


def main():
    bg = gradient().convert("RGBA")

    # 右侧压暗，让文字更清楚
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for x in range(W):
        a = int(70 * (x / W) ** 1.6)
        sd.line([(x, 0), (x, H)], fill=(0, 0, 0, a))
    bg = Image.alpha_composite(bg, shade)

    d = ImageDraw.Draw(bg)

    # 图标
    icon_path = os.path.join(ROOT, "assets", "icon", "codex-switch-1024.png")
    if os.path.exists(icon_path):
        icon = Image.open(icon_path).convert("RGBA").resize((240, 240), Image.LANCZOS)
        bg.alpha_composite(icon, (90, 200))

    # 文案
    x = 390
    d.text((x, 196), "Codex 后端切换器", font=font(76, True), fill=(255, 255, 255))
    d.text((x, 300), "一键切换 ChatGPT 账号与第三方中转站", font=font(34), fill=(235, 238, 255))
    d.text((x, 360), "切换前自动校验 · 失败不写盘 · 切回账号免登录",
           font=font(28), fill=(210, 216, 255))

    # 底部信息
    d.text((x, 448), "Windows  ·  PowerShell 5.1  ·  MIT",
           font=font(24), fill=(190, 198, 245))
    d.text((x, 486), "github.com/Afterflowsea/codex-backend-switcher",
           font=font(24), fill=(170, 180, 235))

    out = os.path.join(HERE, "social-preview.png")
    bg.convert("RGB").save(out)
    print(f"social-preview.png 已生成：{W}x{H}")


if __name__ == "__main__":
    main()
