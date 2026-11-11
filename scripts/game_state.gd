extends Node
## Global game state (autoloaded as `Game`): chosen car, settings, best times,
## progress (stars, unlocks, trophies), Grand Prix and 2-player state,
## controls and the shared UI theme.

## Settings for this computer (volume, graphics) and which player went last.
const SAVE_PATH := "user://race_track_mayhem.cfg"
## Each player's own save slot: name, progress, records, cars and preferences.
const PLAYER_PATH := "user://player_%d.cfg"
const MAX_PLAYERS := 6
const NAME_LENGTH := 12
## Track number used in online races on the host's own track.
const ONLINE_TRACK := 999
## Track number used for this week's challenge track.
const WEEKLY_TRACK := 998
## Seasonal event tracks, each only at its time of year (see EVENTS).
const HOLIDAY_TRACK := 997        # Frosty Backyard, December
const HALLOWEEN_TRACK := 996      # Pumpkin Patch Panic, October
const SUMMER_TRACK := 995         # Sandy Shores Splash, June to August
var force_holiday := false        # for testing: show the holiday track any time
var force_event := -1             # for testing: switch on this event track any time

## Seasonal events: the track card, which built-in layout it uses, the
## secret car you win by finishing it, its badge stat and its menu button.
const EVENTS := {
	HOLIDAY_TRACK: {"id": "frosty_backyard", "name": "Frosty Backyard", "room": "snowyard", "room_name": "The Snowy Yard",
		"blurb": "A holiday special! Race the garden under fresh snow, past snowmen and twinkly trees.",
		"features": ["Big jump over the frozen pond", "Snowy bumps", "Loop", "Spiral", "Slalom"],
		"stars": 2, "color": Color(0.55, 0.75, 1.0), "layout": 5, "car": "car_sleigh", "stat": "holiday",
		"button": "Holiday Race!", "button_color": Color(1.0, 0.45, 0.45),
		"tip": "Frosty Backyard: a snowy holiday track. Finish it to unlock Santa's Sleigh!"},
	HALLOWEEN_TRACK: {"id": "pumpkin_patch_panic", "name": "Pumpkin Patch Panic", "room": "spooky", "room_name": "The Spooky Garden",
		"blurb": "A Halloween special! Race the garden at night past glowing pumpkins, a friendly ghost and bats.",
		"features": ["Loop-de-loop under the moon", "Ramp jump", "Hill", "Chicane"],
		"stars": 1, "color": Color(1.0, 0.55, 0.15), "layout": 0, "car": "car_pumpkin", "stat": "halloween",
		"button": "Halloween Race!", "button_color": Color(1.0, 0.6, 0.2),
		"tip": "Pumpkin Patch Panic: a spooky night race. Finish it to unlock the Pumpkin Rider!"},
	SUMMER_TRACK: {"id": "sandy_shores_splash", "name": "Sandy Shores Splash", "room": "beach", "room_name": "The Beach",
		"blurb": "A summer special! Race along the beach past sand castles, palm trees and crabs, with the waves rolling in.",
		"features": ["Double loop", "Wavy bumps", "Zig-zags", "Jump"],
		"stars": 2, "color": Color(0.3, 0.8, 0.95), "layout": 3, "car": "car_surf", "stat": "summer",
		"button": "Beach Race!", "button_color": Color(0.5, 0.95, 1.0),
		"tip": "Sandy Shores Splash: a sunny summer beach track. Finish it to unlock the Surf Buggy!"},
}
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard"]
const QUALITY_NAMES := ["Low", "Medium", "High"]
const TOUCH_NAMES := ["Auto", "On", "Off"]
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
var touch_mode: int = 0          # on-screen buttons: 0 auto (phones/tablets), 1 on, 2 off
var fullscreen := false
var steer_assist := true         # gentle steering help for little drivers
var ghost_enabled := true        # race against your best lap
var powerups_enabled := true     # item boxes on the track
var online_times := true         # send best times to the online top-10 lists
var auto_go := false             # the car accelerates by itself (for little racers)
var tilt_steer := 0              # phones: 0 off, 1 tilt to steer, 2 tilt (flipped)
const TILT_NAMES := ["Off", "On", "On (flipped)"]

# Progress
var stars: int = 0               # earned by finishing races
var trophies: Dictionary = {}    # difficulty (int) -> best Grand Prix place (1..3)
var custom: Dictionary = {}      # car id -> {"paint": id, "sticker": id, "wheels": id}
var extras: Array = []           # special unlocks earned by doing things (see grant())
var stats: Dictionary = {}       # counters for badges: races, wins, jumps... (see Badges)
var badges: Array = []           # badge ids this player has earned
var story_beaten := 0            # Story Mode: how many bosses beaten (rooms open = this + 1)
var friend_id := ""              # this player's friend code, like K7QM2XPA
var daily := {}                  # daily challenges: {"day", "progress": {id: n}, "done": [ids], "streak", "streak_day"}
var friends: Array = []          # [{"id": friend code, "name": their name}]
var pending_join := ""           # a friend's race code to join when the online screen opens
const MAX_FRIENDS := 20

# Story Mode race in progress
var story_active := false
var story_chapter := 0
var story_super := false         # racing the Super version of the boss
var super_beaten: Array = []     # chapters whose Super boss you've beaten
var open_story := false          # the main menu opens the story map when it loads

## A new badge was just earned (the Toast layer shows a pop-up).
signal badge_earned(badge_id: String)

# Game modes
var gp_active := false
var gp_race := 0                 # which race of the cup (0..4)
var gp_points: Dictionary = {}   # racer name -> points
var gp_roster: Array = []        # [{name, car, player (0 = computer, 1 or 2)}], same for the whole cup
var last_unlocks: Array = []     # unlocks earned by the last race, shown on the results screen

# Track Builder
const MAX_CUSTOM_TRACKS := 12
const ROOM_THEMES := [["bedroom", "The Bedroom"], ["playroom", "The Playroom"], ["kitchen", "The Kitchen"], ["bathroom", "The Bathroom"], ["living_room", "The Living Room"], ["garden", "The Garden"], ["garage", "The Garage"], ["snowyard", "The Snowy Yard"], ["spooky", "The Spooky Garden"], ["beach", "The Beach"]]
var custom_tracks: Array = []    # [{"name": String, "room": String, "pieces": Array[String]}]
var editing_slot := -1           # which custom track the builder is editing (-1 = a new one)
var skip_track_select := false   # "Race It!" in the builder goes straight to the race
var builder_advanced := false    # Track Builder in Advanced mode (more pieces and tools)
var builder_free := false        # Track Builder opens in Build Anywhere (drag pieces anywhere)
var builder_handoff := {}        # a track passed between the two builders when switching

var ui_theme: Theme

## Save slots (one per player). player_slot is -1 until someone is picked.
var player_slot := -1
var player_name := ""
var player_chosen := false        # picked on the "Who's racing?" screen this time
var _own_prefs := {}              # this player's settings while an online race uses the host's


## Tilt steering: tip the phone like a steering wheel. -1 (left) .. 1 (right).
func tilt_amount() -> float:
	var g := Input.get_gravity()
	if g.length() < 1.0:
		return 0.0
	# In landscape the phone's long side is its y axis; which way is "right"
	# depends on which way round it's held.
	var side := g.y / g.length()
	if DisplayServer.screen_get_orientation() == DisplayServer.SCREEN_REVERSE_LANDSCAPE:
		side = -side
	if tilt_steer == 2:
		side = -side
	if absf(side) < 0.06:
		return 0.0   # a little dead zone so holding it "about level" goes straight
	return clampf((side - signf(side) * 0.06) * 3.0, -1.0, 1.0)


static func is_mobile() -> bool:
	return OS.has_feature("mobile")


## Show the on-screen buttons? (Auto = on phones, tablets and touch screens.)
func use_touch() -> bool:
	if touch_mode == 1:
		return true
	if touch_mode == 2:
		return false
	return is_mobile() or DisplayServer.is_touchscreen_available()


## Android's back button (or back gesture) works like Esc / Back.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for pressed in [true, false]:
			var ev := InputEventAction.new()
			ev.action = "ui_cancel"
			ev.pressed = pressed
			Input.parse_input_event(ev)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_buses()
	load_settings()
	ui_theme = _make_theme()
	get_tree().root.theme = ui_theme
	apply_display()
	get_tree().root.add_child.call_deferred(Toast.new())


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


func goto_editor(slot: int = -1) -> void:
	editing_slot = slot
	builder_handoff = {}
	goto("res://scenes/free_builder.tscn" if builder_free else "res://scenes/track_editor.tscn")


func goto_race() -> void:
	goto("res://scenes/race.tscn")


# --------------------------------------------------------------------------
# Saving
# --------------------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var has_file := cfg.load(SAVE_PATH) == OK
	master_volume = float(cfg.get_value("settings", "volume", 0.8))
	music_volume = float(cfg.get_value("settings", "music_volume", 0.6))
	sfx_volume = float(cfg.get_value("settings", "sfx_volume", 0.9))
	# Phones and tablets start on Low graphics so the game runs smoothly.
	quality = clampi(int(cfg.get_value("settings", "quality", 0 if is_mobile() else 1)), 0, 2)
	touch_mode = clampi(int(cfg.get_value("settings", "touch", 0)), 0, 2)
	online_times = bool(cfg.get_value("settings", "online_times", true))
	tilt_steer = clampi(int(cfg.get_value("settings", "tilt", 0)), 0, 2)
	fullscreen = bool(cfg.get_value("settings", "fullscreen", false))
	_apply_volume()
	if has_file and not cfg.has_section_key("players", "last") and _list_slots().is_empty():
		# A save from before save slots: keep everything as the first player.
		if cfg.has_section("progress") or cfg.has_section("records") or cfg.has_section("builder"):
			_read_player(cfg)
			player_slot = 0
			player_name = "Player 1"
			_write_player()
	var last := int(cfg.get_value("players", "last", 0 if player_slot == 0 else -1))
	if last >= 0 and FileAccess.file_exists(PLAYER_PATH % last):
		select_player(last)
	elif not _list_slots().is_empty():
		select_player(_list_slots()[0])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "volume", master_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("settings", "quality", quality)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "touch", touch_mode)
	cfg.set_value("settings", "online_times", online_times)
	cfg.set_value("settings", "tilt", tilt_steer)
	cfg.set_value("players", "last", player_slot)
	cfg.save(SAVE_PATH)
	_write_player()


# --------------------------------------------------------------------------
# Players (save slots)
# --------------------------------------------------------------------------

## Everyone with a save slot: [{slot, name, stars, difficulty, trophies}].
func list_players() -> Array:
	var out: Array = []
	for slot in _list_slots():
		var cfg := ConfigFile.new()
		if cfg.load(PLAYER_PATH % slot) != OK:
			continue
		out.append({
			"slot": slot,
			"name": String(cfg.get_value("player", "name", "Player %d" % (slot + 1))),
			"stars": int(cfg.get_value("progress", "stars", 0)),
			"difficulty": clampi(int(cfg.get_value("settings", "difficulty", 0)), 0, 2),
			"trophies": (cfg.get_value("progress", "trophies", {}) as Dictionary).size(),
		})
	return out


func _list_slots() -> Array:
	var out: Array = []
	for slot in MAX_PLAYERS:
		if FileAccess.file_exists(PLAYER_PATH % slot):
			out.append(slot)
	return out


## Makes a new player and switches to them. Returns the slot, or -1 if full.
func create_player(new_name: String, diff: int, steer_help: bool, go_by_itself := false) -> int:
	var slot := -1
	for i in MAX_PLAYERS:
		if not FileAccess.file_exists(PLAYER_PATH % i):
			slot = i
			break
	if slot < 0:
		return -1
	_read_player(ConfigFile.new())   # a fresh start
	player_slot = slot
	player_name = clean_name(new_name)
	difficulty = clampi(diff, 0, 2)
	steer_assist = steer_help
	auto_go = go_by_itself
	player_chosen = true
	save_settings()
	return slot


func select_player(slot: int) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PLAYER_PATH % slot) != OK:
		return
	_read_player(cfg)
	player_slot = slot
	player_name = String(cfg.get_value("player", "name", "Player %d" % (slot + 1)))


func rename_player(new_name: String) -> void:
	player_name = clean_name(new_name)
	save_settings()


func delete_player(slot: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PLAYER_PATH % slot))
	# Their ghost laps go too, so a new player in this slot starts fresh.
	var ghosts: String = GhostCar.DIR if slot == 0 else "%sp%d/" % [GhostCar.DIR, slot]
	for f in DirAccess.get_files_at(ghosts):
		if f.ends_with(".cfg"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ghosts + f))
	if slot == player_slot:
		player_slot = -1
		player_name = ""
		_read_player(ConfigFile.new())
		var left := _list_slots()
		if not left.is_empty():
			select_player(left[0])
		save_settings()


static func clean_name(n: String) -> String:
	n = n.strip_edges().replace("\n", " ")
	if n.length() > NAME_LENGTH:
		n = n.substr(0, NAME_LENGTH)
	return n if n != "" else "Racer"


## Loads one player's slot (an empty ConfigFile gives a fresh start).
func _read_player(cfg: ConfigFile) -> void:
	selected_car = int(cfg.get_value("player", "car", 0))
	custom_tracks = cfg.get_value("builder", "tracks", [])
	# Saves remember how many built-in tracks there were, so a picked Track
	# Builder track stays the same one when new built-in tracks are added.
	var saved_track := int(cfg.get_value("player", "track", 0))
	var built_in_then := int(cfg.get_value("player", "built_in_tracks", 6))
	if saved_track >= built_in_then:
		saved_track += Track.TRACKS.size() - built_in_then
	selected_track = clampi(saved_track, 0, track_count() - 1)
	laps = clampi(int(cfg.get_value("settings", "laps", 3)), 1, 9)
	difficulty = clampi(int(cfg.get_value("settings", "difficulty", 0)), 0, 2)
	steer_assist = bool(cfg.get_value("settings", "steer_assist", true))
	ghost_enabled = bool(cfg.get_value("settings", "ghost", true))
	powerups_enabled = bool(cfg.get_value("settings", "powerups", true))
	builder_advanced = bool(cfg.get_value("settings", "builder_advanced", false))
	builder_free = bool(cfg.get_value("settings", "builder_free", false))
	auto_go = bool(cfg.get_value("settings", "auto_go", false))
	best_times = cfg.get_value("records", "best_times", {})
	best_laps = cfg.get_value("records", "best_laps", {})
	stars = int(cfg.get_value("progress", "stars", 0))
	trophies = cfg.get_value("progress", "trophies", {})
	custom = cfg.get_value("progress", "custom", {})
	extras = cfg.get_value("progress", "extras", [])
	stats = cfg.get_value("progress", "stats", {})
	badges = cfg.get_value("progress", "badges", [])
	story_beaten = int(cfg.get_value("progress", "story", 0))
	super_beaten = cfg.get_value("progress", "super", [])
	friend_id = String(cfg.get_value("friends", "id", ""))
	daily = cfg.get_value("progress", "daily", {})
	friends = cfg.get_value("friends", "list", [])
	selected_car = clampi(selected_car, 0, CarData.count() - 1)


## Online races use the host's laps, difficulty and power-ups; keep this
## player's own settings safe (and saved) until the online session ends.
func begin_online_override(p_laps: int, p_difficulty: int, p_powerups: bool) -> void:
	if _own_prefs.is_empty():
		_own_prefs = {"laps": laps, "difficulty": difficulty, "powerups": powerups_enabled,
			"track": selected_track}
	laps = clampi(p_laps, 1, 9)
	difficulty = clampi(p_difficulty, 0, 2)
	powerups_enabled = p_powerups
	end_grand_prix()


func end_online_override() -> void:
	if _own_prefs.is_empty():
		return
	laps = _own_prefs["laps"]
	difficulty = _own_prefs["difficulty"]
	powerups_enabled = _own_prefs["powerups"]
	selected_track = _own_prefs["track"]
	_own_prefs = {}


func _write_player() -> void:
	if player_slot < 0:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "car", selected_car)
	var keep_track: int = _own_prefs.get("track", selected_track)
	if keep_track == WEEKLY_TRACK or keep_track == ONLINE_TRACK or EVENTS.has(keep_track):
		keep_track = 0   # special tracks aren't remembered as "the last track"
	cfg.set_value("player", "track", keep_track)
	cfg.set_value("player", "built_in_tracks", Track.TRACKS.size())
	cfg.set_value("settings", "laps", _own_prefs.get("laps", laps))
	cfg.set_value("settings", "difficulty", _own_prefs.get("difficulty", difficulty))
	cfg.set_value("settings", "steer_assist", steer_assist)
	cfg.set_value("settings", "ghost", ghost_enabled)
	cfg.set_value("settings", "powerups", _own_prefs.get("powerups", powerups_enabled))
	cfg.set_value("settings", "builder_advanced", builder_advanced)
	cfg.set_value("settings", "builder_free", builder_free)
	cfg.set_value("settings", "auto_go", auto_go)
	cfg.set_value("records", "best_times", best_times)
	cfg.set_value("records", "best_laps", best_laps)
	cfg.set_value("progress", "stars", stars)
	cfg.set_value("progress", "trophies", trophies)
	cfg.set_value("progress", "custom", custom)
	cfg.set_value("progress", "extras", extras)
	cfg.set_value("progress", "stats", stats)
	cfg.set_value("progress", "badges", badges)
	cfg.set_value("progress", "story", story_beaten)
	cfg.set_value("progress", "super", super_beaten)
	cfg.set_value("friends", "id", friend_id)
	cfg.set_value("progress", "daily", daily)
	cfg.set_value("friends", "list", friends)
	cfg.set_value("builder", "tracks", custom_tracks)
	cfg.save(PLAYER_PATH % player_slot)


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
	if selected_track == ONLINE_TRACK:
		return false   # someone else's track: no record to keep
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
	var key := "%s_%d" % [track_info(track_index)["id"], laps]
	return float(best_times.get(key, -1.0))


## Which online top-10 list a track uses. Built-in tracks go by name; Track
## Builder tracks go by their pieces, so everyone with the same (shared) track
## races on the same list. One list per number of laps.
func board_key(index: int, lap_count: int) -> String:
	if index < Track.TRACKS.size():
		return "%s_%d" % [Track.TRACKS[index]["id"], lap_count]
	if index == WEEKLY_TRACK:
		return "weekly%d_%d" % [int(weekly_track()["week"]), lap_count]
	if EVENTS.has(index):
		return "%s_%d" % [EVENTS[index]["id"], lap_count]
	var pieces: Array = []
	if index == ONLINE_TRACK:
		pieces = Net.race_config.get("custom", {}).get("pieces", [])
	elif index - Track.TRACKS.size() < custom_tracks.size():
		pieces = custom_tracks[index - Track.TRACKS.size()].get("pieces", [])
	return "c%s_%d" % [JSON.stringify(pieces).md5_text().substr(0, 10), lap_count]


func track_id() -> String:
	return track_info(selected_track)["id"]


func track_name() -> String:
	return track_info(selected_track)["name"]


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
	_add_action("respawn", [KEY_R], [JOY_BUTTON_BACK], [])
	_add_action("use_item", [KEY_E, KEY_Q], [JOY_BUTTON_Y], [])
	_add_action("camera", [KEY_C], [JOY_BUTTON_LEFT_SHOULDER], [])
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])


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
	return extras.has(item_id) or Unlocks.available(stars, trophies).has(item_id)


## Unlocks a special item (holiday car, badge rewards, story mode...).
## Returns true the first time.
func grant(item_id: String) -> bool:
	if extras.has(item_id):
		return false
	extras.append(item_id)
	save_settings()
	return true


## Counts something toward badges (no save: call check_badges() after).
func add_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


## Remembers that you finished this track (for the Tourist badge).
func note_track(track_key: String) -> void:
	var done: Array = stats.get("tracks", [])
	if not done.has(track_key):
		done.append(track_key)
	stats["tracks"] = done


## Awards any badges the stats have reached, saves, and returns the new ids.
## quiet: don't pop up a toast (the results screen lists them itself).
func check_badges(quiet := false) -> Array:
	if player_slot < 0:
		return []
	stats["stars"] = stars
	var fresh := Badges.newly_earned(stats, badges)
	badges.append_array(fresh)
	save_settings()
	if not quiet:
		for b in fresh:
			badge_earned.emit(b)
	return fresh


## Counts one thing and awards its badge right away, with a pop-up.
func add_stat_now(key: String, amount: int = 1) -> void:
	add_stat(key, amount)
	check_badges()


## The holidays: December 1st to January 6th.
func holiday_on() -> bool:
	return event_on(HOLIDAY_TRACK)


## Is this seasonal event on today?
##   Holiday: December 1st to January 6th.  Halloween: all of October and
##   November 1st.  Summer: June, July and August.
func event_on(index: int) -> bool:
	if index == force_event or (index == HOLIDAY_TRACK and force_holiday):
		return true
	var d := Time.get_date_dict_from_system()
	var m := int(d["month"])
	var day := int(d["day"])
	match index:
		HOLIDAY_TRACK:
			return m == 12 or (m == 1 and day <= 6)
		HALLOWEEN_TRACK:
			return m == 10 or (m == 11 and day == 1)
		SUMMER_TRACK:
			return m >= 6 and m <= 8
	return false


## The seasonal event tracks that are on today.
func events_on() -> Array:
	return EVENTS.keys().filter(func(i): return event_on(i))


## The paint/sticker/wheels picked for a car (ids), with defaults.
func custom_for(car_id: String) -> Dictionary:
	var c: Dictionary = custom.get(car_id, {})
	return {"paint": c.get("paint", "paint_original"), "sticker": c.get("sticker", "sticker_none"), "wheels": c.get("wheels", "wheels_classic"),
		# Car Designer: your own colours ("" = the paint job's), where the
		# sticker sits (-1 front .. 1 back), how big it is, and the car's name.
		"color": String(c.get("color", "")), "accent": String(c.get("accent", "")),
		"sticker_at": float(c.get("sticker_at", 0.0)), "sticker_size": float(c.get("sticker_size", 1.0)),
		"nickname": String(c.get("nickname", ""))}


func set_custom(car_id: String, slot: String, item_id: Variant) -> void:
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
	story_active = false   # leaving for another mode ends a story race too


# --------------------------------------------------------------------------
# Daily challenges (see Daily)
# --------------------------------------------------------------------------

## Today's goals, starting a fresh day's progress if the date changed.
func daily_goals() -> Array:
	var day := Daily.today()
	if int(daily.get("day", -1)) != day:
		daily["day"] = day
		daily["progress"] = {}
		daily["done"] = []
	return Daily.goals_for(day)


func daily_progress(g: Dictionary) -> int:
	return mini(int((daily.get("progress", {}) as Dictionary).get(g["id"], 0)), int(g["goal"]))


func daily_streak() -> int:
	# The streak ends if a whole day went by with nothing done.
	if Daily.today() - int(daily.get("streak_day", -10)) > 1:
		return 0
	return int(daily.get("streak", 0))


## Counts a finished race toward today's goals. Returns the goals just
## completed ({"text", "stars"}); the caller hands out the stars (award_stars).
func daily_race(race: Dictionary) -> Array:
	if player_slot < 0:
		return []
	var goals := daily_goals()
	var progress: Dictionary = daily.get("progress", {})
	var done: Array = daily.get("done", [])
	var fresh: Array = []
	for g in goals:
		if done.has(g["id"]):
			continue
		var n := Daily.amount(g, race)
		if n <= 0:
			continue
		progress[g["id"]] = int(progress.get(g["id"], 0)) + n
		if int(progress[g["id"]]) >= int(g["goal"]):
			done.append(g["id"])
			fresh.append({"text": g["text"], "stars": Daily.STARS_EACH})
	daily["progress"] = progress
	daily["done"] = done
	if not fresh.is_empty():
		var today := Daily.today()
		if int(daily.get("streak_day", -10)) != today:
			daily["streak"] = daily_streak() + 1
			daily["streak_day"] = today
		add_stat("daily", fresh.size())
		if done.size() >= goals.size():
			fresh.append({"text": "All three done today!", "stars": Daily.ALL_BONUS})
		stats["streak_best"] = maxi(int(stats.get("streak_best", 0)), int(daily["streak"]))
	save_settings()
	return fresh


## This player's friend code (made the first time it's needed).
func my_friend_code() -> String:
	if player_slot < 0:
		return ""
	if friend_id == "":
		const LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
		for i in 8:
			friend_id += LETTERS[randi() % LETTERS.length()]
		save_settings()
	return friend_id


func is_friend(code: String) -> bool:
	return friends.any(func(f: Dictionary) -> bool: return f["id"] == code)


## Adds a friend by their code. Returns "" or a message saying what's wrong.
func add_friend(code: String, friend_name: String = "") -> String:
	code = code.strip_edges().to_upper().replace(" ", "")
	var ok := code.length() == 8
	for ch in code:
		if not ((ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9")):
			ok = false
	if not ok:
		return "Friend codes have 8 letters and numbers."
	if code == my_friend_code():
		return "That's your own code!"
	if is_friend(code):
		return "Already your friend!"
	if friends.size() >= MAX_FRIENDS:
		return "You have %d friends already! Remove one first." % MAX_FRIENDS
	friends.append({"id": code, "name": friend_name.substr(0, NAME_LENGTH) if friend_name != "" else "New friend"})
	save_settings()
	add_stat_now("friends")
	return ""


func remove_friend(code: String) -> void:
	friends = friends.filter(func(f: Dictionary) -> bool: return f["id"] != code)
	save_settings()


## Story Mode: race the boss of chapter i (pick your car first).
func start_story(i: int, super_boss := false) -> void:
	end_grand_prix()
	story_active = true
	story_super = super_boss
	story_chapter = clampi(i, 0, Story.count() - 1)
	selected_track = story_chapter
	skip_track_select = true
	goto_garage()


## You finished ahead of the boss. Returns true the first time.
func beat_boss(i: int) -> bool:
	if story_super:
		if super_beaten.has(i):
			return false
		super_beaten.append(i)
		add_stat("super_bosses")
		return true
	if i < story_beaten:
		return false
	story_beaten = i + 1
	add_stat("bosses")
	return true


## Racers sorted by Grand Prix points (most first).
func gp_standings() -> Array:
	var rows: Array = []
	for r in gp_roster:
		rows.append({"name": r["name"], "car": r["car"], "player": r["player"], "points": int(gp_points.get(r["name"], 0))})
	rows.sort_custom(func(a, b): return a["points"] > b["points"])
	return rows


# --------------------------------------------------------------------------
# All tracks: the built-in ones, then the player's own from the Track Builder
# --------------------------------------------------------------------------

func track_count() -> int:
	return Track.TRACKS.size() + custom_tracks.size()


func is_custom_track(index: int) -> bool:
	return index >= Track.TRACKS.size() and index != WEEKLY_TRACK and not EVENTS.has(index)


# --------------------------------------------------------------------------
# Weekly challenge: a new Track Builder-style track every Monday. It's made
# from the week number, so everyone's game builds exactly the same track.
# --------------------------------------------------------------------------

const _WEEK_ADJ := ["Wacky", "Turbo", "Twisty", "Mega", "Zippy", "Loopy", "Bouncy", "Crazy", "Super", "Wild", "Speedy", "Jumpy"]
const _WEEK_NOUN := ["Whirl", "Dash", "Rally", "Run", "Rumble", "Raceway", "Circuit", "Sprint", "Scramble", "Zoom", "Twister", "Blast"]
var _weekly_cache: Dictionary = {}


## The week number (weeks start on Monday).
static func week_number() -> int:
	# Day 0 of Unix time was a Thursday; shift so each week starts on Monday.
	return int(floor((Time.get_unix_time_from_system() + 3.0 * 86400.0) / (7.0 * 86400.0)))


## This week's challenge: {"week", "name", "room", "pieces"}.
func weekly_track() -> Dictionary:
	var week := week_number()
	if int(_weekly_cache.get("week", -1)) == week:
		return _weekly_cache
	var rng := RandomNumberGenerator.new()
	var pieces: Array = []
	# Try a few variations of this week's track until one doesn't run into itself.
	for attempt in 40:
		rng.seed = week * 1000 + attempt
		pieces = _random_pieces(rng)
		var t := Track.new()
		t.custom = true
		t.custom_pieces = pieces
		t._build_closed_layout()
		t._resample()
		var clashes := t.count_clashes()
		t.free()
		if clashes == 0:
			break
	rng.seed = week
	var title := "%s %s" % [_WEEK_ADJ[rng.randi() % _WEEK_ADJ.size()], _WEEK_NOUN[rng.randi() % _WEEK_NOUN.size()]]
	var room: String = ROOM_THEMES[week % ROOM_THEMES.size()][0]
	_weekly_cache = {"week": week, "name": title, "room": room, "pieces": pieces}
	return _weekly_cache


static func _random_pieces(rng: RandomNumberGenerator) -> Array:
	var stunts := ["loop", "corkscrew", "jump", "big_jump", "spiral", "hill", "bumps", "wiggles"]
	var turns := ["left", "right", "bend_left", "bend_right"]
	var out: Array = ["straight", "boost"]
	var n := rng.randi_range(9, 13)
	var used_stunts := 0
	while out.size() < n:
		var r := rng.randf()
		if r < 0.42:
			out.append(turns[rng.randi() % turns.size()])
		elif r < 0.75 and used_stunts < 5:
			out.append(stunts[rng.randi() % stunts.size()])
			used_stunts += 1
		elif r < 0.88:
			out.append("straight")
		else:
			out.append("boost")
	# Always at least one loop or jump: it's a challenge!
	if not (out.has("loop") or out.has("jump") or out.has("big_jump")):
		out.insert(rng.randi_range(2, out.size() - 1), ["loop", "jump"][rng.randi() % 2])
	return out


static func room_name(theme: String) -> String:
	for r in ROOM_THEMES:
		if r[0] == theme:
			return r[1]
	return "The Bedroom"


## Card details for any track (built-in or custom).
func track_info(index: int) -> Dictionary:
	if index < Track.TRACKS.size():
		return Track.TRACKS[maxi(index, 0)]
	if index == ONLINE_TRACK:
		return custom_track_info(Net.race_config.get("custom", {}), "online_custom", "A track built by the host!")
	if EVENTS.has(index):
		var info: Dictionary = EVENTS[index].duplicate()
		info["event"] = true
		info["holiday"] = index == HOLIDAY_TRACK
		return info
	if index == WEEKLY_TRACK:
		var w := weekly_track()
		var info := custom_track_info(w, "weekly_%d" % w["week"], "This week's challenge! A brand new track every Monday.")
		info["custom"] = false
		info["weekly"] = true
		info["color"] = Color(0.95, 0.75, 0.15)
		return info
	var slot := index - Track.TRACKS.size()
	if slot >= custom_tracks.size():
		return Track.TRACKS[0]
	var t: Dictionary = custom_tracks[slot]
	var n := (t.get("pieces", []) as Array).size()
	var blurb := ("Shared by %s! %d pieces." % [t["by"], n]) if t.has("by") else ("A track YOU built! %d pieces." % n)
	return custom_track_info(t, "custom_%d_%s" % [slot, String(t.get("name", "")).to_snake_case()], blurb)


static func custom_track_info(t: Dictionary, track_key: String, blurb: String) -> Dictionary:
	var pieces: Array = t.get("pieces", [])
	var feats: Array = []
	for id in pieces:
		var nm: String = Track.piece_info(String(id)).get("name", "")
		if nm != "" and not feats.has(nm) and not nm in ["Straight", "Turn Left", "Turn Right", "Bend Left", "Bend Right"]:
			feats.append(nm)
	if feats.is_empty():
		feats.append("Built by you!")
	return {
		"id": track_key,
		"name": t.get("name", "My Track"),
		"room": t.get("room", "bedroom"),
		"room_name": room_name(t.get("room", "bedroom")),
		"blurb": blurb,
		"features": feats.slice(0, 5),
		"stars": 0,
		"color": Color(0.95, 0.55, 0.15),
		"custom": true,
		"by": String(t.get("by", "")),
	}
