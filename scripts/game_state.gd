extends Node
## Global game state (autoloaded as `Game`): chosen car, settings, best times,
## controls and the shared UI theme.

const SAVE_PATH := "user://race_track_mayhem.cfg"
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard"]

var selected_car: int = 0
var selected_track: int = 0
var laps: int = 3
var difficulty: int = 0          # 0 easy, 1 normal, 2 hard
var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.9
var best_times: Dictionary = {}  # track id -> best race time (seconds)
var best_laps: Dictionary = {}   # track id -> best single lap (seconds)

var ui_theme: Theme


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_buses()
	load_settings()
	ui_theme = _make_theme()
	get_tree().root.theme = ui_theme


# --------------------------------------------------------------------------
# Scene helpers
# --------------------------------------------------------------------------

func goto(scene_path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)


func goto_menu() -> void:
	goto("res://scenes/main_menu.tscn")


func goto_garage() -> void:
	goto("res://scenes/vehicle_select.tscn")


func goto_track_select() -> void:
	goto("res://scenes/track_select.tscn")


func goto_race() -> void:
	goto("res://scenes/race.tscn")


# --------------------------------------------------------------------------
# Saving
# --------------------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_apply_volume()
		return
	selected_car = int(cfg.get_value("player", "car", 0))
	selected_track = clampi(int(cfg.get_value("player", "track", 0)), 0, Track.TRACKS.size() - 1)
	laps = int(cfg.get_value("settings", "laps", 3))
	difficulty = int(cfg.get_value("settings", "difficulty", 0))
	master_volume = float(cfg.get_value("settings", "volume", 0.8))
	music_volume = float(cfg.get_value("settings", "music_volume", 0.6))
	sfx_volume = float(cfg.get_value("settings", "sfx_volume", 0.9))
	best_times = cfg.get_value("records", "best_times", {})
	best_laps = cfg.get_value("records", "best_laps", {})
	selected_car = clampi(selected_car, 0, CarData.count() - 1)
	laps = clampi(laps, 1, 9)
	difficulty = clampi(difficulty, 0, 2)
	_apply_volume()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "car", selected_car)
	cfg.set_value("player", "track", selected_track)
	cfg.set_value("settings", "laps", laps)
	cfg.set_value("settings", "difficulty", difficulty)
	cfg.set_value("settings", "volume", master_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("records", "best_times", best_times)
	cfg.set_value("records", "best_laps", best_laps)
	cfg.save(SAVE_PATH)


func set_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volume()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volume()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volume()


func _apply_volume() -> void:
	for pair in [["Master", master_volume], ["Music", music_volume], ["SFX", sfx_volume]]:
		var bus := AudioServer.get_bus_index(pair[0])
		if bus < 0:
			continue
		var v: float = pair[1]
		AudioServer.set_bus_mute(bus, v <= 0.001)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.001)))


## Separate Music and SFX volume channels, both feeding Master.
func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


## Records a finished race. Returns true if it was a new best race time.
func submit_result(race_time: float, best_lap: float) -> bool:
	var new_record := false
	var key := "%s_%d" % [track_id(), laps]
	if not best_times.has(key) or race_time < float(best_times[key]):
		best_times[key] = race_time
		new_record = true
	if best_lap > 0.0 and (not best_laps.has(track_id()) or best_lap < float(best_laps[track_id()])):
		best_laps[track_id()] = best_lap
	save_settings()
	return new_record


func best_time_for_current() -> float:
	return best_time_for(selected_track)


func best_time_for(track_index: int) -> float:
	var key := "%s_%d" % [Track.TRACKS[track_index]["id"], laps]
	return float(best_times.get(key, -1.0))


func track_id() -> String:
	return Track.TRACKS[selected_track]["id"]


func track_name() -> String:
	return Track.TRACKS[selected_track]["name"]


static func format_time(t: float) -> String:
	if t < 0.0:
		return "--:--.--"
	var minutes := int(t / 60.0)
	var secs := fmod(t, 60.0)
	return "%d:%05.2f" % [minutes, secs]


static func ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n


# --------------------------------------------------------------------------
# Controls (keyboard + gamepad), created in code so they are easy to read.
# --------------------------------------------------------------------------

func _setup_input() -> void:
	_add_action("accelerate", [KEY_W, KEY_UP], [JOY_BUTTON_A], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_add_action("brake", [KEY_S, KEY_DOWN], [JOY_BUTTON_X], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_add_action("steer_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_action("steer_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_action("turbo", [KEY_SPACE, KEY_SHIFT], [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER], [])
	_add_action("respawn", [KEY_R], [JOY_BUTTON_Y], [])
	_add_action("camera", [KEY_C], [JOY_BUTTON_LEFT_SHOULDER], [])
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])


func _add_action(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	for a in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = a[0]
		jm.axis_value = a[1]
		InputMap.action_add_event(action, jm)


# --------------------------------------------------------------------------
# Big, bright, kid-friendly UI theme
# --------------------------------------------------------------------------

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Comic Sans MS", "Chalkboard SE", "Fredoka", "Nunito", "Arial Rounded MT Bold", "Verdana", "sans-serif"])
	font.font_weight = 800
	t.default_font = font

	var normal := _box(Color(1.0, 0.55, 0.1), Color(0.75, 0.3, 0.0))
	var hover := _box(Color(1.0, 0.7, 0.2), Color(0.85, 0.4, 0.0))
	var pressed := _box(Color(0.9, 0.42, 0.05), Color(0.6, 0.25, 0.0))
	var focus := _box(Color(0, 0, 0, 0), Color(1, 1, 1))
	focus.draw_center = false
	focus.set_border_width_all(5)
	var disabled := _box(Color(0.6, 0.6, 0.6), Color(0.4, 0.4, 0.4))

	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color(1, 1, 0.85))
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_outline_color", "Button", Color(0.45, 0.18, 0.0))
	t.set_constant("outline_size", "Button", 6)
	t.set_font_size("font_size", "Button", 30)

	t.set_color("font_outline_color", "Label", Color(0.1, 0.05, 0.2))
	t.set_constant("outline_size", "Label", 8)
	t.set_color("font_color", "Label", Color.WHITE)

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.12, 0.1, 0.3, 0.85)
	panel.set_corner_radius_all(24)
	panel.set_border_width_all(6)
	panel.border_color = Color(1.0, 0.8, 0.2)
	panel.set_content_margin_all(24)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(1.0, 0.55, 0.1)
	grabber.set_corner_radius_all(8)
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(1, 1, 1, 0.3)
	slider_bg.set_corner_radius_all(8)
	slider_bg.content_margin_top = 6
	slider_bg.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", grabber)
	t.set_stylebox("grabber_area_highlight", "HSlider", grabber)
	return t


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(4)
	sb.border_width_bottom = 9
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	return sb
