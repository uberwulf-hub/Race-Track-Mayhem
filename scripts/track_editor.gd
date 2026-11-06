extends Node3D
## The Track Builder: snap pieces together to make your own track!
## Press a piece button to add it to the end of the track. The road back to
## the start line is drawn for you automatically, so every track works.
## A little car drives your track while you build it.

const MAX_PIECES := 40
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


func _ready() -> void:
	Sfx.play_music("garage")
	_slot = Game.editing_slot
	if _slot >= 0 and _slot < Game.custom_tracks.size():
		var t: Dictionary = Game.custom_tracks[_slot]
		_pieces = (t.get("pieces", []) as Array).duplicate()
		_room_theme = t.get("room", "bedroom")
	else:
		_slot = -1
		_pieces = ["straight", "right", "loop", "right"]   # a little starter track
	_build_scene()
	_build_ui()
	if _slot >= 0:
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


func _unhandled_input(event: InputEvent) -> void:
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

func _add(id: String) -> void:
	if _pieces.size() >= MAX_PIECES:
		_say("That's the biggest track allowed! (%d pieces)" % MAX_PIECES, Color(1.0, 0.7, 0.3))
		Sfx.play("back")
		return
	_pieces.append(id)
	Sfx.play("click", randf_range(0.95, 1.15))
	_disarm_clear()
	_rebuild()


func _undo() -> void:
	if _pieces.is_empty():
		return
	_pieces.pop_back()
	Sfx.play("back")
	_disarm_clear()
	_rebuild()


func _clear() -> void:
	if not _clear_armed:
		_clear_armed = true
		_clear_button.text = "Sure? Tap again"
		return
	_pieces.clear()
	_disarm_clear()
	Sfx.play("crash", 1.3, -10.0)
	_rebuild()


func _disarm_clear() -> void:
	_clear_armed = false
	_clear_button.text = "Clear"


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
	_place_cursor()
	_count_label.text = "%d / %d pieces" % [_pieces.size(), MAX_PIECES]
	var clashes := _track.count_clashes()
	if _pieces.is_empty():
		_say("Tap a piece to start building!", Color(1, 1, 1))
	elif clashes > 0:
		_say("Uh-oh! The track runs into itself. Try Undo, or add more pieces.", Color(1.0, 0.75, 0.3))
	else:
		_say("Looking great! Keep building, or tap Race It!", Color(0.6, 1.0, 0.65))


## A bouncing arrow at the end of your pieces, where the next one will go.
func _place_cursor() -> void:
	if _cursor:
		_cursor.queue_free()
	_cursor = Node3D.new()
	add_child(_cursor)
	var end := _track.builder_end
	_cursor.global_transform = Transform3D(end.basis, end.origin + Vector3.UP * 3.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.2)
	mat.emission_energy_multiplier = 1.5
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
	label.text = "NEXT PIECE"
	label.font_size = 64
	label.pixel_size = 0.04
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 3.5, 0)
	label.modulate = Color(1.0, 0.95, 0.4)
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
	if _slot < 0:
		if Game.custom_tracks.size() >= Game.MAX_CUSTOM_TRACKS:
			_say("You have %d tracks already! Delete one in the track picker." % Game.MAX_CUSTOM_TRACKS, Color(1.0, 0.7, 0.3))
			return false
		Game.custom_tracks.append(data)
		_slot = Game.custom_tracks.size() - 1
		Game.editing_slot = _slot
	else:
		Game.custom_tracks[_slot] = data
	Game.save_settings()
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
	top.add_child(RaceHud.make_label("TRACK BUILDER", 40, Color(1.0, 0.85, 0.2), 12))
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(330, 52)
	_name_edit.max_length = 24
	_name_edit.placeholder_text = "Name your track"
	_name_edit.add_theme_font_size_override("font_size", 26)
	top.add_child(_name_edit)
	_room_button = _button(top, "Room: " + Game.room_name(_room_theme).trim_prefix("The "), _cycle_room)
	_room_button.add_theme_font_size_override("font_size", 22)
	_count_label = RaceHud.make_label("", 22, Color.WHITE, 8)
	top.add_child(_count_label)

	# --- left: piece palette ---
	var panel := PanelContainer.new()
	RaceHud.pin(panel, Vector2(0, 0), Vector2(12, 84), Vector2(352, 520))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(RaceHud.make_label("Tap to add a piece:", 22, Color(1.0, 0.95, 0.6), 8))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for p in Track.PIECES:
		var b := _button(grid, p["name"], Callable())
		var id: String = p["id"]
		b.pressed.connect(func(): _add(id))
		b.custom_minimum_size = Vector2(150, 54)
		b.add_theme_font_size_override("font_size", 20)
		var col: Color = p["color"]
		for state in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = col.lightened(0.15) if state == "hover" else (col.darkened(0.15) if state == "pressed" else col)
			sb.border_color = col.darkened(0.35)
			sb.set_border_width_all(3)
			sb.border_width_bottom = 7
			sb.set_corner_radius_all(14)
			b.add_theme_stylebox_override(state, sb)

	# --- status line ---
	_status = RaceHud.make_label("", 24, Color.WHITE, 10)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RaceHud.pin(_status, Vector2(0.5, 1), Vector2(-260, -150), Vector2(860, 60))
	root.add_child(_status)
	var hint := RaceHud.make_label("Q / E or right-drag to turn the view, mouse wheel to zoom", 16, Color(1, 1, 1, 0.8), 6)
	RaceHud.pin(hint, Vector2(1, 0), Vector2(-520, 80), Vector2(500, 24))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint)

	# --- bottom bar ---
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	RaceHud.pin(bottom, Vector2(0.5, 1), Vector2(-440, -86), Vector2(1000, 76))
	root.add_child(bottom)
	_button(bottom, "Back", _back)
	_button(bottom, "Undo", _undo)
	_clear_button = _button(bottom, "Clear", _clear)
	_button(bottom, "Save", func(): _save())
	var race := _button(bottom, "Race It!", _race_it)
	race.add_theme_font_size_override("font_size", 36)


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b
