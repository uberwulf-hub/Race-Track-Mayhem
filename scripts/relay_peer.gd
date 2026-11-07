class_name RelayPeer
extends MultiplayerPeerExtension
## Online races over the internet, through a small relay server.
##
## Home routers don't let other houses connect straight in, so everyone
## connects OUT to the relay instead. The host opens a "room" and gets a short
## code; the others join with that code. The relay passes the game's messages
## between the computers in the room (it never looks inside them).
##
## To Godot's networking this behaves like any other connection (ENet), so
## everything in Net (lobby, race syncing, power-ups) works unchanged.
##
## Messages to and from the relay (see server/relay):
## - control messages are JSON text:
##     relay -> us:  {"t":"welcome","id":1,"code":"ZOOM"}   our peer id (+ room code)
##                   {"t":"join","id":N} / {"t":"leave","id":N}
##                   {"t":"error","msg":"..."}
##     us -> relay:  {"t":"kick","id":N}                    (host only)
## - game data is binary: 4-byte little-endian peer id + 1 byte channel + the packet.
##     us -> relay:  the id is who it's for (0 = everyone else)
##     relay -> us:  the id is who it's from

signal room_ready(code: String)
signal relay_error(message: String)

var _ws := WebSocketPeer.new()
var _status := MultiplayerPeer.CONNECTION_DISCONNECTED
var _my_id := 0
var _hosting := false
var _target := 0
var _channel := 0
var _mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _incoming: Array = []      # [[from, channel, PackedByteArray], ...]
var _peers: Dictionary = {}    # peer id -> true
var code := ""


## Opens a new room on the relay (we become peer 1, the host).
func create_room(relay_url: String, protocol: int) -> Error:
	_hosting = true
	return _open("%s/host?v=%d" % [relay_url, protocol])


## Joins the room with this code.
func join_room(relay_url: String, room_code: String, protocol: int) -> Error:
	_hosting = false
	return _open("%s/join/%s?v=%d" % [relay_url, room_code.strip_edges().to_upper().uri_encode(), protocol])


func _open(url: String) -> Error:
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	var err := _ws.connect_to_url(url)
	if err == OK:
		_status = MultiplayerPeer.CONNECTION_CONNECTING
	return err


# --- MultiplayerPeer ---------------------------------------------------------

func _poll() -> void:
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		if _status != MultiplayerPeer.CONNECTION_DISCONNECTED:
			var was_connected := _status == MultiplayerPeer.CONNECTION_CONNECTED
			var reason := _ws.get_close_reason()
			_drop_all()
			_status = MultiplayerPeer.CONNECTION_DISCONNECTED
			if not was_connected:
				relay_error.emit(reason if reason != "" else "Couldn't reach the internet race server.")
		return
	while _ws.get_available_packet_count() > 0:
		var pkt := _ws.get_packet()
		if _ws.was_string_packet():
			_on_control(pkt.get_string_from_utf8())
		elif pkt.size() >= 5:
			var from := pkt.decode_s32(0)
			_incoming.append([from, pkt[4], pkt.slice(5)])


func _on_control(text: String) -> void:
	var msg = JSON.parse_string(text)
	if not (msg is Dictionary):
		return
	match String(msg.get("t", "")):
		"welcome":
			_my_id = int(msg["id"])
			code = String(msg.get("code", ""))
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			for id in msg.get("peers", []):
				_add_peer(int(id))
			if _hosting:
				room_ready.emit(code)
		"join":
			_add_peer(int(msg["id"]))
		"leave":
			var id := int(msg["id"])
			if _peers.has(id):
				_peers.erase(id)
				peer_disconnected.emit(id)
		"error":
			relay_error.emit(String(msg.get("msg", "Something went wrong with the internet race.")))


func _add_peer(id: int) -> void:
	if id != _my_id and not _peers.has(id):
		_peers[id] = true
		peer_connected.emit(id)


func _drop_all() -> void:
	for id in _peers.keys():
		peer_disconnected.emit(id)
	_peers.clear()
	_incoming.clear()


func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	return _incoming.pop_front()[2]


func _get_packet_peer() -> int:
	return int(_incoming[0][0]) if not _incoming.is_empty() else 0


func _get_packet_channel() -> int:
	return int(_incoming[0][1]) if not _incoming.is_empty() else 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var out := PackedByteArray()
	out.resize(5)
	out.encode_s32(0, _target)
	out[4] = _channel
	out.append_array(buffer)
	return _ws.send(out, WebSocketPeer.WRITE_MODE_BINARY)


func _get_max_packet_size() -> int:
	return 1 << 20


func _set_target_peer(peer: int) -> void:
	_target = peer


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _get_unique_id() -> int:
	return _my_id


func _is_server() -> bool:
	return _hosting


func _is_server_relay_supported() -> bool:
	return false   # the relay already delivers straight to whoever a message is for


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _set_refuse_new_connections(_enable: bool) -> void:
	pass


func _is_refusing_new_connections() -> bool:
	return false


func _disconnect_peer(peer: int, _force: bool) -> void:
	if _hosting and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify({"t": "kick", "id": peer}))


func _close() -> void:
	_ws.close(1000, "bye")
	_drop_all()
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
