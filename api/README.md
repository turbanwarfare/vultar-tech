# API

Cloudflare Worker written in Python, with a D1 database. It keeps track of credits and crate unlocks.

## Setup

Log in and create the database:

```bash
npx wrangler login
npx wrangler d1 create game-db
```

Put the `database_id` from the output into `wrangler.toml`. Then apply the migrations, add the two keys and deploy:

```bash
npx wrangler d1 migrations apply game-db --remote
npx wrangler secret put GAME_API_KEY
npx wrangler secret put ADMIN_API_KEY
npx wrangler deploy
```

Wrangler asks for each key when you run `secret put`. Keys shouldn't be put in any file or committed.

For Discord alerts, also add a webhook:

```bash
npx wrangler secret put ALERT_WEBHOOK_URL
```

## Endpoints

Game servers send `Authorization: Bearer <GAME_API_KEY>`:

- `GET /v1/players/{userId}` returns credits and unlocks
- `POST /v1/players/{userId}/purchase` with `{ txId, credits, productId }`
- `POST /v1/players/{userId}/crate-open` with `{ txId, crateId, amount, cost, refund, unlocks }`
- `POST /v1/players/{userId}/match-reward` with `{ txId, credits, map, win, private }`

Admin requests send `Authorization: Bearer <ADMIN_API_KEY>`:

- `GET /admin/players/{userId}` returns credits, unlocks and the last 100 ledger rows
- `POST /admin/players/{userId}/credits` with `{ delta, reason }`
- `POST /admin/players/{userId}/unlocks` with `{ itemId, reason }`
- `DELETE /admin/players/{userId}/unlocks/{itemId}?reason=...`

The API caps match rewards no matter what the game sends. Public matches can give up to 300 credits, with a 5 minute cooldown and a limit of 5,000 a day. Private matches can give up to 15. A reward over the cap is rejected and reported to Discord.

Every change goes into the `ledger` table, which doesn't allow UPDATE or DELETE.

## Alerts

If `ALERT_WEBHOOK_URL` is set, the Worker posts to Discord when:

- one credit change is 10,000 or more
- an admin changes credits or unlocks
- a player reaches the 100,000 a day purchase cap
- the API hits an unexpected error (at most once a minute)
- the database check, which runs every 15 minutes, fails

It also posts a daily summary at 12:00 UTC with the number of players, total credits held and changes in the last 24 hours. If the summary stops showing up, the Worker is down.

Data can be viewed in the D1 console in the Cloudflare dashboard. Changes should go through the admin endpoints.

## Local testing

Put fake keys in `.dev.vars`, which is gitignored, then run:

```bash
npx wrangler d1 migrations apply game-db --local
npx wrangler dev
```

## Restoring

To roll the database back to an earlier point:

```bash
npx wrangler d1 time-travel restore game-db --timestamp=<unix-seconds>
```
