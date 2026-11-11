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
var _badges_panel: Control
var _story_panel: Control
var _daily_panel: Control
var _title: Control
var _option_buttons: Dictionary = {}
var _laps_label: Label
var _diff_button: Button
var _title_letters: Array[Label] = []
var _time := 0.0

# Save slots ("Who's racing?")
var _who_panel: Control
var _who_list: VBoxContainer
var _new_panel: Control
var _name_edit: LineEdit
var _new_diff := 0
var _new_steer := true
var _new_auto := false
var _removing := false
var _renaming := false
var _new_title: Label
var _go_button: Button
var _remove_armed := -1

const FUN_NAMES := ["Zippy", "Rocket", "Flash", "Sparky", "Dash", "Bolt", "Nitro", "Comet",
	"Blaze", "Whizz", "Champ", "Ace", "Skipper", "Bumble", "Pickle", "Noodle"]


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
	_title = title
	RaceHud.pin(title, Vector2(0.5, 0), Vector2(-600, 30), Vector2(1200, 260))
	title.add_theme_constant_override("separation", -20)
	root.add_child(title)
	title.add_child(_title_row("RACE TRACK", 92, [Color(1.0, 0.35, 0.3), Color(1.0, 0.65, 0.15), Color(1.0, 0.9, 0.2), Color(0.4, 0.9, 0.35), Color(0.35, 0.7, 1.0), Color(0.75, 0.45, 1.0)]))
	title.add_child(_title_row("MAYHEM!", 132, [Color(1.0, 0.55, 0.1)]))

	# Main buttons
	_main_box = VBoxContainer.new()
	RaceHud.pin(_main_box, Vector2(0.5, 0.5), Vector2(-280, -62), Vector2(560, 380))
	_main_box.add_theme_constant_override("separation", 12)
	root.add_child(_main_box)
	var modes := _row(_main_box)
	var play := _button(modes, "Quick Race", func():
		Game.end_grand_prix()
		Game.goto_garage())
	var cup := _button(modes, "Grand Prix", func():
		Game.start_grand_prix()
		Game.goto_garage())
	var story := _button(modes, "Story", _open_story)
	story.tooltip_text = "Beat the boss car in every room of the house!"
	for b: Button in [play, cup, story]:
		b.add_theme_font_size_override("font_size", 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mid := _row(_main_box)
	var builder := _button(mid, "Track Builder", func():
		Game.end_grand_prix()
		Game.goto_editor(-1))
	# This week's challenge track: new every Monday, with its own online top 10.
	var weekly := _button(mid, "Weekly: " + String(Game.weekly_track()["name"]), func():
		Game.end_grand_prix()
		Game.selected_track = Game.WEEKLY_TRACK
		Game.skip_track_select = true
		Game.goto_garage())
	weekly.tooltip_text = "This week's challenge track. A new one every Monday!"
	weekly.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	for b: Button in [builder, weekly]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var online_row := _row(_main_box)
	var online := _button(online_row, "Race Online!", func():
		Game.end_grand_prix()
		Game.goto("res://scenes/online.tscn"))
	online.add_theme_color_override("font_color", Color(0.75, 1.0, 1.0))
	online.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Today's three goals (a ★ when there's something left to do).
	var goals := Game.daily_goals()
	var left := goals.filter(func(g): return not (Game.daily.get("done", []) as Array).has(g["id"])).size()
	var daily_btn := _button(online_row, ("Daily Goals (%d)" % left) if left > 0 else "Daily Goals ✓", _open_daily)
	daily_btn.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	daily_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Seasonal event tracks (holidays, Halloween, summer) at their time of year.
	for ev: int in Game.events_on():
		var info: Dictionary = Game.EVENTS[ev]
		var ev_button := _button(online_row, String(info["button"]), func():
			Game.end_grand_prix()
			Game.selected_track = ev
			Game.skip_track_select = true
			Game.goto_garage())
		ev_button.tooltip_text = info["tip"]
		ev_button.add_theme_color_override("font_color", info["button_color"])
		ev_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var more := _row(_main_box)
	var badges_btn := _button(more, "Badges", _open_badges)
	var extras: Array = [badges_btn, _button(more, "Options", func(): _show_panel(_options_panel)), _button(more, "How to Play", func(): _show_panel(_help_panel))]
	if OS.get_name() != "Web" and not Game.is_mobile():
		extras.append(_button(more, "Quit", func(): get_tree().quit()))
	for b: Button in extras:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.grab_focus.call_deferred()

	# Who's playing (their own save slot); press to switch.
	var who := _button(root, _player_text(), _open_who)
	who.add_theme_font_size_override("font_size", 24)
	who.tooltip_text = "Switch player"
	RaceHud.pin(who, Vector2(0, 0), Vector2(16, 14), Vector2(320, 56))
	who.alignment = HORIZONTAL_ALIGNMENT_LEFT
	who.clip_text = true

	var star_label := RaceHud.make_label("★ %d" % Game.stars, 40, Color(1.0, 0.9, 0.3), 12)
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	star_label.tooltip_text = "Stars: win races to unlock paint, stickers, wheels and more!"
	RaceHud.pin(star_label, Vector2(1, 0), Vector2(-220, 14), Vector2(200, 56))
	root.add_child(star_label)

	var best := Game.best_time_for_current()
	if best > 0.0:
		var rec := RaceHud.make_label("Best time (%d laps): %s" % [Game.laps, Game.format_time(best)], 24, Color(0.8, 1.0, 0.8), 8)
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		RaceHud.pin(rec, Vector2(0.5, 1), Vector2(-300, -44), Vector2(600, 36))
		root.add_child(rec)

	# The version number, quietly in the corner (handy for checking you're up to date).
	var ver := RaceHud.make_label("v" + str(ProjectSettings.get_setting("application/config/version", "?")), 16, Color(1, 1, 1, 0.45), 4)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	RaceHud.pin(ver, Vector2(1, 1), Vector2(-150, -30), Vector2(140, 24))
	root.add_child(ver)

	_options_panel = _build_options(root)
	_help_panel = _build_help(root)
	_credits_panel = _build_credits(root)
	_badges_panel = _build_badges(root)
	_story_panel = _build_story(root)
	_daily_panel = _build_daily(root)
	_who_panel = _build_who(root)
	_new_panel = _build_new_player(root)
	var credits_btn := _button(root, "Credits", func(): _show_panel(_credits_panel))
	credits_btn.add_theme_font_size_override("font_size", 20)
	RaceHud.pin(credits_btn, Vector2(0, 1), Vector2(16, -64), Vector2(130, 48))

	if Net.end_reason != "":
		var note := RaceHud.make_label(Net.end_reason, 26, Color(1.0, 0.75, 0.5), 8)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		RaceHud.pin(note, Vector2(0.5, 1), Vector2(-400, -90), Vector2(800, 40))
		root.add_child(note)
		Net.end_reason = ""

	# First time in this session (or nobody saved yet): ask who's racing.
	if Game.player_slot < 0 or not Game.player_chosen:
		_open_who.call_deferred()
	elif Game.open_story:
		_open_story.call_deferred()
	Game.open_story = false


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
		if cb.is_valid():
			cb.call())
	b.focus_entered.connect(func(): Sfx.play("click", 1.0, -8.0))
	parent.add_child(b)
	return b


func _row(parent: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	return row


## A pop-up panel with a title and a Back button in its top corner (so Back is
## always on screen, however small the window). Pass back = Callable() for none.
func _panel(root: Control, title_text: String, back: Variant = null) -> Array:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	var cb: Callable = back if back is Callable else func(): _show_panel(null)
	if cb.is_valid():
		var back_btn := _button(t, "< Back", cb)
		back_btn.add_theme_font_size_override("font_size", 20)
		back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		back_btn.position = Vector2(-6, 4)
		back_btn.size = Vector2(110, 44)
		back_btn.set_meta("corner_back", true)
		t.set_meta("back", back_btn)
	return [center, box]


func _show_panel(panel: Control) -> void:
	_main_box.visible = panel == null
	_title.visible = panel == null
	_options_panel.visible = panel == _options_panel
	_help_panel.visible = panel == _help_panel
	_credits_panel.visible = panel == _credits_panel
	_badges_panel.visible = panel == _badges_panel
	_story_panel.visible = panel == _story_panel
	_daily_panel.visible = panel == _daily_panel
	_who_panel.visible = panel == _who_panel
	_new_panel.visible = panel == _new_panel
	if panel == null:
		(_main_box.get_child(0).get_child(0) as Button).grab_focus()
	else:
		var buttons := panel.find_children("*", "Button", true, false).filter(func(x): return not x.has_meta("corner_back"))
		if buttons.size() > 0:
			(buttons[0] as Button).grab_focus()
		_fit_to_screen.call_deferred(panel)


## Shrinks a panel that's taller than the window, so nothing ends up off screen.
func _fit_to_screen(center: Control) -> void:
	var panel := center.get_child(0) as Control
	panel.scale = Vector2.ONE
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var room := get_viewport().get_visible_rect().size - Vector2(24, 24)
	var k := minf(1.0, minf(room.y / maxf(1.0, panel.size.y), room.x / maxf(1.0, panel.size.x)))
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(k, k)


func _build_options(root: Control) -> Control:
	var parts := _panel(root, "Options")
	var box: VBoxContainer = parts[1]
	box.add_theme_constant_override("separation", 8)
	var grid := GridContainer.new()
	grid.columns = 4   # two settings per row, so it fits on small screens
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)

	grid.add_child(RaceHud.make_label("Laps:", 28))
	var laps_row := HBoxContainer.new()
	laps_row.add_theme_constant_override("separation", 12)
	grid.add_child(laps_row)
	_button(laps_row, "-", func(): _change_laps(-1))
	_laps_label = RaceHud.make_label(str(Game.laps), 36, Color(1.0, 0.9, 0.3))
	_laps_label.custom_minimum_size = Vector2(50, 0)
	_laps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	laps_row.add_child(_laps_label)
	_button(laps_row, "+", func(): _change_laps(1))

	_choice(grid, "Other cars:", func() -> String: return Game.DIFFICULTY_NAMES[Game.difficulty], func():
		Game.difficulty = (Game.difficulty + 1) % 3)
	_choice(grid, "Graphics:", func() -> String: return Game.QUALITY_NAMES[Game.quality] + ("" if Game.fancy_renderer() else " (basic)"), func():
		Game.quality = (Game.quality + 1) % 3
		Game.apply_display())
	_choice(grid, "Fullscreen:", func() -> String: return "On" if Game.fullscreen else "Off", func():
		Game.fullscreen = not Game.fullscreen
		Game.apply_display())
	_choice(grid, "Steering help:", func() -> String: return "On" if Game.steer_assist else "Off", func():
		Game.steer_assist = not Game.steer_assist)
	_choice(grid, "Ghost car:", func() -> String: return "On" if Game.ghost_enabled else "Off", func():
		Game.ghost_enabled = not Game.ghost_enabled)
	_choice(grid, "Power-ups:", func() -> String: return "On" if Game.powerups_enabled else "Off", func():
		Game.powerups_enabled = not Game.powerups_enabled)
	_choice(grid, "Touch buttons:", func() -> String: return Game.TOUCH_NAMES[Game.touch_mode], func():
		Game.touch_mode = (Game.touch_mode + 1) % 3)
	_choice(grid, "Online times:", func() -> String: return "On" if Game.online_times else "Off", func():
		Game.online_times = not Game.online_times)
	_choice(grid, "Auto-Go:", func() -> String: return "On" if Game.auto_go else "Off", func():
		Game.auto_go = not Game.auto_go)
	if Game.is_mobile():
		_choice(grid, "Tilt to steer:", func() -> String: return Game.TILT_NAMES[Game.tilt_steer], func():
			Game.tilt_steer = (Game.tilt_steer + 1) % 3)
	_slider_row(grid, "Volume:", Game.master_volume, func(v: float): Game.set_volume(v))
	_slider_row(grid, "Music:", Game.music_volume, func(v: float): Game.set_music_volume(v))
	_slider_row(grid, "Sounds:", Game.sfx_volume, func(v: float): Game.set_sfx_volume(v))

	var note := RaceHud.make_label("Graphics: Low runs on any PC. High looks amazing but needs a good graphics card.", 18, Color(0.85, 0.9, 1.0), 4)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(760, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	_button(box, "Back", func(): _show_panel(null))
	return parts[0]


## A label plus a button that cycles through choices.
func _choice(grid: GridContainer, label: String, current: Callable, next: Callable) -> void:
	grid.add_child(RaceHud.make_label(label, 28))
	var b := _button(grid, current.call(), Callable())
	b.custom_minimum_size = Vector2(200, 0)
	b.pressed.connect(func():
		next.call()
		b.text = current.call()
		Game.save_settings())


func _slider_row(box: Container, label: String, value: float, setter: Callable) -> void:
	box.add_child(RaceHud.make_label(label, 28))
	var row := HBoxContainer.new()
	box.add_child(row)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(200, 40)
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
		"QUICK RACE: pick a car and one of 8 tracks.   GRAND PRIX: race all 8 for points!",
		"WEEKLY: a brand new challenge track every Monday, with its own online top 10!",
		"",
		"Go:  W / Up      Steer:  A D / Left Right      Brake:  S / Down",
		"TURBO:  Space      Back on track:  R      Camera:  C      Pause:  Esc",
		"",
		"Drive over glowing pads for a BOOST. Slow down for turns or you'll spin out!",
		"Win races to earn STARS and unlock paint, stickers, wheels...",
		"...and win a Grand Prix to unlock the SECRET car!",
		"TRACK BUILDER: snap pieces together, then Share your track with a code!",
		"POWER-UPS: drive through ? boxes, then press E (or Y) to use them!",
		"RACE ONLINE: one computer taps Host a Race, the others find it and join!",
	]
	for line in lines:
		var l := RaceHud.make_label(line, 22, Color.WHITE, 6)
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
		"Music: the Mesa Mayhem soundtrack by Andrew Saulls, made with Suno",
		"",
		"Full license texts are in the licenses folder.",
	]
	for line in lines:
		var l := RaceHud.make_label(line, 22, Color.WHITE, 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	_button(box, "Back", func(): _show_panel(null))
	return parts[0]


func _open_daily() -> void:
	var root := _daily_panel.get_parent() as Control
	_daily_panel.queue_free()
	_daily_panel = _build_daily(root)
	_show_panel(_daily_panel)


## Today's three daily goals with how far along you are, and your streak.
func _build_daily(root: Control) -> Control:
	var parts := _panel(root, "Daily Goals")
	var box: VBoxContainer = parts[1]
	box.custom_minimum_size = Vector2(760, 0)
	var intro := RaceHud.make_label("New goals every day! Each one is worth %d ★, and doing all three gets %d more." % [Daily.STARS_EACH, Daily.ALL_BONUS], 20, Color(0.85, 0.95, 1.0), 6)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	var done: Array = Game.daily.get("done", [])
	for g in Game.daily_goals():
		var finished := done.has(g["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		var tick := RaceHud.make_label("✓" if finished else "•", 34, Color(0.4, 1.0, 0.5) if finished else Color(1.0, 0.9, 0.4), 8)
		tick.custom_minimum_size = Vector2(40, 0)
		row.add_child(tick)
		var text := RaceHud.make_label(String(g["text"]), 26, Color(0.75, 1.0, 0.75) if finished else Color.WHITE, 8)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(text)
		var have := Game.daily_progress(g)
		var bar := ProgressBar.new()
		bar.max_value = int(g["goal"])
		bar.value = have
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(150, 24)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.35, 0.9, 0.45)
		fill.set_corner_radius_all(8)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(1, 1, 1, 0.15)
		back.set_corner_radius_all(8)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", back)
		row.add_child(bar)
		row.add_child(RaceHud.make_label("%d/%d" % [have, int(g["goal"])], 22, Color(1.0, 0.9, 0.5), 6))
	var streak := Game.daily_streak()
	var s := RaceHud.make_label(("Streak: %d day%s in a row!" % [streak, "" if streak == 1 else "s"]) if streak > 0 else "Do a goal today to start a streak!", 24, Color(1.0, 0.6, 0.25), 8)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	_button(box, "Let's Race!", func():
		Game.end_grand_prix()
		Game.goto_garage())
	return parts[0]


func _open_story() -> void:
	var root := _story_panel.get_parent() as Control
	_story_panel.queue_free()
	_story_panel = _build_story(root)   # fresh, with the latest progress
	_show_panel(_story_panel)


## The story map: one boss per room, opened in order.
func _build_story(root: Control) -> Control:
	var parts := _panel(root, "Story Mode")
	var box: VBoxContainer = parts[1]
	box.custom_minimum_size = Vector2(900, 0)
	var intro := RaceHud.make_label("Each room has a boss car. Finish ahead of the boss to open the next room! Beaten bosses can be raced again as Super bosses.", 20, Color(0.85, 0.95, 1.0), 6)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(intro)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var focus: Button
	for i in Story.count():
		var ch := Story.chapter(i)
		var open := i <= Game.story_beaten
		var beaten := i < Game.story_beaten
		var where := RaceHud.make_label("%d.  %s" % [i + 1, Story.room_name(i)], 22, Color.WHITE if open else Color(0.6, 0.6, 0.68), 6)
		grid.add_child(where)
		var who := RaceHud.make_label(String(ch["boss"]) if open else "? ? ?", 22, Color(1.0, 0.75, 0.45) if open else Color(0.6, 0.6, 0.68), 6)
		who.custom_minimum_size = Vector2(230, 0)
		grid.add_child(who)
		var status := RaceHud.make_label("Beaten! ★" if beaten else ("Your next race!" if open else "Locked"), 20,
			Color(0.5, 1.0, 0.55) if beaten else (Color(1.0, 0.9, 0.3) if open else Color(0.55, 0.55, 0.62)), 6)
		status.custom_minimum_size = Vector2(170, 0)
		grid.add_child(status)
		var idx := i
		var b := _button(grid, "Race!" if open else "  ?  ", func(): Game.start_story(idx))
		b.add_theme_font_size_override("font_size", 22)
		b.disabled = not open
		# Beat a boss and its Super version opens: faster, with a special trick.
		if beaten:
			var sup := _button(grid, "Super ★" if Game.super_beaten.has(i) else "Super!", func(): Game.start_story(idx, true))
			sup.add_theme_font_size_override("font_size", 20)
			sup.add_theme_color_override("font_color", Color(1.0, 0.6, 0.95))
			sup.tooltip_text = "A Super rematch: %s is faster and uses %s!" % [ch["boss"], ch.get("trick", {}).get("name", "tricks")]
		else:
			grid.add_child(Control.new())   # keeps the rows lined up
		if open and not beaten:
			focus = b
	if Game.story_beaten >= Story.count():
		var champ := RaceHud.make_label("You beat every boss! You're the champion of the whole house!", 22, Color(1.0, 0.85, 0.3), 8)
		champ.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(champ)
	if focus:
		focus.set_meta("story_focus", true)
	return parts[0]


func _open_badges() -> void:
	var root := _badges_panel.get_parent() as Control
	_badges_panel.queue_free()
	_badges_panel = _build_badges(root)   # fresh, with any badges just earned
	_show_panel(_badges_panel)


## The Badges room: every badge, shiny if you've earned it, grey with how
## far along you are if not.
func _build_badges(root: Control) -> Control:
	var parts := _panel(root, "Badges")
	var box: VBoxContainer = parts[1]
	box.custom_minimum_size = Vector2(1060, 0)
	var who := Game.player_name if Game.player_name != "" else "You"
	var st := Game.stats
	var summary := RaceHud.make_label("%s: %d of %d badges   |   %d races   %d wins   %d jumps" % [who, Game.badges.size(), Badges.LIST.size(),
		int(st.get("races", 0)), int(st.get("wins", 0)), int(st.get("jumps", 0))], 22, Color(0.85, 0.95, 1.0), 6)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(summary)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	var stats_now := Game.stats.duplicate()
	stats_now["stars"] = Game.stars
	for b in Badges.LIST:
		var got: bool = Game.badges.has(b["id"])
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(200, 0)
		cell.add_theme_constant_override("separation", 0)
		cell.tooltip_text = b["desc"]
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		var medal := BadgeMedal.make(b, got, 64)
		medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(medal)
		var n := RaceHud.make_label(b["name"], 19, Color.WHITE if got else Color(0.7, 0.7, 0.78), 5)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(n)
		var p := Badges.progress(b, stats_now)
		var info: String = b["desc"]
		if not got and int(p[1]) > 1:
			info += "  (%d/%d)" % [p[0], p[1]]
		var d := RaceHud.make_label(info, 14, Color(1.0, 0.9, 0.5) if got else Color(0.75, 0.75, 0.85), 4)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(200, 0)
		cell.add_child(d)
		grid.add_child(cell)
	return parts[0]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _main_box.visible:
		Sfx.play("back")
		if _new_panel.visible and not _renaming:
			_open_who()
		elif _who_panel.visible and Game.player_slot < 0:
			return   # someone has to pick a player first
		else:
			_show_panel(null)


# ---------------------------------------------------------------------------
# Players: "Who's racing?" and "New Player"
# ---------------------------------------------------------------------------

func _player_text() -> String:
	return "Racer: " + (Game.player_name if Game.player_name != "" else "?")


func _build_who(root: Control) -> Control:
	var parts := _panel(root, "Who's racing?", Callable())
	_who_list = parts[1]
	return parts[0]


func _open_who() -> void:
	_removing = false
	_remove_armed = -1
	_fill_who()
	_show_panel(_who_panel)
	# Start on whoever played last.
	for b in _who_list.find_children("*", "Button", true, false):
		if b.has_meta("slot") and int(b.get_meta("slot")) == Game.player_slot:
			(b as Button).grab_focus()
			break


func _fill_who() -> void:
	for i in range(_who_list.get_child_count() - 1, 0, -1):   # keep the title
		_who_list.get_child(i).queue_free()
	var players := Game.list_players()
	if players.is_empty():
		var hi := RaceHud.make_label("Hi! Make a player so the game can save your stars, trophies, tracks and best times.", 22, Color.WHITE, 6)
		hi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hi.custom_minimum_size = Vector2(560, 0)
		_who_list.add_child(hi)
	elif _removing:
		var warn := RaceHud.make_label("Pick a player to remove (press twice). Their save is gone for good!", 20, Color(1.0, 0.75, 0.6), 6)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_who_list.add_child(warn)
	for p: Dictionary in players:
		var slot: int = p["slot"]
		var text := "%s      ★ %d   %s" % [p["name"], p["stars"], Game.DIFFICULTY_NAMES[p["difficulty"]]]
		if _removing:
			text = ("Really remove %s?" % p["name"]) if _remove_armed == slot else ("Remove " + String(p["name"]))
		var b := _button(_who_list, text, func(): _pick_player(slot))
		b.set_meta("slot", slot)
		b.add_theme_font_size_override("font_size", 30)
		if _removing:
			b.modulate = Color(1.0, 0.7, 0.65)
	if not _removing and players.size() < Game.MAX_PLAYERS:
		var add := _button(_who_list, "+ New Player", _open_new_player)
		add.add_theme_font_size_override("font_size", 30)
		add.modulate = Color(0.75, 1.0, 0.75)
	var row := _row(_who_list)
	if not players.is_empty():
		_button(row, "Done" if _removing else "Remove a Player", func():
			_removing = not _removing
			_remove_armed = -1
			_fill_who()
			_focus_first(_who_list))
	if Game.player_slot >= 0 and Game.player_chosen and not _removing:
		_button(row, "Change " + Game.player_name, func(): _open_new_player(true))
		_button(row, "Back", func(): _show_panel(null))


func _focus_first(box: Control) -> void:
	var buttons := box.find_children("*", "Button", true, false)
	if buttons.size() > 0:
		(buttons[0] as Button).grab_focus.call_deferred()


func _pick_player(slot: int) -> void:
	if _removing:
		if _remove_armed != slot:
			_remove_armed = slot
			_fill_who()
			for b in _who_list.find_children("*", "Button", true, false):
				if b.has_meta("slot") and int(b.get_meta("slot")) == slot:
					(b as Button).grab_focus.call_deferred()
			return
		Game.delete_player(slot)
		Sfx.play("crash")
		_removing = Game.list_players().size() > 0
		_remove_armed = -1
		if Game.list_players().is_empty():
			Game.player_chosen = false
		_fill_who()
		_focus_first(_who_list)
		return
	Game.select_player(slot)
	Game.player_chosen = true
	Game.save_settings()
	Game.goto_menu()   # reload so stars, best times and options are theirs


func _build_new_player(root: Control) -> Control:
	var parts := _panel(root, "New Player", func():
		if _renaming:
			_show_panel(null)
		else:
			_open_who())
	var box: VBoxContainer = parts[1]
	_new_title = box.get_child(0) as Label
	box.add_theme_constant_override("separation", 10)
	box.add_child(RaceHud.make_label("What's your name?", 28))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	box.add_child(name_row)
	_name_edit = LineEdit.new()
	_name_edit.max_length = Game.NAME_LENGTH
	_name_edit.placeholder_text = "Type your name"
	_name_edit.add_theme_font_size_override("font_size", 34)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(_t: String): _finish_new_player())
	name_row.add_child(_name_edit)
	_button(name_row, "Surprise me!", func():
		_name_edit.text = FUN_NAMES[randi() % FUN_NAMES.size()])

	# Letters for controller players (keyboard players can just type).
	var keys := GridContainer.new()
	keys.columns = 10
	keys.add_theme_constant_override("h_separation", 4)
	keys.add_theme_constant_override("v_separation", 4)
	box.add_child(keys)
	for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		var letter: String = ch
		var k := _button(keys, letter, func(): _type(letter))
		k.custom_minimum_size = Vector2(52, 48)
		k.add_theme_font_size_override("font_size", 22)
	var edit_row := _row(box)
	var space := _button(edit_row, "Space", func(): _type(" "))
	var del := _button(edit_row, "Delete", func():
		_name_edit.text = _name_edit.text.substr(0, maxi(0, _name_edit.text.length() - 1)))
	for k: Button in [space, del]:
		k.custom_minimum_size = Vector2(160, 48)
		k.add_theme_font_size_override("font_size", 20)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	box.add_child(grid)
	grid.add_child(RaceHud.make_label("Other cars:", 28))
	var diff_btn := _button(grid, "", Callable())
	diff_btn.custom_minimum_size = Vector2(240, 0)
	grid.add_child(RaceHud.make_label("Steering help:", 28))
	var steer_btn := _button(grid, "", Callable())
	grid.add_child(RaceHud.make_label("Auto-Go:", 28))
	var auto_btn := _button(grid, "", Callable())
	var hint := RaceHud.make_label("", 18, Color(0.85, 0.9, 1.0), 4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var refresh := func():
		diff_btn.text = Game.DIFFICULTY_NAMES[_new_diff]
		steer_btn.text = "On" if _new_steer else "Off"
		auto_btn.text = "On (car goes by itself)" if _new_auto else "Off"
		hint.text = ["Easy: great for little racers.", "Normal: a fair race.", "Hard: the computer cars are fast!"][_new_diff] \
			+ "  You can change this any time in Options."
	diff_btn.pressed.connect(func():
		_new_diff = (_new_diff + 1) % 3
		refresh.call())
	steer_btn.pressed.connect(func():
		_new_steer = not _new_steer
		refresh.call())
	auto_btn.pressed.connect(func():
		_new_auto = not _new_auto
		refresh.call())
	_name_edit.set_meta("refresh", refresh)

	var row := _row(box)
	var go := _button(row, "Let's Race!", _finish_new_player)
	go.add_theme_font_size_override("font_size", 32)
	_go_button = go
	_button(row, "Back", func():
		if _renaming:
			_show_panel(null)
		else:
			_open_who())
	return parts[0]


func _type(ch: String) -> void:
	if _name_edit.text.length() < Game.NAME_LENGTH:
		var t := _name_edit.text
		# Capital first letter, small letters after (unless after a space).
		if t != "" and not t.ends_with(" ") and ch != " ":
			ch = ch.to_lower()
		_name_edit.text = t + ch


func _open_new_player(rename := false) -> void:
	_renaming = rename
	_new_title.text = "Change Player" if rename else "New Player"
	_go_button.text = "Save" if rename else "Let's Race!"
	_name_edit.text = Game.player_name if rename else ""
	_new_diff = Game.difficulty if rename else 0
	_new_steer = Game.steer_assist if rename else true
	_new_auto = Game.auto_go if rename else false
	(_name_edit.get_meta("refresh") as Callable).call()
	_show_panel(_new_panel)
	_name_edit.grab_focus.call_deferred()


func _finish_new_player() -> void:
	if _name_edit.text.strip_edges() == "":
		_name_edit.placeholder_text = "Type a name first!"
		_name_edit.grab_focus()
		Sfx.play("back")
		return
	if _renaming:
		Game.difficulty = _new_diff
		Game.steer_assist = _new_steer
		Game.auto_go = _new_auto
		Game.rename_player(_name_edit.text)
		Game.goto_menu()
		return
	if Game.create_player(_name_edit.text, _new_diff, _new_steer, _new_auto) < 0:
		return
	Sfx.play("voice_go")
	Game.goto_menu()
