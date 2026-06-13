#!/usr/bin/env python3
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CURRENT_SCREENSHOT_SET = "2026-06-13-1811-photo-video-copy"
SOURCE_DIR = ROOT / "MarketingScreenshots" / CURRENT_SCREENSHOT_SET / "app-store-6.9"
OUTPUT_DIR = ROOT / "MarketingScreenshots" / CURRENT_SCREENSHOT_SET / "app-store-6.9-marketing"

CANVAS_SIZE = (1320, 2868)
PHONE_SCREEN_WIDTH = 910
PHONE_TOP = 690

FONT_BOLD = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_REGULAR = "/System/Library/Fonts/STHeiti Light.ttc"


@dataclass(frozen=True)
class Shot:
    source: str
    output: str
    eyebrow: str
    title: str
    subtitle: str
    accent: tuple[int, int, int]


SHOTS = [
    Shot(
        source="01-welcome.png",
        output="01-local-first.png",
        eyebrow="TrueKeep / 留真",
        title="你的回忆，只在你的设备上",
        subtitle="本地扫描，不上传照片或视频，也不会自动删除",
        accent=(35, 112, 93),
    ),
    Shot(
        source="02-permission-rationale.png",
        output="02-permission-before-access.png",
        eyebrow="权限透明",
        title="请求权限前，先把边界说清楚",
        subtitle="只查找候选项目，删除前始终需要你确认",
        accent=(31, 101, 86),
    ),
    Shot(
        source="04-home-review-queue.png",
        output="03-review-queue.png",
        eyebrow="清理线索",
        title="把值得复核的照片分组",
        subtitle="截图、相似、误拍、模糊和大视频一目了然",
        accent=(47, 127, 114),
    ),
    Shot(
        source="05-screenshot-review.png",
        output="04-review-before-bin.png",
        eyebrow="逐张复核",
        title="先确认，再加入复核箱",
        subtitle="推荐保留项默认不会进入删除选择",
        accent=(36, 112, 98),
    ),
    Shot(
        source="06-review-bin.png",
        output="05-review-bin.png",
        eyebrow="二次确认",
        title="删除前，还有一层复核",
        subtitle="选中项可以取消或恢复，确认前不改变图库",
        accent=(41, 111, 104),
    ),
    Shot(
        source="07-delete-safety-confirmation.png",
        output="06-delete-safety.png",
        eyebrow="删除安全",
        title="iCloud 风险明确提示",
        subtitle="真正删除前再次确认，测试时可开启安全锁",
        accent=(166, 57, 78),
    ),
]


def font(size: int, *, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REGULAR, size=size)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def gradient_background(accent: tuple[int, int, int]) -> Image.Image:
    width, height = CANVAS_SIZE
    top = (246, 250, 247)
    bottom = (232, 242, 237)
    image = Image.new("RGB", CANVAS_SIZE, top)
    pixels = image.load()
    for y in range(height):
        ratio = y / (height - 1)
        base = tuple(round(top[i] * (1 - ratio) + bottom[i] * ratio) for i in range(3))
        for x in range(width):
            distance = ((x - width * 0.12) ** 2 + (y - height * 0.10) ** 2) ** 0.5
            glow = max(0, 1 - distance / 1100) * 0.12
            pixels[x, y] = tuple(round(base[i] * (1 - glow) + accent[i] * glow) for i in range(3))
    return image


def text_width(draw: ImageDraw.ImageDraw, text: str, typeface: ImageFont.FreeTypeFont) -> int:
    box = draw.textbbox((0, 0), text, font=typeface)
    return box[2] - box[0]


def wrap_text(draw: ImageDraw.ImageDraw, text: str, typeface: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    lines: list[str] = []
    current = ""
    for char in text:
        candidate = current + char
        if current and text_width(draw, candidate, typeface) > max_width:
            lines.append(current)
            current = char
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines


def draw_centered_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    y: int,
    typeface: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
    max_width: int,
    line_gap: int,
) -> int:
    lines = wrap_text(draw, text, typeface, max_width)
    for line in lines:
        box = draw.textbbox((0, 0), line, font=typeface)
        width = box[2] - box[0]
        height = box[3] - box[1]
        draw.text(((CANVAS_SIZE[0] - width) // 2, y), line, font=typeface, fill=fill)
        y += height + line_gap
    return y


def paste_device(canvas: Image.Image, screenshot: Image.Image) -> tuple[int, int, int, int]:
    phone_screen_height = round(PHONE_SCREEN_WIDTH * screenshot.height / screenshot.width)
    screen = screenshot.resize((PHONE_SCREEN_WIDTH, phone_screen_height), Image.Resampling.LANCZOS)

    frame_padding = 28
    frame_size = (PHONE_SCREEN_WIDTH + frame_padding * 2, phone_screen_height + frame_padding * 2)
    frame_x = (CANVAS_SIZE[0] - frame_size[0]) // 2
    frame_y = PHONE_TOP

    shadow = Image.new("RGBA", (frame_size[0] + 120, frame_size[1] + 120), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((60, 50, frame_size[0] + 60, frame_size[1] + 50), radius=92, fill=(14, 54, 45, 58))
    shadow = shadow.filter(ImageFilter.GaussianBlur(36))
    canvas.alpha_composite(shadow, (frame_x - 60, frame_y - 50))

    frame = Image.new("RGBA", frame_size, (0, 0, 0, 0))
    frame_draw = ImageDraw.Draw(frame)
    frame_draw.rounded_rectangle((0, 0, frame_size[0], frame_size[1]), radius=88, fill=(18, 28, 25))
    frame_draw.rounded_rectangle(
        (frame_padding, frame_padding, frame_size[0] - frame_padding, frame_size[1] - frame_padding),
        radius=64,
        fill=(245, 249, 246),
    )

    screen_mask = rounded_mask(screen.size, 56)
    screen_layer = Image.new("RGBA", screen.size, (0, 0, 0, 0))
    screen_layer.paste(screen.convert("RGBA"), (0, 0), screen_mask)
    frame.alpha_composite(screen_layer, (frame_padding, frame_padding))
    canvas.alpha_composite(frame, (frame_x, frame_y))

    return (frame_x, frame_y, frame_size[0], frame_size[1])


def build_shot(shot: Shot) -> dict[str, object]:
    source = SOURCE_DIR / shot.source
    screenshot = Image.open(source).convert("RGB")
    canvas = gradient_background(shot.accent).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    eyebrow_font = font(30, bold=True)
    eyebrow_box = draw.textbbox((0, 0), shot.eyebrow, font=eyebrow_font)
    draw.text(
        ((CANVAS_SIZE[0] - (eyebrow_box[2] - eyebrow_box[0])) // 2, 102),
        shot.eyebrow,
        font=eyebrow_font,
        fill=shot.accent,
    )
    underline_width = min(220, eyebrow_box[2] - eyebrow_box[0])
    draw.rounded_rectangle(
        (
            (CANVAS_SIZE[0] - underline_width) // 2,
            154,
            (CANVAS_SIZE[0] + underline_width) // 2,
            162,
        ),
        radius=4,
        fill=shot.accent,
    )

    title_end = draw_centered_text(
        draw,
        shot.title,
        205,
        font(72, bold=True),
        (20, 31, 28),
        max_width=1040,
        line_gap=18,
    )
    subtitle_end = draw_centered_text(
        draw,
        shot.subtitle,
        title_end + 24,
        font(39),
        (74, 91, 84),
        max_width=980,
        line_gap=12,
    )
    frame_bounds = paste_device(canvas, screenshot)

    output = OUTPUT_DIR / shot.output
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output, quality=96)

    return {
        "source": str(source.relative_to(ROOT)),
        "output": str(output.relative_to(ROOT)),
        "canvasSize": CANVAS_SIZE,
        "titleBottom": subtitle_end,
        "deviceFrame": frame_bounds,
    }


def build_contact_sheet(outputs: list[Path]) -> Path:
    thumb_width = 330
    thumb_height = round(thumb_width * CANVAS_SIZE[1] / CANVAS_SIZE[0])
    gap = 24
    cols = 3
    rows = (len(outputs) + cols - 1) // cols
    sheet = Image.new(
        "RGB",
        (cols * thumb_width + (cols + 1) * gap, rows * thumb_height + (rows + 1) * gap),
        (239, 244, 241),
    )
    for index, output in enumerate(outputs):
        image = Image.open(output).convert("RGB").resize((thumb_width, thumb_height), Image.Resampling.LANCZOS)
        x = gap + (index % cols) * (thumb_width + gap)
        y = gap + (index // cols) * (thumb_height + gap)
        sheet.paste(image, (x, y))
    contact = OUTPUT_DIR / "contact-sheet.png"
    sheet.save(contact, quality=95)
    return contact


def main() -> None:
    outputs: list[Path] = []
    manifest = []
    for shot in SHOTS:
        item = build_shot(shot)
        output = ROOT / item["output"]
        outputs.append(output)
        manifest.append(item)

    contact = build_contact_sheet(outputs)
    with (OUTPUT_DIR / "manifest.json").open("w", encoding="utf-8") as file:
        json.dump(
            {
                "sourceDirectory": str(SOURCE_DIR.relative_to(ROOT)),
                "outputDirectory": str(OUTPUT_DIR.relative_to(ROOT)),
                "contactSheet": str(contact.relative_to(ROOT)),
                "screenshots": manifest,
            },
            file,
            ensure_ascii=False,
            indent=2,
        )

    readme = OUTPUT_DIR / "README.md"
    readme.write_text(
        "# TrueKeep 6.9-inch Marketing Screenshot Candidates\n\n"
        "Generated from the current simulator screenshot set. These are review candidates for App Store / launch marketing, not final approved assets.\n\n"
        "- Canvas: `1320 x 2868`\n"
        "- Source: `../app-store-6.9/`\n"
        "- Contact sheet: `contact-sheet.png`\n"
        "- No source screenshots are overwritten.\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
