"""
make_demo_gif.py
生成 README 用的演示动图（GIF），模拟真实的控制台输出。

为什么用画帧而不是录屏：
  - 不依赖录屏工具，纯脚本可复现、可改字
  - 输出尺寸和节奏可控，文件小
  - 文字用 SimSun（ASCII 宽 12，中文宽 24），和真实控制台对齐一致

用法：
    python make_demo_gif.py            # 生成 demo.gif
    python make_demo_gif.py --preview  # 只输出一张静帧，用来检查排版
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------- 画布 ----------
W, H = 1000, 600
PAD_X, PAD_TOP = 26, 22
TITLE_H = 38
LINE_H = 28
FONT_SIZE = 24

# ---------- 配色（VS Code 暗色系）----------
C_BG        = (12, 12, 12)
C_TITLEBAR  = (24, 24, 24)
C_BORDER    = (42, 42, 42)
C_TEXT      = (212, 212, 212)
C_PROMPT    = (86, 156, 214)
C_HILIGHT   = (79, 193, 255)
C_OK        = (78, 201, 176)
C_DIM       = (150, 150, 150)
C_WARN      = (220, 220, 170)
C_CURSOR    = (212, 212, 212)

FONT_CANDIDATES = [
    (r"C:\Windows\Fonts\simsun.ttc", 0),
    (r"C:\Windows\Fonts\msgothic.ttc", 0),
]


def load_font(size):
    for path, idx in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size, index=idx)
    return ImageFont.load_default()


FONT = load_font(FONT_SIZE)


# ---------- 逐行样式 ----------
def style_for(line):
    """返回 (颜色, 是否加粗用高亮色)"""
    s = line.strip()
    if line.startswith("PS "):
        return C_PROMPT
    if s.startswith("已切换到") or s.startswith("OK：") or s.startswith("  OK："):
        return C_OK
    if s.startswith("校验") or s.startswith("正在打开"):
        return C_DIM
    if s.startswith("接口:") or s.startswith("模型:") or s.startswith("代理:"):
        return C_DIM
    if s.startswith("* "):
        return C_HILIGHT
    if s.startswith("选择"):
        return C_WARN
    if s.startswith("当前:"):
        return C_TEXT
    return C_TEXT


def draw_window_base():
    img = Image.new("RGB", (W, H), C_BG)
    d = ImageDraw.Draw(img)

    # 圆角窗体
    d.rounded_rectangle([0, 0, W - 1, H - 1], radius=14, fill=C_BG, outline=C_BORDER, width=1)
    # 标题栏
    d.rounded_rectangle([0, 0, W - 1, TITLE_H], radius=14, fill=C_TITLEBAR)
    d.rectangle([0, TITLE_H - 14, W - 1, TITLE_H], fill=C_TITLEBAR)

    # 三个圆点
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        cx = 22 + i * 22
        d.ellipse([cx - 6, TITLE_H / 2 - 6, cx + 6, TITLE_H / 2 + 6], fill=c)

    # 标题文字
    small = load_font(15)
    title = "PowerShell  —  Codex 后端切换器"
    tw = small.getlength(title)
    d.text(((W - tw) / 2, (TITLE_H - 15) / 2 - 2), title, font=small, fill=(150, 150, 150))
    return img


def render(lines, cursor=None):
    """lines: 文本行列表；cursor: (行号, 列偏移)，在该行末尾画光标"""
    img = draw_window_base()
    d = ImageDraw.Draw(img)

    y = TITLE_H + PAD_TOP
    for i, line in enumerate(lines):
        if line:
            color = style_for(line)
            d.text((PAD_X, y), line, font=FONT, fill=color)
        if cursor and cursor[0] == i:
            # 用等宽字体的字符宽计算光标位置
            col = cursor[1]
            cw = FONT.getlength("A")
            x = PAD_X + col * cw
            d.rectangle([x + 1, y + 3, x + cw - 1, y + FONT_SIZE + 3], fill=C_CURSOR)
        y += LINE_H
    return img


# ---------- 剧本 ----------
CMD = r".\bin\switcher.bat"

MENU = [
    "",
    "  ==============================================",
    "            Codex 后端切换器",
    "  ==============================================",
    "",
    "   当前: 中转站 A",
    "",
    "   * 1. ChatGPT 账号     (官方账号)",
    "     2. 中转站 A         https://relay-a.example.com/v1",
    "     3. 中转站 B         https://relay-b.example.com/v1",
    "     4. 中转站 C         https://relay-c.example.com/v1",
    "",
    "   0. 退出",
    "   选择 ",
]

RESULT = [
    "",
    "校验 https://relay-b.example.com/v1 ...",
    "  OK：共 26 个模型（文本 18），选用 gpt-6.1-sol",
    "",
    "已切换到「中转站 B」",
    "  接口: https://relay-b.example.com/v1",
    "  模型: gpt-6.1-sol",
    "  代理: http://127.0.0.1:7890",
    "",
    "正在打开 Codex…",
]


def build_frames():
    frames = []          # (image, duration_ms)
    prompt_line = "PS C:\\codex-backend-switcher> "

    # 1. 逐字敲命令
    for n in range(len(CMD) + 1):
        lines = [prompt_line + CMD[:n]]
        frames.append((render(lines, cursor=(0, len(prompt_line) + n)), 45))

    # 2. 回车，菜单逐行出现
    lines = [prompt_line + CMD]
    frames.append((render(lines, cursor=(0, len(prompt_line) + len(CMD))), 260))

    for i in range(len(MENU)):
        lines = [prompt_line + CMD] + MENU[: i + 1]
        cursor = None
        if i == len(MENU) - 1:
            cursor = (len(lines) - 1, len(MENU[-1]))
        # 菜单出现得快一些
        unit = 70 if i >= 11 else 45
        frames.append((render(lines, cursor=cursor), unit))

    # 3. 停顿，让人看清菜单
    lines = [prompt_line + CMD] + MENU
    frames.append((render(lines, cursor=(len(lines) - 1, len(MENU[-1]))), 900))

    # 4. 输入 3 并回车 -> 清屏
    typed = MENU[:-1] + ["   选择 3"]
    lines = [prompt_line + CMD] + typed
    frames.append((render(lines, cursor=(len(lines) - 1, len(typed[-1]))), 260))

    frames.append((render([prompt_line + CMD + " 3"], cursor=(0, len(prompt_line) + len(CMD) + 2)), 220))

    # 5. 结果逐行出现
    head = prompt_line + CMD + " 3"
    for i in range(len(RESULT) + 1):
        lines = [head] + RESULT[:i]
        frames.append((render(lines), 110 if i < len(RESULT) else 0))

    # 6. 停留
    frames.append((render([head] + RESULT), 2200))

    return frames


def save_gif(frames, out_path, scale=0.86):
    imgs = []
    for im, dur in frames:
        if scale != 1:
            im = im.resize((int(W * scale), int(H * scale)), Image.LANCZOS)
        # 统一调色板，减少体积
        imgs.append((im.convert("P", palette=Image.ADAPTIVE, colors=64), max(dur, 30)))

    first, _ = imgs[0]
    rest = [i for i, _ in imgs[1:]]
    durs = [d for _, d in imgs]

    first.save(
        out_path,
        save_all=True,
        append_images=rest,
        duration=durs,
        loop=0,
        optimize=True,
        disposal=2,
    )
    return out_path


def main():
    if "--preview" in sys.argv:
        lines = ["PS C:\\codex-backend-switcher> " + CMD] + MENU + [""] + RESULT[:8]
        render(lines).save(os.path.join(HERE, "preview.png"))
        print("preview.png 已生成")
        return

    frames = build_frames()
    out = save_gif(frames, os.path.join(HERE, "demo.gif"))
    size_kb = os.path.getsize(out) / 1024
    print(f"demo.gif 已生成：{len(frames)} 帧，{size_kb:.0f} KB")


if __name__ == "__main__":
    main()
