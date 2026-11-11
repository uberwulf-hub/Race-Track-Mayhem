extends Node
## Online races (autoloaded as `Net`).
##
## One computer HOSTS a race and the others JOIN it. Games on the same home
## network find each other automatically (the host shouts "I'm here!" on the
## network every second); you can also join by typing the host's address.
##
## How a race stays in sync:
## - Every computer drives its own car and sends where it is about 20 times a
##   second. The host also drives the computer cars and sends theirs.
## - The other cars you see are "remote" cars that glide to where they were
##   last seen.
## - Power-ups: using one is sent to everyone, so the shot appears on every
##   screen; a hit only counts on the computer that owns the car that was hit.
##
## The messages go through Godot's ENet networking. Internet play can reuse all
## of this later; it only needs a different way to find and reach the host.

const PORT := 24680
const DISCOVERY_PORT := 24681
const MAX_CLIENTS := 5          # plus the host = 6 racers
const MAX_RACERS := 6
const PROTOCOL := 5             # the game's version for racing together: bump when tracks,
                                # cars or messages change, so mismatched copies can't join
const RELAY_PROTOCOL := 1       # the race server's message format (server/relay)
const SEND_RATE := 1.0 / 20.0
const GAME_TAG := "RaceTrackMayhem"
## The internet race server (see server/relay). Set RACE_RELAY_URL to use another one.
const DEFAULT_RELAY := "wss://race-track-mayhem-relay.andrewsaulls.workers.dev"

signal lobby_changed                       # players or settings changed
signal games_found_changed                 # LAN games list changed
signal join_failed(reason: String)
signal session_ended(reason: String)       # we left or lost the host
signal states_received(states: Array)      # car positions from other computers
signal item_used(key: String, kind: String, side: float)
signal item_hit(victim_key: String, kind: String, by_key: String)
signal go_received                         # host says: start the countdown!
signal player_left(peer_id: int)
signal emote_received(peer_id: int, text: String)
signal rematch_voted(peer_id: int)
signal friends_changed                     # who's online changed (or their names)
signal invite_received(from_name: String, room: String)   # a friend said "Race me!"

## Quick messages players can send (no typing, so they're kid-safe).
const EMOTES := ["Nice!", "Wow!", "Haha!", "GG!", "Go go go!", "Oops!"]
const EMOTE_COLORS := [Color(0.5, 1.0, 0.6), Color(1.0, 0.85, 0.3), Color(1.0, 0.6, 0.85), Color(0.6, 0.85, 1.0), Color(1.0, 0.55, 0.3), Color(0.8, 0.7, 1.0)]

var active := false        # in an online lobby or race
var is_host := false
var in_race := false
var players := {}          # peer id -> {"name", "car", "look"}
var settings := {"track": 0, "laps": 3, "difficulty": 0, "powerups": true, "ai": true}
var custom_track := {}     # the host's own track, when that's the one picked
var race_config := {}      # {"roster": [...], "track", "custom", "laps", "difficulty", "powerups"}
var found := {}            # ip -> {"name", "players", "open", "seen"}
var end_reason := ""       # shown on the menu after a session ends

var _peer: MultiplayerPeer
var internet := false      # this session goes through the internet relay
var room_code := ""        # internet races: the code others type to join
var _shout: PacketPeerUDP
var _listen: PacketPeerUDP
var _shout_timer := 0.0
var _loaded := {}          # peer id -> true once their race scene is ready

# Friends
const FRIEND_POLL := 10.0  # seconds between check-ins with the friends hub
var friends_online := {}   # friend code -> true while they're playing
var _friend_timer := 2.0
var _friend_busy := false
var _invite_to := ""       # friend to invite once our internet race has its code


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("Couldn't reach that race."))
	multiplayer.server_disconnected.connect(func(): leave("The host left the race."))


func _process(delta: float) -> void:
	_friend_timer -= delta
	if _friend_timer <= 0.0:
		_friend_timer = FRIEND_POLL
		_friend_hello()
	if is_host and active:
		_shout_timer -= delta
		if _shout_timer <= 0.0:
			_shout_timer = 1.0
			_send_shout()
	_poll_listen()


func my_id() -> int:
	return multiplayer.get_unique_id() if active else 1


func my_info() -> Dictionary:
	var car: int = Game.selected_car
	if not CarData.is_available(car):
		car = 0
	return {"name": Game.player_name if Game.player_name != "" else "Racer",
		"car": car, "look": Game.custom_for(CarData.get_car(car)["id"]), "fid": Game.my_friend_code()}


# ---------------------------------------------------------------------------
# Hosting and joining
# ---------------------------------------------------------------------------

func host() -> String:
	leave("", false)
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(PORT, MAX_CLIENTS)
	_peer = enet
	if err != OK:
		_peer = null
		return "Couldn't start a race here (is another one already running on this computer?)."
	multiplayer.multiplayer_peer = _peer
	active = true
	is_host = true
	in_race = false
	players = {1: my_info()}
	_shout = PacketPeerUDP.new()
	_shout.set_broadcast_enabled(true)
	_shout.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_shout_timer = 0.0
	lobby_changed.emit()
	return ""


static func relay_url() -> String:
	var custom := OS.get_environment("RACE_RELAY_URL")
	return custom if custom != "" else DEFAULT_RELAY


# ---------------------------------------------------------------------------
# Sharing tracks (saved on the same server under a short code)
# ---------------------------------------------------------------------------

static func web_url() -> String:
	return relay_url().replace("wss://", "https://").replace("ws://", "http://")


## Saves a Track Builder track on the server. Returns {"code": "KXQRM"} or {"error": "..."}.
func share_track(track: Dictionary) -> Dictionary:
	var body := JSON.stringify({"name": track.get("name", "My Track"), "room": track.get("room", "bedroom"),
		"pieces": track.get("pieces", []), "by": track.get("by", Game.player_name)})
	return await _web("POST", "/tracks", body)


## Gets a shared track by its code. Returns the track or {"error": "..."}.
func fetch_track(code: String) -> Dictionary:
	code = code.strip_edges().to_upper()
	if code.length() < 5:
		return {"error": "Track codes have 5 letters."}
	return await _web("GET", "/tracks/" + code.uri_encode(), "")


## The Track Gallery: {"top": [cards], "new": [cards]} or {"error": "..."}.
## A card is {"code", "name", "room", "by", "plays", "length"}.
func gallery() -> Dictionary:
	return await _web("GET", "/tracks", "")


## Counts one race on a shared track (for the gallery's "most raced" list).
func count_play(code: String) -> void:
	code = code.strip_edges().to_upper()
	if code.length() >= 5 and code.is_valid_identifier():
		_web("POST", "/tracks/%s/play" % code, "{}")


func _web(method: String, path: String, body: String) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 12.0
	add_child(req)
	var m := HTTPClient.METHOD_POST if method == "POST" else HTTPClient.METHOD_GET
	var err := req.request(web_url() + path, ["Content-Type: application/json"], m, body)
	if err != OK:
		req.queue_free()
		return {"error": "Couldn't reach the track server."}
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"error": "Couldn't reach the track server. Are you on the internet?"}
	var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not (data is Dictionary):
		return {"error": "The track server sent something odd. Try again!"}
	return data


# ---------------------------------------------------------------------------
# Friends: who's playing, and "Race me!" invites (through the race server)
# ---------------------------------------------------------------------------

## Checks in with the friends hub: says we're playing, learns which friends
## are, and picks up any invites. Not during a race (invites wait till after).
func _friend_hello() -> void:
	if _friend_busy or Game.player_slot < 0 or in_race or OS.get_environment("RACE_NO_FRIENDS") != "":
		return
	var tree := get_tree()
	if tree.current_scene and tree.current_scene.has_method("_on_net_states"):
		return   # racing on your own: don't interrupt
	_friend_busy = true
	var ids: Array = Game.friends.map(func(f: Dictionary) -> String: return f["id"])
	var res: Dictionary = await _web("POST", "/friends/hello", JSON.stringify({"id": Game.my_friend_code(),
		"name": Game.player_name, "friends": ids}))
	_friend_busy = false
	if res.has("error"):
		return
	var changed := false
	var online: Dictionary = res.get("online", {}) if res.get("online") is Dictionary else {}
	for id in online:
		if bool(friends_online.get(id, false)) != bool(online[id]):
			changed = true
		friends_online[id] = bool(online[id])
	# Friends added by code learn their real names.
	var names: Dictionary = res.get("names", {}) if res.get("names") is Dictionary else {}
	for f: Dictionary in Game.friends:
		var n := String(names.get(f["id"], "")).substr(0, Game.NAME_LENGTH)
		if n != "" and n != f["name"]:
			f["name"] = n
			changed = true
	if changed:
		Game.save_settings()
		friends_changed.emit()
	var invites: Array = res.get("invites", []) if res.get("invites") is Array else []
	for inv in invites:
		if inv is Dictionary and Game.is_friend(String(inv.get("from", ""))):
			invite_received.emit(String(inv.get("name", "A friend")).substr(0, Game.NAME_LENGTH), String(inv.get("room", "")))


## Asks the friends hub again soon (after adding a friend, say).
func check_friends_soon() -> void:
	_friend_timer = minf(_friend_timer, 0.5)


func is_online(friend_code: String) -> bool:
	return bool(friends_online.get(friend_code, false))


## "Race me!": opens an internet race and invites the friend to it (as soon
## as the race code arrives from the server).
func race_friend(friend_code: String) -> void:
	host_internet()
	_invite_to = friend_code
	if room_code != "":
		_send_invite()


func _send_invite() -> void:
	if _invite_to == "" or room_code == "":
		return
	var to := _invite_to
	_invite_to = ""
	await _web("POST", "/friends/invite", JSON.stringify({"id": Game.my_friend_code(), "name": Game.player_name,
		"to": to, "room": room_code}))


# ---------------------------------------------------------------------------
# Friend ghosts: best laps saved on the race server
# ---------------------------------------------------------------------------

## Sends your best lap on a track (so friends can race your ghost).
func upload_ghost(track_key: String, lap: float, data: PackedFloat32Array, car_id: String) -> void:
	if Game.player_slot < 0 or not Game.online_times or data.is_empty():
		return
	var packed := Marshalls.raw_to_base64(data.to_byte_array().compress(FileAccess.COMPRESSION_GZIP))
	if packed.length() > 150000:
		return   # an extra long lap: too big to share
	_web("POST", "/ghosts", JSON.stringify({"id": Game.my_friend_code(), "name": Game.player_name,
		"car": car_id, "track": track_key, "lap": lap, "data": packed}))


## Which friends have a ghost on a track: {friend code: {"name", "car", "lap"}}.
func list_ghosts(track_key: String) -> Dictionary:
	var ids: Array = Game.friends.map(func(f: Dictionary) -> String: return f["id"])
	if ids.is_empty():
		return {}
	var res: Dictionary = await _web("GET", "/ghosts/%s?ids=%s" % [track_key.uri_encode(), ",".join(ids)], "")
	return res.get("ghosts", {}) if res.get("ghosts") is Dictionary else {}


## A friend's ghost lap: {"name", "car", "lap", "data": PackedFloat32Array} or {"error"}.
func fetch_ghost(track_key: String, friend_code: String) -> Dictionary:
	var res: Dictionary = await _web("GET", "/ghosts/%s/%s" % [track_key.uri_encode(), friend_code.uri_encode()], "")
	if not res.has("data"):
		return {"error": String(res.get("error", "Couldn't get that ghost."))}
	var raw := Marshalls.base64_to_raw(String(res["data"]))
	var bytes := raw.decompress_dynamic(4 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	var data := bytes.to_float32_array()
	if data.size() < 16 or data.size() % 8 != 0:
		return {"error": "That ghost got muddled on the way. Try again!"}
	return {"name": String(res.get("name", "A friend")).substr(0, Game.NAME_LENGTH), "car": String(res.get("car", "")),
		"lap": float(res.get("lap", 0.0)), "data": data}


## Sends a finished race time to a track's online top 10.
## Returns {"rank": N (0 = not in the top 10), "top": [...]} or {"error": "..."}.
func submit_time(board: String, racer: String, time: float, car: String) -> Dictionary:
	return await _web("POST", "/times/" + board, JSON.stringify({"name": racer, "time": time, "car": car}))


## A track's online top 10: {"top": [{"name", "time", "car", "date"}, ...]} or {"error": "..."}.
func get_times(board: String) -> Dictionary:
	return await _web("GET", "/times/" + board, "")


## Opens an internet race. The room code arrives a moment later (lobby_changed).
func host_internet() -> void:
	leave("", false)
	var relay := RelayPeer.new()
	relay.room_ready.connect(func(c: String):
		room_code = c
		lobby_changed.emit()
		_send_invite())
	relay.relay_error.connect(func(m: String): _fail(m))
	var err := relay.create_room(relay_url(), RELAY_PROTOCOL)
	if err != OK:
		_fail("Couldn't reach the internet race server.")
		return
	_peer = relay
	multiplayer.multiplayer_peer = relay
	active = true
	is_host = true
	internet = true
	in_race = false
	room_code = ""
	players = {1: my_info()}
	lobby_changed.emit()


## Joins an internet race by its room code.
func join_internet(code: String) -> void:
	leave("", false)
	code = code.strip_edges().to_upper()
	if code.length() < 4:
		_fail("Type the 4-letter race code first.")
		return
	var relay := RelayPeer.new()
	relay.relay_error.connect(func(m: String): _fail(m))
	var err := relay.join_room(relay_url(), code, RELAY_PROTOCOL)
	if err != OK:
		_fail("Couldn't reach the internet race server.")
		return
	_peer = relay
	multiplayer.multiplayer_peer = relay
	active = true
	is_host = false
	internet = true
	in_race = false
	room_code = code
	players = {}
	_watch_join(15.0)


func join(address: String) -> void:
	leave("", false)
	address = address.strip_edges()
	if address == "":
		_fail("Type the host's address first.")
		return
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(address, PORT)
	_peer = enet
	if err != OK:
		_peer = null
		_fail("That address doesn't look right.")
		return
	multiplayer.multiplayer_peer = _peer
	active = true
	is_host = false
	in_race = false
	players = {}
	_watch_join(10.0)


## Leaves the lobby or race. `reason` is shown on the menu afterwards.
func leave(reason: String = "", announce: bool = true) -> void:
	var was_active := active
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	is_host = false
	in_race = false
	internet = false
	room_code = ""
	players = {}
	race_config = {}
	_loaded = {}
	_shout = null
	Game.end_online_override()
	if was_active and announce:
		end_reason = reason
		session_ended.emit(reason)
		if reason != "":
			Game.goto_menu.call_deferred()


## Gives up on joining if the host hasn't answered within a few seconds,
## and says what usually fixes it (instead of "Joining..." forever).
func _watch_join(seconds: float) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(seconds * 1000.0):
		await get_tree().create_timer(0.5).timeout
		if not active or is_host or not players.is_empty():
			return
	if internet:
		_fail("Couldn't join that race. Check the code, and that the host is still in the lobby.")
	else:
		_fail("Couldn't connect to that race. On the HOST computer, tap Fix Firewall and choose Yes. "
			+ "Both devices must be on the same Wi-Fi. (Or use Host on the Internet: it needs no firewall changes.)")


func _fail(reason: String) -> void:
	leave("", false)
	join_failed.emit(reason)


func _on_connected() -> void:
	_hello.rpc_id(1, PROTOCOL, my_info())


func _on_peer_connected(_id: int) -> void:
	pass   # the new player says hello first


func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players.erase(id)
		player_left.emit(id)
		if is_host:
			_sync_lobby()


# --- messages to the host ---

@rpc("any_peer", "reliable")
func _hello(protocol: int, info: Dictionary) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_rejected.rpc_id(id, "That race is on a different version of the game. Update both computers!")
		_kick_later(id)
		return
	if in_race:
		_rejected.rpc_id(id, "That race has already started. Try again when it's over!")
		_kick_later(id)
		return
	if players.size() >= MAX_RACERS:
		_rejected.rpc_id(id, "That race is full!")
		_kick_later(id)
		return
	players[id] = _clean_info(info)
	_sync_lobby()


@rpc("any_peer", "reliable")
func _set_info(info: Dictionary) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id] = _clean_info(info)
		_sync_lobby()


@rpc("any_peer", "reliable")
func _scene_loaded() -> void:
	if is_host:
		_loaded[multiplayer.get_remote_sender_id()] = true


func _clean_info(info: Dictionary) -> Dictionary:
	var car := clampi(int(info.get("car", 0)), 0, CarData.count() - 1)
	return {"name": Game.clean_name(String(info.get("name", "Racer"))), "car": car,
		"look": info.get("look", {}) if info.get("look", {}) is Dictionary else {},
		"fid": String(info.get("fid", "")).substr(0, 10)}


func _kick_later(id: int) -> void:
	get_tree().create_timer(0.5).timeout.connect(func():
		if _peer and is_host:
			_peer.disconnect_peer(id))


# --- messages from the host ---

@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	_fail(reason)


@rpc("authority", "reliable", "call_local")
func _lobby(p: Dictionary, s: Dictionary, custom: Dictionary) -> void:
	players = p
	settings = s
	custom_track = custom
	lobby_changed.emit()


func _sync_lobby() -> void:
	if is_host:
		_lobby.rpc(players, settings, custom_track)


# ---------------------------------------------------------------------------
# Lobby actions
# ---------------------------------------------------------------------------

## Changes my car (any player).
func set_my_car(car: int) -> void:
	Game.selected_car = car
	Game.save_settings()
	if is_host:
		players[1] = my_info()
		_sync_lobby()
	else:
		_set_info.rpc_id(1, my_info())


## The host changes the race settings.
func set_setting(key: String, value: Variant) -> void:
	if not is_host:
		return
	settings[key] = value
	if key == "track":
		var i := int(value)
		custom_track = Game.custom_tracks[i - Track.TRACKS.size()] if Game.is_custom_track(i) else {}
	_sync_lobby()


## Host only: builds the line-up and tells everyone to load the race.
func start_race() -> void:
	if not is_host:
		return
	var roster: Array = []
	var ids := players.keys()
	ids.sort()
	var used_cars: Array = []
	for id in ids:
		var p: Dictionary = players[id]
		roster.append({"key": "p%d" % id, "peer": id, "name": p["name"], "car": p["car"], "look": p["look"]})
		used_cars.append(int(p["car"]))
	if settings["ai"]:
		var names := ["Zoomy", "Vroomer", "Speedy", "Turbo Tom", "Rally Rae"]
		names.shuffle()
		var pool: Array = []
		for i in CarData.count():
			if not CarData.get_car(i).get("secret", false) and not used_cars.has(i):
				pool.append(i)
		if pool.is_empty():
			pool = [0, 1, 2, 3]
		pool.shuffle()
		var k := 0
		while roster.size() < 5:
			roster.append({"key": "ai%d" % k, "peer": 1, "name": names[k % names.size()], "car": pool[k % pool.size()], "look": {}, "ai": true})
			k += 1
	# Mix up the grid, people in the middle so it's fair.
	var ai: Array = roster.filter(func(e): return e.get("ai", false))
	var people: Array = roster.filter(func(e): return not e.get("ai", false))
	people.shuffle()
	var order: Array = ai.duplicate()
	for i in people.size():
		order.insert(mini(1 + i * 2, order.size()), people[i])
	var track_index := int(settings["track"])
	var config := {
		"roster": order,
		"track": track_index if not Game.is_custom_track(track_index) else Game.ONLINE_TRACK,
		"custom": custom_track,
		"laps": int(settings["laps"]),
		"difficulty": int(settings["difficulty"]),
		"powerups": bool(settings["powerups"]),
	}
	_loaded = {}
	_begin_race.rpc(config)


@rpc("authority", "reliable", "call_local")
func _begin_race(config: Dictionary) -> void:
	race_config = config
	in_race = true
	Game.begin_online_override(int(config["laps"]), int(config["difficulty"]), bool(config["powerups"]))
	Game.selected_track = int(config["track"])
	Game.goto_race()


## The race scene calls this when it's built. The host waits for everyone
## (or a few seconds), then starts the countdown on every computer.
func race_scene_ready() -> void:
	if is_host:
		_loaded[1] = true
		_wait_for_everyone()
	else:
		_scene_loaded.rpc_id(1)


func _wait_for_everyone() -> void:
	var waited := 0.0
	while waited < 12.0:
		if not is_host or not in_race:
			return
		var all := true
		for id in players:
			if not _loaded.has(id):
				all = false
		if all:
			break
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	if is_host and in_race:
		_go.rpc()


@rpc("authority", "reliable", "call_local")
func _go() -> void:
	go_received.emit()


## Host only: everyone goes back to the lobby.
func back_to_lobby() -> void:
	if is_host:
		_to_lobby.rpc()


@rpc("authority", "reliable", "call_local")
func _to_lobby() -> void:
	in_race = false
	race_config = {}
	Game.end_online_override()
	Game.goto("res://scenes/online.tscn")


# ---------------------------------------------------------------------------
# During the race
# ---------------------------------------------------------------------------

func send_states(states: Array) -> void:
	if active and in_race and not states.is_empty():
		_states.rpc(states)


@rpc("any_peer", "unreliable_ordered")
func _states(states: Array) -> void:
	states_received.emit(states)


func send_item(key: String, kind: String, side: float) -> void:
	if active and in_race:
		_item.rpc(key, kind, side)


@rpc("any_peer", "reliable")
func _item(key: String, kind: String, side: float) -> void:
	item_used.emit(key, kind, side)


func send_hit(victim_key: String, kind: String, by_key: String) -> void:
	if active and in_race:
		_hit.rpc(victim_key, kind, by_key)


@rpc("any_peer", "reliable")
func _hit(victim_key: String, kind: String, by_key: String) -> void:
	item_hit.emit(victim_key, kind, by_key)


# ---------------------------------------------------------------------------
# Emotes and rematch votes
# ---------------------------------------------------------------------------

var _last_emote := 0


func send_emote(index: int) -> void:
	if not active or index < 0 or index >= EMOTES.size():
		return
	if Time.get_ticks_msec() - _last_emote < 700:
		return   # no spamming
	_last_emote = Time.get_ticks_msec()
	_emote.rpc(index)
	emote_received.emit(my_id(), EMOTES[index])


@rpc("any_peer", "reliable")
func _emote(index: int) -> void:
	if index >= 0 and index < EMOTES.size():
		emote_received.emit(multiplayer.get_remote_sender_id(), EMOTES[index])


func vote_rematch() -> void:
	if active and not is_host:
		_rematch.rpc_id(1)


@rpc("any_peer", "reliable")
func _rematch() -> void:
	if is_host:
		rematch_voted.emit(multiplayer.get_remote_sender_id())


func player_name_of(peer_id: int) -> String:
	return String(players.get(peer_id, {}).get("name", "Someone"))


# ---------------------------------------------------------------------------
# Finding games on the home network
# ---------------------------------------------------------------------------

func start_looking() -> void:
	stop_looking()
	_listen = PacketPeerUDP.new()
	if _listen.bind(DISCOVERY_PORT) != OK:
		_listen = null   # another copy of the game on this computer is already listening
	found.clear()
	games_found_changed.emit()


func stop_looking() -> void:
	if _listen:
		_listen.close()
	_listen = null


func _send_shout() -> void:
	if _shout == null:
		return
	var host_name := String(players.get(1, {}).get("name", "Someone"))
	var msg := JSON.stringify({"game": GAME_TAG, "v": PROTOCOL, "name": host_name,
		"players": players.size(), "open": not in_race})
	_shout.put_packet(msg.to_utf8_buffer())


func _poll_listen() -> void:
	if _listen == null:
		return
	var changed := false
	while _listen.get_available_packet_count() > 0:
		var pkt := _listen.get_packet()
		var ip := _listen.get_packet_ip()
		var data = JSON.parse_string(pkt.get_string_from_utf8())
		if not (data is Dictionary) or data.get("game", "") != GAME_TAG:
			continue
		found[ip] = {"name": String(data.get("name", "?")).substr(0, Game.NAME_LENGTH),
			"players": int(data.get("players", 1)), "open": bool(data.get("open", true)),
			"same_version": int(data.get("v", 0)) == PROTOCOL, "seen": Time.get_ticks_msec()}
		changed = true
	for ip in found.keys():
		if Time.get_ticks_msec() - int(found[ip]["seen"]) > 4000:
			found.erase(ip)
			changed = true
	if changed:
		games_found_changed.emit()


## This computer's address on the home network, for joining by hand.
## Windows only: asks Windows (the "allow changes?" prompt) to let the game
## through the firewall. Removes any rule that blocks it (made when someone
## clicked Cancel on the first-time network prompt), then allows it on every
## network type. Returns false if this isn't Windows or it couldn't start.
static func fix_firewall() -> bool:
	if OS.get_name() != "Windows":
		return false
	var exe := OS.get_executable_path().replace("/", "\\")
	var rules := ('netsh advfirewall firewall delete rule name=all program="%s" & '
		+ 'netsh advfirewall firewall add rule name="Race Track Mayhem" dir=in action=allow program="%s" enable=yes profile=any & '
		+ 'netsh advfirewall firewall add rule name="Race Track Mayhem" dir=out action=allow program="%s" enable=yes profile=any') % [exe, exe, exe]
	var ps := "Start-Process -FilePath cmd.exe -Verb RunAs -WindowStyle Hidden -ArgumentList '/c %s'" % rules.replace("'", "''")
	return OS.create_process("powershell.exe", ["-NoProfile", "-WindowStyle", "Hidden", "-Command", ps]) > 0


static func local_address() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and a.split(".").size() == 4 and int(a.split(".")[1]) >= 16 and int(a.split(".")[1]) <= 31):
			return a
	return "127.0.0.1"
