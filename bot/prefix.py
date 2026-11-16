import re

import discord
from discord import AppCommandOptionType, app_commands

USER_ID = re.compile(r"^(?:<@!?)?(\d{15,20})>?$")


def usage(command: app_commands.Command) -> str:
    names = "".join(f" <{param.name}>" if param.required else f" [{param.name}]" for param in command.parameters)
    return f"Usage: `.{command.qualified_name}{names}`"


async def convert(param: app_commands.Parameter, raw: str, fetch_user):
    if param.type is AppCommandOptionType.user:
        match = USER_ID.match(raw)
        if not match:
            raise ValueError(f"`{param.name}` has to be a mention or user ID.")
        return await fetch_user(int(match.group(1)))

    value = raw
    if param.type is AppCommandOptionType.integer:
        try:
            value = int(raw.replace(",", ""))
        except ValueError:
            raise ValueError(f"`{param.name}` has to be a whole number.") from None

    if param.choices:
        options = {str(choice.value).lower(): choice.value for choice in param.choices}
        if raw.lower() not in options:
            raise ValueError(f"`{param.name}` has to be one of: {', '.join(map(str, options.values()))}.")
        return options[raw.lower()]

    size = len(value) if isinstance(value, str) else value
    low, high = param.min_value, param.max_value
    if (low is not None and size < low) or (high is not None and size > high):
        unit = " characters" if isinstance(value, str) else ""
        raise ValueError(f"`{param.name}` has to be between {low} and {high}{unit}.")
    return value


async def parse(command: app_commands.Command, text: str, fetch_user) -> dict:
    params = command.parameters
    parts = text.split(None, len(params) - 1) if params else []
    if len(parts) < sum(param.required for param in params):
        raise ValueError(usage(command))
    return {param.name: await convert(param, raw, fetch_user) for param, raw in zip(params, parts)}


class MessageInteraction:
    def __init__(self, message: discord.Message, command: app_commands.Command):
        self.message = message
        self.command = command
        self.user = message.author
        self.guild_id = message.guild.id if message.guild else None
        self.channel_id = message.channel.id
        self.response = self
        self.followup = self
        self.done = False

    def is_done(self) -> bool:
        return self.done

    async def defer(self, **_):
        self.done = True

    async def send_message(self, content=None, **kwargs):
        self.done = True
        return await self.send(content, **kwargs)

    async def send(self, content=None, *, ephemeral=False, wait=False, **kwargs):
        return await self.message.reply(content, **kwargs)
