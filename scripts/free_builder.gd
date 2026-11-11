extends Node3D
## Build Anywhere: the Track Builder like a real toy track set. Drag pieces
## out of the tray onto the floor; when a piece's end comes close to another
## end it snaps on with a click. Pick up any piece and move it, turn it or
## throw it in the bin.
##
## The race track is every piece joined up in a row from the start line (the
## road home is still drawn automatically, so it always works). Pieces that
## aren't joined on are shown faded and left out of the race.
##
## Pieces are measured with Track.piece_shape(), so a snapped piece is exactly
## where the real track puts it. Saved tracks keep the usual "pieces" list
## (for racing and sharing) plus a "layout" with where every piece sits.

const MAX_TILES := 40
const SNAP_DIST := 16.0         # how close (world units) a piece must be to snap on
const GRID := 2.0               # loose pieces snap to this grid...
const TURN_STEP := PI / 4.0     # ...and turn in 45 degree steps
const HISTORY := 60
const START := Transform3D(Basis(), Vector3(0.0, Track.BASE_HEIGHT, 0.0))
const NAMES := ["Super Speedway", "Zoom Zone", "Crazy Circuit", "Loop Land", "Turbo Town", "Wiggle Way", "Jump Jungle", "Rocket Run"]

var _tiles: Array = []          # [{"id": String, "t": Transform3D (where the piece starts)}]
var _chain: Array = []          # indexes into _tiles, in race order from the start line
var _chain_ids: Array = []      # their piece ids (what the race builds)
var _room_theme := "bedroom"
var _slot := -1
var _by := ""
var _sel := -1                  # picked tile (-1 = none)

# Holding a piece (dragging it around)
var _held := {}                 # {"id", "yaw", "offset": Vector3, "from": Transform3D or null}
var _held_pose := Transform3D()
var _held_snap := false
var _held_node: MeshInstance3D
var _snap_marker: MeshInstance3D

# Pointer
var _press_at := Vector2.ZERO
var _press_tile := -1
var _pressing := false
var _cam_dragging := false

# Scene
var _track: Track
var _track_ids: Array = ["__none__"]
var _floor: MeshInstance3D
var _car: ToyCarModel
var _car_s := 0.0
var _cam: Camera3D
var _cam_angle := 0.5
var _cam_zoom := 1.0
var _center := Vector3.ZERO
var _fit := 90.0
var _time := 0.0
var _loose_nodes: Array[Node] = []
var _socket_nodes: Array[Node] = []
var _highlight: MeshInstance3D
var _undo_stack: Array = []
var _clear_armed := false
var _switch_armed := false

# UI
var _name_edit: LineEdit
var _room_button: Button
var _status: Label
var _count_label: Label
var _tools: PanelContainer
var _tools_title: Label
var _flip_button: Button
var _bin: PanelContainer
var _bin_style: StyleBoxFlat
var _clear_button: Button
var _switch_button: Button

static var _ribbons := {}        # piece id -> ArrayMesh of its road, at the origin
static var _middles := {}        # piece id -> its middle point, at the origin


func _ready() -> void:
	Sfx.play_music("garage")
	var data := {}
	if not Game.builder_handoff.is_empty():
		data = Game.builder_handoff
		Game.builder_handoff = {}
		_slot = Game.editing_slot
	else:
		_slot = Game.editing_slot
		if _slot >= 0 and _slot < Game.custom_tracks.size():
			data = Game.custom_tracks[_slot]
		else:
			_slot = -1
	if data.is_empty():
		data = {"pieces": ["straight", "right", "loop", "right"]}   # a little starter track
	_room_theme = String(data.get("room", "bedroom"))
	_by = String(data.get("by", ""))
	_tiles = _load_layout(data)
	_build_scene()
	_build_ui()
	_name_edit.text = String(data.get("name", "")) if data.has("name") else NAMES[randi() % NAMES.size()]
	_rebuild(true)
	_say("Drag pieces onto the floor. Ends snap together when they get close!", Color(0.8, 0.95, 1.0))


# ---------------------------------------------------------------------------
# Pieces: shapes, sockets and the chain from the start line
# ---------------------------------------------------------------------------

static func _end(id: String) -> Transform3D:
	return Track.piece_shape(id)["end"]


static func _middle(id: String) -> Vector3:
	if not _middles.has(id):
		var pts: PackedVector3Array = Track.piece_shape(id)["points"]
		var sum := Vector3.ZERO
		for p in pts:
			sum += Vector3(p.x, 0.0, p.z)
		_middles[id] = sum / maxf(1.0, pts.size())
	return _middles[id]


static func _same(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.6 and a.basis.z.dot(b.basis.z) > 0.995


static func _yaw_of(t: Transform3D) -> float:
	var fwd := -t.basis.z
	return atan2(-fwd.x, -fwd.z)


static func _pose(pos: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, Track.BASE_HEIGHT, pos.z))


## Pieces joined up in a row from the start line, as indexes into _tiles.
func _find_chain() -> Array:
	var out: Array = []
	var used := {}
	var cur := START
	while out.size() < MAX_TILES:
		var next := -1
		for i in _tiles.size():
			if not used.has(i) and _same(_tiles[i]["t"], cur):
				next = i
				break
		if next < 0:
			break
		used[next] = true
		out.append(next)
		cur = (_tiles[next]["t"] as Transform3D) * _end(_tiles[next]["id"])
		if _same(cur, START):
			break   # came all the way round to the start line
	return out


## Open ends a held piece can snap to: [{"pose": where the held piece would
## start, "at": Transform3D of the end it joins}].
func _snap_spots(id: String) -> Array:
	var spots: Array = []
	var exits: Array = [START]
	var entries: Array = []
	for t in _tiles:
		exits.append((t["t"] as Transform3D) * _end(t["id"]))
		entries.append(t["t"])
	# Our start goes on an exit nobody has used yet...
	for e: Transform3D in exits:
		var taken := false
		for t in _tiles:
			if _same(t["t"], e):
				taken = true
				break
		if not taken:
			spots.append({"pose": e, "at": e})
	# ...or our end goes on the start of a piece nothing leads into.
	var inv := _end(id).affine_inverse()
	for s: Transform3D in entries:
		if _same(s, START):
			continue
		var fed := false
		for e: Transform3D in exits:
			if _same(e, s):
				fed = true
				break
		if not fed:
			spots.append({"pose": s * inv, "at": s})
	return spots


# ---------------------------------------------------------------------------
# Loading, saving
# ---------------------------------------------------------------------------

## Tiles from a saved layout, or laid out in a row from the plain piece list.
func _load_layout(data: Dictionary) -> Array:
	var out: Array = []
	var layout = data.get("layout", null)
	if layout is Array and not (layout as Array).is_empty():
		for e in layout:
			if not e is Dictionary or Track.piece_info(String(e.get("id", ""))).is_empty():
				continue
			out.append({"id": String(e["id"]), "t": _pose(Vector3(float(e.get("x", 0)), 0.0, float(e.get("z", 0))), float(e.get("yaw", 0)))})
			if out.size() >= MAX_TILES:
				break
		return out
	var pose := START
	for id in data.get("pieces", []):
		if Track.piece_info(String(id)).is_empty():
			continue
		out.append({"id": String(id), "t": pose})
		pose = pose * _end(String(id))
		pose = _pose(pose.origin, _yaw_of(pose))   # keep it level and tidy
		if out.size() >= MAX_TILES:
			break
	return out


func _layout_data() -> Array:
	var out: Array = []
	for t in _tiles:
		var tr: Transform3D = t["t"]
		out.append({"id": t["id"], "x": snappedf(tr.origin.x, 0.001), "z": snappedf(tr.origin.z, 0.001), "yaw": snappedf(_yaw_of(tr), 0.00001)})
	return out


func _save() -> bool:
	if _chain_ids.is_empty():
		_say("Join some pieces onto the start line first!", Color(1.0, 0.7, 0.3))
		return false
	var data := {"name": _clean_name(), "room": _room_theme, "pieces": _chain_ids.duplicate(), "layout": _layout_data()}
	if _by != "":
		data["by"] = _by
	if _slot < 0:
		if Game.custom_tracks.size() >= Game.MAX_CUSTOM_TRACKS:
			_say("You have %d tracks already! Delete one in the track picker." % Game.MAX_CUSTOM_TRACKS, Color(1.0, 0.7, 0.3))
			return false
		Game.custom_tracks.append(data)
		_slot = Game.custom_tracks.size() - 1
		Game.editing_slot = _slot
		Game.add_stat("tracks_built")
	else:
		Game.custom_tracks[_slot] = data
	Game.save_settings()
	Game.check_badges()
	Sfx.play("select")
	_say("Saved: %s!" % data["name"], Color(0.6, 1.0, 0.65))
	return true


func _race_it() -> void:
	var loose := _tiles.size() - _chain.size()
	if not _save():
		return
	if loose > 0:
		Sfx.play("go")
	Game.end_grand_prix()
	Game.selected_track = Track.TRACKS.size() + _slot
	Game.skip_track_select = true
	Game.goto_garage()


func _clean_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n.substr(0, 24) if n != "" else "My Track"


## Back to the simple (snap in a row) builder, taking the joined-up pieces.
func _switch_to_simple() -> void:
	var loose := _tiles.size() - _chain.size()
	if loose > 0 and not _switch_armed:
		_switch_armed = true
		_switch_button.text = "Sure? Tap again"
		_say("The simple builder only keeps pieces joined to the track: %d loose piece%s will be left out." % [loose, "" if loose == 1 else "s"], Color(1.0, 0.75, 0.3))
		return
	Game.builder_free = false
	Game.save_settings()
	Game.builder_handoff = {"name": _clean_name(), "room": _room_theme, "pieces": _chain_ids.duplicate(), "by": _by}
	Game.editing_slot = _slot
	Game.goto("res://scenes/track_editor.tscn")


func _back() -> void:
	Sfx.play("back")
	Game.goto_track_select()


# ---------------------------------------------------------------------------
# Editing
# ---------------------------------------------------------------------------

func _remember() -> void:
	_undo_stack.append(_layout_data())
	if _undo_stack.size() > HISTORY:
		_undo_stack.pop_front()


func _undo() -> void:
	if _undo_stack.is_empty():
		_say("Nothing to undo.", Color(1, 1, 1, 0.8))
		return
	_tiles = _load_layout({"layout": _undo_stack.pop_back()})
	if _tiles.is_empty():
		_tiles = []
	_sel = -1
	Sfx.play("back")
	_rebuild()


func _clear() -> void:
	if not _clear_armed:
		_clear_armed = true
		_clear_button.text = "Sure? Tap again"
		get_tree().create_timer(3.0).timeout.connect(func():
			_clear_armed = false
			if is_instance_valid(_clear_button):
				_clear_button.text = "Clear")
		return
	_clear_armed = false
	_clear_button.text = "Clear"
	_remember()
	_tiles.clear()
	_sel = -1
	_rebuild()


func _select(i: int) -> void:
	_sel = i
	_refresh_tools()
	_place_highlight()


func _delete_selected() -> void:
	if _sel < 0 or _sel >= _tiles.size():
		return
	_remember()
	_tiles.remove_at(_sel)
	_sel = -1
	Sfx.play("pop", 1.2)
	_rebuild()


## Turns the picked piece 45 degrees round its middle (it comes unsnapped).
func _turn_selected() -> void:
	if _sel < 0:
		return
	_remember()
	var t: Transform3D = _tiles[_sel]["t"]
	var id: String = _tiles[_sel]["id"]
	var mid := t * _middle(id)
	var yaw := _yaw_of(t) - TURN_STEP
	var nt := _pose(Vector3.ZERO, yaw)
	nt.origin = mid - nt.basis * _middle(id)
	nt.origin.y = Track.BASE_HEIGHT
	_tiles[_sel]["t"] = _try_snap(id, nt)
	Sfx.play("click")
	_rebuild()


func _flip_selected() -> void:
	if _sel < 0 or not Track.FLIPPED.has(_tiles[_sel]["id"]):
		return
	_remember()
	_tiles[_sel]["id"] = Track.FLIPPED[_tiles[_sel]["id"]]
	Sfx.play("click")
	_rebuild()


## A pose snapped onto the nearest open end, if one is close enough.
func _try_snap(id: String, free_pose: Transform3D) -> Transform3D:
	var best := SNAP_DIST
	var out := free_pose
	var mid := free_pose * _middle(id)
	for s in _snap_spots(id):
		var p: Transform3D = s["pose"]
		var d := (p * _middle(id)).distance_to(mid)
		if d < best:
			best = d
			out = p
	return out


# ---------------------------------------------------------------------------
# Holding and dropping pieces
# ---------------------------------------------------------------------------

## Starts carrying a new piece from the tray.
func _grab_new(id: String) -> void:
	if _tiles.size() >= MAX_TILES:
		_say("That's %d pieces, the most a track can have!" % MAX_TILES, Color(1.0, 0.7, 0.3))
		return
	var yaw := _yaw_of(_chain_end())
	_held = {"id": id, "yaw": yaw, "offset": -(Basis(Vector3.UP, yaw) * _middle(id)), "from": null, "new": true}
	_press_at = get_viewport().get_mouse_position()
	_show_held()
	Sfx.play("click", 1.2)


## Picks up a piece that's already on the floor.
func _grab_tile(i: int, hit: Vector3) -> void:
	_remember()
	var t: Transform3D = _tiles[i]["t"]
	_held = {"id": _tiles[i]["id"], "yaw": _yaw_of(t), "offset": t.origin - hit, "from": t, "new": false}
	_tiles.remove_at(i)
	_sel = -1
	_rebuild()
	_show_held()
	Sfx.play("click", 1.3)


func _show_held() -> void:
	if _held_node:
		_held_node.queue_free()
	_held_node = MeshInstance3D.new()
	_held_node.mesh = _ribbon(_held["id"])
	add_child(_held_node)
	_tools.visible = false
	_bin.visible = true
	_move_held(get_viewport().get_mouse_position())


func _move_held(screen: Vector2) -> void:
	var hit = _floor_hit(screen)
	if hit == null:
		return
	var id: String = _held["id"]
	var free_pose := _pose((hit as Vector3) + (_held["offset"] as Vector3), _held["yaw"])
	free_pose.origin = Vector3(snappedf(free_pose.origin.x, GRID), Track.BASE_HEIGHT, snappedf(free_pose.origin.z, GRID))
	var snapped := _try_snap(id, free_pose)
	var was := _held_snap
	_held_snap = not snapped.is_equal_approx(free_pose)
	_held_pose = snapped
	_held_node.transform = Transform3D(_held_pose.basis, _held_pose.origin + Vector3.UP * 0.6)
	var over_bin := _over_bin(screen)
	_held_node.material_override = _ribbon_mat(Color(1.0, 0.3, 0.25, 0.6) if over_bin else (Color(0.3, 1.0, 1.0, 0.8) if _held_snap else Color(1.0, 1.0, 1.0, 0.55)), _held_snap)
	_bin_style.bg_color = Color(0.9, 0.2, 0.15, 0.95) if over_bin else Color(0.55, 0.15, 0.15, 0.8)
	if _held_snap and not was:
		Sfx.play("click", 1.6, -6.0)
	_show_snap_marker()


func _show_snap_marker() -> void:
	if _snap_marker:
		_snap_marker.queue_free()
		_snap_marker = null
	if not _held_snap:
		return
	_snap_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.6
	tm.outer_radius = 3.4
	_snap_marker.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 1.0, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.3, 1.0, 1.0)
	m.emission_energy_multiplier = 2.0
	m.no_depth_test = true
	_snap_marker.material_override = m
	_snap_marker.position = _held_pose.origin + Vector3.UP * 0.8
	add_child(_snap_marker)


func _turn_held() -> void:
	if _held.is_empty():
		return
	var id: String = _held["id"]
	# Keep the piece's middle under your finger while it turns.
	var old_mid := Basis(Vector3.UP, _held["yaw"]) * _middle(id)
	_held["yaw"] = float(_held["yaw"]) - TURN_STEP
	var new_mid := Basis(Vector3.UP, _held["yaw"]) * _middle(id)
	_held["offset"] = (_held["offset"] as Vector3) + old_mid - new_mid
	Sfx.play("click")
	_move_held(get_viewport().get_mouse_position())


func _drop(screen: Vector2) -> void:
	if _held.is_empty():
		return
	var id: String = _held["id"]
	var is_new: bool = _held["new"]
	var tap := is_new and screen.distance_to(_press_at) < 14.0
	if tap:
		# A quick tap on a tray piece: put it on the end of the track.
		var end := _chain_end()
		var closed := _chain.size() > 0 and _same(end, START)
		_remember()
		if closed:
			_tiles.append({"id": id, "t": _pose(_center + Vector3(0, 0, _fit * 0.4), 0.0)})
			_say("Your track already joins up! The new piece is waiting on the floor - drag it in.", Color(1.0, 0.85, 0.4))
		else:
			_tiles.append({"id": id, "t": end})
		Sfx.play("select")
	elif _over_bin(screen):
		Sfx.play("pop", 0.8)
		if not is_new:
			_say("Thrown away! (Undo brings it back.)", Color(1.0, 0.8, 0.6))
	else:
		if is_new:
			_remember()
		_tiles.append({"id": id, "t": _held_pose})
		_sel = -1
		Sfx.play("select" if _held_snap else "click", 1.0)
	_held = {}
	_held_snap = false
	if _held_node:
		_held_node.queue_free()
		_held_node = null
	if _snap_marker:
		_snap_marker.queue_free()
		_snap_marker = null
	_bin_style.bg_color = Color(0.55, 0.15, 0.15, 0.8)
	_rebuild()


## Where the joined-up track ends (where a new piece would go).
func _chain_end() -> Transform3D:
	if _chain.is_empty():
		return START
	var last: Dictionary = _tiles[_chain.back()]
	return (last["t"] as Transform3D) * _end(last["id"])


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# While carrying a piece, follow the pointer everywhere (even over buttons).
	if _held.is_empty():
		return
	if event is InputEventMouseMotion:
		_move_held(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop(event.position)
		_pressing = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_turn_held()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_turn_held()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _held.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.position
			_pressing = true
			_cam_dragging = false
			_press_tile = _tile_at(event.position)
		else:
			if _pressing and not _cam_dragging:
				_select(_tile_at(event.position))
			_pressing = false
		return
	if event is InputEventMouseMotion and _pressing and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not _cam_dragging and event.position.distance_to(_press_at) > 12.0:
			if _press_tile >= 0:
				# Pick the piece up and carry it.
				var hit = _floor_hit(_press_at)
				if hit != null:
					var i := _press_tile
					_press_tile = -1
					_pressing = false
					_grab_tile(i, hit)
					_move_held(event.position)
					return
			_cam_dragging = true
		if _cam_dragging:
			_cam_angle -= event.relative.x * 0.008
		return
	if event is InputEventMagnifyGesture:
		_cam_zoom = clampf(_cam_zoom / event.factor, 0.35, 1.8)
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom = clampf(_cam_zoom * 0.9, 0.35, 1.8)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom = clampf(_cam_zoom * 1.1, 0.35, 1.8)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		_cam_angle -= event.relative.x * 0.008
	elif event is InputEventKey and event.pressed and not event.echo and not _name_edit.has_focus():
		match (event as InputEventKey).keycode:
			KEY_DELETE, KEY_BACKSPACE:
				_delete_selected()
			KEY_R:
				_turn_selected()
			KEY_F:
				_flip_selected()
			KEY_Z:
				if (event as InputEventKey).ctrl_pressed:
					_undo()
	elif event.is_action_pressed("ui_cancel"):
		_back()


## The piece under a screen point (-1 = none): joined pieces and loose ones.
func _tile_at(screen: Vector2) -> int:
	var best := -1
	var best_d := 38.0   # pixels
	for i in _tiles.size():
		var t: Transform3D = _tiles[i]["t"]
		var pts: PackedVector3Array = Track.piece_shape(_tiles[i]["id"])["points"]
		var step := maxi(1, pts.size() / 24)
		for k in range(0, pts.size(), step):
			var w := t * pts[k]
			if _cam.is_position_behind(w):
				continue
			var d := _cam.unproject_position(w).distance_to(screen)
			if d < best_d:
				best_d = d
				best = i
	return best


func _floor_hit(screen: Vector2) -> Variant:
	var from := _cam.project_ray_origin(screen)
	var dir := _cam.project_ray_normal(screen)
	return Plane(Vector3.UP, Track.BASE_HEIGHT).intersects_ray(from, dir)


func _over_bin(screen: Vector2) -> bool:
	return _bin.visible and _bin.get_global_rect().has_point(screen)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

## Rebuilds the race track from the joined-up pieces and redraws loose ones.
func _rebuild(fit_view := false) -> void:
	_chain = _find_chain()
	_chain_ids = _chain.map(func(i): return String(_tiles[i]["id"]))
	if _chain_ids != _track_ids:
		_track_ids = _chain_ids.duplicate()
		if _track:
			_track.queue_free()
		_track = Track.new()
		_track.custom = true
		_track.custom_pieces = _chain_ids.duplicate()
		add_child(_track)
		_track.build()
	for n in _loose_nodes:
		n.queue_free()
	_loose_nodes.clear()
	for i in _tiles.size():
		if _chain.has(i):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = _ribbon(_tiles[i]["id"])
		mi.material_override = _ribbon_mat(Color(1.0, 0.42, 0.05, 0.85), false)
		mi.transform = Transform3D((_tiles[i]["t"] as Transform3D).basis, (_tiles[i]["t"] as Transform3D).origin + Vector3.UP * 0.3)
		add_child(mi)
		_loose_nodes.append(mi)
	_show_sockets()
	if fit_view:
		_fit_view()
	if _sel >= _tiles.size():
		_sel = -1
	_refresh_tools()
	_place_highlight()
	var loose := _tiles.size() - _chain.size()
	_count_label.text = "%d / %d pieces" % [_tiles.size(), MAX_TILES]
	var clashes := _track.count_clashes() if _track else 0
	if _tiles.is_empty():
		_say("Drag a piece from the left onto the floor to start!", Color.WHITE)
	elif _chain.is_empty():
		_say("Snap a piece onto the start line (the glowing arrow) to begin your track.", Color(1.0, 0.85, 0.4))
	elif clashes > 0:
		_say("Uh-oh! The track runs into itself. Move a piece, or Undo.", Color(1.0, 0.75, 0.3))
	elif loose > 0:
		_say("%d loose piece%s (faded) - snap %s onto the track or %s won't be in the race." % [loose, "" if loose == 1 else "s", "it" if loose == 1 else "them", "it" if loose == 1 else "they"], Color(1.0, 0.85, 0.4))
	else:
		_say("Looking great! The road home is added for you. Tap Race It!", Color(0.6, 1.0, 0.65))


## Glowing arrows on every open end you can snap a piece onto.
func _show_sockets() -> void:
	for n in _socket_nodes:
		n.queue_free()
	_socket_nodes.clear()
	var end := _chain_end()
	var closed := not _chain.is_empty() and _same(end, START)
	if not closed:
		_socket_nodes.append(_arrow(end, Color(0.4, 1.0, 0.45), "SNAP HERE" if _chain.size() < 2 else ""))
	for i in _tiles.size():
		if _chain.has(i):
			continue
		var t: Transform3D = _tiles[i]["t"]
		var e := t * _end(_tiles[i]["id"])
		var used := false
		for o in _tiles:
			if _same(o["t"], e):
				used = true
		if not used:
			_socket_nodes.append(_arrow(e, Color(1.0, 0.85, 0.3), ""))


func _arrow(at: Transform3D, col: Color, text: String) -> Node3D:
	var n := Node3D.new()
	n.transform = Transform3D(at.basis, at.origin + Vector3.UP * 1.6)
	add_child(n)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.4
	m.no_depth_test = true
	m.render_priority = 5
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 1.4
	cm.height = 2.6
	cone.mesh = cm
	cone.material_override = m
	cone.rotation.x = -PI * 0.5
	n.add_child(cone)
	if text != "":
		var l := Label3D.new()
		l.text = text
		l.font_size = 56
		l.pixel_size = 0.04
		l.outline_size = 12
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.modulate = col
		l.position = Vector3(0, 3.2, 0)
		n.add_child(l)
	return n


func _place_highlight() -> void:
	if _highlight:
		_highlight.queue_free()
		_highlight = null
	if _sel < 0 or _sel >= _tiles.size():
		return
	_highlight = MeshInstance3D.new()
	_highlight.mesh = _ribbon(_tiles[_sel]["id"])
	_highlight.material_override = _ribbon_mat(Color(0.4, 1.0, 1.0, 0.5), true)
	var t: Transform3D = _tiles[_sel]["t"]
	_highlight.transform = Transform3D(t.basis, t.origin + Vector3.UP * 0.7)
	add_child(_highlight)


## A flat road shape for a piece (its loops and hills flattened onto the
## floor, with a gap where a jump is), cached per piece.
func _ribbon(id: String) -> ArrayMesh:
	if _ribbons.has(id):
		return _ribbons[id]
	var shape := Track.piece_shape(id)
	var pts: PackedVector3Array = shape["points"]
	var air: PackedByteArray = shape["air"]
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	var hw := Track.HALF_WIDTH
	# The road, plus darker kerbs along both edges so you can see each piece.
	for k in range(1, pts.size()):
		if air[k] or air[k - 1]:
			continue
		var a := Vector3(pts[k - 1].x, pts[k - 1].y * 0.15, pts[k - 1].z)
		var b := Vector3(pts[k].x, pts[k].y * 0.15, pts[k].z)
		var dir := Vector3(b.x - a.x, 0.0, b.z - a.z)
		if dir.length() < 0.001:
			continue
		var side := dir.normalized().cross(Vector3.UP) * hw
		st.add_vertex(a - side)
		st.add_vertex(b - side)
		st.add_vertex(b + side)
		st.add_vertex(a - side)
		st.add_vertex(b + side)
		st.add_vertex(a + side)
		for e: float in [-1.0, 1.0]:
			var o := side * e
			var inner := side * e * 0.78
			var lift := Vector3.UP * 0.05
			st.set_color(Color(0.55, 0.2, 0.0))
			st.add_vertex(a + inner + lift)
			st.add_vertex(b + inner + lift)
			st.add_vertex(b + o + lift)
			st.add_vertex(a + inner + lift)
			st.add_vertex(b + o + lift)
			st.add_vertex(a + o + lift)
			st.set_color(Color.WHITE)
	st.commit(mesh)
	_ribbons[id] = mesh
	return mesh


func _ribbon_mat(col: Color, glow: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	if glow:
		m.emission_enabled = true
		m.emission = Color(col.r, col.g, col.b)
		m.emission_energy_multiplier = 1.2
	return m


func _fit_view() -> void:
	var r := _track.get_aabb_xz() if _track else Rect2(-40, -40, 80, 80)
	for t in _tiles:
		var o: Vector3 = (t["t"] as Transform3D).origin
		r = r.expand(Vector2(o.x, o.z))
	_center = Vector3(r.get_center().x, 0.0, r.get_center().y)
	_fit = maxf(r.size.x, r.size.y) * 0.8 + 50.0
	_floor.position = _center
	(_floor.mesh as PlaneMesh).size = r.size + Vector2(400, 400)


func _process(delta: float) -> void:
	_time += delta
	if Input.is_key_pressed(KEY_Q) and not _name_edit.has_focus():
		_cam_angle -= delta * 1.2
	elif Input.is_key_pressed(KEY_E) and not _name_edit.has_focus():
		_cam_angle += delta * 1.2
	var dist := _fit * _cam_zoom
	# Steep, nearly top-down view: easy to see where pieces go.
	var goal := _center + Vector3(sin(_cam_angle) * dist * 0.5, dist * 1.05, cos(_cam_angle) * dist * 0.5)
	_cam.position = _cam.position.lerp(goal, minf(1.0, delta * 3.0))
	_cam.look_at(_center, Vector3.UP)
	if _track and _track.count > 0 and not _chain.is_empty():
		_car.visible = true
		_car_s = fposmod(_car_s + delta * 32.0, _track.length)
		var f := _track.sample(_car_s)
		_car.global_transform = Transform3D(f.basis, f.origin)
		_car.animate(32.0, 0.0, delta)
	else:
		_car.visible = false
	if _snap_marker:
		_snap_marker.scale = Vector3.ONE * (1.0 + sin(_time * 10.0) * 0.12)
	for n in _socket_nodes:
		(n as Node3D).scale = Vector3.ONE * (1.0 + sin(_time * 5.0) * 0.15)


# ---------------------------------------------------------------------------
# Scene and UI
# ---------------------------------------------------------------------------

func _build_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.75, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.97, 0.92)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.75
	add_child(sun)
	Game.apply_quality(env, sun)
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	_floor = MeshInstance3D.new()
	_floor.mesh = PlaneMesh.new()
	add_child(_floor)
	_apply_floor()
	var car_def := CarData.get_car(Game.selected_car)
	_car = ToyCarModel.new().setup(car_def, true, Game.custom_for(car_def["id"]))
	add_child(_car)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 2000.0
	_cam.position = Vector3(0, 150, 60)
	add_child(_cam)
	_cam.current = true


func _apply_floor() -> void:
	var r := Room.create(_room_theme)
	r._configure()
	var img := r._floor_image()
	var tile := r.floor_tile_size
	r.free()
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_scale = Vector3(40.0, 40.0, 1.0) * (24.0 / tile)
	m.roughness = 0.7
	_floor.material_override = m


func _cycle_room() -> void:
	var i := 0
	for k in Game.ROOM_THEMES.size():
		if Game.ROOM_THEMES[k][0] == _room_theme:
			i = k
	_room_theme = Game.ROOM_THEMES[(i + 1) % Game.ROOM_THEMES.size()][0]
	_room_button.text = "Room: " + Game.room_name(_room_theme).trim_prefix("The ")
	_apply_floor()
	Sfx.play("click")


func _say(text: String, col: Color) -> void:
	if _status:
		_status.text = text
		_status.add_theme_color_override("font_color", col)


func _refresh_tools() -> void:
	if _tools == null:
		return
	_tools.visible = _sel >= 0 and _held.is_empty()
	if _sel < 0:
		return
	var id: String = _tiles[_sel]["id"]
	var where := ("#%d on the track" % (_chain.find(_sel) + 1)) if _chain.has(_sel) else "loose"
	_tools_title.text = "%s\n(%s)" % [Track.piece_info(id).get("name", id), where]
	_flip_button.disabled = not Track.FLIPPED.has(id)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.ui_theme
	layer.add_child(root)

	# --- top bar ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	RaceHud.pin(top, Vector2(0, 0), Vector2(16, 10), Vector2(980, 64))
	root.add_child(top)
	top.add_child(RaceHud.make_label("BUILD ANYWHERE", 32, Color(1.0, 0.85, 0.2), 12))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(260, 52)
	_name_edit.max_length = 24
	_name_edit.placeholder_text = "Name your track"
	_name_edit.add_theme_font_size_override("font_size", 24)
	top.add_child(_name_edit)
	_room_button = _button(top, "Room: " + Game.room_name(_room_theme).trim_prefix("The "), _cycle_room)
	_room_button.add_theme_font_size_override("font_size", 20)
	_room_button.custom_minimum_size = Vector2(250, 52)
	_switch_button = _button(root, "Simple Builder", _switch_to_simple)
	_switch_button.tooltip_text = "The builder where pieces join up in a row by themselves"
	_switch_button.add_theme_font_size_override("font_size", 20)
	RaceHud.pin(_switch_button, Vector2(1, 0), Vector2(-252, 14), Vector2(238, 52))

	# --- left: the tray of pieces to drag out ---
	var tray := PanelContainer.new()
	RaceHud.pin(tray, Vector2(0, 0), Vector2(12, 84), Vector2(300, 470))
	root.add_child(tray)
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", 6)
	tray.add_child(tbox)
	var tt := RaceHud.make_label("Drag a piece out:", 21, Color(1.0, 0.95, 0.6), 8)
	tbox.add_child(tt)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	tbox.add_child(grid)
	for p in Track.PIECES:
		var id: String = p["id"]
		var b := Button.new()
		b.text = p["name"]
		b.custom_minimum_size = Vector2(138, 46)
		b.add_theme_font_size_override("font_size", 18)
		b.focus_mode = Control.FOCUS_NONE
		b.button_down.connect(func(): _grab_new(id))
		_style_piece_button(b, p["color"])
		grid.add_child(b)
	tray.reset_size.call_deferred()

	# --- right: tools for the picked piece ---
	_tools = PanelContainer.new()
	RaceHud.pin(_tools, Vector2(1, 0), Vector2(-262, 90), Vector2(250, 260))
	root.add_child(_tools)
	var tools_box := VBoxContainer.new()
	tools_box.add_theme_constant_override("separation", 6)
	_tools.add_child(tools_box)
	_tools_title = RaceHud.make_label("", 22, Color(0.5, 1.0, 1.0), 8)
	_tools_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools_box.add_child(_tools_title)
	var turn := _button(tools_box, "Turn  (R)", _turn_selected)
	_flip_button = _button(tools_box, "Flip Left/Right  (F)", _flip_selected)
	var del := _button(tools_box, "Delete", _delete_selected)
	del.modulate = Color(1.0, 0.75, 0.7)
	var done := _button(tools_box, "Done", func(): _select(-1))
	for b: Button in [turn, _flip_button, del, done]:
		b.add_theme_font_size_override("font_size", 18)
		b.custom_minimum_size = Vector2(0, 42)
	_tools.visible = false

	# --- bottom right: the bin, view controls and the count ---
	_bin = PanelContainer.new()
	_bin_style = StyleBoxFlat.new()
	_bin_style.bg_color = Color(0.55, 0.15, 0.15, 0.8)
	_bin_style.set_corner_radius_all(18)
	_bin_style.border_color = Color(1, 1, 1, 0.7)
	_bin_style.set_border_width_all(3)
	_bin.add_theme_stylebox_override("panel", _bin_style)
	_bin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	RaceHud.pin(_bin, Vector2(1, 1), Vector2(-182, -246), Vector2(170, 116))
	root.add_child(_bin)
	var bin_l := RaceHud.make_label("BIN\nDrop here to\nthrow away", 18, Color.WHITE, 6)
	bin_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bin_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bin.add_child(bin_l)
	_count_label = RaceHud.make_label("", 20, Color.WHITE, 8)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	RaceHud.pin(_count_label, Vector2(1, 1), Vector2(-212, -282), Vector2(200, 32))
	root.add_child(_count_label)
	var view := HBoxContainer.new()
	view.add_theme_constant_override("separation", 6)
	RaceHud.pin(view, Vector2(1, 1), Vector2(-330, -338), Vector2(318, 50))
	root.add_child(view)
	for v in [["<", func(): _cam_angle += 0.4], [">", func(): _cam_angle -= 0.4],
			["-", func(): _cam_zoom = clampf(_cam_zoom * 1.15, 0.35, 1.8)], ["+", func(): _cam_zoom = clampf(_cam_zoom * 0.87, 0.35, 1.8)]]:
		var vb := _button(view, v[0], v[1])
		vb.custom_minimum_size = Vector2(54, 48)
		vb.add_theme_font_size_override("font_size", 24)
		vb.focus_mode = Control.FOCUS_NONE

	# --- status line and hint ---
	_status = RaceHud.make_label("", 22, Color.WHITE, 10)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RaceHud.pin(_status, Vector2(0.5, 1), Vector2(-330, -150), Vector2(660, 60))
	root.add_child(_status)
	var hint := RaceHud.make_label("Drag a piece to move it.  R / right-click: turn.  Drag the floor: turn the view.", 15, Color(1, 1, 1, 0.85), 6)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	RaceHud.pin(hint, Vector2(1, 0), Vector2(-700, 70), Vector2(680, 44))
	root.add_child(hint)

	# --- bottom bar ---
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	RaceHud.pin(bottom, Vector2(0.5, 1), Vector2(-450, -86), Vector2(900, 76))
	root.add_child(bottom)
	_button(bottom, "Back", _back)
	_button(bottom, "Undo", _undo)
	_clear_button = _button(bottom, "Clear", _clear)
	_button(bottom, "Save", func(): _save())
	var race := _button(bottom, "Race It!", _race_it)
	race.add_theme_font_size_override("font_size", 36)


func _style_piece_button(b: Button, col: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.lightened(0.15) if state == "hover" else (col.darkened(0.15) if state == "pressed" else col)
		sb.border_color = col.darkened(0.35)
		sb.set_border_width_all(3)
		sb.border_width_bottom = 6
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override(state, sb)


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	parent.add_child(b)
	return b
