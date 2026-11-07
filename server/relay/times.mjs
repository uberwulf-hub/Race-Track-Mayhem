// Online best times: a top-10 list for every track (and number of laps).
//   POST /times/<board>  {"name","time","car"}  -> {"rank": 3, "top": [...]}   (rank 0 = not in the top 10)
//   GET  /times/<board>                          -> {"top": [{"name","time","car","date"}, ...]}
// <board> is like "bedroom_speedway_3" (built-in track + laps) or "c1a2b3c4d5_3"
// (a Track Builder track, named after its pieces, so everyone with that track shares a list).

const TOP = 10;
const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });

export function boardName(s) {
  return String(s || "").toLowerCase().replace(/[^a-z0-9_]/g, "").slice(0, 60);
}

export class TimesBoard {
  constructor(state) {
    this.storage = state.storage;
  }

  async fetch(request) {
    let top = (await this.storage.get("top")) || [];
    if (request.method === "GET") return json({ top });
    if (request.method !== "POST") return json({ error: "Not found" }, 404);
    let body;
    try { body = JSON.parse(await request.text()); } catch { body = null; }
    const name = typeof body?.name === "string" ? body.name.replace(/[\u0000-\u001f]/g, "").trim().slice(0, 12) : "";
    const time = Number(body?.time);
    const car = typeof body?.car === "string" ? body.car.slice(0, 24) : "";
    // A toy-car race can't take less than 5 seconds or more than an hour.
    if (!name || !isFinite(time) || time < 5 || time > 3600) return json({ error: "That time doesn't look right." }, 400);
    const entry = { name, time: Math.round(time * 1000) / 1000, car, date: new Date().toISOString().slice(0, 10) };
    // One spot per racer name: keep their best.
    const mine = top.findIndex((e) => e.name.toLowerCase() === name.toLowerCase());
    if (mine >= 0 && top[mine].time <= entry.time) {
      return json({ rank: 0, best: top[mine].time, top });
    }
    if (mine >= 0) top.splice(mine, 1);
    top.push(entry);
    top.sort((a, b) => a.time - b.time);
    top = top.slice(0, TOP);
    await this.storage.put("top", top);
    const rank = top.indexOf(entry) + 1;
    return json({ rank, top });
  }
}
