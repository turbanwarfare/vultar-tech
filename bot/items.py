import re
from pathlib import Path

COSMETICS = Path(__file__).resolve().parent / "Cosmetics"
ITEM_FILES = {
    "GunSkins.luau": "GunSkin",
    "PlayerCards.luau": "PlayerCard",
    "ChatGradients.luau": "ChatGradient",
    "Special.luau": None,
}
ID = re.compile(r'\bid\s*=\s*"([^"]+)"')
CATEGORY = re.compile(r'\bcategory\s*=\s*"([^"]+)"')
GUNS = re.compile(r"guns\s*=\s*\{([^}]*)\}")
PACK_SKIN = re.compile(r'withMythic\(\s*"([^"]+)"')
QUOTED = re.compile(r'"([^"]+)"')


def load(root: Path = COSMETICS) -> dict[str, list[str]]:
    found: dict[str, set[str]] = {}
    for filename, default in ITEM_FILES.items():
        text = (root / "Items" / filename).read_text(encoding="utf-8")
        matches = list(ID.finditer(text))
        for index, match in enumerate(matches):
            end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
            category = CATEGORY.search(text, match.end(), end)
            found.setdefault(category.group(1) if category else default, set()).add(match.group(1))

    crates = (root / "Crates.luau").read_text(encoding="utf-8")
    guns = {gun for block in GUNS.findall(crates) for gun in QUOTED.findall(block)}
    found["CratePack"] = {f"{skin}:{gun}" for skin in PACK_SKIN.findall(crates) for gun in guns}
    return {category: sorted(ids) for category, ids in found.items() if ids}


def all_ids(catalog: dict[str, list[str]]) -> list[str]:
    return sorted({item for ids in catalog.values() for item in ids})
