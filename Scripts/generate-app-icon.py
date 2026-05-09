#!/usr/bin/env python3

from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
ICON_PATH = ROOT / "Sources/DebugProcessWatcher/Resources/AppIcon.icns"
MASTER_PATH = ROOT / "Sources/DebugProcessWatcher/Resources/AppIcon-master.png"


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

        source_path = args.source if args.source is not None else MASTER_PATH
        source = Image.open(source_path).convert("RGBA")
        if source.size != (1024, 1024):
            source = source.resize((1024, 1024), Image.Resampling.LANCZOS)
        master = source

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
