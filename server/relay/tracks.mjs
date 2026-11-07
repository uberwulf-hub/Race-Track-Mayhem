// Track sharing: a track built in the Track Builder is saved under a short
// code (like KXQRM) that friends type in to get the same track.
//   POST /tracks        {"name","room","pieces":[...],"by"}  ->  {"code":"KXQRM"}
//   GET  /tracks/KXQRM                                        ->  the track
import { newCode } from "./relay-core.mjs";

export const PIECES = ["straight", "left", "right", "bend_left", "bend_right", "boost", "loop", "corkscrew",
  "jump", "big_jump", "hill", "bumps", "spiral", "wiggles"];
export const ROOMS = ["bedroom", "playroom", "kitchen", "bathroom", "living_room", "garden"];
const MAX_PIECES = 40;

/** Checks a track and keeps only what the game needs. Returns null if it isn't a real track. */
export function cleanTrack(t) {
  if (!t || typeof t !== "object" || !Array.isArray(t.pieces)) return null;
  const pieces = t.pieces.filter((p) => PIECES.includes(p)).slice(0, MAX_PIECES);
  if (pieces.length === 0 || pieces.length !== t.pieces.length) return null;
  const text = (s, n, d) => (typeof s === "string" ? s.replace(/[\u0000-\u001f]/g, "").trim().slice(0, n) : "") || d;
  return {
    name: text(t.name, 24, "Shared Track"),
    room: ROOMS.includes(t.room) ? t.room : "bedroom",
    pieces,
    by: text(t.by, 12, "a friend"),
  };
}

export function trackCode() {
  return newCode() + newCode().slice(0, 1); // 5 letters
}

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });

/** The shelf of shared tracks (a Durable Object with its own storage). */
export class TrackShelf {
  constructor(state) {
    this.storage = state.storage;
  }

  async fetch(request) {
    const url = new URL(request.url);
    const parts = url.pathname.split("/").filter(Boolean); // ["tracks", CODE?]
    if (request.method === "POST" && parts.length === 1) {
      const body = await request.text();
      if (body.length > 4000) return json({ error: "That track is too big." }, 413);
      let track;
      try { track = cleanTrack(JSON.parse(body)); } catch { track = null; }
      if (!track) return json({ error: "That doesn't look like a track." }, 400);
      for (let tries = 0; tries < 10; tries++) {
        const code = trackCode();
        if (!(await this.storage.get(code))) {
          await this.storage.put(code, { ...track, saved: Date.now() });
          return json({ code });
        }
      }
      return json({ error: "Couldn't make a code. Try again!" }, 503);
    }
    if (request.method === "GET" && parts.length === 2) {
      const code = parts[1].toUpperCase().replace(/[^A-Z]/g, "");
      const track = await this.storage.get(code);
      if (!track) return json({ error: "No track with that code. Check the letters!" }, 404);
      const { saved, ...rest } = track;
      return json(rest);
    }
    return json({ error: "Not found" }, 404);
  }
}
