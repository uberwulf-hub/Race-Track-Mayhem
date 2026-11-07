# Race relay server

Lets Race Track Mayhem players in different houses race each other over the
internet. Home routers block other houses from connecting in, so everyone
connects *out* to this relay, which passes the game's messages along inside a
"room". The host gets a 4-letter room code; the others type it to join.

- `relay-core.mjs` - the rules (rooms, codes, passing messages along).
- `worker.mjs` + `wrangler.toml` - the Cloudflare Workers version (free plan).
- `local.mjs` - the same relay for testing on one computer: `npm install && node local.mjs`.

**Live server:** `wss://race-track-mayhem-relay.andrewsaulls.workers.dev` (the game's `Net.DEFAULT_RELAY`).

## Putting it online (Cloudflare, free)

1. Make a free Cloudflare account.
2. `cd server/relay && npm install && npx wrangler login && npx wrangler deploy`
   (or let the "Relay server" GitHub workflow do it with a `CLOUDFLARE_API_TOKEN` secret).
3. It prints the address, like `https://race-track-mayhem-relay.<you>.workers.dev`.
   The game's `Net.RELAY_URL` is that address with `wss://`.

Message format (see `scripts/relay_peer.gd` in the game):
- JSON text: `welcome` (your id, the room code, who's already there), `join`, `leave`, `error`, and `kick` (host only).
- Binary: 4-byte little-endian peer id, 1 channel byte, then the game's packet.
  Sent with the id of who it's for (0 = everyone else); delivered with the id of who it's from.
