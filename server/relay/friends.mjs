// Friends: who's playing right now, and "Race me!" invites.
// Every player has a friend code (like K7QM2XPA). The game says hello every
// few seconds while it's running:
//   POST /friends/hello   {"id","name","friends":[ids]}  ->  {"online": {id: true|false}, "names": {id: name}, "invites": [...]}
//   POST /friends/invite  {"id","name","to","room"}      ->  {"ok": true}
// An invite is {"from", "name", "room"} (room = the 4-letter internet race code)
// and is handed over once, on the friend's next hello.
//
// The hub can be shut down and restarted by Cloudflare at any moment, so
// everything lives in its storage, not just in memory.

const ONLINE_FOR = 45 * 1000;     // ms since the last hello that still counts as "playing"
const SEEN_EVERY = 25 * 1000;     // write "I'm playing" at most this often (saves storage writes)
const INVITE_FOR = 3 * 60 * 1000; // invites expire after 3 minutes
const MAX_FRIENDS = 50;
const MAX_INVITES = 5;

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });

export const cleanId = (s) => (typeof s === "string" && /^[A-Z0-9]{6,10}$/.test(s) ? s : "");
export const cleanName = (s) => (typeof s === "string" ? s.replace(/[\u0000-\u001f]/g, "").trim().slice(0, 12) : "") || "A friend";
export const cleanRoom = (s) => (typeof s === "string" && /^[A-Z]{4,8}$/.test(s) ? s : "");

/** In-memory storage with the same get/put/delete calls as a Durable Object's (for tests). */
export class MemoryStorage {
  constructor() { this.m = new Map(); }
  async get(k) {
    if (Array.isArray(k)) {
      const out = new Map();
      for (const key of k) if (this.m.has(key)) out.set(key, this.m.get(key));
      return out;
    }
    return this.m.get(k);
  }
  async put(k, v) { this.m.set(k, v); }
  async delete(k) { return this.m.delete(k); }
}

/** The friends logic, kept apart from Cloudflare so it can be tested. */
export class Friends {
  constructor(storage) {
    this.storage = storage;
    this.lastWrite = new Map();   // id -> when we last saved their hello (only a cache)
  }

  async hello(body, now = Date.now()) {
    const id = cleanId(body?.id);
    if (!id) return { error: "Bad friend code." };
    const name = cleanName(body.name);
    const last = this.lastWrite.get(id);
    if (!last || now - last.at > SEEN_EVERY || last.name !== name) {
      await this.storage.put("seen:" + id, { name, at: now });
      this.lastWrite.set(id, { name, at: now });
    }
    const online = {};
    const names = {};
    const ids = (Array.isArray(body.friends) ? body.friends.slice(0, MAX_FRIENDS) : []).map(cleanId).filter(Boolean);
    const seen = ids.length ? await this.storage.get(ids.map((f) => "seen:" + f)) : new Map();
    for (const fid of ids) {
      const s = seen.get("seen:" + fid);
      online[fid] = !!s && now - s.at < ONLINE_FOR;
      if (s) names[fid] = s.name;
    }
    let invites = [];
    const box = await this.storage.get("inbox:" + id);
    if (box && box.length) {
      invites = box.filter((i) => now - i.at < INVITE_FOR).map(({ at, ...rest }) => rest);
      await this.storage.delete("inbox:" + id);
    }
    if (this.lastWrite.size > 5000) this.lastWrite.clear();
    return { online, names, invites };
  }

  async invite(body, now = Date.now()) {
    const id = cleanId(body?.id);
    const to = cleanId(body?.to);
    const room = cleanRoom(body?.room);
    if (!id || !to || !room) return { error: "That invite doesn't look right." };
    const old = (await this.storage.get("inbox:" + to)) || [];
    const box = old.filter((i) => i.from !== id && now - i.at < INVITE_FOR);
    box.push({ from: id, name: cleanName(body.name), room, at: now });
    await this.storage.put("inbox:" + to, box.slice(-MAX_INVITES));
    const s = await this.storage.get("seen:" + to);
    return { ok: true, online: !!s && now - s.at < ONLINE_FOR };
  }
}

/** One hub object for everyone (a Durable Object). */
export class FriendHub {
  constructor(state) {
    this.friends = new Friends(state.storage);
  }

  async fetch(request) {
    if (request.method !== "POST") return json({ error: "Not found" }, 404);
    const text = await request.text();
    if (text.length > 4000) return json({ error: "Too big." }, 413);
    let body;
    try { body = JSON.parse(text); } catch { body = null; }
    const path = new URL(request.url).pathname;
    const res = path.endsWith("/hello") ? await this.friends.hello(body)
      : path.endsWith("/invite") ? await this.friends.invite(body) : { error: "Not found" };
    return json(res, res.error ? 400 : 200);
  }
}
