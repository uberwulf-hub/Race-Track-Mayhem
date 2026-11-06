extends Node3D
## The garage: spin through the toy cars on a turntable and pick one.

var _index := 0
var _turntable: Node3D
var _car_holder: Node3D
var _car_model: ToyCarModel
var _name_label: Label
var _blurb_label: Label
var _stat_rows: Dictionary = {}   # stat key -> Array[Panel] pips
var _dots: HBoxContainer
var _race_button: Button
var _spin := 0.0
var _bounce := 0.0


func _ready() -> void:
	Sfx.play_music("menu")
	_index = Game.selected_car
	_build_scene()
	_build_ui()
	_show_car(false)


func _process(delta: float) -> void:
	_spin += delta * 0.7
	_turntable.rotation.y = _spin
	_bounce = maxf(0.0, _bounce - delta * 3.0)
	if _car_holder:
		_car_holder.position.y = 1.0 + sin(_bounce * PI) * 1.2
	if _car_model:
		_car_model.animate(4.0, 0.0, delta)


func _input(event: InputEvent) -> void:
	# Left / right always flips through the cars (instead of moving button focus).
	if event.is_action_pressed("ui_left") or event.is_action_pressed("steer_left"):
		_change(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("steer_right"):
		_change(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		Sfx.play("back")
		Game.goto_menu()


func _change(d: int) -> void:
	_index = wrapi(_index + d, 0, CarData.count())
	Sfx.play("click", 1.0 + d * 0.1)
	_show_car(true)


func _show_car(animate: bool) -> void:
	var car := CarData.get_car(_index)
	if _car_model:
		_car_model.queue_free()
	_car_model = ToyCarModel.new().setup(car)
	_car_model.scale = Vector3.ONE * 3.0
	_car_holder.add_child(_car_model)
	if animate:
		_bounce = 1.0
	_name_label.text = car["name"]
	_name_label.add_theme_color_override("font_color", (car["body"] as Color).lightened(0.25))
	_blurb_label.text = car["blurb"]
	for key in _stat_rows:
		var value: int = car["stats"][key]
		var pips: Array = _stat_rows[key]
		for i in pips.size():
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(8)
			sb.bg_color = Color(1.0, 0.8, 0.2) if i < value else Color(1, 1, 1, 0.18)
			(pips[i] as Panel).add_theme_stylebox_override("panel", sb)
	for i in _dots.get_child_count():
		var dot := _dots.get_child(i) as Panel
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.bg_color = CarData.get_car(i)["body"]
		sb.set_border_width_all(4 if i == _index else 0)
		sb.border_color = Color.WHITE
		dot.add_theme_stylebox_override("panel", sb)
		dot.custom_minimum_size = Vector2(30, 30) if i == _index else Vector2(20, 20)


func _choose() -> void:
	Game.selected_car = _index
	Game.save_settings()
	Sfx.play("go")
	Game.goto_track_select()


# ---------------------------------------------------------------------------

func _build_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.15, 0.4)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 1.0)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 30, 0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	add_child(key)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 30, 6)
	spot.rotation_degrees = Vector3(-80, 0, 0)
	spot.spot_range = 60.0
	spot.spot_angle = 28.0
	spot.light_energy = 3.0
	spot.light_color = Color(1.0, 0.95, 0.8)
	add_child(spot)

	# Wooden play table
	var table := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(80, 2, 60)
	table.mesh = tm
	table.material_override = ToyCarModel.plastic(Color(0.75, 0.52, 0.32), 0.6)
	table.position = Vector3(0, -1, 0)
	add_child(table)

	# Back wall with big dots
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(120, 60, 1)
	wall.mesh = wm
	wall.material_override = ToyCarModel.plastic(Color(0.45, 0.35, 0.8), 0.9)
	wall.position = Vector3(0, 20, -22)
	add_child(wall)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 18:
		var dot := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := rng.randf_range(1.0, 2.5)
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.2
		dot.mesh = cm
		dot.material_override = ToyCarModel.plastic(Color.from_hsv(rng.randf(), 0.55, 1.0), 0.6)
		dot.rotation.x = PI * 0.5
		dot.position = Vector3(rng.randf_range(-50, 50), rng.randf_range(2, 40), -21.4)
		add_child(dot)

	# Striped turntable
	_turntable = Node3D.new()
	add_child(_turntable)
	for i in 2:
		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 9.0 - i * 2.5
		dm.bottom_radius = 9.2 - i * 2.5
		dm.height = 1.0
		disc.mesh = dm
		disc.material_override = ToyCarModel.plastic(Color(1.0, 0.5, 0.1) if i == 0 else Color(1.0, 0.85, 0.2), 0.3)
		disc.position = Vector3(0, 0.5 + i * 0.05, 0)
		_turntable.add_child(disc)
	_car_holder = Node3D.new()
	_car_holder.position = Vector3(0, 1.0, 0)
	_turntable.add_child(_car_holder)

	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.position = Vector3(-6.5, 9.5, 22.0)
	add_child(cam)
	cam.look_at(Vector3(-6.5, 2.5, 0), Vector3.UP)
	cam.current = true
	# Shift the car left on screen so the stats fit on the right.
	_turntable.position.x = -11.0


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.ui_theme
	layer.add_child(root)

	var header := RaceHud.make_label("PICK YOUR CAR!", 64, Color(1.0, 0.85, 0.2), 16)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RaceHud.pin(header, Vector2(0.5, 0), Vector2(-500, 16), Vector2(1000, 80))
	root.add_child(header)

	var panel := PanelContainer.new()
	RaceHud.pin(panel, Vector2(1, 0.5), Vector2(-560, -230), Vector2(520, 440))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_name_label = RaceHud.make_label("", 52, Color.WHITE, 14)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name_label)
	_blurb_label = RaceHud.make_label("", 22, Color(0.95, 0.95, 1.0), 6)
	_blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blurb_label.custom_minimum_size = Vector2(460, 64)
	box.add_child(_blurb_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for key in ["speed", "accel", "handling", "weight"]:
		grid.add_child(RaceHud.make_label(CarData.STAT_LABELS[key], 26, Color.WHITE, 8))
		var pips_box := HBoxContainer.new()
		pips_box.add_theme_constant_override("separation", 6)
		var pips: Array = []
		for i in 5:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(38, 26)
			pips_box.add_child(pip)
			pips.append(pip)
		grid.add_child(pips_box)
		_stat_rows[key] = pips

	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 10)
	_dots.custom_minimum_size = Vector2(0, 36)
	box.add_child(_dots)
	for i in CarData.count():
		var d := Panel.new()
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(d)

	# Arrows + buttons along the bottom
	var bottom := HBoxContainer.new()
	RaceHud.pin(bottom, Vector2(0.5, 1), Vector2(-460, -110), Vector2(920, 90))
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 22)
	root.add_child(bottom)
	_make_button(bottom, "Back", func(): Game.goto_menu())
	_make_button(bottom, "  <  ", func(): _change(-1))
	_race_button = _make_button(bottom, "RACE!", _choose)
	_race_button.add_theme_font_size_override("font_size", 46)
	_make_button(bottom, "  >  ", func(): _change(1))
	_race_button.grab_focus.call_deferred()


func _make_button(parent: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL if text == "RACE!" or text == "Back" else Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	parent.add_child(b)
	return b
