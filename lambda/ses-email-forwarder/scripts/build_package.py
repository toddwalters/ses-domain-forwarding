#!/usr/bin/env python3

from pathlib import Path
import zipfile


ROOT = Path(__file__).resolve().parent.parent
DIST_DIR = ROOT / "dist"
OUTPUT = DIST_DIR / "ses-email-forwarder.zip"
FILES = ["index.js", "package.json", "package-lock.json"]
FIXED_TIMESTAMP = (2020, 1, 1, 0, 0, 0)
FILE_MODE = 0o100644 << 16


def main() -> None:
    DIST_DIR.mkdir(parents=True, exist_ok=True)
    if OUTPUT.exists():
        OUTPUT.unlink()

    with zipfile.ZipFile(OUTPUT, "w", compression=zipfile.ZIP_STORED) as archive:
        for relative_name in FILES:
            source = ROOT / relative_name
            info = zipfile.ZipInfo(relative_name, FIXED_TIMESTAMP)
            info.create_system = 3
            info.external_attr = FILE_MODE
            with source.open("rb") as handle:
                archive.writestr(info, handle.read())


if __name__ == "__main__":
    main()
