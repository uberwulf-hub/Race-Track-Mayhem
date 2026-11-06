extends Node3D
## Title screen. Computer cars race around one of the rooms (picked at
## random) in the background while the camera slowly circles it.

var track: Track
var camera: Camera3D
var _center := Vector3.ZERO
var _angle := 0.0
var _racers: Array[Racer] = []
var _follow_idx := 0
var _follow_timer := 0.0

var _main_box: VBoxContainer
var _options_panel: Control
var _help_panel: Control
var _credits_panel: Control
var _laps_label: Label
var _diff_button: Button
var _title_letters: Array[Label] = []
var _time := 0.0


func _ready() -> void:
	Sfx.play_music("menu")
	track = Track.new()
	track.layout_id = randi() % Track.TRACKS.size()
	add_child(track)
	track.build()
	var room := Room.create(Track.TRACKS[track.layout_id]["room"])
	add_child(room)
	room.build(track)
	var r := track.get_aabb_xz()
	_center = Vector3(r.get_center().x, 0.0, r.get_center().y)

	for i in CarData.count():
		var racer := Racer.new()
		add_child(racer)
		racer.setup(track, CarData.get_car(i), false, "Demo%d" % i)
		racer.laps_to_win = 9999
		racer.rubber_band = randf_range(0.8, 0.95)
		racer.place_on_grid(-4.0 - i * 9.0, -1.5 if i % 2 == 0 else 1.5)
		racer.controls_enabled = true
		_racers.append(racer)

	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = 600.0
	add_child(camera)
	camera.current = true

	_build_ui()


func _process(delta: float) -> void:
	_time += delta
	for i in _racers.size():
		for j in range(i + 1, _racers.size()):
			_racers[i].bump_with(_racers[j])

	# Alternate between a slow orbit of the room and following a car.
	_follow_timer += delta
	if _follow_timer > 16.0:
		_follow_timer = 0.0
		_follow_idx = (_follow_idx + 1) % _racers.size()
	if _follow_timer < 9.0:
		_angle += delta * 0.08
		var pos := _center + Vector3(sin(_angle) * 80.0, 42.0, cos(_angle) * 80.0)
		camera.global_position = camera.global_position.lerp(pos, minf(1.0, delta * 1.5)) if _time > 0.1 else pos
		camera.look_at(_center + Vector3(0, -6.0, 0), Vector3.UP)
	else:
		var car := _racers[_follow_idx]
		var frame := track.sample(car.s)
		var side := frame.basis.x * 9.0 + Vector3.UP * 5.0 - frame.basis.z * 3.0
		var target := car.global_position + Vector3(side.x, absf(side.y) + 2.0, side.z)
		camera.global_position = camera.global_position.lerp(target, minf(1.0, delta * 2.0))
		camera.look_at(car.global_position, Vector3.UP)

	# Bouncy title letters
	for i in _title_letters.size():
		var l := _title_letters[i]
		l.position.y = sin(_time * 3.0 + i * 0.5) * 8.0
		l.rotation = sin(_time * 2.0 + i) * 0.06


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.ui_theme
	layer.add_child(root)

	# Title
	var title := VBoxContainer.new()
	RaceHud.pin(title, Vector2(0.5, 0), Vector2(-600, 30), Vector2(1200, 260))
	title.add_theme_constant_override("separation", -20)
	root.add_child(title)
	title.add_child(_title_row("RACE TRACK", 92, [Color(1.0, 0.35, 0.3), Color(1.0, 0.65, 0.15), Color(1.0, 0.9, 0.2), Color(0.4, 0.9, 0.35), Color(0.35, 0.7, 1.0), Color(0.75, 0.45, 1.0)]))
	title.add_child(_title_row("MAYHEM!", 132, [Color(1.0, 0.55, 0.1)]))

	# Main buttons
	_main_box = VBoxContainer.new()
	RaceHud.pin(_main_box, Vector2(0.5, 0.5), Vector2(-170, -55), Vector2(340, 300))
	_main_box.add_theme_constant_override("separation", 14)
	root.add_child(_main_box)
	var play := _button(_main_box, "PLAY!", func(): Game.goto_garage())
	play.add_theme_font_size_override("font_size", 46)
	_button(_main_box, "Options", func(): _show_panel(_options_panel))
	_button(_main_box, "How to Play", func(): _show_panel(_help_panel))
	if OS.get_name() != "Web":
		_button(_main_box, "Quit", func(): get_tree().quit())
	play.grab_focus.call_deferred()

	var best := Game.best_time_for_current()
	if best > 0.0:
		var rec := RaceHud.make_label("Best time (%d laps): %s" % [Game.laps, Game.format_time(best)], 24, Color(0.8, 1.0, 0.8), 8)
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		RaceHud.pin(rec, Vector2(0.5, 1), Vector2(-300, -44), Vector2(600, 36))
		root.add_child(rec)

	_options_panel = _build_options(root)
	_help_panel = _build_help(root)
	_credits_panel = _build_credits(root)
	var credits_btn := _button(root, "Credits", func(): _show_panel(_credits_panel))
	credits_btn.add_theme_font_size_override("font_size", 20)
	RaceHud.pin(credits_btn, Vector2(0, 1), Vector2(16, -64), Vector2(130, 48))


func _title_row(text: String, size: int, colors: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	var ci := 0
	for ch in text:
		var l := RaceHud.make_label(ch, size, colors[ci % colors.size()], 22)
		l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.25))
		l.pivot_offset = Vector2(size * 0.3, size * 0.6)
		if ch == " ":
			l.custom_minimum_size = Vector2(size * 0.3, 0)
		row.add_child(l)
		if ch != " ":
			ci += 1
			_title_letters.append(l)
	return row


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	b.focus_entered.connect(func(): Sfx.play("click", 1.0, -8.0))
	parent.add_child(b)
	return b


func _panel(root: Control, title_text: String) -> Array:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 200
	center.visible = false
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(560, 0)
	panel.add_child(box)
	var t := RaceHud.make_label(title_text, 48, Color(1.0, 0.85, 0.2), 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	return [center, box]


func _show_panel(panel: Control) -> void:
	_main_box.visible = panel == null
	_options_panel.visible = panel == _options_panel
	_help_panel.visible = panel == _help_panel
	_credits_panel.visible = panel == _credits_panel
	if panel == null:
		(_main_box.get_child(0) as Button).grab_focus()
	else:
		var buttons := panel.find_children("*", "Button", true, false)
		if buttons.size() > 0:
			(buttons[0] as Button).grab_focus()


func _build_options(root: Control) -> Control:
	var parts := _panel(root, "Options")
	var box: VBoxContainer = parts[1]

	var laps_row := HBoxContainer.new()
	laps_row.alignment = BoxContainer.ALIGNMENT_CENTER
	laps_row.add_theme_constant_override("separation", 16)
	box.add_child(laps_row)
	laps_row.add_child(RaceHud.make_label("Laps:", 32))
	_button(laps_row, "-", func(): _change_laps(-1))
	_laps_label = RaceHud.make_label(str(Game.laps), 40, Color(1.0, 0.9, 0.3))
	_laps_label.custom_minimum_size = Vector2(50, 0)
	_laps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	laps_row.add_child(_laps_label)
	_button(laps_row, "+", func(): _change_laps(1))

	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 16)
	box.add_child(diff_row)
	diff_row.add_child(RaceHud.make_label("Other cars:", 32))
	_diff_button = _button(diff_row, Game.DIFFICULTY_NAMES[Game.difficulty], func():
		Game.difficulty = (Game.difficulty + 1) % 3
		_diff_button.text = Game.DIFFICULTY_NAMES[Game.difficulty]
		Game.save_settings())
	_diff_button.custom_minimum_size = Vector2(200, 0)

	_slider_row(box, "Volume:", Game.master_volume, func(v: float): Game.set_volume(v))
	_slider_row(box, "Music:", Game.music_volume, func(v: float): Game.set_music_volume(v))
	_slider_row(box, "Sounds:", Game.sfx_volume, func(v: float): Game.set_sfx_volume(v))

	_button(box, "Back", func(): _show_panel(null))
	return parts[0]


func _slider_row(box: Container, label: String, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var l := RaceHud.make_label(label, 32)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(260, 40)
	slider.value_changed.connect(func(v: float):
		setter.call(v)
		Sfx.play("click"))
	slider.drag_ended.connect(func(_c: bool): Game.save_settings())
	row.add_child(slider)


func _change_laps(d: int) -> void:
	Game.laps = clampi(Game.laps + d, 1, 9)
	_laps_label.text = str(Game.laps)
	Game.save_settings()


func _build_help(root: Control) -> Control:
	var parts := _panel(root, "How to Play")
	var box: VBoxContainer = parts[1]
	var lines := [
		"Pick your toy car, then pick one of 5 tracks around the house!",
		"",
		"Go:  W  or  Up arrow",
		"Steer:  A / D  or  Left / Right arrows",
		"Brake / Reverse:  S  or  Down arrow",
		"TURBO:  Space  (watch the blue bar!)",
		"Stuck?  Press  R  to hop back on the track",
		"Camera:  C        Pause:  Esc",
		"",
		"Drive over the glowing pads for a BOOST.",
		"Go fast in the loops and on the jumps - too slow and you'll fall off!",
		"Steer into the turns or you'll fly over the edge!",
	]
	for line in lines:
		var l := RaceHud.make_label(line, 24, Color.WHITE, 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	_button(box, "Got it!", func(): _show_panel(null))
	return parts[0]


func _build_credits(root: Control) -> Control:
	var parts := _panel(root, "Credits")
	var box: VBoxContainer = parts[1]
	var lines := [
		"Race Track Mayhem",
		"",
		"Made with the Godot Engine (godotengine.org)",
		"Godot is (c) Juan Linietsky, Ariel Manzur and contributors, MIT license",
		"",
		"Sound effects: Kenney (kenney.nl) and Landeplage, CC0",
		"Music: Juhani Junkala, \"5 Chiptunes (Action)\", CC0",
		"",
		"Full license texts are in the licenses folder.",
	]
	for line in lines:
		var l := RaceHud.make_label(line, 22, Color.WHITE, 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	_button(box, "Back", func(): _show_panel(null))
	return parts[0]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _main_box.visible:
		Sfx.play("back")
		_show_panel(null)
