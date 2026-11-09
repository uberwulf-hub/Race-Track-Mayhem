extends Node3D
## The garage: spin through the toy cars on a turntable, give your car a
## paint job, stickers and wheels, and pick it. In 2-player mode, player 1
## picks first, then player 2.

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
var _lock_label: Label
var _custom_rows: Dictionary = {}  # slot -> Label
var _header: Label
var _stats_panel: Control
var _design_panel: Control
var _design_button: Button
var _nick_edit: LineEdit
var _design_sticker: Label
var _at_slider: HSlider
var _size_slider: HSlider
var _swatches: Dictionary = {}     # "color"/"accent" -> Array[Button]
var _refreshing := false
var _bottom: Control

## Colours for the Car Designer ("" = the car's own).
const DESIGN_COLORS := ["", "e8241c", "ff7a1a", "ffd21f", "7ed321", "1fae4b", "1fc8d8", "2f6fe8",
	"7a3fe0", "ff5fb4", "ffffff", "8a8f99", "1e1e26", "8b5a2b"]


func _ready() -> void:
	Sfx.play_music("garage")
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
	if _design_panel and _design_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			Sfx.play("back")
			_close_designer()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("steer_left"):
		_change(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("steer_right"):
		_change(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		Sfx.play("back")
		if _design_panel.visible:
			_close_designer()
		else:
			_go_back()


func _change(d: int) -> void:
	_index = wrapi(_index + d, 0, CarData.count())
	Sfx.play("click", 1.0 + d * 0.1)
	_show_car(true)


func _show_car(animate: bool) -> void:
	var car := CarData.get_car(_index)
	var unlocked := CarData.is_available(_index)
	if _car_model:
		_car_model.queue_free()
	_car_model = ToyCarModel.new().setup(car, true, Game.custom_for(car["id"]) if unlocked else {})
	if not unlocked:
		_silhouette(_car_model)
	_lock_label.visible = not unlocked
	if not unlocked:
		_lock_label.text = "LOCKED!\n" + Unlocks.requirement_text(Unlocks.get_item(car.get("unlock", "")))
	_race_button.disabled = not unlocked
	_design_button.disabled = not unlocked
	for slot in _custom_rows:
		var l: Label = _custom_rows[slot]
		l.text = Unlocks.get_item(Game.custom_for(car["id"])[slot]).get("name", "") if unlocked else "?"
	_car_model.scale = Vector3.ONE * 3.0
	_car_holder.add_child(_car_model)
	if animate:
		_bounce = 1.0
	var nick := CarData.nickname(Game.custom_for(car["id"]))
	_name_label.text = ("???" if not unlocked else (nick if nick != "" else car["name"]))
	var own := ToyCarModel._html_color(Game.custom_for(car["id"])["color"])
	_name_label.add_theme_color_override("font_color", (own if own.a > 0.0 and unlocked else car["body"] as Color).lightened(0.25))
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
	if not CarData.is_available(_index):
		return
	Game.selected_car = _index
	Game.save_settings()
	Sfx.play("go")
	if Game.skip_track_select and not Game.gp_active:
		Game.skip_track_select = false
		Game.goto_race()
		return
	if Game.gp_active:
		Game.selected_track = 0
		Game.goto_race()
	else:
		Game.goto_track_select()


func _go_back() -> void:
	Game.skip_track_select = false
	Game.end_grand_prix()
	Game.goto_menu()


## Shows a locked car as a dark mystery shape.
func _silhouette(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ToyCarModel.plastic(Color(0.08, 0.06, 0.14), 0.6)
		elif c is Label3D:
			c.visible = false
		_silhouette(c)


## Cycles the paint / sticker / wheels for the shown car through what's unlocked.
func _cycle(slot: String, d: int) -> void:
	var car := CarData.get_car(_index)
	if not CarData.is_available(_index):
		return
	var options: Array = []
	for it in Unlocks.of_kind(slot):
		if Game.is_unlocked(it["id"]):
			options.append(it["id"])
	var current: String = Game.custom_for(car["id"])[slot]
	var i := wrapi(options.find(current) + d, 0, options.size())
	Game.set_custom(car["id"], slot, options[i])
	if slot == "paint":
		Game.set_custom(car["id"], "color", "")   # a paint job replaces your own colour
	Sfx.play("click", 1.0 + d * 0.1)
	_show_car(true)
	if _design_panel.visible:
		_lock_label.visible = false
		_sync_designer()


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
	Game.apply_quality(env, key)
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
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

	var header_text := "PICK YOUR CAR!"
	if Game.gp_active:
		header_text = "GRAND PRIX: PICK YOUR CAR!"
	elif Game.story_active:
		header_text = "BOSS RACE vs %s!" % String(Story.chapter(Game.story_chapter)["boss"]).to_upper()
	elif Game.skip_track_select and Game.selected_track == Game.WEEKLY_TRACK:
		header_text = "WEEKLY CHALLENGE: PICK YOUR CAR!"
	var header := RaceHud.make_label(header_text, 56, Color(1.0, 0.85, 0.2), 16)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RaceHud.pin(header, Vector2(0.5, 0), Vector2(-500, 16), Vector2(1000, 80))
	root.add_child(header)

	var panel := PanelContainer.new()
	RaceHud.pin(panel, Vector2(1, 0.5), Vector2(-560, -282), Vector2(540, 520))
	root.add_child(panel)
	_stats_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_theme_constant_override("separation", 6)
	_name_label = RaceHud.make_label("", 44, Color.WHITE, 14)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name_label)
	_blurb_label = RaceHud.make_label("", 19, Color(0.95, 0.95, 1.0), 6)
	_blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blurb_label.custom_minimum_size = Vector2(480, 50)
	box.add_child(_blurb_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for key in ["speed", "accel", "handling", "weight"]:
		grid.add_child(RaceHud.make_label(CarData.STAT_LABELS[key], 22, Color.WHITE, 8))
		var pips_box := HBoxContainer.new()
		pips_box.add_theme_constant_override("separation", 6)
		var pips: Array = []
		for i in 5:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(36, 20)
			pips_box.add_child(pip)
			pips.append(pip)
		grid.add_child(pips_box)
		_stat_rows[key] = pips

	# Paint job, stickers and wheels
	var custom := GridContainer.new()
	custom.columns = 4
	custom.add_theme_constant_override("h_separation", 10)
	custom.add_theme_constant_override("v_separation", 4)
	box.add_child(custom)
	for slot in ["paint", "sticker", "wheels"]:
		custom.add_child(RaceHud.make_label({"paint": "Paint", "sticker": "Stickers", "wheels": "Wheels"}[slot], 22, Color(1.0, 0.9, 0.5), 8))
		var minus := _make_button(custom, "<", func(): _cycle(slot, -1))
		var value := RaceHud.make_label("", 22, Color.WHITE, 8)
		value.custom_minimum_size = Vector2(190, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		custom.add_child(value)
		var plus := _make_button(custom, ">", func(): _cycle(slot, 1))
		for b: Button in [minus, plus]:
			b.add_theme_font_size_override("font_size", 20)
			b.custom_minimum_size = Vector2(44, 34)
		_custom_rows[slot] = value
	var hint_row := HBoxContainer.new()
	hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_row.add_theme_constant_override("separation", 14)
	box.add_child(hint_row)
	_design_button = _make_button(hint_row, "Car Designer", _open_designer)
	_design_button.add_theme_font_size_override("font_size", 22)
	_design_button.add_theme_color_override("font_color", Color(0.75, 1.0, 1.0))
	var hint := RaceHud.make_label("★ %d - win races\nto unlock more!" % Game.stars, 17, Color(1.0, 0.9, 0.3), 6)
	hint_row.add_child(hint)
	_design_panel = _build_designer(root)

	_lock_label = RaceHud.make_label("", 34, Color(1.0, 0.75, 0.3), 12)
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RaceHud.pin(_lock_label, Vector2(0, 0.5), Vector2(40, 140), Vector2(560, 100))
	root.add_child(_lock_label)

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
	_bottom = bottom
	_make_button(bottom, "Back", _go_back)
	_make_button(bottom, "  <  ", func(): _change(-1))
	var go_text := "Pick a Track  >"
	if Game.gp_active:
		go_text = "Start the Cup!"
	elif Game.skip_track_select:
		go_text = "RACE!"
	_race_button = _make_button(bottom, go_text, _choose)
	_race_button.add_theme_font_size_override("font_size", 38)
	_make_button(bottom, "  >  ", func(): _change(1))
	_race_button.grab_focus.call_deferred()


func _make_button(parent: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL if text.strip_edges().length() > 1 else Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	parent.add_child(b)
	return b


# ---------------------------------------------------------------------------
# Car Designer: your own colours, sticker spot and size, and a name.
# ---------------------------------------------------------------------------

func _build_designer(root: Control) -> Control:
	var panel := PanelContainer.new()
	RaceHud.pin(panel, Vector2(1, 0.5), Vector2(-560, -260), Vector2(540, 560))
	panel.visible = false
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := RaceHud.make_label("CAR DESIGNER", 36, Color(0.75, 1.0, 1.0), 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	box.add_child(name_row)
	name_row.add_child(RaceHud.make_label("Name", 22, Color(1.0, 0.9, 0.5), 8))
	_nick_edit = LineEdit.new()
	_nick_edit.max_length = CarData.NICKNAME_LENGTH
	_nick_edit.placeholder_text = "Give your car a name"
	_nick_edit.add_theme_font_size_override("font_size", 24)
	_nick_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nick_edit.text_changed.connect(func(t: String):
		_set_design("nickname", t.strip_edges(), false))
	_nick_edit.text_submitted.connect(func(_t: String): _nick_edit.release_focus())
	name_row.add_child(_nick_edit)

	for slot in ["color", "accent"]:
		box.add_child(RaceHud.make_label("Body colour" if slot == "color" else "Stripes and trim", 22, Color(1.0, 0.9, 0.5), 8))
		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		box.add_child(grid)
		var list: Array = []
		for hex: String in DESIGN_COLORS:
			var b := Button.new()
			b.custom_minimum_size = Vector2(62, 40)
			b.focus_mode = Control.FOCUS_ALL
			b.tooltip_text = "The car's own colour" if hex == "" else ""
			if hex == "":
				b.text = "Auto"
				b.add_theme_font_size_override("font_size", 16)
			b.pressed.connect(func():
				Sfx.play("click")
				_set_design(slot, hex, true))
			grid.add_child(b)
			list.append(b)
		_swatches[slot] = list

	var st_row := HBoxContainer.new()
	st_row.add_theme_constant_override("separation", 10)
	box.add_child(st_row)
	st_row.add_child(RaceHud.make_label("Sticker", 22, Color(1.0, 0.9, 0.5), 8))
	var minus := _make_button(st_row, "<", func(): _cycle("sticker", -1))
	_design_sticker = RaceHud.make_label("", 22, Color.WHITE, 8)
	_design_sticker.custom_minimum_size = Vector2(200, 0)
	_design_sticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st_row.add_child(_design_sticker)
	var plus := _make_button(st_row, ">", func(): _cycle("sticker", 1))
	for b: Button in [minus, plus]:
		b.add_theme_font_size_override("font_size", 20)
		b.custom_minimum_size = Vector2(44, 34)

	_at_slider = _slider(box, "Front", "Back", -1.0, 1.0, "sticker_at")
	_size_slider = _slider(box, "Small", "Big", 0.6, 1.4, "sticker_size")

	var done := _make_button(box, "Done!", _close_designer)
	done.add_theme_font_size_override("font_size", 30)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.custom_minimum_size = Vector2(200, 0)
	return panel


func _slider(box: Container, left: String, right: String, lo: float, hi: float, key: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var l := RaceHud.make_label(left, 20, Color(0.85, 0.9, 1.0), 6)
	l.custom_minimum_size = Vector2(70, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 34)
	s.value_changed.connect(func(v: float): _set_design(key, v, false))
	row.add_child(s)
	row.add_child(RaceHud.make_label(right, 20, Color(0.85, 0.9, 1.0), 6))
	return s


func _open_designer() -> void:
	if not CarData.is_available(_index):
		return
	_stats_panel.visible = false
	_bottom.visible = false
	_design_panel.visible = true
	_lock_label.visible = false
	_sync_designer()
	_nick_edit.grab_focus.call_deferred()


func _close_designer() -> void:
	_nick_edit.release_focus()
	_design_panel.visible = false
	_stats_panel.visible = true
	_bottom.visible = true
	Game.save_settings()
	_show_car(true)
	_race_button.grab_focus.call_deferred()


## Fills the designer's controls from the shown car's saved look.
func _sync_designer() -> void:
	var look := Game.custom_for(CarData.get_car(_index)["id"])
	_refreshing = true
	if _nick_edit.text != look["nickname"]:
		_nick_edit.text = look["nickname"]
	_at_slider.value = look["sticker_at"]
	_size_slider.value = look["sticker_size"]
	_refreshing = false
	var sticker := String(look["sticker"])
	_design_sticker.text = Unlocks.get_item(sticker).get("name", "")
	_at_slider.editable = sticker != "sticker_none"
	_size_slider.editable = sticker != "sticker_none"
	var car := CarData.get_car(_index)
	for slot in _swatches:
		var picked := String(look[slot])
		var buttons: Array = _swatches[slot]
		for i in buttons.size():
			var hex: String = DESIGN_COLORS[i]
			var col: Color = (car["body"] if slot == "color" else car["accent"]) if hex == "" else Color.html(hex)
			var sb := StyleBoxFlat.new()
			sb.bg_color = col
			sb.set_corner_radius_all(10)
			var on := hex == picked
			sb.set_border_width_all(5 if on else 2)
			sb.border_color = Color.WHITE if on else Color(0, 0, 0, 0.5)
			var b: Button = buttons[i]
			for state in ["normal", "hover", "pressed", "focus"]:
				var s2 := sb.duplicate() as StyleBoxFlat
				if state == "hover" or state == "focus":
					s2.border_color = Color(1.0, 0.9, 0.4)
					s2.set_border_width_all(5)
				b.add_theme_stylebox_override(state, s2)
			b.add_theme_color_override("font_color", Color.BLACK if col.get_luminance() > 0.55 else Color.WHITE)


func _set_design(key: String, value: Variant, rebuild_ui: bool) -> void:
	if _refreshing:
		return
	var car := CarData.get_car(_index)
	var c := Game.custom_for(car["id"])
	c[key] = value
	Game.custom[car["id"]] = c   # saved when the designer closes
	if key == "nickname":
		var nick := CarData.nickname(c)
		_name_label.text = nick if nick != "" else car["name"]
		return
	_rebuild_model()
	if rebuild_ui:
		_sync_designer()


## Swaps in a freshly built car without the bounce or resetting anything.
func _rebuild_model() -> void:
	var car := CarData.get_car(_index)
	if _car_model:
		_car_model.queue_free()
	_car_model = ToyCarModel.new().setup(car, true, Game.custom_for(car["id"]))
	_car_model.scale = Vector3.ONE * 3.0
	_car_holder.add_child(_car_model)
