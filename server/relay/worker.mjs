// Race Track Mayhem relay on Cloudflare Workers (free plan is plenty for a family).
// Each race room is a Durable Object named after its code, so everyone in a
// race ends up talking to the same little object.
//   wss://<your-worker>.workers.dev/host?v=1        open a new room (you're the host)
//   wss://<your-worker>.workers.dev/join/ZOOM?v=1   join room ZOOM
import { Room, newCode, PROTOCOL } from "./relay-core.mjs";
export { TrackShelf } from "./tracks.mjs";
export { TimesBoard } from "./times.mjs";
export { FriendHub } from "./friends.mjs";
export { GhostShelf } from "./ghosts.mjs";
import { boardName } from "./times.mjs";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    // Shared tracks live on one "shelf".
    if (url.pathname === "/tracks" || url.pathname.startsWith("/tracks/")) {
      const shelf = env.TRACKS.get(env.TRACKS.idFromName("shelf"));
      return shelf.fetch(request);
    }
    // Friends online and "Race me!" invites: one hub for everyone.
    if (url.pathname === "/friends/hello" || url.pathname === "/friends/invite") {
      return env.FRIENDS.get(env.FRIENDS.idFromName("hub")).fetch(request);
    }
    // Friend ghosts: everyone's best laps, on one shelf.
    if (url.pathname === "/ghosts" || url.pathname.startsWith("/ghosts/")) {
      return env.GHOSTS.get(env.GHOSTS.idFromName("ghosts")).fetch(request);
    }
    // Online best times: one little object per track board.
    if (url.pathname.startsWith("/times/")) {
      const board = boardName(url.pathname.slice(7));
      if (!board) return new Response("Not found", { status: 404 });
      return env.TIMES.get(env.TIMES.idFromName(board)).fetch(request);
    }
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Race Track Mayhem race server is running.", { status: 200 });
    }
    if (Number(url.searchParams.get("v")) !== PROTOCOL) {
      return refuse("This game is a different version than the race server. Update the game!");
    }
    const parts = url.pathname.split("/").filter(Boolean);
    if (parts[0] === "host") {
      // Find a free code (a room that already has a host says no).
      for (let tries = 0; tries < 8; tries++) {
        const code = newCode();
        const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
        const res = await stub.fetch(`https://room/${code}/host`, request);
        if (res.status !== 409) return res;
      }
      return refuse("The race server is busy. Try again!");
    }
    if (parts[0] === "join" && parts[1]) {
      const code = parts[1].toUpperCase().replace(/[^A-Z]/g, "").slice(0, 8);
      const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
      return stub.fetch(`https://room/${code}/join`, request);
    }
    return new Response("Not found", { status: 404 });
  },
};

// Sends one error message and closes, so the game can show what went wrong.
function refuse(msg) {
  const [client, server] = Object.values(new WebSocketPair());
  server.accept();
  server.send(JSON.stringify({ t: "error", msg }));
  server.close(4000, msg.slice(0, 100));
  return new Response(null, { status: 101, webSocket: client });
}

export class RaceRoom {
  constructor(state) {
    this.state = state;
    this.room = null;
  }

  async fetch(request) {
    const [, code, action] = new URL(request.url).pathname.split("/");
    if (action === "host" && this.room && !this.room.empty) {
      return new Response("taken", { status: 409 });
    }
    if (action === "join" && (!this.room || this.room.empty)) {
      return refuse("No race with that code. Check the letters!");
    }
    if (!this.room || this.room.empty) {
      this.room = new Room(code,
        (ws, data) => { try { ws.send(data); } catch (e) { console.log("send failed", String(e)); } },
        (ws, c, reason) => { try { ws.close(c, reason); } catch {} });
    }
    const [client, server] = Object.values(new WebSocketPair());
    server.accept();
    // Newer Workers hand binary messages over as Blobs; the relay needs the raw bytes.
    try { server.binaryType = "arraybuffer"; } catch {}
    const id = action === "host" ? this.room.addHost(server) : this.room.addGuest(server);
    if (id) {
      // Messages are handled one at a time, in order (a Blob needs a moment to read).
      let queue = Promise.resolve();
      server.addEventListener("message", (e) => {
        queue = queue.then(async () => {
          let data = e.data;
          if (typeof data !== "string" && typeof data.arrayBuffer === "function") data = await data.arrayBuffer();
          this.room.onMessage(id, data);
        }).catch((err) => console.log("message failed", String(err)));
      });
      const gone = () => this.room && this.room.onLeave(id);
      server.addEventListener("close", gone);
      server.addEventListener("error", gone);
    }
    return new Response(null, { status: 101, webSocket: client });
  }
}
