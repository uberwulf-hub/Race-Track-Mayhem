// Track sharing: a track built in the Track Builder is saved under a short
// code (like KXQRM) that friends type in to get the same track.
//   POST /tracks        {"name","room","pieces":[...],"by"}  ->  {"code":"KXQRM"}
//   GET  /tracks/KXQRM                                        ->  the track
//   POST /tracks/KXQRM/play                                   ->  counts one race on it
//   GET  /tracks                         ->  the Track Gallery: {"top": [...], "new": [...]}
import { newCode } from "./relay-core.mjs";

export const PIECES = ["straight", "left", "right", "bend_left", "bend_right", "boost", "loop", "corkscrew",
  "jump", "big_jump", "hill", "bumps", "spiral", "wiggles"];
export const ROOMS = ["bedroom", "playroom", "kitchen", "bathroom", "living_room", "garden", "garage", "attic", "snowyard", "spooky", "beach"];
const MAX_PIECES = 40;
const INDEX_KEY = "_index";   // codes are only letters, so this can't clash
const MAX_INDEX = 400;        // tracks remembered for the gallery
const GALLERY_SIZE = 15;

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

/** A gallery card for a track (no pieces, just what the list shows). */
function card(code, t, plays) {
  return { code, name: t.name, room: t.room, by: t.by, plays: plays | 0, length: t.pieces ? t.pieces.length : (t.length | 0), saved: Number(t.saved) || 0 };
}

/** The gallery lists from the index: most raced, and newest. */
export function galleryLists(index) {
  const all = Object.values(index);
  const top = all.filter((c) => c.plays > 0).sort((a, b) => b.plays - a.plays || b.saved - a.saved).slice(0, GALLERY_SIZE);
  const fresh = [...all].sort((a, b) => b.saved - a.saved).slice(0, GALLERY_SIZE);
  return { top, new: fresh };
}

/** Keeps the index to MAX_INDEX tracks, dropping the least raced (oldest first). */
export function trimIndex(index) {
  const codes = Object.keys(index);
  if (codes.length <= MAX_INDEX) return index;
  codes.sort((a, b) => index[a].plays - index[b].plays || index[a].saved - index[b].saved);
  for (const c of codes.slice(0, codes.length - MAX_INDEX)) delete index[c];
  return index;
}

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
          const saved = { ...track, saved: Date.now(), plays: 0 };
          await this.storage.put(code, saved);
          const index = (await this.storage.get(INDEX_KEY)) || {};
          index[code] = card(code, saved, 0);
          await this.storage.put(INDEX_KEY, trimIndex(index));
          return json({ code });
        }
      }
      return json({ error: "Couldn't make a code. Try again!" }, 503);
    }
    if (request.method === "GET" && parts.length === 1) {
      let index = await this.storage.get(INDEX_KEY);
      if (!index) {
        // First time: build the gallery from every track shared so far.
        index = {};
        const all = await this.storage.list({ limit: 2000 });
        for (const [code, t] of all) {
          if (/^[A-Z]+$/.test(code) && t && Array.isArray(t.pieces)) index[code] = card(code, t, t.plays | 0);
        }
        await this.storage.put(INDEX_KEY, trimIndex(index));
      }
      return json(galleryLists(index));
    }
    if (request.method === "GET" && parts.length === 2) {
      const code = parts[1].toUpperCase().replace(/[^A-Z]/g, "");
      const track = await this.storage.get(code);
      if (!track) return json({ error: "No track with that code. Check the letters!" }, 404);
      const { saved, plays, ...rest } = track;
      return json({ ...rest, code, plays: plays | 0 });
    }
    if (request.method === "POST" && parts.length === 3 && parts[2] === "play") {
      const code = parts[1].toUpperCase().replace(/[^A-Z]/g, "");
      const track = await this.storage.get(code);
      if (!track) return json({ error: "No track with that code." }, 404);
      track.plays = (track.plays | 0) + 1;
      await this.storage.put(code, track);
      const index = (await this.storage.get(INDEX_KEY)) || {};
      index[code] = card(code, track, track.plays);   // older tracks join the gallery too
      await this.storage.put(INDEX_KEY, trimIndex(index));
      return json({ plays: track.plays });
    }
    return json({ error: "Not found" }, 404);
  }
}
