import asyncio
from typing import Literal

import discord
from discord import app_commands

import prefix


@app_commands.command()
async def sample(
    interaction: discord.Interaction,
    player: app_commands.Range[str, 1, 32],
    amount: app_commands.Range[int, -100, 100],
    reason: app_commands.Range[str, 1, 120],
):
    pass


@app_commands.command()
async def listing(interaction: discord.Interaction, category: Literal["GunSkin", "PlayerCard"] | None = None):
    pass


@app_commands.command()
async def member(interaction: discord.Interaction, member: discord.User):
    pass


async def fetch_user(user_id: int):
    return user_id


def parse(command, text):
    return asyncio.run(prefix.parse(command, text, fetch_user))


def fails(command, text):
    try:
        parse(command, text)
    except ValueError as problem:
        return str(problem)
    raise AssertionError(f"{text!r} should fail")


assert parse(sample, "Player1 1,00 won the event") == {"player": "Player1", "amount": 100, "reason": "won the event"}
assert parse(sample, "123456789 -5 oops") == {"player": "123456789", "amount": -5, "reason": "oops"}
assert "Usage: `.sample <player> <amount> <reason>`" in fails(sample, "Player1 5")
assert "whole number" in fails(sample, "Player1 lots reason")
assert "between -100 and 100" in fails(sample, "Player1 500 reason")
assert "between 1 and 32" in fails(sample, f"{'a' * 33} 5 reason")
assert parse(listing, "") == {}
assert parse(listing, "gunskin") == {"category": "GunSkin"}
assert "GunSkin, PlayerCard" in fails(listing, "hats")
assert parse(member, "<@111111111111111111>") == {"member": 111111111111111111}
assert parse(member, "111111111111111111") == {"member": 111111111111111111}
assert "mention or user ID" in fails(member, "someone")


class FakeMessage:
    author = channel = type("Thing", (), {"id": 1})()
    guild = None

    async def reply(self, content=None, **kwargs):
        return (content, kwargs)


shim = prefix.MessageInteraction(FakeMessage(), sample)
assert not shim.response.is_done()
asyncio.run(shim.response.defer(ephemeral=True))
assert shim.response.is_done()
assert asyncio.run(shim.followup.send(embed="x", ephemeral=True, wait=True)) == (None, {"embed": "x"})
print("ok")
