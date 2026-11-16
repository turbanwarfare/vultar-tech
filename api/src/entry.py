import hmac
import json
import re
import time
import uuid
from urllib.parse import parse_qs, unquote, urlparse

from js import Object
from pyodide.ffi import to_js
from workers import Response, WorkerEntrypoint, fetch

CREDIT_PACKS = {100, 200, 500, 800, 1000, 1500, 5000, 10000}
MAX_PURCHASE_CREDITS_PER_DAY = 100_000
MAX_CRATE_COST = 100_000
MAX_CRATE_AMOUNT = 10
MAX_UNLOCKS_PER_REQUEST = 20
MAX_ADMIN_DELTA = 1_000_000
MAX_BODY_BYTES = 8_192
LEDGER_PAGE_SIZE = 100
DAY_MS = 86_400_000
LARGE_CREDIT_ALERT = 10_000
HOUR_MS = 3_600_000
MATCH_RULES = {
    "match": {"max_reward": 300, "cooldown_ms": 5 * 60_000, "hour_cap": None, "day_cap": 2_000},
    "match_private": {"max_reward": 100, "cooldown_ms": 10 * 60_000, "hour_cap": None, "day_cap": 2_000},
}
ERROR_ALERT_COOLDOWN_S = 60
DAILY_STATUS_CRON = "0 12 * * *"

COLOR_INFO = 0x5865F2
COLOR_WARN = 0xFF8C00
COLOR_ERROR = 0xED4245
COLOR_OK = 0x57F287

last_error_alert = 0.0
username_cache = {}

ITEM_ID = re.compile(r"^[A-Za-z0-9_-]{1,64}(:[A-Za-z0-9_+ -]{1,32})?$")
TX_ID = re.compile(r"^[A-Za-z0-9_:.{}-]{8,128}$")
MAP_NAME = re.compile(r"^[A-Za-z0-9_ -]{1,40}$")
RANK_NAME = re.compile(r"^[A-Za-z ]{1,32}$")
CRATE_ID = re.compile(r"^[A-Za-z0-9_-]{1,32}$")
USER_ID = re.compile(r"^[1-9][0-9]{0,15}$")


class HttpError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message


def now_ms():
    return int(time.time() * 1000)


def js_obj(value):
    return to_js(value, dict_converter=Object.fromEntries)


def py(value):
    return value.to_py() if hasattr(value, "to_py") else value


def json_response(status, body):
    return Response(json.dumps(body), status=status, headers={"content-type": "application/json"})


def key_matches(provided, expected):
    if not provided or not expected:
        return False
    return hmac.compare_digest(provided.encode(), str(expected).encode())


def bearer_token(request):
    header = request.headers.get("authorization")
    if header and header.startswith("Bearer "):
        return header[7:]
    return None


def parse_user_id(raw):
    if raw is None or not USER_ID.match(raw):
        raise HttpError(400, "invalid userId")
    return int(raw)


def require_int(value, name, minimum, maximum):
    if isinstance(value, float) and value.is_integer():
        value = int(value)
    if not isinstance(value, int) or isinstance(value, bool) or value < minimum or value > maximum:
        raise HttpError(400, f"invalid {name}")
    return value


def require_string(value, name, pattern):
    if not isinstance(value, str) or not pattern.match(value):
        raise HttpError(400, f"invalid {name}")
    return value


def require_reason(value):
    if not isinstance(value, str) or not value.strip() or len(value) > 200:
        raise HttpError(400, "reason is required (max 200 chars)")
    return value.strip()


async def read_body(request):
    text = await request.text()
    if len(text.encode()) > MAX_BODY_BYTES:
        raise HttpError(413, "body too large")
    try:
        parsed = json.loads(text)
    except ValueError:
        parsed = None
    if not isinstance(parsed, dict):
        raise HttpError(400, "body must be a JSON object")
    return parsed


def place_id(request):
    header = request.headers.get("roblox-id")
    return header[:32] if header else ""


def escape_markdown(text):
    return re.sub(r"([\\*_~`|>\[\]()])", r"\\\1", text)


async def player_label(user_id):
    profile_url = f"https://www.roblox.com/users/{user_id}/profile"
    names = username_cache.get(user_id)
    if names is None:
        try:
            response = await fetch(f"https://users.roblox.com/v1/users/{user_id}")
            if response.status == 200:
                data = py(await response.json())
                names = (data.get("name"), data.get("displayName"))
                username_cache[user_id] = names
        except Exception as err:
            print(f"username lookup failed: {err}")
    if not names or not names[0]:
        return f"[{user_id}]({profile_url})"
    name, display = names
    label = f"[{escape_markdown(name)}]({profile_url})"
    if display and display != name:
        label += f" ({escape_markdown(display)})"
    return label


async def send_alert(env, title, color, fields):
    url = getattr(env, "ALERT_WEBHOOK_URL", None)
    if not url:
        return
    embed = {
        "title": title,
        "color": color,
        "fields": [{"name": name, "value": str(value)[:1024], "inline": True} for name, value in fields],
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    try:
        await fetch(
            str(url),
            method="POST",
            headers={"content-type": "application/json"},
            body=json.dumps({"embeds": [embed], "allowed_mentions": {"parse": []}}),
        )
    except Exception as err:
        print(f"alert failed: {err}")


class Api:
    def __init__(self, env):
        self.env = env
        self.db = env.DB

    async def first(self, sql, *params):
        return py(await self.db.prepare(sql).bind(*params).first())

    async def all(self, sql, *params):
        result = py(await self.db.prepare(sql).bind(*params).all())
        return result["results"]

    async def get_credits(self, user_id):
        row = await self.first("SELECT credits FROM players WHERE user_id = ?", user_id)
        return row["credits"] if row else 0

    async def get_profile(self, user_id):
        rows = await self.all("SELECT item_id FROM unlocks WHERE user_id = ? ORDER BY created_at", user_id)
        return {
            "userId": user_id,
            "credits": await self.get_credits(user_id),
            "unlocks": [row["item_id"] for row in rows],
        }

    async def replay_if_exists(self, tx_id, user_id):
        existing = await self.first("SELECT user_id FROM ledger WHERE tx_id = ?", tx_id)
        if not existing:
            return None
        if existing["user_id"] != user_id:
            raise HttpError(409, "txId already used for another player")
        return json_response(200, {"credits": await self.get_credits(user_id), "replayed": True})

    async def apply_credit_change(self, tx_id, user_id, delta, source, detail, place, unlocks, before_apply=None):
        replay = await self.replay_if_exists(tx_id, user_id)
        if replay:
            return replay

        if before_apply:
            await before_apply()

        now = now_ms()
        statements = [
            self.db.prepare("INSERT OR IGNORE INTO players (user_id, credits, updated_at) VALUES (?, 0, ?)").bind(
                user_id, now
            ),
            self.db.prepare("UPDATE players SET credits = credits + ?, updated_at = ? WHERE user_id = ?").bind(
                delta, now, user_id
            ),
            self.db.prepare(
                """INSERT INTO ledger (tx_id, user_id, kind, source, delta, balance_after, item_ids, detail, place_id, created_at)
                   VALUES (?, ?, 'credits', ?, ?, (SELECT credits FROM players WHERE user_id = ?), NULLIF(?, ''), ?, NULLIF(?, ''), ?)"""
            ).bind(tx_id, user_id, source, delta, user_id, json.dumps(unlocks) if unlocks else "", detail, place, now),
        ]
        for item_id in unlocks:
            statements.append(
                self.db.prepare("INSERT OR IGNORE INTO unlocks (user_id, item_id, created_at) VALUES (?, ?, ?)").bind(
                    user_id, item_id, now
                )
            )

        try:
            await self.db.batch(to_js(statements))
        except Exception as err:
            message = str(err)
            if "CHECK constraint failed" in message:
                raise HttpError(409, "insufficient credits")
            if "UNIQUE constraint failed: ledger.tx_id" in message:
                raced = await self.replay_if_exists(tx_id, user_id)
                if raced:
                    return raced
            raise

        credits = await self.get_credits(user_id)
        if source == "admin" or abs(delta) >= LARGE_CREDIT_ALERT:
            await send_alert(
                self.env,
                "Admin credit change" if source == "admin" else "Large credit change",
                COLOR_WARN,
                [
                    ("Player", await player_label(user_id)),
                    ("Change", f"{delta:+,}"),
                    ("New balance", f"{credits:,}"),
                    ("Source", source),
                    ("Detail", detail),
                    ("Place", place or "-"),
                ],
            )
        return json_response(200, {"credits": credits, "replayed": False})

    async def handle_purchase(self, request, user_id):
        body = await read_body(request)
        credits = require_int(body.get("credits"), "credits", 1, 10_000)
        if credits not in CREDIT_PACKS:
            raise HttpError(400, "credits must match a credit pack")
        product_id = require_int(body.get("productId"), "productId", 1, 2**53 - 1)

        async def check_daily_cap():
            row = await self.first(
                "SELECT COALESCE(SUM(delta), 0) AS total FROM ledger WHERE user_id = ? AND source = 'purchase' AND created_at > ?",
                user_id,
                now_ms() - DAY_MS,
            )
            if (row["total"] if row else 0) + credits > MAX_PURCHASE_CREDITS_PER_DAY:
                await send_alert(
                    self.env,
                    "Daily purchase cap reached",
                    COLOR_ERROR,
                    [("Player", await player_label(user_id)), ("Bought (24h)", f"{(row['total'] if row else 0):,}"), ("Attempted", f"+{credits:,}")],
                )
                raise HttpError(429, "daily purchase cap reached")

        return await self.apply_credit_change(
            require_string(body.get("txId"), "txId", TX_ID),
            user_id,
            credits,
            "purchase",
            f"product {product_id}",
            place_id(request),
            [],
            check_daily_cap,
        )

    async def handle_match_reward(self, request, user_id):
        body = await read_body(request)
        private = body.get("private") is True
        win = body.get("win") is True
        source = "match_private" if private else "match"
        rules = MATCH_RULES[source]
        map_name = require_string(body.get("map"), "map", MAP_NAME)
        tx_id = require_string(body.get("txId"), "txId", TX_ID)

        credits = body.get("credits")
        if not isinstance(credits, (int, float)) or isinstance(credits, bool) or credits != int(credits) or not (1 <= credits <= rules["max_reward"]):
            await send_alert(
                self.env,
                "Rejected match reward",
                COLOR_ERROR,
                [
                    ("Player", await player_label(user_id)),
                    ("Requested", str(credits)[:40]),
                    ("Max allowed", rules["max_reward"]),
                    ("Server", "private" if private else "public"),
                    ("Place", place_id(request) or "-"),
                ],
            )
            raise HttpError(400, "invalid credits")
        credits = int(credits)

        async def check_caps():
            now = now_ms()
            row = await self.first(
                """SELECT COALESCE(MAX(created_at), 0) AS last,
                          COALESCE(SUM(CASE WHEN created_at > ? THEN delta END), 0) AS hour,
                          COALESCE(SUM(delta), 0) AS day
                   FROM ledger WHERE user_id = ? AND source = ? AND created_at > ?""",
                now - HOUR_MS,
                user_id,
                source,
                now - DAY_MS,
            )
            row = row or {}
            if now - row.get("last", 0) < rules["cooldown_ms"]:
                raise HttpError(403, "match reward cooldown")
            if rules["hour_cap"] is not None and row.get("hour", 0) + credits > rules["hour_cap"]:
                raise HttpError(403, "hourly match reward cap reached")
            if rules["day_cap"] is not None and row.get("day", 0) + credits > rules["day_cap"]:
                raise HttpError(403, "daily match reward cap reached")

        return await self.apply_credit_change(
            tx_id,
            user_id,
            credits,
            source,
            f"{'win' if win else 'loss'} {map_name}",
            place_id(request),
            [],
            check_caps,
        )

    async def handle_crate_open(self, request, user_id):
        body = await read_body(request)
        cost = require_int(body.get("cost"), "cost", 1, MAX_CRATE_COST)
        refund = require_int(body.get("refund"), "refund", 0, cost)
        amount = require_int(body.get("amount"), "amount", 1, MAX_CRATE_AMOUNT)
        crate_id = require_string(body.get("crateId"), "crateId", CRATE_ID)

        raw_unlocks = body.get("unlocks")
        if not isinstance(raw_unlocks, list) or len(raw_unlocks) > MAX_UNLOCKS_PER_REQUEST:
            raise HttpError(400, "invalid unlocks")
        unlocks = list(dict.fromkeys(require_string(item, "unlock id", ITEM_ID) for item in raw_unlocks))

        return await self.apply_credit_change(
            require_string(body.get("txId"), "txId", TX_ID),
            user_id,
            refund - cost,
            "crate",
            f"{amount}x {crate_id}",
            place_id(request),
            unlocks,
        )

    async def game_route(self, request, parts):
        if not parts or parts[0] != "players":
            raise HttpError(404, "not found")
        user_id = parse_user_id(parts[1] if len(parts) > 1 else None)

        limit = py(await self.env.GAME_LIMITER.limit(js_obj({"key": f"user:{user_id}"})))
        if not limit["success"]:
            raise HttpError(429, "rate limited")

        if len(parts) == 2 and request.method == "GET":
            return json_response(200, await self.get_profile(user_id))
        if len(parts) == 3 and parts[2] == "purchase" and request.method == "POST":
            return await self.handle_purchase(request, user_id)
        if len(parts) == 3 and parts[2] == "crate-open" and request.method == "POST":
            return await self.handle_crate_open(request, user_id)
        if len(parts) == 3 and parts[2] == "match-reward" and request.method == "POST":
            return await self.handle_match_reward(request, user_id)
        if len(parts) == 3 and parts[2] == "rank":
            return await self.handle_rank(request, user_id)
        raise HttpError(404, "not found")

    async def handle_rank(self, request, user_id):
        if request.method == "GET":
            row = await self.first("SELECT rank FROM staff_ranks WHERE user_id = ?", user_id)
            return json_response(200, {"rank": row["rank"] if row else None})
        if request.method == "PUT":
            body = await read_body(request)
            rank = require_string(body.get("rank"), "rank", RANK_NAME)
            granted_by = require_int(body.get("by"), "by", 1, 10**16)
            row = await self.first(
                """INSERT INTO staff_ranks (user_id, rank, granted_by, updated_at) VALUES (?, ?, ?, ?)
                   ON CONFLICT(user_id) DO UPDATE SET rank = excluded.rank, granted_by = excluded.granted_by,
                   updated_at = excluded.updated_at WHERE staff_ranks.rank <> 'Player'
                   RETURNING rank""",
                user_id,
                rank,
                granted_by,
                now_ms(),
            )
            if row is None:
                raise HttpError(409, "rank is locked")
            return json_response(200, {"rank": rank})
        if request.method == "DELETE":
            rank = require_string((parse_qs(urlparse(request.url).query).get("rank") or [None])[0], "rank", RANK_NAME)
            row = await self.first("DELETE FROM staff_ranks WHERE user_id = ? AND rank = ? RETURNING user_id", user_id, rank)
            return json_response(200, {"cleared": row is not None})
        raise HttpError(405, "method not allowed")

    async def log_unlock_change(self, user_id, item_id, reason, kind):
        now = now_ms()
        if kind == "unlock":
            change = self.db.prepare("INSERT OR IGNORE INTO unlocks (user_id, item_id, created_at) VALUES (?, ?, ?)").bind(
                user_id, item_id, now
            )
        else:
            change = self.db.prepare("DELETE FROM unlocks WHERE user_id = ? AND item_id = ?").bind(user_id, item_id)

        ledger = self.db.prepare(
            """INSERT INTO ledger (tx_id, user_id, kind, source, delta, item_ids, detail, created_at)
               VALUES (?, ?, ?, 'admin', 0, ?, ?, ?)"""
        ).bind(f"admin:{uuid.uuid4()}", user_id, kind, json.dumps([item_id]), reason, now)

        await self.db.batch(to_js([change, ledger]))
        await send_alert(
            self.env,
            "Admin unlock added" if kind == "unlock" else "Admin unlock removed",
            COLOR_WARN,
            [("Player", await player_label(user_id)), ("Item", item_id), ("Reason", reason)],
        )

    async def admin_route(self, request, parts, query):
        if not parts or parts[0] != "players":
            raise HttpError(404, "not found")
        user_id = parse_user_id(parts[1] if len(parts) > 1 else None)

        if len(parts) == 2 and request.method == "GET":
            ledger = await self.all(
                "SELECT * FROM ledger WHERE user_id = ? ORDER BY created_at DESC LIMIT ?", user_id, LEDGER_PAGE_SIZE
            )
            profile = await self.get_profile(user_id)
            profile["ledger"] = ledger
            return json_response(200, profile)

        if len(parts) == 3 and parts[2] == "credits" and request.method == "POST":
            body = await read_body(request)
            delta = require_int(body.get("delta"), "delta", -MAX_ADMIN_DELTA, MAX_ADMIN_DELTA)
            if delta == 0:
                raise HttpError(400, "delta must not be 0")
            return await self.apply_credit_change(
                f"admin:{uuid.uuid4()}", user_id, delta, "admin", require_reason(body.get("reason")), "", []
            )

        if len(parts) == 3 and parts[2] == "unlocks" and request.method == "POST":
            body = await read_body(request)
            item_id = require_string(body.get("itemId"), "itemId", ITEM_ID)
            await self.log_unlock_change(user_id, item_id, require_reason(body.get("reason")), "unlock")
            return json_response(200, await self.get_profile(user_id))

        if len(parts) == 4 and parts[2] == "unlocks" and request.method == "DELETE":
            item_id = require_string(unquote(parts[3]), "itemId", ITEM_ID)
            reason = require_reason((query.get("reason") or [None])[0])
            await self.log_unlock_change(user_id, item_id, reason, "remove_unlock")
            return json_response(200, await self.get_profile(user_id))

        raise HttpError(404, "not found")

    async def route(self, request):
        url = urlparse(request.url)
        parts = [part for part in url.path.split("/") if part]
        token = bearer_token(request)

        if parts and parts[0] == "v1":
            if not key_matches(token, getattr(self.env, "GAME_API_KEY", None)):
                raise HttpError(401, "unauthorized")
            return await self.game_route(request, parts[1:])

        if parts and parts[0] == "admin":
            if not key_matches(token, getattr(self.env, "ADMIN_API_KEY", None)):
                raise HttpError(401, "unauthorized")
            limit = py(await self.env.ADMIN_LIMITER.limit(js_obj({"key": "admin"})))
            if not limit["success"]:
                raise HttpError(429, "rate limited")
            return await self.admin_route(request, parts[1:], parse_qs(url.query))

        raise HttpError(404, "not found")


async def check_status(env, cron):
    try:
        db = env.DB
        stats = py(
            await db.prepare(
                """SELECT
                     (SELECT COUNT(*) FROM players) AS players,
                     (SELECT COALESCE(SUM(credits), 0) FROM players) AS credits,
                     (SELECT COUNT(*) FROM ledger WHERE created_at > ?) AS changes"""
            )
            .bind(now_ms() - DAY_MS)
            .first()
        )
    except Exception as err:
        await send_alert(env, "Database error", COLOR_ERROR, [("Status", "DOWN"), ("Error", str(err)[:500])])
        return

    if cron == DAILY_STATUS_CRON:
        await send_alert(
            env,
            "Daily status",
            COLOR_OK,
            [
                ("Status", "ONLINE"),
                ("Players", f"{stats['players']:,}"),
                ("Credits held", f"{stats['credits']:,}"),
                ("Changes (24h)", f"{stats['changes']:,}"),
            ],
        )
        await send_daily_economy(env, db)


async def send_daily_economy(env, db):
    since = now_ms() - DAY_MS
    try:
        flow = py(
            await db.prepare(
                """SELECT
                     COALESCE(SUM(CASE WHEN source = 'purchase' THEN delta END), 0) AS bought,
                     COALESCE(SUM(CASE WHEN source IN ('match', 'match_private') THEN delta END), 0) AS earned,
                     COALESCE(-SUM(CASE WHEN source = 'crate' THEN delta END), 0) AS crate_spent,
                     COALESCE(SUM(CASE WHEN source = 'crate' THEN CAST(substr(detail, 1, instr(detail, 'x') - 1) AS INTEGER) END), 0) AS crates_opened,
                     COALESCE(SUM(CASE WHEN source = 'admin' AND kind = 'credits' THEN delta END), 0) AS admin,
                     COUNT(DISTINCT user_id) AS active,
                     (SELECT COUNT(*) FROM unlocks WHERE created_at > ?) AS unlocked
                   FROM ledger WHERE created_at > ?"""
            )
            .bind(since, since)
            .first()
        )
    except Exception as err:
        await send_alert(env, "Daily economy failed", COLOR_ERROR, [("Error", str(err)[:500])])
        return

    net = flow["bought"] + flow["earned"] - flow["crate_spent"] + flow["admin"]
    await send_alert(
        env,
        "Daily economy (24h)",
        COLOR_INFO,
        [
            ("Credits bought", f"{flow['bought']:,}"),
            ("Credits earned", f"{flow['earned']:,}"),
            ("Spent on crates", f"{flow['crate_spent']:,}"),
            ("Crates opened", f"{flow['crates_opened']:,}"),
            ("Items unlocked", f"{flow['unlocked']:,}"),
            ("Admin changes", f"{flow['admin']:+,}" if flow["admin"] else "0"),
            ("Net credits", f"{net:+,}" if net else "0"),
            ("Active players", f"{flow['active']:,}"),
        ],
    )


class Default(WorkerEntrypoint):
    async def scheduled(self, controller, env=None, ctx=None):
        await check_status(self.env, getattr(controller, "cron", ""))

    async def fetch(self, request):
        try:
            return await Api(self.env).route(request)
        except HttpError as err:
            return json_response(err.status, {"error": err.message})
        except Exception as err:
            print(f"unhandled error: {err}")
            global last_error_alert
            if time.time() - last_error_alert > ERROR_ALERT_COOLDOWN_S:
                last_error_alert = time.time()
                url = urlparse(request.url)
                await send_alert(
                    self.env,
                    "API error",
                    COLOR_ERROR,
                    [("Request", f"{request.method} {url.path}"[:200]), ("Error", str(err)[:500])],
                )
            return json_response(500, {"error": "internal error"})
