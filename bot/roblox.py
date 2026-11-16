import asyncio
import re

import aiohttp

USERNAME = re.compile(r"^[A-Za-z0-9_]{3,20}$")
USER_ID = re.compile(r"^[1-9][0-9]{0,15}$")
TIMEOUT = aiohttp.ClientTimeout(total=3)
ERRORS = (aiohttp.ClientError, asyncio.TimeoutError, ValueError)


def profile_url(user_id: int) -> str:
    return f"https://www.roblox.com/users/{user_id}/profile"


async def _json(session: aiohttp.ClientSession, method: str, url: str, **kwargs):
    try:
        async with session.request(method, url, timeout=TIMEOUT, **kwargs) as response:
            if response.status != 200:
                return None
            return await response.json(content_type=None)
    except ERRORS:
        return None


async def resolve(session: aiohttp.ClientSession, text: str) -> tuple[int, str | None] | None:
    text = text.strip()
    if USER_ID.match(text):
        user_id = int(text)
        data = await _json(session, "GET", f"https://users.roblox.com/v1/users/{user_id}")
        return user_id, data.get("name") if isinstance(data, dict) else None
    if not USERNAME.match(text):
        return None
    data = await _json(
        session,
        "POST",
        "https://users.roblox.com/v1/usernames/users",
        json={"usernames": [text], "excludeBannedUsers": False},
    )
    found = data.get("data") if isinstance(data, dict) else None
    if not found:
        return None
    return int(found[0]["id"]), found[0].get("name")


async def names(session: aiohttp.ClientSession, user_ids: list[int]) -> dict[int, str]:
    result: dict[int, str] = {}
    for start in range(0, len(user_ids), 100):
        data = await _json(
            session,
            "POST",
            "https://users.roblox.com/v1/users",
            json={"userIds": user_ids[start : start + 100], "excludeBannedUsers": False},
        )
        for user in (data or {}).get("data", []):
            result[int(user["id"])] = user["name"]
    return result


async def headshot(session: aiohttp.ClientSession, user_id: int) -> str | None:
    data = await _json(
        session,
        "GET",
        "https://thumbnails.roblox.com/v1/users/avatar-headshot",
        params={"userIds": str(user_id), "size": "150x150", "format": "Png", "isCircular": "false"},
    )
    found = data.get("data") if isinstance(data, dict) else None
    url = found[0].get("imageUrl") if found else None
    return url if isinstance(url, str) and url.startswith("https://") else None
