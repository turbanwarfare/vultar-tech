import json
import os
from pathlib import Path

DEFAULT_FILE = Path(__file__).with_name("staff.json")


def load(path: Path = DEFAULT_FILE) -> set[int]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return set()
    return {int(user_id) for user_id in data}


def save(user_ids: set[int], path: Path = DEFAULT_FILE):
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(sorted(user_ids)), encoding="utf-8")
    os.replace(temp, path)
