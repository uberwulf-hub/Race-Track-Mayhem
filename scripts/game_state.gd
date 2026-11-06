extends Node
## Global game state (autoloaded as `Game`): chosen car, settings, best times,
## progress (stars, unlocks, trophies), Grand Prix and 2-player state,
## controls and the shared UI theme.

const SAVE_PATH := "user://race_track_mayhem.cfg"
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard"]
const QUALITY_NAMES := ["Low", "Medium", "High"]
const GP_POINTS := [10, 8, 6, 5, 4]

var selected_car: int = 0
var selected_track: int = 0
var laps: int = 3
var difficulty: int = 0          # 0 easy, 1 normal, 2 hard
var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.9
var best_times: Dictionary = {}  # track id -> best race time (seconds)
var best_laps: Dictionary = {}   # track id -> best single lap (seconds)

# Settings
var quality: int = 1             # 0 low, 1 medium, 2 high
var fullscreen := false
var steer_assist := true         # gentle steering help for little drivers
var ghost_enabled := true        # race against your best lap

# Progress
var stars: int = 0               # earned by finishing races
var trophies: Dictionary = {}    # difficulty (int) -> best Grand Prix place (1..3)
var custom: Dictionary = {}      # car id -> {"paint": id, "sticker": id, "wheels": id}

# Game modes
var two_player := false
var p2_car: int = 1
var gp_active := false
var gp_race := 0                 # which race of the cup (0..4)
var gp_points: Dictionary = {}   # racer name -> points
var gp_roster: Array = []        # [{name, car, player (0 = computer, 1 or 2)}], same for the whole cup
var last_unlocks: Array = []     # unlocks earned by the last race, shown on the results screen

var ui_theme: Theme


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_buses()
	load_settings()
	ui_theme = _make_theme()
	get_tree().root.theme = ui_theme
	apply_display()


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
	quality = clampi(int(cfg.get_value("settings", "quality", 1)), 0, 2)
	fullscreen = bool(cfg.get_value("settings", "fullscreen", false))
	steer_assist = bool(cfg.get_value("settings", "steer_assist", true))
	ghost_enabled = bool(cfg.get_value("settings", "ghost", true))
	stars = int(cfg.get_value("progress", "stars", 0))
	trophies = cfg.get_value("progress", "trophies", {})
	custom = cfg.get_value("progress", "custom", {})
	p2_car = int(cfg.get_value("player", "p2_car", 1))
	selected_car = clampi(selected_car, 0, CarData.count() - 1)
	p2_car = clampi(p2_car, 0, CarData.count() - 1)
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
	cfg.set_value("settings", "quality", quality)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "steer_assist", steer_assist)
	cfg.set_value("settings", "ghost", ghost_enabled)
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("progress", "trophies", trophies)
	cfg.set_value("progress", "custom", custom)
	cfg.set_value("player", "p2_car", p2_car)
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


# --------------------------------------------------------------------------
# Graphics
# --------------------------------------------------------------------------

## True when running on the full (Forward+) renderer. Old PCs fall back to
## the simpler OpenGL renderer automatically, and the fancy effects switch off.
func fancy_renderer() -> bool:
	return RenderingServer.get_rendering_device() != null


func apply_display() -> void:
	if OS.has_feature("editor") and DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	var vp := get_tree().root
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality == 0 else Viewport.SCREEN_SPACE_AA_DISABLED


## Turns the environment's effects up or down for the chosen quality.
func apply_quality(env: Environment, sun: DirectionalLight3D = null) -> void:
	var fancy := fancy_renderer()
	env.glow_enabled = true
	env.ssao_enabled = fancy and quality >= 1
	env.ssao_radius = 2.5
	env.ssao_intensity = 1.6
	env.ssao_light_affect = 0.15
	env.ssil_enabled = fancy and quality >= 2
	env.ssil_radius = 6.0
	env.ssr_enabled = fancy and quality >= 2
	env.ssr_max_steps = 48
	env.sdfgi_enabled = fancy and quality >= 2
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.6
	env.sdfgi_energy = 0.6
	env.volumetric_fog_enabled = fancy and quality >= 2
	env.volumetric_fog_density = 0.0012
	env.volumetric_fog_albedo = Color(1.0, 0.97, 0.9)
	env.volumetric_fog_length = 260.0
	env.volumetric_fog_ambient_inject = 0.0
	if sun:
		sun.shadow_enabled = true
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality >= 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.light_volumetric_fog_energy = 2.5
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096][quality], true)


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
	# Two-player split screen: each player gets their own keys and controller.
	_add_player_actions("p1_", KEY_W, KEY_S, KEY_A, KEY_D, [KEY_SPACE, KEY_SHIFT], KEY_R, 0)
	_add_player_actions("p2_", KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, [KEY_ENTER, KEY_KP_0, KEY_CTRL], KEY_BACKSPACE, 1)


func _add_player_actions(prefix: String, up: Key, down: Key, left: Key, right: Key, turbo: Array, reset: Key, device: int) -> void:
	_add_action(prefix + "accelerate", [up], [JOY_BUTTON_A], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], device)
	_add_action(prefix + "brake", [down], [JOY_BUTTON_X], [[JOY_AXIS_TRIGGER_LEFT, 1.0]], device)
	_add_action(prefix + "steer_left", [left], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]], device)
	_add_action(prefix + "steer_right", [right], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]], device)
	_add_action(prefix + "turbo", turbo, [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER], [], device)
	_add_action(prefix + "respawn", [reset], [JOY_BUTTON_Y], [], device)


func _add_action(action: String, keys: Array, buttons: Array, axes: Array, device: int = -1) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.device = device
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	for a in axes:
		var jm := InputEventJoypadMotion.new()
		jm.device = device
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


# --------------------------------------------------------------------------
# Progress: stars, unlocks, trophies, car paint jobs
# --------------------------------------------------------------------------

## Stars for finishing a race in `place` (everyone who finishes gets one).
static func stars_for_place(place: int) -> int:
	return [3, 2, 1, 1, 1, 1][clampi(place - 1, 0, 5)]


## Adds stars and returns the unlocks that just became available.
func award_stars(amount: int) -> Array:
	var before := Unlocks.available(stars, trophies)
	stars += amount
	var after := Unlocks.available(stars, trophies)
	var fresh: Array = []
	for u in after:
		if not before.has(u):
			fresh.append(u)
	save_settings()
	return fresh


## Saves a Grand Prix trophy (keeps the best place per difficulty). Returns new unlocks.
func award_trophy(place: int) -> Array:
	var before := Unlocks.available(stars, trophies)
	var key := difficulty
	if place <= 3 and (not trophies.has(key) or place < int(trophies[key])):
		trophies[key] = place
	var after := Unlocks.available(stars, trophies)
	var fresh: Array = []
	for u in after:
		if not before.has(u):
			fresh.append(u)
	save_settings()
	return fresh


func is_unlocked(item_id: String) -> bool:
	return Unlocks.available(stars, trophies).has(item_id)


## The paint/sticker/wheels picked for a car (ids), with defaults.
func custom_for(car_id: String) -> Dictionary:
	var c: Dictionary = custom.get(car_id, {})
	return {"paint": c.get("paint", "paint_original"), "sticker": c.get("sticker", "sticker_none"), "wheels": c.get("wheels", "wheels_classic")}


func set_custom(car_id: String, slot: String, item_id: String) -> void:
	var c := custom_for(car_id)
	c[slot] = item_id
	custom[car_id] = c
	save_settings()


# --------------------------------------------------------------------------
# Grand Prix
# --------------------------------------------------------------------------

func start_grand_prix() -> void:
	gp_active = true
	gp_race = 0
	gp_points.clear()
	gp_roster.clear()
	selected_track = 0


func end_grand_prix() -> void:
	gp_active = false
	gp_roster.clear()


## Racers sorted by Grand Prix points (most first).
func gp_standings() -> Array:
	var rows: Array = []
	for r in gp_roster:
		rows.append({"name": r["name"], "car": r["car"], "player": r["player"], "points": int(gp_points.get(r["name"], 0))})
	rows.sort_custom(func(a, b): return a["points"] > b["points"])
	return rows
