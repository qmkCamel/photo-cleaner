from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Tools" / "truekeep-logo-reference.png"
APP_ICON_OUT = ROOT / "TrueKeep" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "app-icon-1024.png"
LOGO_MARK_OUT = ROOT / "TrueKeep" / "Resources" / "Assets.xcassets" / "LogoMark.imageset" / "logo-mark.png"


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


def generate() -> None:
    source = Image.open(SOURCE).convert("RGB")
    square = fill_edge_connected_background(logo_background_square(source))

    APP_ICON_OUT.parent.mkdir(parents=True, exist_ok=True)
    LOGO_MARK_OUT.parent.mkdir(parents=True, exist_ok=True)

    square.resize((1024, 1024), Image.Resampling.LANCZOS).save(APP_ICON_OUT)
    square.resize((512, 512), Image.Resampling.LANCZOS).save(LOGO_MARK_OUT)

    print(APP_ICON_OUT)
    print(LOGO_MARK_OUT)


if __name__ == "__main__":
    generate()
