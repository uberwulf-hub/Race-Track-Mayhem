// A relay for testing on one computer (or running on your own server):
//   cd server/relay && npm install && node local.mjs   (listens on port 24690)
// Then point the game at ws://127.0.0.1:24690 (RACE_RELAY_URL environment variable).
import { WebSocketServer } from "ws";
import { Room, newCode, PROTOCOL } from "./relay-core.mjs";

const port = Number(process.env.PORT || 24690);
const rooms = new Map();
const wss = new WebSocketServer({ port });

const send = (ws, data) => { if (ws.readyState === 1) ws.send(data, { binary: typeof data !== "string" }); };
const close = (ws, code, reason) => ws.close(code, reason);

wss.on("connection", (ws, req) => {
  const url = new URL(req.url, "http://x");
  if (Number(url.searchParams.get("v")) !== PROTOCOL) {
    send(ws, JSON.stringify({ t: "error", msg: "This game is a different version than the race server. Update the game!" }));
    return close(ws, 4005, "Different version");
  }
  let room, id;
  const parts = url.pathname.split("/").filter(Boolean);
  if (parts[0] === "host") {
    let code;
    do { code = newCode(); } while (rooms.has(code));
    room = new Room(code, send, close);
    rooms.set(code, room);
    id = room.addHost(ws);
  } else if (parts[0] === "join" && parts[1]) {
    room = rooms.get(parts[1].toUpperCase());
    if (!room) {
      send(ws, JSON.stringify({ t: "error", msg: "No race with that code. Check the letters!" }));
      return close(ws, 4004, "No race with that code.");
    }
    id = room.addGuest(ws);
    if (!id) return;
  } else {
    return close(ws, 4000, "Bad request");
  }
  ws.on("message", (data, isBinary) => room.onMessage(id, isBinary ? data : data.toString()));
  ws.on("close", () => {
    room.onLeave(id);
    if (room.empty) rooms.delete(room.code);
  });
});
console.log(`Race Track Mayhem relay listening on ws://0.0.0.0:${port}`);
