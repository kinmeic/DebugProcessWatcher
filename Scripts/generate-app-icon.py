#!/usr/bin/env python3

from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
ICON_PATH = ROOT / "Sources/DebugProcessWatcher/Resources/AppIcon.icns"
MASTER_PATH = ROOT / "Sources/DebugProcessWatcher/Resources/AppIcon-master.png"


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def build_master(source: Image.Image) -> Image.Image:
    size = 1024
    radius = 232

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((42, 54, size - 42, size - 28), radius=radius, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.alpha_composite(shadow)

    scaled = source.resize((948, 948), Image.Resampling.LANCZOS)
    content = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    content.alpha_composite(scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2 - 8))

    clip = rounded_mask(size, radius)
    clipped = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    clipped.paste(content, mask=clip)

    gloss = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gloss_draw = ImageDraw.Draw(gloss)
    gloss_draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, outline=(255, 255, 255, 50), width=4)

    highlight = Image.new("L", (size, size), 0)
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.rounded_rectangle((44, 44, size - 44, size // 2), radius=radius - 28, fill=120)
    highlight = highlight.filter(ImageFilter.GaussianBlur(44))
    gloss_alpha = ImageChops.multiply(highlight, clip)
    gloss_overlay = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    gloss_overlay.putalpha(gloss_alpha)
    gloss_overlay = Image.blend(Image.new("RGBA", (size, size), (255, 255, 255, 0)), gloss_overlay, 0.08)

    canvas.alpha_composite(clipped)
    canvas.alpha_composite(gloss_overlay)
    canvas.alpha_composite(gloss)
    return canvas


def write_iconset(master: Image.Image, iconset_dir: Path) -> None:
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }

    for name, edge in sizes.items():
        resized = master.resize((edge, edge), Image.Resampling.LANCZOS)
        resized.save(iconset_dir / name)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate AppIcon.icns from a source image.")
    parser.add_argument(
        "--source",
        type=Path,
        help="Use an existing 1024x1024 PNG as the master app icon without re-styling it.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        output_iconset = temp_path / "output.iconset"
        output_iconset.mkdir()

        if args.source is not None:
            source = Image.open(args.source).convert("RGBA")
            if source.size != (1024, 1024):
                source = source.resize((1024, 1024), Image.Resampling.LANCZOS)
            master = source
        else:
            source_iconset = temp_path / "source.iconset"
            subprocess.run(
                ["iconutil", "-c", "iconset", str(ICON_PATH), "-o", str(source_iconset)],
                check=True,
            )
            source = Image.open(source_iconset / "icon_512x512@2x.png").convert("RGBA")
            master = build_master(source)

        master.save(MASTER_PATH)
        write_iconset(master, output_iconset)

        rebuilt = temp_path / "AppIcon.icns"
        subprocess.run(
            ["iconutil", "-c", "icns", str(output_iconset), "-o", str(rebuilt)],
            check=True,
        )
        shutil.copy2(rebuilt, ICON_PATH)


if __name__ == "__main__":
    main()
