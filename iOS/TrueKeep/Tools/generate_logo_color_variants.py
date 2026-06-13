from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Tools" / "truekeep-logo-reference.png"
OUT_DIR = ROOT / "Tools" / "logo-color-variants"

PALETTES = [
    {
        "slug": "mist-blue",
        "label": "Mist Blue",
        "dark": (92, 119, 132),
        "mid": (139, 160, 169),
        "light": (184, 195, 197),
        "ivory": (246, 241, 232),
    },
    {
        "slug": "warm-taupe",
        "label": "Warm Taupe",
        "dark": (124, 108, 96),
        "mid": (164, 148, 131),
        "light": (205, 195, 178),
        "ivory": (247, 240, 229),
    },
    {
        "slug": "dusty-rose",
        "label": "Dusty Rose",
        "dark": (133, 103, 102),
        "mid": (179, 146, 140),
        "light": (215, 197, 185),
        "ivory": (248, 240, 232),
    },
    {
        "slug": "lavender-gray",
        "label": "Lavender Gray",
        "dark": (105, 104, 128),
        "mid": (151, 148, 169),
        "light": (200, 196, 207),
        "ivory": (246, 241, 234),
    },
    {
        "slug": "clay-olive",
        "label": "Clay Olive",
        "dark": (101, 119, 91),
        "mid": (148, 157, 124),
        "light": (202, 197, 165),
        "ivory": (248, 241, 226),
    },
    {
        "slug": "deep-teal",
        "label": "Deep Teal",
        "dark": (49, 91, 91),
        "mid": (88, 132, 128),
        "light": (164, 184, 175),
        "ivory": (244, 239, 229),
    },
]


def logo_background_square(image: Image.Image) -> Image.Image:
    rgb = np.asarray(image.convert("RGB")).astype(int)
    red = rgb[:, :, 0]
    green = rgb[:, :, 1]
    blue = rgb[:, :, 2]
    background_mask = (
        (green - red > 4)
        & (green - blue > 1)
        & (green < 235)
        & (red < 230)
    )
    ys, xs = np.where(background_mask)
    left, top, right, bottom = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    width = right - left
    height = bottom - top
    side = min(width, height)
    center_x = (left + right) // 2
    center_y = (top + bottom) // 2
    left = center_x - side // 2
    top = center_y - side // 2
    return image.crop((left, top, left + side, top + side))


def fill_edge_connected_background(image: Image.Image) -> Image.Image:
    pixels = np.asarray(image.convert("RGB")).copy()
    rgb = pixels.astype(np.int16)
    red = rgb[:, :, 0]
    green = rgb[:, :, 1]
    blue = rgb[:, :, 2]
    green_background = (
        (green - red > 3)
        & (green - blue > 0)
        & (green < 230)
        & (red < 225)
    )
    fill = np.median(pixels[green_background], axis=0).astype(np.uint8)
    edge_background = (
        (pixels.mean(axis=2) > 200)
        & ((pixels.max(axis=2) - pixels.min(axis=2)) < 65)
    )

    height, width = edge_background.shape
    visited = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        for y in (0, height - 1):
            if edge_background[y, x] and not visited[y, x]:
                visited[y, x] = True
                queue.append((y, x))
    for y in range(height):
        for x in (0, width - 1):
            if edge_background[y, x] and not visited[y, x]:
                visited[y, x] = True
                queue.append((y, x))

    while queue:
        y, x = queue.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny = y + dy
            nx = x + dx
            if (
                0 <= ny < height
                and 0 <= nx < width
                and edge_background[ny, nx]
                and not visited[ny, nx]
            ):
                visited[ny, nx] = True
                queue.append((ny, nx))

    pixels[visited] = fill
    return Image.fromarray(pixels, mode="RGB")


def mix(a: np.ndarray, b: np.ndarray, t: np.ndarray) -> np.ndarray:
    return a * (1 - t[..., None]) + b * t[..., None]


def recolor(image: Image.Image, palette: dict[str, object]) -> Image.Image:
    rgb = np.asarray(image.convert("RGB")).astype(np.float32) / 255.0
    luma = (
        rgb[:, :, 0] * 0.2126
        + rgb[:, :, 1] * 0.7152
        + rgb[:, :, 2] * 0.0722
    )
    maxc = rgb.max(axis=2)
    minc = rgb.min(axis=2)
    saturation = np.divide(maxc - minc, np.maximum(maxc, 0.001))

    dark = np.array(palette["dark"], dtype=np.float32) / 255.0
    mid = np.array(palette["mid"], dtype=np.float32) / 255.0
    light = np.array(palette["light"], dtype=np.float32) / 255.0
    ivory = np.array(palette["ivory"], dtype=np.float32) / 255.0

    color_t = np.clip((luma - 0.34) / 0.44, 0, 1)
    colored = np.where(
        color_t[..., None] < 0.52,
        mix(dark, mid, np.clip(color_t / 0.52, 0, 1)),
        mix(mid, light, np.clip((color_t - 0.52) / 0.48, 0, 1)),
    )

    ivory_tint = ivory * np.clip((luma / 0.96), 0.72, 1.08)[..., None]
    color_mask = ((saturation > 0.035) & (luma < 0.91)).astype(np.float32)
    color_mask = np.clip(color_mask * 1.18, 0, 1)
    out = ivory_tint * (1 - color_mask[..., None]) + colored * color_mask[..., None]

    # Reapply the source luminance texture so the soft edges and shadows remain from the reference.
    out_luma = (
        out[:, :, 0] * 0.2126
        + out[:, :, 1] * 0.7152
        + out[:, :, 2] * 0.0722
    )
    texture = np.clip((luma + 0.03) / np.maximum(out_luma + 0.03, 0.001), 0.80, 1.18)
    out = np.clip(out * texture[..., None], 0, 1)
    return Image.fromarray((out * 255).astype(np.uint8), mode="RGB")


def load_font(size: int) -> ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def make_contact_sheet(items: list[tuple[dict[str, object], Image.Image]]) -> Image.Image:
    cell_w = 420
    cell_h = 490
    icon = 336
    margin = 34
    label_h = 48
    sheet = Image.new("RGB", (cell_w * 3, cell_h * 2), (247, 245, 239))
    draw = ImageDraw.Draw(sheet)
    font = load_font(24)

    for idx, (palette, image) in enumerate(items):
        col = idx % 3
        row = idx // 3
        x = col * cell_w
        y = row * cell_h
        preview = image.resize((icon, icon), Image.Resampling.LANCZOS)
        sheet.paste(preview, (x + (cell_w - icon) // 2, y + margin))
        label = str(palette["label"])
        bbox = draw.textbbox((0, 0), label, font=font)
        text_x = x + (cell_w - (bbox[2] - bbox[0])) // 2
        draw.text((text_x, y + margin + icon + label_h // 2), label, fill=(70, 76, 72), font=font)
    return sheet


def generate() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    source = fill_edge_connected_background(
        logo_background_square(Image.open(SOURCE))
    ).resize((1024, 1024), Image.Resampling.LANCZOS)

    outputs: list[tuple[dict[str, object], Image.Image]] = []
    for palette in PALETTES:
        variant = recolor(source, palette)
        output_path = OUT_DIR / f"{palette['slug']}.png"
        variant.save(output_path)
        outputs.append((palette, variant))
        print(output_path)

    contact_sheet = make_contact_sheet(outputs)
    sheet_path = OUT_DIR / "contact-sheet.png"
    contact_sheet.save(sheet_path)
    print(sheet_path)


if __name__ == "__main__":
    generate()
