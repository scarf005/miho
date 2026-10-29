# /// script
# requires-python = ">=3.11"
# dependencies = ["fonttools==4.60.1"]
# ///
"""Subset the bundled OFL fonts to the characters the game uses.

Run after changing any Korean or Hanja text: `just fonts`.
"""

import pathlib
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = pathlib.Path.home() / ".cache" / "miho" / "fonts"
BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl"
FONTS = {
    "NotoSerifKR": ("notoserifkr", "NotoSerifKR%5Bwght%5D.ttf"),
    "NanumBrushScript": ("nanumbrushscript", "NanumBrushScript-Regular.ttf"),
}


def fetch(folder: str, name: str) -> pathlib.Path:
    path = CACHE / folder / urllib.request.unquote(name)
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        urllib.request.urlretrieve(f"{BASE}/{folder}/{name}", path)
    return path


def used_text() -> str:
    chars = {chr(c) for c in range(0x20, 0x7F)}
    for path in [*ROOT.glob("src/**/*.gd"), *ROOT.glob("src/**/*.tscn")]:
        chars |= {c for c in path.read_text(encoding="utf-8") if ord(c) > 0x7E}
    return "".join(sorted(chars))


def main() -> None:
    out = ROOT / "assets" / "fonts"
    out.mkdir(parents=True, exist_ok=True)
    text = used_text()
    for stem, (folder, name) in FONTS.items():
        source = fetch(folder, name)
        license_path = fetch(folder, "OFL.txt")
        (out / f"{stem}-OFL.txt").write_bytes(license_path.read_bytes())
        font = TTFont(source)
        options = subset.Options()
        options.layout_features = ["*"]
        options.name_IDs = ["*"]
        options.notdef_outline = True
        subsetter = subset.Subsetter(options)
        subsetter.populate(text=text)
        subsetter.subset(font)
        font.save(out / f"{stem}-Miho.ttf")
        print(stem, len(font.getGlyphOrder()), "glyphs")


main()
