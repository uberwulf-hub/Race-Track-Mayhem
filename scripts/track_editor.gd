extends Node3D
## The Track Builder: snap pieces together to make your own track!
## Press a piece button to add it. The pieces show as a row of chips along
## the bottom: tap one (or tap the piece on the track) to pick it, then move
## it, delete it and so on. The road back to the start line is drawn for you
## automatically, so every track works. A little car drives it as you build.
##
## Easy mode: 8 simple pieces, new pieces go on the end.
## Advanced mode: all the pieces, new pieces go in after the one you picked,
## drag chips to reorder, plus Replace, Flip, Copy and keyboard shortcuts.

const MAX_PIECES := 40
const EASY_PIECES := ["straight", "left", "right", "boost", "loop", "jump", "hill", "bumps"]
const SHORT := {"straight": "Straight", "left": "Left", "right": "Right", "bend_left": "Bend L",
	"bend_right": "Bend R", "boost": "Boost", "loop": "Loop", "corkscrew": "Cork-\nscrew",
	"jump": "Jump", "big_jump": "Big\nJump", "hill": "Hill", "bumps": "Bumps", "spiral": "Spiral", "wiggles": "Wiggles", "halfpipe_right": "Half-\nPipe R", "halfpipe_left": "Half-\nPipe L", "tunnel": "Tunnel"}
const HISTORY := 60
const NAMES := ["Super Speedway", "Zoom Zone", "Crazy Circuit", "Loop Land", "Turbo Town", "Wiggle Way", "Jump Jungle", "Rocket Run"]

var _pieces: Array = []
var _room_theme := "bedroom"
var _slot := -1

var _track: Track
var _floor: MeshInstance3D
var _car: ToyCarModel
var _car_s := 0.0
var _cursor: Node3D
var _cam: Camera3D
var _cam_angle := 0.6
var _cam_zoom := 1.0
var _center := Vector3.ZERO
var _fit := 80.0
var _time := 0.0

var _name_edit: LineEdit
var _room_button: Button
var _status: Label
var _count_label: Label
var _clear_button: Button
var _clear_armed := false

var _sel := -1                  # the picked piece (-1 = none)
var _replacing := false         # Advanced: the next palette tap replaces the picked piece
var _undo_stack: Array = []
var _redo_stack: Array = []
var _highlight: MeshInstance3D
var _ui_root: Control
var _palette_panel: PanelContainer
var _palette_title: Label
var _palette_grid: GridContainer
var _tools: PanelContainer
var _tools_title: Label
var _tool_buttons: Dictionary = {}
var _strip_scroll: ScrollContainer
var _strip: HBoxContainer
var _mode_button: Button
var _redo_button: Button
var _hint: Label
var _insert_mark: Label
var _press_at := Vector2.ZERO   # where a left click / finger went down
var _dragging := false          # dragging turns the view instead of picking a piece


func _ready() -> void:
	Sfx.play_music("garage")
	_slot = Game.editing_slot
	var handoff: Dictionary = Game.builder_handoff
	Game.builder_handoff = {}
	if not handoff.is_empty():
		# Coming from Build Anywhere with this track.
		_pieces = (handoff.get("pieces", []) as Array).duplicate()
		_room_theme = String(handoff.get("room", "bedroom"))
	elif _slot >= 0 and _slot < Game.custom_tracks.size():
		var t: Dictionary = Game.custom_tracks[_slot]
		_pieces = (t.get("pieces", []) as Array).duplicate()
		_room_theme = t.get("room", "bedroom")
	else:
		_slot = -1
		_pieces = ["straight", "right", "loop", "right"]   # a little starter track
	_build_scene()
	_build_ui()
	if not handoff.is_empty():
		_name_edit.text = String(handoff.get("name", "My Track"))
	elif _slot >= 0:
		_name_edit.text = Game.custom_tracks[_slot].get("name", "My Track")
	else:
		_name_edit.text = NAMES[randi() % NAMES.size()]
	_rebuild()


func _process(delta: float) -> void:
	_time += delta
	if Input.is_key_pressed(KEY_Q):
		_cam_angle -= delta * 1.2
	elif Input.is_key_pressed(KEY_E):
		_cam_angle += delta * 1.2
	else:
		_cam_angle += delta * 0.08
	var dist := _fit * _cam_zoom
	var goal := _center + Vector3(sin(_cam_angle) * dist, dist * 0.75, cos(_cam_angle) * dist)
	_cam.position = _cam.position.lerp(goal, minf(1.0, delta * 3.0))
	_cam.look_at(_center, Vector3.UP)
	# The preview car drives around the track.
	if _track and _track.count > 0:
		_car_s = fposmod(_car_s + delta * 32.0, _track.length)
		var f := _track.sample(_car_s)
		_car.global_transform = Transform3D(f.basis, f.origin)
		_car.animate(32.0, 0.0, delta)
	if _cursor:
		_cursor.scale = Vector3.ONE * (1.0 + sin(_time * 5.0) * 0.12)
	if _highlight:
		var m := _highlight.material_override as StandardMaterial3D
		m.emission_energy_multiplier = 1.2 + sin(_time * 6.0) * 0.6


func _unhandled_input(event: InputEvent) -> void:
	# Tap the track to pick a piece; drag (mouse or one finger) to turn the view.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.position
			_dragging = false
		elif not _dragging:
			_pick_at(event.position)
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if _dragging or event.position.distance_to(_press_at) > 14.0:
			_dragging = true
			_cam_angle -= event.relative.x * 0.008
		return
	if event is InputEventMagnifyGesture:   # pinch to zoom on phones and tablets
		_cam_zoom = clampf(_cam_zoom / event.factor, 0.4, 1.6)
		return
	if event is InputEventKey and event.pressed and not event.echo and not _name_edit.has_focus():
		if _key_shortcut(event as InputEventKey):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom = clampf(_cam_zoom * 0.9, 0.4, 1.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom = clampf(_cam_zoom * 1.1, 0.4, 1.6)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		_cam_angle -= event.relative.x * 0.008
	elif event.is_action_pressed("ui_cancel"):
		_back()


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

func _advanced() -> bool:
	return Game.builder_advanced


## Remembers the track before a change, so Undo can bring it back.
func _remember() -> void:
	_undo_stack.append([_pieces.duplicate(), _sel])
	if _undo_stack.size() > HISTORY:
		_undo_stack.pop_front()
	_redo_stack.clear()


## A palette button: add a piece (or swap the picked one, in Replace mode).
func _palette(id: String) -> void:
	if _replacing and _sel >= 0:
		_remember()
		_pieces[_sel] = id
		_replacing = false
		Sfx.play("select")
		_rebuild()
		return
	if _pieces.size() >= MAX_PIECES:
		_say("That's the biggest track allowed! (%d pieces)" % MAX_PIECES, Color(1.0, 0.7, 0.3))
		Sfx.play("back")
		return
	_remember()
	if _sel >= 0:
		_sel += 1
		_pieces.insert(_sel, id)       # in after the picked piece, and pick the new one
	else:
		_pieces.append(id)
	Sfx.play("click", randf_range(0.95, 1.15))
	_disarm_clear()
	_rebuild()


func _select(i: int) -> void:
	_sel = i if i >= 0 and i < _pieces.size() else -1
	_replacing = false
	if _sel >= 0:
		Sfx.play("click", 1.2)
		_say("New pieces go after #%d now (the yellow arrow). Tap Done to build on the end again." % (_sel + 1), Color(1.0, 0.95, 0.5))
	_refresh_selection()


func _move(d: int) -> void:
	var j := _sel + d
	if _sel < 0 or j < 0 or j >= _pieces.size():
		Sfx.play("back")
		return
	_remember()
	var t = _pieces[_sel]
	_pieces[_sel] = _pieces[j]
	_pieces[j] = t
	_sel = j
	Sfx.play("click", 1.0 + d * 0.1)
	_rebuild()


## Drag and drop in the chip row (Advanced): put piece `from` at `to`.
func _move_to(from: int, to: int) -> void:
	if from == to or from < 0 or from >= _pieces.size():
		return
	_remember()
	var id = _pieces[from]
	_pieces.remove_at(from)
	to = clampi(to if to < from else to - 1, 0, _pieces.size())
	_pieces.insert(to, id)
	_sel = to
	Sfx.play("select")
	_rebuild()


func _delete_selected() -> void:
	if _sel < 0:
		return
	_remember()
	_pieces.remove_at(_sel)
	_sel = mini(_sel, _pieces.size() - 1)   # pick the next one, so you can keep deleting
	Sfx.play("crash", 1.5, -12.0)
	_rebuild()


func _flip_selected() -> void:
	if _sel < 0 or not Track.FLIPPED.has(String(_pieces[_sel])):
		return
	_remember()
	_pieces[_sel] = Track.FLIPPED[String(_pieces[_sel])]
	Sfx.play("select")
	_rebuild()


func _copy_selected() -> void:
	if _sel < 0 or _pieces.size() >= MAX_PIECES:
		return
	_remember()
	_pieces.insert(_sel + 1, _pieces[_sel])
	_sel += 1
	Sfx.play("select")
	_rebuild()


func _toggle_replace() -> void:
	_replacing = not _replacing and _sel >= 0
	_refresh_selection()


func _undo() -> void:
	if _undo_stack.is_empty():
		Sfx.play("back")
		return
	_redo_stack.append([_pieces.duplicate(), _sel])
	var snap: Array = _undo_stack.pop_back()
	_pieces = snap[0]
	_sel = mini(int(snap[1]), _pieces.size() - 1)
	Sfx.play("back")
	_disarm_clear()
	_rebuild()


func _redo() -> void:
	if _redo_stack.is_empty():
		return
	_undo_stack.append([_pieces.duplicate(), _sel])
	var snap: Array = _redo_stack.pop_back()
	_pieces = snap[0]
	_sel = mini(int(snap[1]), _pieces.size() - 1)
	Sfx.play("select")
	_rebuild()


func _clear() -> void:
	if not _clear_armed:
		_clear_armed = true
		_clear_button.text = "Sure? Tap again"
		return
	_remember()
	_pieces.clear()
	_sel = -1
	_disarm_clear()
	Sfx.play("crash", 1.3, -10.0)
	_rebuild()


func _disarm_clear() -> void:
	_clear_armed = false
	_clear_button.text = "Clear"


func _toggle_mode() -> void:
	Game.builder_advanced = not Game.builder_advanced
	Game.save_settings()
	_replacing = false
	_fill_palette()
	_refresh_selection()
	_say("Advanced mode: all the pieces, drag chips to move them, and more tools!" if _advanced() \
		else "Easy mode: click the track where you want to build, then tap a piece to add it there.", Color(0.7, 0.9, 1.0))


## Keyboard shortcuts (Advanced mode, plus Delete and Ctrl+Z everywhere).
func _key_shortcut(k: InputEventKey) -> bool:
	if k.ctrl_pressed and k.keycode == KEY_Z:
		_undo()
		return true
	if k.ctrl_pressed and k.keycode == KEY_Y:
		_redo()
		return true
	if k.keycode == KEY_DELETE or k.keycode == KEY_BACKSPACE:
		_delete_selected()
		return true
	if not _advanced():
		return false
	match k.keycode:
		KEY_BRACKETLEFT, KEY_COMMA:
			_select(maxi(0, _sel - 1) if _sel >= 0 else _pieces.size() - 1)
			return true
		KEY_BRACKETRIGHT, KEY_PERIOD:
			_select(mini(_pieces.size() - 1, _sel + 1))
			return true
		KEY_F:
			_flip_selected()
			return true
		KEY_D:
			_copy_selected()
			return true
	if k.ctrl_pressed and k.keycode == KEY_LEFT:
		_move(-1)
		return true
	if k.ctrl_pressed and k.keycode == KEY_RIGHT:
		_move(1)
		return true
	return false


## Clicking the track in 3D picks the piece under the mouse.
func _pick_at(mouse: Vector2) -> void:
	var best := -1
	var best_d := 42.0   # pixels
	for i in _pieces.size():
		for p in _track.piece_points(i):
			if _cam.is_position_behind(p):
				continue
			var d := _cam.unproject_position(p).distance_to(mouse)
			if d < best_d:
				best_d = d
				best = i
	_select(best)


## Rebuilds the 3D preview from the piece list.
func _rebuild() -> void:
	if _track:
		_track.queue_free()
	_track = Track.new()
	_track.custom = true
	_track.custom_pieces = _pieces.duplicate()
	add_child(_track)
	_track.build()
	var r := _track.get_aabb_xz()
	_center = Vector3(r.get_center().x, 0.0, r.get_center().y)
	_fit = maxf(r.size.x, r.size.y) * 0.85 + 30.0
	_floor.position = _center
	(_floor.mesh as PlaneMesh).size = r.size + Vector2(160, 160)
	_count_label.text = "%d / %d pieces" % [_pieces.size(), MAX_PIECES]
	_fill_strip()
	_refresh_selection()
	var clashes := _track.count_clashes()
	if _pieces.is_empty():
		_say("Tap a piece to start building!", Color(1, 1, 1))
	elif clashes > 0:
		_say("Uh-oh! The track runs into itself. Try Undo, or move a piece.", Color(1.0, 0.75, 0.3))
	else:
		_say("Looking great! Keep building, or tap Race It!", Color(0.6, 1.0, 0.65))


## Shows which piece is picked: the glowing piece on the track, the chip,
## the tools panel and where the next piece will go.
func _refresh_selection() -> void:
	if _sel >= _pieces.size():
		_sel = _pieces.size() - 1
	for c in _strip.get_children():
		if c is Chip:
			(c as Chip).set_picked((c as Chip).index == _sel)
			if (c as Chip).index == _sel:
				_strip_scroll.ensure_control_visible.call_deferred(c)
	_tools.visible = _sel >= 0
	_redo_button.visible = _advanced()
	if _sel >= 0:
		var id := String(_pieces[_sel])
		_tools_title.text = "#%d  %s" % [_sel + 1, Track.piece_info(id).get("name", id)]
		_tool_buttons["left"].disabled = _sel == 0
		_tool_buttons["right"].disabled = _sel == _pieces.size() - 1
		for k in ["flip", "copy", "replace"]:
			_tool_buttons[k].visible = _advanced()
		_tool_buttons["flip"].disabled = not Track.FLIPPED.has(id)
		_tool_buttons["copy"].disabled = _pieces.size() >= MAX_PIECES
		_tool_buttons["replace"].text = "Pick a new piece!" if _replacing else "Replace"
	if _replacing:
		_palette_title.text = "Tap the new piece for #%d:" % (_sel + 1)
	else:
		_palette_title.text = ("Add after #%d:" % (_sel + 1)) if _sel >= 0 else "Add to the end:"
	_place_insert_mark()
	_place_highlight()
	_place_cursor()


func _place_highlight() -> void:
	if _highlight:
		_highlight.queue_free()
		_highlight = null
	if _sel < 0:
		return
	var pts := _track.piece_points(_sel)
	var ups := _track.piece_ups(_sel)
	if pts.size() < 2:
		return
	# A glowing ribbon just above the road on the picked piece.
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for k in pts.size():
		var fwd := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var side := fwd.cross(ups[k]).normalized() * 5.2
		var lift := ups[k] * 0.45
		im.surface_add_vertex(pts[k] + lift - side)
		im.surface_add_vertex(pts[k] + lift + side)
	im.surface_end()
	_highlight = MeshInstance3D.new()
	_highlight.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.4, 1.0, 1.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 1.0)
	_highlight.material_override = mat
	add_child(_highlight)


## A bouncing arrow where the next piece will go.
func _place_cursor() -> void:
	if _cursor:
		_cursor.queue_free()
	_cursor = Node3D.new()
	add_child(_cursor)
	var end := _track.builder_end
	if _sel >= 0:
		end = _track.piece_end(_sel)
	_cursor.global_transform = Transform3D(end.basis, end.origin + end.basis.y * 3.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.2)
	mat.emission_energy_multiplier = 1.5
	mat.no_depth_test = true          # always visible, even behind a loop
	mat.render_priority = 10
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 1.6
	cm.height = 3.0
	cone.mesh = cm
	cone.material_override = mat
	cone.rotation.x = -PI * 0.5
	_cursor.add_child(cone)
	var label := Label3D.new()
	label.text = "NEW PIECES GO HERE"
	label.font_size = 64
	label.pixel_size = 0.04
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 3.5, 0)
	label.modulate = Color(1.0, 0.95, 0.4)
	label.no_depth_test = true
	label.render_priority = 11
	_cursor.add_child(label)


func _cycle_room() -> void:
	var i := 0
	for k in Game.ROOM_THEMES.size():
		if Game.ROOM_THEMES[k][0] == _room_theme:
			i = k
	_room_theme = Game.ROOM_THEMES[(i + 1) % Game.ROOM_THEMES.size()][0]
	_room_button.text = "Room: " + Game.room_name(_room_theme).trim_prefix("The ")
	_apply_floor()
	Sfx.play("click")


func _apply_floor() -> void:
	var r := Room.create(_room_theme)
	r._configure()
	var img := r._floor_image()
	var tile := r.floor_tile_size
	r.free()
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_scale = Vector3(30.0, 30.0, 1.0) * (24.0 / tile)
	m.roughness = 0.7
	_floor.material_override = m


# ---------------------------------------------------------------------------
# Saving and racing
# ---------------------------------------------------------------------------

func _save() -> bool:
	if _pieces.is_empty():
		_say("Add some pieces first!", Color(1.0, 0.7, 0.3))
		return false
	var data := {"name": _clean_name(), "room": _room_theme, "pieces": _pieces.duplicate()}
	if _slot >= 0 and Game.custom_tracks[_slot].has("by"):
		data["by"] = Game.custom_tracks[_slot]["by"]   # still the friend's track you got
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
	if not _save():
		return
	Sfx.play("go")
	Game.end_grand_prix()
	Game.selected_track = Track.TRACKS.size() + _slot
	Game.skip_track_select = true
	Game.goto_garage()


func _to_build_anywhere() -> void:
	Game.builder_free = true
	Game.save_settings()
	var by := ""
	if _slot >= 0 and _slot < Game.custom_tracks.size():
		by = String(Game.custom_tracks[_slot].get("by", ""))
	Game.builder_handoff = {"name": _clean_name(), "room": _room_theme, "pieces": _pieces.duplicate(), "by": by}
	Game.editing_slot = _slot
	Game.goto("res://scenes/free_builder.tscn")


func _back() -> void:
	Sfx.play("back")
	Game.goto_track_select()


func _clean_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n.substr(0, 24) if n != "" else "My Track"


func _say(text: String, col: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", col)


# ---------------------------------------------------------------------------
# Scene and UI
# ---------------------------------------------------------------------------

func _build_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.75, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.97, 0.92)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.0
	add_child(sun)
	Game.apply_quality(env, sun)
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	_floor = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	_floor.mesh = pm
	add_child(_floor)
	_apply_floor()
	_car = ToyCarModel.new().setup(CarData.get_car(Game.selected_car), true, Game.custom_for(CarData.get_car(Game.selected_car)["id"]))
	add_child(_car)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 1200.0
	_cam.position = Vector3(0, 120, 120)
	add_child(_cam)
	_cam.current = true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.ui_theme
	layer.add_child(root)

	# --- top bar: title, name, room ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	RaceHud.pin(top, Vector2(0, 0), Vector2(16, 10), Vector2(1248, 64))
	root.add_child(top)
	top.add_child(RaceHud.make_label("TRACK BUILDER", 34, Color(1.0, 0.85, 0.2), 12))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(220, 52)
	_name_edit.max_length = 24
	_name_edit.placeholder_text = "Name your track"
	_name_edit.add_theme_font_size_override("font_size", 26)
	top.add_child(_name_edit)
	_room_button = _button(top, "Room: " + Game.room_name(_room_theme).trim_prefix("The "), _cycle_room)
	_room_button.add_theme_font_size_override("font_size", 20)
	_room_button.custom_minimum_size = Vector2(220, 52)
	_count_label = RaceHud.make_label("", 20, Color.WHITE, 8)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	RaceHud.pin(_count_label, Vector2(1, 1), Vector2(-212, -218), Vector2(200, 32))
	root.add_child(_count_label)

	_mode_button = _button(root, "", _toggle_mode)
	_mode_button.add_theme_font_size_override("font_size", 18)
	_mode_button.tooltip_text = "Easy: big simple pieces.  Advanced: every piece and more tools."
	RaceHud.pin(_mode_button, Vector2(1, 0), Vector2(-232, 14), Vector2(218, 52))
	_mode_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# Build Anywhere: drag pieces around the floor like a real toy track set.
	var anywhere := _button(top, "Build Anywhere!", _to_build_anywhere)
	anywhere.add_theme_font_size_override("font_size", 20)
	anywhere.add_theme_color_override("font_color", Color(0.6, 1.0, 1.0))
	anywhere.tooltip_text = "Drag pieces anywhere on the floor and snap them together"
	anywhere.custom_minimum_size = Vector2(0, 52)
	_ui_root = root

	# --- left: piece palette ---
	_palette_panel = PanelContainer.new()
	RaceHud.pin(_palette_panel, Vector2(0, 0), Vector2(12, 84), Vector2(352, 430))
	root.add_child(_palette_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_palette_panel.add_child(box)
	_palette_title = RaceHud.make_label("", 22, Color(1.0, 0.95, 0.6), 8)
	box.add_child(_palette_title)
	_palette_grid = GridContainer.new()
	_palette_grid.columns = 2
	_palette_grid.add_theme_constant_override("h_separation", 6)
	_palette_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_palette_grid)
	_fill_palette()

	# --- right: tools for the picked piece ---
	_tools = PanelContainer.new()
	RaceHud.pin(_tools, Vector2(1, 0), Vector2(-282, 110), Vector2(270, 300))
	_tools.grow_horizontal = Control.GROW_DIRECTION_BEGIN   # if it needs more room, grow left, not off-screen
	root.add_child(_tools)
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", 6)
	_tools.add_child(tbox)
	_tools_title = RaceHud.make_label("", 24, Color(0.5, 1.0, 1.0), 8)
	_tools_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tbox.add_child(_tools_title)
	var moves := HBoxContainer.new()
	moves.add_theme_constant_override("separation", 6)
	tbox.add_child(moves)
	_tool_buttons["left"] = _button(moves, "< Move", func(): _move(-1))
	_tool_buttons["right"] = _button(moves, "Move >", func(): _move(1))
	for k in ["left", "right"]:
		_tool_buttons[k].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tool_buttons["delete"] = _button(tbox, "Delete", _delete_selected)
	_tool_buttons["delete"].modulate = Color(1.0, 0.75, 0.7)
	_tool_buttons["replace"] = _button(tbox, "Replace", _toggle_replace)
	_tool_buttons["flip"] = _button(tbox, "Flip Left/Right", _flip_selected)
	_tool_buttons["copy"] = _button(tbox, "Copy", _copy_selected)
	_tool_buttons["done"] = _button(tbox, "Done", func(): _select(-1))
	for b in _tool_buttons.values():
		(b as Button).add_theme_font_size_override("font_size", 18)
		(b as Button).custom_minimum_size = Vector2(0, 44)

	# --- the piece chips, in track order ---
	_strip_scroll = ScrollContainer.new()
	_strip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	RaceHud.pin(_strip_scroll, Vector2(0, 1), Vector2(12, -178), Vector2(1256, 86))
	root.add_child(_strip_scroll)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 6)
	_strip_scroll.add_child(_strip)

	# --- status line ---
	_status = RaceHud.make_label("", 22, Color.WHITE, 10)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RaceHud.pin(_status, Vector2(0.5, 1), Vector2(-280, -224), Vector2(600, 44))
	root.add_child(_status)
	_hint = RaceHud.make_label("Tap the track where you want to add pieces.   Drag to turn the view   Pinch or wheel: zoom", 16, Color(1, 1, 1, 0.8), 6)
	RaceHud.pin(_hint, Vector2(1, 0), Vector2(-830, 74), Vector2(810, 24))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_hint)

	# --- bottom bar ---
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 8)
	RaceHud.pin(bottom, Vector2(0.5, 1), Vector2(-500, -86), Vector2(1000, 76))
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(bottom)
	_button(bottom, "Back", _back)
	_button(bottom, "Undo", _undo)
	_redo_button = _button(bottom, "Redo", _redo)
	_clear_button = _button(bottom, "Clear", _clear)
	_button(bottom, "Save", func(): _save())
	var race := _button(bottom, "Race It!", _race_it)
	race.add_theme_font_size_override("font_size", 36)
	# Zoom buttons (handy on phones), in the bottom bar so nothing can cover them.
	for z in [["-", 1.15], ["+", 0.87]]:
		var factor: float = z[1]
		var zb := _button(bottom, z[0], func(): _cam_zoom = clampf(_cam_zoom * factor, 0.4, 1.6))
		zb.custom_minimum_size = Vector2(46, 0)
		zb.add_theme_font_size_override("font_size", 24)


## The piece buttons: 8 big ones in Easy mode, all of them in Advanced.
func _fill_palette() -> void:
	_mode_button.text = "Advanced Mode" if _advanced() else "Easy Mode"
	for c in _palette_grid.get_children():
		_palette_grid.remove_child(c)
		c.queue_free()
	var big := not _advanced()
	for p in Track.PIECES:
		var id: String = p["id"]
		if big and not EASY_PIECES.has(id):
			continue
		var b := _button(_palette_grid, p["name"], func(): _palette(id))
		b.custom_minimum_size = Vector2(160, 80) if big else Vector2(160, 46)
		b.add_theme_font_size_override("font_size", 26 if big else 19)
		_style_piece_button(b, p["color"], 7)
	_palette_panel.reset_size.call_deferred()   # shrink to fit


func _style_piece_button(b: Button, col: Color, depth: int) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.lightened(0.15) if state == "hover" else (col.darkened(0.15) if state == "pressed" else col)
		sb.border_color = Color.WHITE if state == "focus" else col.darkened(0.35)
		sb.set_border_width_all(3)
		sb.border_width_bottom = depth
		sb.set_corner_radius_all(14)
		if state == "focus":
			sb.draw_center = false
		b.add_theme_stylebox_override(state, sb)


## One chip per piece, plus Start and the automatic road home at the ends.
func _fill_strip() -> void:
	for c in _strip.get_children():
		_strip.remove_child(c)
		if c != _insert_mark:
			c.queue_free()
	_strip.add_child(_end_chip("START"))
	for i in _pieces.size():
		var id := String(_pieces[i])
		var chip := Chip.new()
		chip.editor = self
		chip.index = i
		chip.text = "%d\n%s" % [i + 1, SHORT.get(id, id)]
		chip.custom_minimum_size = Vector2(84, 70)
		chip.add_theme_font_size_override("font_size", 15)
		chip.color = Track.piece_info(id).get("color", Color.GRAY)
		chip.pressed.connect(func(): _select(-1 if _sel == chip.index else chip.index))
		_strip.add_child(chip)
		chip.set_picked(false)
	_strip.add_child(_end_chip("back to\nSTART"))


## A "+" in the chip row where new pieces will go.
func _place_insert_mark() -> void:
	if _insert_mark == null or not is_instance_valid(_insert_mark):
		_insert_mark = RaceHud.make_label("+", 40, Color(1.0, 0.95, 0.3), 10)
		_insert_mark.custom_minimum_size = Vector2(30, 70)
		_insert_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_insert_mark.tooltip_text = "New pieces go here"
	if _insert_mark.get_parent() != _strip:
		if _insert_mark.get_parent():
			_insert_mark.get_parent().remove_child(_insert_mark)
		_strip.add_child(_insert_mark)
	# After the picked chip, or just before "back to START".
	var at := _strip.get_child_count() - 2
	for c in _strip.get_children():
		if c is Chip and (c as Chip).index == _sel:
			at = c.get_index() + 1
	_strip.move_child(_insert_mark, clampi(at, 0, _strip.get_child_count() - 1))


func _end_chip(text: String) -> Label:
	var l := RaceHud.make_label(text, 15, Color(1, 1, 1, 0.75), 6)
	l.custom_minimum_size = Vector2(78, 70)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b


## A piece in the chip row. Tap to pick it; in Advanced mode drag it to move it.
class Chip extends Button:
	var editor
	var index := 0
	var color := Color.GRAY

	func set_picked(on: bool) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color if not on else color.lightened(0.2)
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(5 if on else 2)
		sb.border_width_bottom = 8 if on else 5
		sb.border_color = Color(0.5, 1.0, 1.0) if on else color.darkened(0.4)
		for state in ["normal", "hover", "pressed"]:
			add_theme_stylebox_override(state, sb)
		var fsb := sb.duplicate() as StyleBoxFlat
		fsb.border_color = Color.WHITE
		add_theme_stylebox_override("focus", fsb)
		scale = Vector2(1.08, 1.08) if on else Vector2.ONE
		pivot_offset = custom_minimum_size * 0.5

	func _get_drag_data(_at: Vector2) -> Variant:
		if not editor._advanced():
			return null
		var ghost := Button.new()
		ghost.text = text
		ghost.custom_minimum_size = custom_minimum_size
		ghost.modulate = Color(1, 1, 1, 0.75)
		set_drag_preview(ghost)
		return {"chip": index}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("chip")

	func _drop_data(at: Vector2, data: Variant) -> void:
		# Drop on the right half of a chip = after it.
		var to := index + (1 if at.x > size.x * 0.5 else 0)
		editor._move_to(int(data["chip"]), to)
