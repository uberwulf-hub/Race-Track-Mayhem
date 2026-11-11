// Friend ghosts: everyone's best lap on each track, so friends can race it.
//   POST /ghosts                      {"id","name","car","track","lap","data"}  ->  {"ok": true, "best": lap}
//   GET  /ghosts/<track>?ids=A,B,C    ->  {"ghosts": {id: {"name","car","lap"}}}   (who has one)
//   GET  /ghosts/<track>/<id>         ->  {"name","car","lap","data"}              (the lap itself)
// "data" is the ghost's recorded lap (base64), kept as it is. Only a faster
// lap replaces the one already saved.
import { cleanId, cleanName } from "./friends.mjs";

const MAX_DATA = 160000;   // base64 characters (a lap of a minute or so)
const MAX_IDS = 50;
const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });

export const cleanTrack = (s) => (typeof s === "string" ? s.toLowerCase().replace(/[^a-z0-9_]/g, "").slice(0, 60) : "");

export class GhostShelf {
  constructor(state) {
    this.storage = state.storage;
  }

  async fetch(request) {
    const url = new URL(request.url);
    const parts = url.pathname.split("/").filter(Boolean); // ["ghosts", track?, id?]
    if (request.method === "POST" && parts.length === 1) {
      const text = await request.text();
      if (text.length > MAX_DATA + 2000) return json({ error: "That ghost is too big." }, 413);
      let b;
      try { b = JSON.parse(text); } catch { b = null; }
      const id = cleanId(b?.id);
      const track = cleanTrack(b?.track);
      const lap = Number(b?.lap);
      const data = typeof b?.data === "string" && /^[A-Za-z0-9+/=]+$/.test(b.data) ? b.data : "";
      if (!id || !track || !data || !isFinite(lap) || lap < 2 || lap > 600) return json({ error: "That ghost doesn't look right." }, 400);
      const key = `g:${track}:${id}`;
      const old = await this.storage.get(key);
      if (old && old.lap <= lap) return json({ ok: true, best: old.lap });
      await this.storage.put(key, { name: cleanName(b.name), car: typeof b.car === "string" ? b.car.slice(0, 24) : "", lap, data });
      return json({ ok: true, best: lap });
    }
    if (request.method === "GET" && parts.length === 2) {
      const track = cleanTrack(parts[1]);
      const ids = (url.searchParams.get("ids") || "").split(",").map(cleanId).filter(Boolean).slice(0, MAX_IDS);
      const got = ids.length ? await this.storage.get(ids.map((i) => `g:${track}:${i}`)) : new Map();
      const ghosts = {};
      for (const i of ids) {
        const g = got.get(`g:${track}:${i}`);
        if (g) ghosts[i] = { name: g.name, car: g.car, lap: g.lap };
      }
      return json({ ghosts });
    }
    if (request.method === "GET" && parts.length === 3) {
      const g = await this.storage.get(`g:${cleanTrack(parts[1])}:${cleanId(parts[2])}`);
      if (!g) return json({ error: "No ghost on this track yet." }, 404);
      return json(g);
    }
    return json({ error: "Not found" }, 404);
  }
}
