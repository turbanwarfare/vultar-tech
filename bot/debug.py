import collections
import os
import time
import traceback
import uuid

OWN_FILES = {"bot.py", "pages.py", "roblox.py", "items.py", "staff.py", "debug.py"}
recent: collections.deque = collections.deque(maxlen=20)


def scrub(text: str, secret_values) -> str:
    for value in secret_values:
        if value and len(value) >= 6:
            text = text.replace(value, "[hidden]")
    return text


def describe(error: BaseException, secret_values) -> str:
    frames = traceback.extract_tb(error.__traceback__)
    own = [frame for frame in frames if os.path.basename(frame.filename) in OWN_FILES]
    frame = (own or frames)[-1] if frames else None
    where = f" · {os.path.basename(frame.filename)}:{frame.lineno} in {frame.name}" if frame else ""
    text = scrub(f"{type(error).__name__}: {error}", secret_values)
    return (text if len(text) <= 700 else text[:699] + "…") + where


def record(command: str, user: str, error: BaseException, secret_values) -> dict:
    entry = {
        "id": uuid.uuid4().hex[:6],
        "when": int(time.time()),
        "command": command,
        "user": user,
        "text": describe(error, secret_values),
    }
    recent.appendleft(entry)
    return entry
