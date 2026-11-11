// Races "at home": a race hosted on one computer shows up on every other
// computer on the same home internet connection, without any firewall
// fiddling. Computers in one house reach the internet from the same address
// (or, with IPv6, the same /64 network), so that's what groups them.
//   POST /home   {"room","name","players","open","v"}   ->  {"ok": true}   (repeat every few seconds)
//   GET  /home                                         ->  {"races": [{"room","name","players","open","v"}]}
// Entries vanish 30 seconds after the host stops saying it's still there.
import { cleanName, cleanRoom } from "./friends.mjs";

const KEEP = 30 * 1000;
const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });

/** Which "house" an address belongs to: the IPv4 address, or an IPv6 /64. */
export function houseOf(ip) {
  if (typeof ip !== "string" || !ip) return "";
  if (ip.includes(":")) {
    const parts = ip.split(":");
    // Expand "::" so we can take the first four groups.
    const gap = parts.indexOf("");
    let full = parts;
    if (gap >= 0) {
      const head = parts.slice(0, gap).filter(Boolean);
      const tail = parts.slice(gap + 1).filter(Boolean);
      full = [...head, ...Array(8 - head.length - tail.length).fill("0"), ...tail];
    }
    return "v6:" + full.slice(0, 4).map((g) => g.toLowerCase()).join(":");
  }
  return "v4:" + ip;
}

export class HomeBoard {
  constructor(state) {
    this.storage = state.storage;
  }

  async fetch(request) {
    const house = houseOf(request.headers.get("x-house-ip") || "");
    if (!house) return json({ races: [] });
    const key = "home:" + house;
    const now = Date.now();
    let races = ((await this.storage.get(key)) || []).filter((r) => now - r.at < KEEP);
    if (request.method === "POST") {
      let b;
      try { b = JSON.parse(await request.text()); } catch { b = null; }
      const room = cleanRoom(b?.room);
      if (!room) return json({ error: "Bad race code." }, 400);
      races = races.filter((r) => r.room !== room);
      if (b?.closed !== true) {
        races.push({ room, name: cleanName(b.name), players: Math.max(1, Math.min(8, Number(b.players) | 0)), open: b.open !== false, v: Number(b.v) | 0, at: now });
      }
      await this.storage.put(key, races.slice(-10));
      return json({ ok: true });
    }
    return json({ races: races.map(({ at, ...r }) => r) });
  }
}
