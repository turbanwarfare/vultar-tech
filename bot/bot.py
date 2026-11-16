import asyncio
import io
import json
import os
import platform
import re
import resource
import ssl
import time
from typing import Literal
from urllib.parse import quote

import aiohttp
import discord
from discord import app_commands
from dotenv import load_dotenv

import debug
import items
import pages
import prefix
import roblox
import staff

load_dotenv()

DISCORD_TOKEN = os.environ["DISCORD_TOKEN"]
ADMIN_API_KEY = os.environ["ADMIN_API_KEY"]
GUILD_ID = int(os.environ["GUILD_ID"])
LOG_WEBHOOK_URL = os.environ.get("LOG_WEBHOOK_URL")
CF_ACCOUNT_ID = os.environ["CF_ACCOUNT_ID"]
D1_DATABASE_ID = os.environ["D1_DATABASE_ID"]
D1_READ_TOKEN = os.environ["D1_READ_TOKEN"]
D1_WRITE_TOKEN = os.environ["D1_WRITE_TOKEN"]

API_URL = "REPLACE_WITH_YOUR_API_URL"
D1_URL = f"https://api.cloudflare.com/client/v4/accounts/{CF_ACCOUNT_ID}/d1/database/{D1_DATABASE_ID}/query"
OWNER_ID = 0
ALLOWED_USERS = staff.load()
MAX_CREDITS = 50_000
CONFIRM_ABOVE = 5_000
ITEM_ID = re.compile(r"^[A-Za-z0-9_-]{1,64}(:[A-Za-z0-9_+ -]{1,32})?$")
BLOCKED_SQL = re.compile(r"\b(DROP|ALTER)\b", re.IGNORECASE)
CODE_FENCE = re.compile(r"^```(?:sql)?\s*(.*?)\s*```$", re.DOTALL | re.IGNORECASE)

BRAND = 0xC0392B
OK = 0x2ECC71
FAIL = 0xE74C3C
CATEGORY_NAMES = {
    "GunSkin": "Gun skins",
    "PlayerCard": "Banners",
    "ChatGradient": "Chat gradients",
    "CratePack": "Crate pack skins",
    "Other": "Other",
}
SECRETS = ("DISCORD_TOKEN", "ADMIN_API_KEY", "LOG_WEBHOOK_URL", "CF_ACCOUNT_ID", "D1_DATABASE_ID", "D1_READ_TOKEN", "D1_WRITE_TOKEN")

TX_ID = re.compile(r"^[A-Za-z0-9:_.-]{1,128}$")
STARTED = int(time.time())
DENIED_LOG_COOLDOWN = 600
denied_logged: dict[int, float] = {}

GUILD = discord.Object(id=GUILD_ID)


class AdminBot(discord.Client):
    def __init__(self):
        intents = discord.Intents.default()
        intents.message_content = True
        super().__init__(intents=intents, allowed_mentions=discord.AllowedMentions.none())
        self.tree = app_commands.CommandTree(self)
        self.api = None
        self.web = None
        self.mention = None

    async def setup_hook(self):
        self.api = aiohttp.ClientSession(
            headers={"Authorization": f"Bearer {ADMIN_API_KEY}"},
            timeout=aiohttp.ClientTimeout(total=15),
        )
        self.web = aiohttp.ClientSession(
            connector=aiohttp.TCPConnector(ssl=ssl.create_default_context()),
            timeout=aiohttp.ClientTimeout(total=15),
        )
        await self.tree.sync(guild=GUILD)

    async def on_ready(self):
        self.mention = re.compile(rf"^(?:<@!?{self.user.id}>\s*)?\.(sql|sqlwrite)\s+(.+)$", re.DOTALL | re.IGNORECASE)
        print(f"Logged in as {self.user} ({self.user.id})")

    async def on_message(self, message: discord.Message):
        if message.author.bot or not self.mention or not message.guild or message.guild.id != GUILD_ID:
            return
        match = self.mention.match(message.content.strip())
        if not match:
            await handle_prefix(message)
            return
        try:
            await handle_mention_sql(message, match.group(1).lower(), match.group(2))
        except Exception as error:
            entry = await report_error(f".{match.group(1).lower()}", message.author, error)
            try:
                await message.reply(f"Error `{entry['id']}`: {type(error).__name__}. Run /errors for details.")
            except discord.HTTPException:
                pass

    async def close(self):
        for session in (self.api, self.web):
            if session:
                await session.close()
        await super().close()


bot = AdminBot()


def is_allowed(interaction: discord.Interaction) -> bool:
    return interaction.guild_id == GUILD_ID and (interaction.user.id in ALLOWED_USERS or interaction.user.id == OWNER_ID)


def is_owner(interaction: discord.Interaction) -> bool:
    return interaction.guild_id == GUILD_ID and interaction.user.id == OWNER_ID


def audit_reason(interaction: discord.Interaction, reason: str) -> str:
    return f"{interaction.user.name} ({interaction.user.id}): {reason}"


def describe_error(status, data):
    if isinstance(data, dict) and isinstance(data.get("error"), str):
        return f"{data['error']} (HTTP {status})"
    return f"HTTP {status}"


def clean(text, limit: int = 1024) -> str:
    text = discord.utils.escape_markdown(str(text))
    return text if len(text) <= limit else text[: limit - 1] + "…"


def card(title: str, color: int = BRAND, description: str | None = None) -> discord.Embed:
    return discord.Embed(title=title, color=color, description=description, timestamp=discord.utils.utcnow())


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]", "", name)


def player_link(user_id: int, name: str | None) -> str:
    return f"[{safe_name(name)}]({roblox.profile_url(user_id)}) (`{user_id}`)" if name else f"`{user_id}`"


def player_plain(user_id: int, name: str | None) -> str:
    return f"{name} ({user_id})" if name else str(user_id)


async def call_api(method, path, json=None, params=None):
    async with bot.api.request(method, f"{API_URL}/{path}", json=json, params=params) as response:
        try:
            data = await response.json(content_type=None)
        except ValueError:
            data = None
        return response.status, data


async def run_sql(token: str, sql: str, params: list | None = None):
    body = {"sql": sql, "params": params} if params else {"sql": sql}
    try:
        async with bot.web.post(D1_URL, json=body, headers={"Authorization": f"Bearer {token}"}) as response:
            status = response.status
            try:
                data = await response.json(content_type=None)
            except ValueError:
                data = None
    except (aiohttp.ClientError, asyncio.TimeoutError) as error:
        return None, f"Couldn't reach Cloudflare ({type(error).__name__})"
    if not isinstance(data, dict) or not data.get("success"):
        errors = data.get("errors") if isinstance(data, dict) else None
        messages = [e.get("message", "unknown error") for e in errors or []]
        return None, "; ".join(messages) or f"HTTP {status}"
    return data["result"], None


async def read_rows(sql: str, params: list | None = None):
    result, error = await run_sql(D1_READ_TOKEN, sql, params)
    return (result[0].get("results") or [] if result else []), error


def format_results(result) -> str:
    lines = []
    for statement in result:
        rows = statement.get("results") or []
        meta = statement.get("meta") or {}
        if rows:
            columns = list(rows[0].keys())
            lines.append(" | ".join(columns))
            for row in rows:
                lines.append(" | ".join(str(row.get(column)) for column in columns))
        lines.append(f"-- {len(rows)} rows, {meta.get('changes', 0)} changed")
    return "\n".join(lines)


def rows_changed(result) -> int:
    return sum((statement.get("meta") or {}).get("changes", 0) for statement in result)


async def send_output(interaction: discord.Interaction, text: str):
    if len(text) <= 1900:
        await interaction.followup.send(f"```\n{text}\n```", ephemeral=True)
        return
    file = discord.File(io.BytesIO(text.encode()), filename="result.txt")
    await interaction.followup.send("The result is long, so it's attached as a file.", file=file, ephemeral=True)


async def post_log(embed: discord.Embed) -> bool:
    if not LOG_WEBHOOK_URL:
        return False
    try:
        async with bot.web.post(
            LOG_WEBHOOK_URL, json={"embeds": [embed.to_dict()], "allowed_mentions": {"parse": []}}
        ) as response:
            if response.status >= 300:
                print(f"Log webhook returned HTTP {response.status}")
            return response.status < 300
    except (aiohttp.ClientError, asyncio.TimeoutError) as error:
        print(f"Log webhook failed: {error!r}")
        return False


def secret_values() -> list[str | None]:
    return [os.environ.get(name) for name in SECRETS]


async def report_error(command: str, user: discord.abc.User, error: BaseException) -> dict:
    entry = debug.record(command, f"{user.name} ({user.id})", error, secret_values())
    print(f"Error {entry['id']} in {command}: {entry['text']}")
    await log_action(user, f"{command} error", False, [("Error ID", entry["id"]), ("Error", f"```\n{entry['text']}\n```")])
    return entry


async def timed(coroutine):
    start = time.perf_counter()
    outcome = await coroutine
    return outcome, (time.perf_counter() - start) * 1000


async def log_action(user: discord.abc.User, title: str, ok: bool, fields: list[tuple[str, object]]):
    embed = card(title if ok else f"{title} (failed)", OK if ok else FAIL)
    embed.add_field(name="By", value=f"{clean(user.name)} (`{user.id}`)", inline=True)
    for name, value in fields:
        text = str(value)[:1024] or "-"
        embed.add_field(name=name, value=text, inline=len(text) < 60)
    await post_log(embed)


async def item_autocomplete(interaction: discord.Interaction, current: str) -> list[app_commands.Choice[str]]:
    current = current.lower()
    matches = [item for item in items.all_ids(items.load()) if current in item.lower()]
    return [app_commands.Choice(name=item, value=item) for item in matches[:25]]


async def find_player(interaction: discord.Interaction, text: str) -> tuple[int, str | None] | None:
    found = await roblox.resolve(bot.web, text)
    if not found:
        await interaction.followup.send(
            embed=card("Player not found", FAIL, f"No Roblox user matches `{clean(text, 40)}`."), ephemeral=True
        )
    return found


def column_fields(embed: discord.Embed, heading: str, entries: list[str]):
    for index, column in enumerate(pages.columns(entries)):
        embed.add_field(name=heading if index == 0 else "​", value=column, inline=True)


def ledger_line(row: dict) -> str:
    when = f"<t:{int(row.get('created_at') or 0) // 1000}:d>"
    source = f"`{row.get('source')}`"
    if row.get("kind") == "credits":
        balance = row.get("balance_after")
        after = f" → {balance:,}" if isinstance(balance, int) else ""
        what = f"**{int(row.get('delta') or 0):+,}** credits{after}"
    else:
        verb = "Unlocked" if row.get("kind") == "unlock" else "Removed"
        what = f"{verb} {clean(row.get('item_ids') or '', 120)}"
    detail = clean(row.get("detail") or "", 90)
    return f"{when} · {what} · {source}" + (f"\n-# {detail}" if detail else "")


class Confirm(discord.ui.View):
    def __init__(self, owner_id: int):
        super().__init__(timeout=30)
        self.owner_id = owner_id
        self.confirmed = False

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        return interaction.user.id == self.owner_id

    @discord.ui.button(label="Confirm", style=discord.ButtonStyle.danger)
    async def confirm(self, interaction: discord.Interaction, button: discord.ui.Button):
        self.confirmed = True
        await interaction.response.edit_message(content="Confirmed. Sending...", view=None)
        self.stop()

    @discord.ui.button(label="Cancel", style=discord.ButtonStyle.secondary)
    async def cancel(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.edit_message(content="Cancelled.", view=None)
        self.stop()


@bot.tree.command(name="credits", description="Give or take a player's credits", guild=GUILD)
@app_commands.check(is_allowed)
@app_commands.describe(player="Roblox username or user ID", amount="Credits to add, negative to take away", reason="Why")
async def credits(
    interaction: discord.Interaction,
    player: app_commands.Range[str, 1, 32],
    amount: app_commands.Range[int, -MAX_CREDITS, MAX_CREDITS],
    reason: app_commands.Range[str, 1, 120],
):
    if amount == 0:
        await interaction.response.send_message("Amount can't be 0.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    found = await find_player(interaction, player)
    if not found:
        return
    user_id, name = found

    if abs(amount) > CONFIRM_ABOVE:
        view = Confirm(interaction.user.id)
        prompt = card("Confirm credit change", BRAND, f"Change {player_link(user_id, name)}'s credits by **{amount:+,}**?")
        prompt.add_field(name="Reason", value=clean(reason))
        await interaction.followup.send(embed=prompt, view=view, ephemeral=True)
        await view.wait()
        if not view.confirmed:
            return

    status, data = await call_api(
        "POST", f"{user_id}/credits", json={"delta": amount, "reason": audit_reason(interaction, reason)}
    )
    log_fields = [("Player", player_plain(user_id, name)), ("Amount", f"{amount:+,}"), ("Reason", reason)]
    if status != 200:
        await interaction.followup.send(embed=card("Credit change failed", FAIL, describe_error(status, data)), ephemeral=True)
        await log_action(interaction.user, "/credits", False, log_fields + [("Error", describe_error(status, data))])
        return

    result = card("Credits updated", OK)
    result.add_field(name="Player", value=player_link(user_id, name), inline=False)
    result.add_field(name="Change", value=f"{amount:+,}", inline=True)
    result.add_field(name="New balance", value=f"{data['credits']:,}", inline=True)
    result.add_field(name="Reason", value=clean(reason), inline=False)
    avatar = await roblox.headshot(bot.web, user_id)
    result.set_thumbnail(url=avatar)
    await interaction.followup.send(embed=result, ephemeral=True)
    verb = f"gave **{amount:,} credits** to" if amount > 0 else f"took **{-amount:,} credits** from"
    await announce(interaction, f"{verb} {player_link(user_id, name)}", reason, avatar)
    await log_action(interaction.user, "/credits", True, log_fields + [("New balance", f"{data['credits']:,}")])


async def announce(interaction: discord.Interaction, action: str, reason: str, avatar: str | None):
    embed = discord.Embed(
        color=OK,
        description=f"{interaction.user.mention} {action}\n**Reason:** {clean(reason)}",
        timestamp=discord.utils.utcnow(),
    )
    embed.set_thumbnail(url=avatar)
    await interaction.followup.send(embed=embed)


async def change_item(interaction: discord.Interaction, player: str, item_id: str, reason: str, give: bool):
    if not ITEM_ID.match(item_id):
        await interaction.response.send_message("That isn't a valid item ID.", ephemeral=True)
        return

    await interaction.response.defer(ephemeral=True)
    found = await find_player(interaction, player)
    if not found:
        return
    user_id, name = found

    if give:
        status, data = await call_api(
            "POST", f"{user_id}/unlocks", json={"itemId": item_id, "reason": audit_reason(interaction, reason)}
        )
    else:
        status, data = await call_api(
            "DELETE", f"{user_id}/unlocks/{quote(item_id, safe='')}", params={"reason": audit_reason(interaction, reason)}
        )

    command = "/giveitem" if give else "/removeitem"
    log_fields = [("Player", player_plain(user_id, name)), ("Item", item_id), ("Reason", reason)]
    if status != 200:
        await interaction.followup.send(embed=card("Item change failed", FAIL, describe_error(status, data)), ephemeral=True)
        await log_action(interaction.user, command, False, log_fields + [("Error", describe_error(status, data))])
        return

    result = card("Item given" if give else "Item removed", OK)
    result.add_field(name="Player", value=player_link(user_id, name), inline=False)
    result.add_field(name="Item", value=f"`{item_id}`", inline=True)
    result.add_field(name="Items owned", value=str(len(data.get("unlocks", []))), inline=True)
    result.add_field(name="Reason", value=clean(reason), inline=False)
    if give:
        result.set_footer(text="They get it next time they join.")
    avatar = await roblox.headshot(bot.web, user_id)
    result.set_thumbnail(url=avatar)
    await interaction.followup.send(embed=result, ephemeral=True)
    verb = f"gave `{item_id}` to" if give else f"removed `{item_id}` from"
    await announce(interaction, f"{verb} {player_link(user_id, name)}", reason, avatar)
    await log_action(interaction.user, command, True, log_fields)


@bot.tree.command(name="giveitem", description="Give a player a skin, banner or chat gradient", guild=GUILD)
@app_commands.check(is_allowed)
@app_commands.describe(player="Roblox username or user ID", item_id="Item to give", reason="Why")
@app_commands.autocomplete(item_id=item_autocomplete)
async def giveitem(
    interaction: discord.Interaction,
    player: app_commands.Range[str, 1, 32],
    item_id: str,
    reason: app_commands.Range[str, 1, 120],
):
    await change_item(interaction, player, item_id, reason, True)


@bot.tree.command(name="removeitem", description="Take an item away from a player", guild=GUILD)
@app_commands.check(is_allowed)
@app_commands.describe(player="Roblox username or user ID", item_id="Item to remove", reason="Why")
@app_commands.autocomplete(item_id=item_autocomplete)
async def removeitem(
    interaction: discord.Interaction,
    player: app_commands.Range[str, 1, 32],
    item_id: str,
    reason: app_commands.Range[str, 1, 120],
):
    await change_item(interaction, player, item_id, reason, False)


@bot.tree.command(name="lookup", description="Show a player's credits, items, rank and history", guild=GUILD)
@app_commands.check(is_owner)
@app_commands.describe(player="Roblox username or user ID")
async def lookup(interaction: discord.Interaction, player: app_commands.Range[str, 1, 32]):
    await interaction.response.defer(ephemeral=True)
    found = await find_player(interaction, player)
    if not found:
        return
    user_id, name = found

    (status, data), avatar, (rank_rows, _) = await asyncio.gather(
        call_api("GET", str(user_id)),
        roblox.headshot(bot.web, user_id),
        read_rows("SELECT rank FROM staff_ranks WHERE user_id = ?", [user_id]),
    )
    if status != 200:
        await interaction.followup.send(embed=card("Lookup failed", FAIL, describe_error(status, data)), ephemeral=True)
        return

    unlocks = data.get("unlocks", [])
    ledger = data.get("ledger", [])
    title = name or str(user_id)

    def base(subtitle: str) -> discord.Embed:
        embed = card(f"{safe_name(title)} · {subtitle}", BRAND)
        embed.url = roblox.profile_url(user_id)
        embed.set_thumbnail(url=avatar)
        return embed

    overview = base("Overview")
    overview.add_field(name="Credits", value=f"{data['credits']:,}", inline=True)
    overview.add_field(name="Items", value=str(len(unlocks)), inline=True)
    overview.add_field(name="Staff rank", value=rank_rows[0]["rank"] if rank_rows else "None", inline=True)
    overview.add_field(name="Purchases", value=str(sum(1 for row in ledger if row.get("source") == "purchase")), inline=True)
    overview.add_field(name="Crates opened", value=str(sum(1 for row in ledger if row.get("source") == "crate" and row.get("kind") == "credits")), inline=True)
    overview.add_field(name="Transactions", value=f"{len(ledger)}+" if len(ledger) >= 100 else str(len(ledger)), inline=True)
    if ledger:
        overview.add_field(name="Last activity", value=f"<t:{int(ledger[0]['created_at']) // 1000}:R>", inline=True)
    embeds = [overview]

    category_of = {item: category for category, ids in items.load().items() for item in ids}
    grouped: dict[str, list[str]] = {}
    for item in unlocks:
        grouped.setdefault(category_of.get(item, "Other"), []).append(f"`{item}`")
    for category, entries in grouped.items():
        for part in pages.chunk(sorted(entries), 30):
            embed = base("Items")
            column_fields(embed, f"{CATEGORY_NAMES.get(category, category)} ({len(entries)})", part)
            embeds.append(embed)

    for part in pages.chunk(ledger, 10) if ledger else []:
        history = base("History")
        history.description = "\n".join(ledger_line(row) for row in part)
        embeds.append(history)

    await pages.send(interaction, pages.number(embeds, f"User ID {user_id}"))


@bot.tree.command(name="items", description="List every item ID you can give", guild=GUILD)
@app_commands.check(is_allowed)
@app_commands.describe(category="Only show one kind of item")
async def items_command(
    interaction: discord.Interaction,
    category: Literal["GunSkin", "PlayerCard", "ChatGradient", "CratePack"] | None = None,
):
    await interaction.response.defer(ephemeral=True)
    embeds = []
    for name, ids in items.load().items():
        if category not in (None, name):
            continue
        for part in pages.chunk([f"`{item}`" for item in ids], 45):
            embed = card(f"{CATEGORY_NAMES.get(name, name)} ({len(ids)})", BRAND)
            column_fields(embed, "Item IDs", part)
            embeds.append(embed)
    await pages.send(interaction, pages.number(embeds or [card("No items found", FAIL)], "Use these with /giveitem"))


@bot.tree.command(name="owners", description="Who owns an item", guild=GUILD)
@app_commands.check(is_owner)
@app_commands.describe(item_id="Item to check")
@app_commands.autocomplete(item_id=item_autocomplete)
async def owners(interaction: discord.Interaction, item_id: str):
    if not ITEM_ID.match(item_id):
        await interaction.response.send_message("That isn't a valid item ID.", ephemeral=True)
        return
    await interaction.response.defer(ephemeral=True)

    (count_rows, error), (rows, list_error) = await asyncio.gather(
        read_rows("SELECT COUNT(*) AS total FROM unlocks WHERE item_id = ?", [item_id]),
        read_rows("SELECT user_id, created_at FROM unlocks WHERE item_id = ? ORDER BY created_at DESC LIMIT 300", [item_id]),
    )
    if error or list_error:
        await interaction.followup.send(embed=card("Query failed", FAIL, clean(error or list_error)), ephemeral=True)
        return

    total = count_rows[0]["total"] if count_rows else 0
    known = await roblox.names(bot.web, [int(row["user_id"]) for row in rows])
    lines = [
        f"`{index}.` {player_link(int(row['user_id']), known.get(int(row['user_id'])))} · <t:{int(row['created_at']) // 1000}:d>"
        for index, row in enumerate(rows, 1)
    ]
    embeds = []
    for part in pages.chunk(lines, 15):
        embed = card(f"Owners of {item_id}", BRAND, "\n".join(part) or "Nobody owns this yet.")
        embed.add_field(name="Total owners", value=f"{total:,}" + (" (showing newest 300)" if total > 300 else ""))
        embeds.append(embed)
    await pages.send(interaction, pages.number(embeds))


@bot.tree.command(name="economy", description="Credits in circulation and the last 24 hours", guild=GUILD)
@app_commands.check(is_allowed)
async def economy(interaction: discord.Interaction):
    await interaction.response.defer(ephemeral=True)
    since = int(time.time() * 1000) - 86_400_000
    (totals, error), (recent, recent_error), (top, top_error) = await asyncio.gather(
        read_rows("SELECT COUNT(*) AS players, COALESCE(SUM(credits), 0) AS credits FROM players"),
        read_rows(
            "SELECT source, kind, COUNT(*) AS n, COALESCE(SUM(delta), 0) AS total FROM ledger WHERE created_at >= ? GROUP BY source, kind",
            [since],
        ),
        read_rows("SELECT user_id, credits FROM players ORDER BY credits DESC LIMIT 10"),
    )
    if error or recent_error or top_error:
        await interaction.followup.send(embed=card("Query failed", FAIL, clean(error or recent_error or top_error)), ephemeral=True)
        return

    def sum_of(source: str, field: str = "total", kind: str = "credits") -> int:
        return sum(int(row[field]) for row in recent if row["source"] == source and row["kind"] == kind)

    overview = card("Economy", BRAND)
    overview.add_field(name="Credits held", value=f"{int(totals[0]['credits']):,}", inline=True)
    overview.add_field(name="Players with data", value=f"{int(totals[0]['players']):,}", inline=True)
    overview.add_field(name="​", value="**Last 24 hours**", inline=False)
    overview.add_field(name="Credits bought", value=f"{sum_of('purchase'):,} ({sum_of('purchase', 'n')} buys)", inline=True)
    overview.add_field(name="Crates opened", value=f"{sum_of('crate', 'n'):,} ({-sum_of('crate'):,} spent)", inline=True)
    overview.add_field(name="Match rewards", value=f"{sum_of('match') + sum_of('match_private'):,}", inline=True)
    overview.add_field(name="Admin credits", value=f"{sum_of('admin'):+,} ({sum_of('admin', 'n')} changes)", inline=True)
    overview.add_field(name="Admin items", value=f"{sum_of('admin', 'n', 'unlock')} given, {sum_of('admin', 'n', 'remove_unlock')} removed", inline=True)

    known = await roblox.names(bot.web, [int(row["user_id"]) for row in top])
    leaderboard = card("Top balances", BRAND, "\n".join(
        f"`{index}.` {player_link(int(row['user_id']), known.get(int(row['user_id'])))} · **{int(row['credits']):,}**"
        for index, row in enumerate(top, 1)
    ) or "No players yet.")
    await pages.send(interaction, pages.number([overview, leaderboard]))


@bot.tree.command(name="sql", description="Run a read-only SQL query on game-db", guild=GUILD)
@app_commands.check(is_owner)
@app_commands.describe(query="SQL to run, like SELECT * FROM staff_ranks")
async def sql(interaction: discord.Interaction, query: app_commands.Range[str, 1, 1800]):
    await interaction.response.defer(ephemeral=True)
    result, error = await run_sql(D1_READ_TOKEN, query)
    if error:
        await interaction.followup.send(f"Failed: {error}", ephemeral=True)
        await log_action(interaction.user, "/sql", False, [("Query", f"```sql\n{query[:1000]}\n```"), ("Error", error)])
        return
    await send_output(interaction, format_results(result))
    await log_action(interaction.user, "/sql", True, [("Query", f"```sql\n{query[:1000]}\n```")])


@bot.tree.command(name="sqlwrite", description="Run SQL that changes game-db (owner only)", guild=GUILD)
@app_commands.check(is_owner)
@app_commands.describe(query="SQL that changes data, like an INSERT, UPDATE or DELETE")
async def sqlwrite(interaction: discord.Interaction, query: app_commands.Range[str, 1, 1800]):
    if BLOCKED_SQL.search(query):
        await interaction.response.send_message("DROP and ALTER aren't allowed from Discord. Use wrangler for those.", ephemeral=True)
        return

    view = Confirm(interaction.user.id)
    await interaction.response.send_message(f"Run this on game-db?\n```sql\n{query}\n```", view=view, ephemeral=True)
    await view.wait()
    if not view.confirmed:
        return

    result, error = await run_sql(D1_WRITE_TOKEN, query)
    if error:
        await interaction.followup.send(f"Failed: {error}", ephemeral=True)
        await log_action(interaction.user, "/sqlwrite", False, [("Query", f"```sql\n{query[:1000]}\n```"), ("Error", error)])
        return
    await send_output(interaction, format_results(result))
    await log_action(interaction.user, "/sqlwrite", True, [("Query", f"```sql\n{query[:1000]}\n```"), ("Rows changed", rows_changed(result))])


async def handle_mention_sql(message: discord.Message, command: str, query: str):
    if message.author.id != OWNER_ID:
        return

    fenced = CODE_FENCE.match(query.strip())
    query = (fenced.group(1) if fenced else query).strip()
    if not query or len(query) > 1800:
        await message.reply("The query has to be between 1 and 1800 characters.")
        return
    if command == "sqlwrite" and BLOCKED_SQL.search(query):
        await message.reply("DROP and ALTER aren't allowed from Discord. Use wrangler for those.")
        return

    view = Confirm(OWNER_ID)
    label = "read-only" if command == "sql" else "**write**"
    prompt = await message.reply(f"Run this {label} query on game-db?\n```sql\n{query}\n```", view=view)
    timed_out = await view.wait()
    if timed_out:
        await prompt.edit(content="Timed out. Nothing was run.", view=None)
        return
    if not view.confirmed:
        return

    result, error = await run_sql(D1_READ_TOKEN if command == "sql" else D1_WRITE_TOKEN, query)
    fields = [("Query", f"```sql\n{query[:1000]}\n```"), ("Channel", message.channel.mention)]
    if error:
        await prompt.edit(content=f"Failed: {error}")
        await log_action(message.author, f".{command}", False, fields + [("Error", error)])
        return

    text = format_results(result)
    if len(text) <= 1900:
        await prompt.edit(content=f"```\n{text}\n```")
    else:
        await prompt.edit(content="The result is long, so it's attached as a file.")
        await message.channel.send(file=discord.File(io.BytesIO(text.encode()), filename="result.txt"))
    if command == "sqlwrite":
        fields.append(("Rows changed", rows_changed(result)))
    await log_action(message.author, f".{command}", True, fields)


@bot.tree.command(name="ping", description="Bot, API and database response times (owner only)", guild=GUILD)
@app_commands.check(is_owner)
async def ping(interaction: discord.Interaction):
    await interaction.response.defer(ephemeral=True)
    ((status, _), api_ms), ((_, d1_error), d1_ms) = await asyncio.gather(
        timed(call_api("GET", "1")), timed(run_sql(D1_READ_TOKEN, "SELECT 1"))
    )
    embed = card("Pong", OK if status == 200 and not d1_error else FAIL)
    embed.add_field(name="Discord", value=f"{bot.latency * 1000:.0f} ms", inline=True)
    embed.add_field(name="Admin API", value=f"{api_ms:.0f} ms" + ("" if status == 200 else f" (HTTP {status})"), inline=True)
    embed.add_field(name="D1", value=f"{d1_ms:.0f} ms" + ("" if not d1_error else " (error)"), inline=True)
    await interaction.followup.send(embed=embed, ephemeral=True)


@bot.tree.command(name="config", description="Which settings loaded, never their values (owner only)", guild=GUILD)
@app_commands.check(is_owner)
async def config(interaction: discord.Interaction):
    embed = card("Config", BRAND)
    embed.add_field(name="Secrets", value="\n".join(f"`{name}` {'set' if os.environ.get(name) else 'MISSING'}" for name in SECRETS), inline=True)
    try:
        catalog = items.load()
        item_status = f"{sum(len(ids) for ids in catalog.values())} items"
    except OSError:
        item_status = "Can't read bot/Cosmetics"
    embed.add_field(
        name="Settings",
        value=f"Staff: {len(ALLOWED_USERS)}\nMax credits: {MAX_CREDITS:,}\nConfirm above: {CONFIRM_ABOVE:,}\nItem list: {item_status}",
        inline=True,
    )
    await interaction.response.send_message(embed=embed, ephemeral=True)


@bot.tree.command(name="sync", description="Re-register the slash commands (owner only)", guild=GUILD)
@app_commands.check(is_owner)
async def sync(interaction: discord.Interaction):
    await interaction.response.defer()
    synced = await bot.tree.sync(guild=GUILD)
    await interaction.followup.send(embed=card("Synced", OK, f"{len(synced)} commands registered."))


@bot.tree.command(name="errors", description="The last 20 errors since the bot started (owner only)", guild=GUILD)
@app_commands.check(is_owner)
async def errors(interaction: discord.Interaction):
    await interaction.response.defer(ephemeral=True)
    entries = [
        f"`{entry['id']}` · <t:{entry['when']}:R> · {entry['command']} · {clean(entry['user'], 80)}\n```\n{entry['text']}\n```"
        for entry in debug.recent
    ]
    embeds = [card(f"Errors ({len(debug.recent)})", FAIL if entries else OK, "\n".join(part) or "No errors since the bot started.") for part in pages.chunk(entries, 4)]
    await pages.send(interaction, pages.number(embeds))


@bot.tree.command(name="health", description="Check that every service the bot uses works (owner only)", guild=GUILD)
@app_commands.check(is_owner)
async def health(interaction: discord.Interaction):
    await interaction.response.defer(ephemeral=True)

    async def item_count():
        return sum(len(ids) for ids in items.load().values())

    async def safely(coroutine):
        try:
            return await timed(coroutine)
        except Exception as error:
            return error, 0.0

    ping_log = card("Health check", BRAND, f"Test entry from /health by {clean(interaction.user.name)}.")
    (api, api_ms), (d1, d1_ms), (user, roblox_ms), (count, items_ms), (logged, log_ms) = await asyncio.gather(
        safely(call_api("GET", "1")),
        safely(run_sql(D1_READ_TOKEN, "SELECT 1")),
        safely(roblox.resolve(bot.web, "1")),
        safely(item_count()),
        safely(post_log(ping_log)),
    )

    def line(ok: bool, ms: float, problem: str) -> str:
        return f"OK · {ms:.0f} ms" if ok else f"**FAILED** · {clean(debug.scrub(problem, secret_values()), 200)}"

    checks = {
        "Admin API": line(isinstance(api, tuple) and api[0] == 200, api_ms, str(api[0] if isinstance(api, tuple) else api)),
        "D1 database": line(isinstance(d1, tuple) and not d1[1], d1_ms, str(d1[1] if isinstance(d1, tuple) else d1)),
        "Roblox": line(isinstance(user, tuple) and bool(user[1]), roblox_ms, "no answer" if not isinstance(user, Exception) else str(user)),
        "Item list": line(isinstance(count, int), items_ms, str(count)) + (f" · {count} items" if isinstance(count, int) else ""),
        "Log webhook": line(logged is True, log_ms, "not set" if not LOG_WEBHOOK_URL else str(logged)),
    }
    embed = card("Health", OK if all(value.startswith("OK") for value in checks.values()) else FAIL)
    for name, value in checks.items():
        embed.add_field(name=name, value=value, inline=False)
    await interaction.followup.send(embed=embed, ephemeral=True)


@bot.tree.command(name="status", description="Uptime, versions and memory (owner only)", guild=GUILD)
@app_commands.check(is_owner)
async def status(interaction: discord.Interaction):
    embed = card("Status", BRAND)
    embed.add_field(name="Started", value=f"<t:{STARTED}:R>", inline=True)
    embed.add_field(name="Memory", value=f"{resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024:.0f} MB peak", inline=True)
    embed.add_field(name="Discord latency", value=f"{bot.latency * 1000:.0f} ms", inline=True)
    embed.add_field(name="Python", value=platform.python_version(), inline=True)
    embed.add_field(name="discord.py", value=discord.__version__, inline=True)
    embed.add_field(name="aiohttp", value=aiohttp.__version__, inline=True)
    embed.add_field(name="Servers", value=str(len(bot.guilds)), inline=True)
    embed.add_field(name="Staff", value=str(len(ALLOWED_USERS)), inline=True)
    last = f" · last <t:{debug.recent[0]['when']}:R>" if debug.recent else ""
    embed.add_field(name="Errors", value=f"{len(debug.recent)}{last}", inline=True)
    await interaction.response.send_message(embed=embed, ephemeral=True)


@bot.tree.command(name="raw", description="The raw API data for a player, as a file (owner only)", guild=GUILD)
@app_commands.check(is_owner)
@app_commands.describe(player="Roblox username or user ID")
async def raw(interaction: discord.Interaction, player: app_commands.Range[str, 1, 32]):
    await interaction.response.defer(ephemeral=True)
    found = await find_player(interaction, player)
    if not found:
        return
    user_id, name = found
    status_code, data = await call_api("GET", str(user_id))
    text = json.dumps({"status": status_code, "data": data}, indent=2)
    file = discord.File(io.BytesIO(text.encode()), filename=f"raw-{user_id}.json")
    await interaction.followup.send(embed=card("Raw API data", BRAND, f"{player_link(user_id, name)} · HTTP {status_code}"), file=file, ephemeral=True)


@bot.tree.command(name="tx", description="One ledger entry in full (owner only)", guild=GUILD)
@app_commands.check(is_owner)
@app_commands.describe(tx_id="Transaction ID from the ledger")
async def tx(interaction: discord.Interaction, tx_id: app_commands.Range[str, 1, 128]):
    if not TX_ID.match(tx_id):
        await interaction.response.send_message("That isn't a valid transaction ID.", ephemeral=True)
        return
    await interaction.response.defer(ephemeral=True)
    rows, error = await read_rows("SELECT * FROM ledger WHERE tx_id = ?", [tx_id])
    if error or not rows:
        await interaction.followup.send(embed=card("Transaction not found", FAIL, clean(error or f"No ledger entry with ID `{tx_id}`.")), ephemeral=True)
        return
    row = rows[0]
    user_id = int(row["user_id"])
    known = await roblox.names(bot.web, [user_id])
    embed = card("Transaction", BRAND, ledger_line(row))
    embed.add_field(name="Player", value=player_link(user_id, known.get(user_id)), inline=False)
    for column, value in row.items():
        if column not in ("user_id", "detail") and value is not None:
            embed.add_field(name=column, value=f"`{clean(value, 200)}`", inline=True)
    if row.get("detail"):
        embed.add_field(name="detail", value=clean(row["detail"]), inline=False)
    await interaction.followup.send(embed=embed, ephemeral=True)


@bot.tree.command(name="dbinfo", description="Row counts and size of game-db (owner only)", guild=GUILD)
@app_commands.check(is_owner)
async def dbinfo(interaction: discord.Interaction):
    await interaction.response.defer(ephemeral=True)
    result, error = await run_sql(
        D1_READ_TOKEN,
        "SELECT (SELECT COUNT(*) FROM players) AS players, (SELECT COUNT(*) FROM unlocks) AS unlocks, "
        "(SELECT COUNT(*) FROM ledger) AS ledger, (SELECT COUNT(*) FROM staff_ranks) AS staff_ranks",
    )
    if error:
        await interaction.followup.send(embed=card("Query failed", FAIL, clean(error)), ephemeral=True)
        return
    counts = (result[0].get("results") or [{}])[0]
    size = (result[0].get("meta") or {}).get("size_after")
    embed = card("game-db", BRAND)
    for table, count in counts.items():
        embed.add_field(name=table, value=f"{int(count):,} rows", inline=True)
    if isinstance(size, (int, float)):
        embed.add_field(name="Size", value=f"{size / 1_048_576:.2f} MB", inline=True)
    await interaction.followup.send(embed=embed, ephemeral=True)


def command_tiers() -> dict[str, list[str]]:
    tiers: dict[str, list[str]] = {"everyone": [], "staff": [], "owner": []}
    for command in bot.tree.get_commands(guild=GUILD):
        checks = getattr(command, "checks", None) or [check for sub in getattr(command, "commands", []) for check in sub.checks]
        tier = "owner" if is_owner in checks else "staff" if is_allowed in checks else "everyone"
        tiers[tier].append(f"`/{command.name}`")
    return {tier: sorted(names) for tier, names in tiers.items()}


@bot.tree.command(name="whoami", description="What you're allowed to do with this bot", guild=GUILD)
async def whoami(interaction: discord.Interaction):
    owner = interaction.user.id == OWNER_ID
    allowed = owner or interaction.user.id in ALLOWED_USERS
    admin = isinstance(interaction.user, discord.Member) and interaction.user.guild_permissions.administrator
    embed = card("Who am I", OK if allowed else BRAND)
    embed.add_field(name="Discord ID", value=f"`{interaction.user.id}`", inline=True)
    embed.add_field(name="Bot access", value="Owner" if owner else "Staff" if allowed else "None", inline=True)
    embed.add_field(name="Server admin", value="Yes" if admin else "No", inline=True)
    tiers = command_tiers()
    embed.add_field(name="Everyone", value=" ".join(tiers["everyone"]), inline=False)
    if allowed:
        embed.add_field(name="Staff", value=" ".join(tiers["staff"]), inline=False)
    if owner:
        embed.add_field(name="Owner", value=" ".join(tiers["owner"] + ["`@bot .sql`", "`@bot .sqlwrite`"]), inline=False)
    if not allowed:
        embed.add_field(name="More access", value="Ask the owner to run /auth add for you.", inline=False)
    await interaction.response.send_message(embed=embed, ephemeral=True)


auth = app_commands.Group(
    name="auth",
    description="Manage who can use the staff commands (owner only)",
    guild_ids=[GUILD_ID],
)


@auth.command(name="add", description="Let someone use the staff commands")
@app_commands.check(is_owner)
@app_commands.describe(member="Who to give access")
async def auth_add(interaction: discord.Interaction, member: discord.User):
    if member.bot or member.id == OWNER_ID or member.id in ALLOWED_USERS:
        await interaction.response.send_message(embed=card("Nothing to change", FAIL, f"{member.mention} is a bot, the owner, or already has access."), ephemeral=True)
        return
    ALLOWED_USERS.add(member.id)
    staff.save(ALLOWED_USERS)
    await interaction.response.send_message(embed=card("Access given", OK, f"{member.mention} can now use the staff commands."), ephemeral=True)
    await log_action(interaction.user, "/auth add", True, [("Member", f"{clean(member.name)} (`{member.id}`)")])


@auth.command(name="remove", description="Take someone's staff access away")
@app_commands.check(is_owner)
@app_commands.describe(member="Who to remove")
async def auth_remove(interaction: discord.Interaction, member: discord.User):
    if member.id not in ALLOWED_USERS:
        await interaction.response.send_message(embed=card("Nothing to change", FAIL, f"{member.mention} doesn't have access."), ephemeral=True)
        return
    ALLOWED_USERS.discard(member.id)
    staff.save(ALLOWED_USERS)
    await interaction.response.send_message(embed=card("Access removed", OK, f"{member.mention} can't use the staff commands anymore."), ephemeral=True)
    await log_action(interaction.user, "/auth remove", True, [("Member", f"{clean(member.name)} (`{member.id}`)")])


@auth.command(name="list", description="Who has staff access")
@app_commands.check(is_owner)
async def auth_list(interaction: discord.Interaction):
    lines = [f"<@{OWNER_ID}> · owner"] + [f"<@{user_id}> · `{user_id}`" for user_id in sorted(ALLOWED_USERS)]
    await interaction.response.send_message(embed=card(f"Bot access ({len(ALLOWED_USERS) + 1})", BRAND, "\n".join(lines)), ephemeral=True)


bot.tree.add_command(auth)


async def handle_prefix(message: discord.Message):
    words = message.content.strip()[1:].split(None, 1) if message.content.startswith(".") else []
    command = bot.tree.get_command(words[0].lower(), guild=GUILD) if words else None
    rest = words[1] if len(words) > 1 else ""
    if isinstance(command, app_commands.Group):
        sub = rest.split(None, 1)
        command = command.get_command(sub[0].lower()) if sub else None
        rest = sub[1] if len(sub) > 1 else ""
    if not command:
        return

    interaction = prefix.MessageInteraction(message, command)
    try:
        if not await command._check_can_run(interaction):
            return
        try:
            values = await prefix.parse(command, rest, bot.fetch_user)
        except ValueError as problem:
            await message.reply(str(problem))
            return
        await command.callback(interaction, **values)
    except Exception as error:
        await on_app_command_error(interaction, error)


@bot.tree.error
async def on_app_command_error(interaction: discord.Interaction, error: app_commands.AppCommandError):
    command = f"/{interaction.command.qualified_name}" if interaction.command else "unknown command"
    if isinstance(error, app_commands.CheckFailure):
        embed = card("Not allowed", FAIL, "You can't use this command. Run /whoami to see what you can use.")
        if time.time() - denied_logged.get(interaction.user.id, 0) >= DENIED_LOG_COOLDOWN:
            denied_logged[interaction.user.id] = time.time()
            await log_action(interaction.user, f"{command} (denied)", False, [("Channel", f"<#{interaction.channel_id}>")])
    else:
        entry = await report_error(command, interaction.user, getattr(error, "original", error))
        if interaction.user.id == OWNER_ID:
            embed = card("Error", FAIL, f"```\n{entry['text']}\n```")
        else:
            embed = card("Something went wrong", FAIL, "Send this error ID to the bot owner.")
        embed.set_footer(text=f"Error ID {entry['id']}")

    try:
        if interaction.response.is_done():
            await interaction.followup.send(embed=embed, ephemeral=True)
        else:
            await interaction.response.send_message(embed=embed, ephemeral=True)
    except discord.HTTPException as reply_error:
        print(f"Couldn't send the error reply: {reply_error!r}")


bot.run(DISCORD_TOKEN)
