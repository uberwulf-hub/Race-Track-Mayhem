extends Node3D
## Runs a race: builds the themed room and the track, puts cars on the grid,
## does the big zoom-in intro and the Ready-Set-GO countdown, then keeps score
## until everyone crosses the finish line.
##
## The player gets a "View": their camera, HUD, engine sounds and rumble.
## (Racing friends happens online, each on their own device.)
## In a Grand Prix it also hands out points and moves on to the next track.

enum State { INTRO, COUNTDOWN, RACING, FINISHED }
enum CamMode { CHASE, HIGH, INTRO, ORBIT }

const INTRO_HOLD := 1.6        # seconds looking at the whole room
const INTRO_ZOOM := 3.6        # seconds zooming down to the car
const AI_NAMES := ["Zoomy", "Vroomer", "Speedy", "Turbo Tom", "Rally Rae"]
const RESULTS_WAIT := 25.0     # 2 players: show results this long after the first finishes

var track: Track
var room: Room
var racers: Array[Racer] = []
var humans: Array[Racer] = []
var player: Racer               # player 1 (kept for older code and tests)
var views: Array[View] = []
var hud: RaceHud                # player 1's HUD
var camera: Camera3D            # player 1's camera
var skid_marks: SkidMarks
var ghost: GhostCar
var powerups: PowerUps

var state := State.INTRO
var _state_time := 0.0
var _race_clock := 0.0
var _countdown_step := -1
var _intro_from := Vector3.ZERO
var _intro_look := Vector3.ZERO
var _results_shown := false
var _first_human_done := -1.0
var _wall_bumps := 0              # the player's wall bumps this race (Smooth Driver badge)
var _finish_order: Array[Racer] = []

var _pause_menu: Control
var _results_panel: Control
var _flames: Dictionary = {}         # racer -> CPUParticles3D
var _ai_engines: Dictionary = {}     # racer -> AudioStreamPlayer3D
var _pass_side: Dictionary = {}      # racer -> was it ahead of player 1?

# Online
var online := false
var _by_key: Dictionary = {}         # net key -> Racer
var _net_go := false                 # the host said start the countdown
var _send_timer := 0.0
var touch: TouchControls


## Everything that belongs to one human player's half of the screen.
class View:
	var racer: Racer
	var index := 0                    # 0 = player 1, 1 = player 2
	var camera: Camera3D
	var hud: RaceHud
	var cam_mode := 2                 # CamMode.INTRO
	var cam_up := Vector3.UP
	var shake := 0.0
	var orbit_angle := 0.0
	var audio: CarAudio
	var reverse_time := 0.0
	var dof: CameraAttributesPractical


func _ready() -> void:
	# The race node keeps listening while paused (so ESC can un-pause);
	# everything that moves is pausable.
	process_mode = Node.PROCESS_MODE_ALWAYS
	online = Net.active and Net.in_race
	track = Track.for_index(Game.selected_track)
	track.name = "Track"
	add_child(track)
	track.build()
	skid_marks = SkidMarks.new()
	track.add_child(skid_marks)

	room = Room.create(Game.track_info(Game.selected_track)["room"])
	room.name = "Room"
	add_child(room)
	room.build(track)
	Spectators.build(room, track)

	_spawn_racers()
	_intro_from = room.overview_position()
	var tr := track.get_aabb_xz()
	_intro_look = Vector3(tr.get_center().x, 0.0, tr.get_center().y)
	_build_views()
	player = humans[0]
	hud = views[0].hud
	camera = views[0].camera

	if humans.size() == 1 and Game.ghost_enabled and not online:
		ghost = GhostCar.new()
		add_child(ghost)
		ghost.setup(track, Game.track_id(), player)

	if Game.powerups_enabled:
		powerups = PowerUps.new()
		add_child(powerups)
		powerups.setup(track, racers)
		powerups.item_got.connect(_on_item_got)
		powerups.item_hit.connect(_on_item_hit)
		if online:
			powerups.online = true
			powerups.item_used.connect(func(r: Racer, kind: String, side: float): Net.send_item(r.net_key, kind, side))
			powerups.item_hit.connect(func(v: Racer, kind: String, by: Racer):
				if not v.remote:
					Net.send_hit(v.net_key, kind, by.net_key if by else ""))
		powerups.process_mode = Node.PROCESS_MODE_PAUSABLE

	for n: Node in [track, room]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	for r in racers:
		r.process_mode = Node.PROCESS_MODE_PAUSABLE
		if room.evening:
			r.model.set_headlights(true)
	_build_pause_menu()
	_setup_ai_engines()
	# On-screen buttons for phones and tablets (one player).
	if Game.use_touch() and humans.size() == 1:
		touch = TouchControls.new().setup()
		touch.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(touch)
		for v in views:
			v.hud.touch = true
	# Each room has its own race song (custom tracks use their room's song).
	Sfx.play_music("race_" + String(Game.track_info(Game.selected_track)["room"]), -9.0)
	_set_state(State.INTRO)
	if online:
		Net.states_received.connect(_on_net_states)
		Net.item_used.connect(_on_net_item)
		Net.item_hit.connect(_on_net_hit)
		Net.go_received.connect(func(): _net_go = true)
		Net.player_left.connect(_on_player_left)
		Net.emote_received.connect(_on_emote)
		Net.rematch_voted.connect(_on_rematch_vote)
		Net.race_scene_ready()


# ---------------------------------------------------------------------------
# Setting up
# ---------------------------------------------------------------------------

## Who's racing: the humans plus computer cars. In a Grand Prix the same
## line-up is kept for all five races.
func _make_roster() -> Array:
	if online:
		# The host's line-up: my car is player 1, the rest are driven elsewhere
		# (the computer cars run on the host).
		var out: Array = []
		var me := "p%d" % Net.my_id()
		for e: Dictionary in Net.race_config["roster"]:
			var mine: bool = e["key"] == me or (e.get("ai", false) and Net.is_host)
			var is_person: bool = not e.get("ai", false)
			out.append({"name": e["name"], "car": e["car"], "look": e.get("look", {}), "key": e["key"],
				"player": 1 if e["key"] == me else 0, "remote": not mine, "human": is_person})
		return out
	if Game.gp_active and not Game.gp_roster.is_empty():
		return Game.gp_roster
	var roster: Array = []
	var me := Game.player_name if Game.player_name != "" else "You"
	roster.append({"name": me, "car": Game.selected_car, "player": 1})
	var pool: Array[int] = []
	for i in CarData.count():
		if not CarData.get_car(i).get("secret", false) and i != Game.selected_car:
			pool.append(i)
	pool.shuffle()
	var names := AI_NAMES.filter(func(n): return String(n).to_lower() != me.to_lower())
	names.shuffle()
	var k := 0
	while roster.size() < 5:
		roster.append({"name": names[k % names.size()], "car": pool[k % pool.size()], "player": 0})
		k += 1
	if Game.gp_active:
		Game.gp_roster = roster
	return roster


func _spawn_racers() -> void:
	var roster := _make_roster()
	# Shuffle the grid, but keep the humans in the middle so it's fair.
	var ai: Array = roster.filter(func(e): return int(e["player"]) == 0)
	var people: Array = roster.filter(func(e): return int(e["player"]) > 0)
	ai.shuffle()
	var order: Array = ai.duplicate()
	for i in people.size():
		order.insert(mini(1 + i * 2, order.size()), people[i])
	if online:
		order = roster   # the host already set the grid

	var base_skill: float = [0.85, 0.93, 1.0][Game.difficulty]
	for slot in order.size():
		var entry: Dictionary = order[slot]
		var pnum := int(entry["player"])
		var car_def := CarData.get_car(int(entry["car"]))
		var r := Racer.new()
		add_child(r)
		var look: Dictionary = Game.custom_for(car_def["id"]) if pnum > 0 else entry.get("look", {})
		r.setup(track, car_def, pnum > 0, entry["name"], look)
		r.player_index = pnum
		r.human = pnum > 0 or entry.get("human", false)
		r.remote = entry.get("remote", false)
		r.net_key = entry.get("key", "")
		if r.net_key != "":
			_by_key[r.net_key] = r
		r.skid_marks = skid_marks
		r.laps_to_win = Game.laps
		r.ai_skill = clampf(base_skill + randf_range(-0.04, 0.04), 0.7, 1.0)
		r.rubber_band = base_skill
		var row := slot / 2
		var lane := -1.6 if slot % 2 == 0 else 1.6
		r.place_on_grid(-4.0 - row * 5.5 - (slot % 2) * 2.0, lane)
		r.lap_completed.connect(_on_lap)
		r.finished.connect(_on_finished)
		r.crashed.connect(_on_crash)
		r.respawned.connect(_on_respawned)
		r.boosted.connect(_on_boost)
		r.landed.connect(_on_landed)
		r.bumped.connect(_on_bumped)
		racers.append(r)
		_add_flame(r)
		if pnum > 0:
			humans.append(r)
	humans.sort_custom(func(a: Racer, b: Racer) -> bool: return a.player_index < b.player_index)


func _build_views() -> void:
	for i in humans.size():
		var v := View.new()
		v.racer = humans[i]
		v.index = i
		var parent: Node = self
		var cam := Camera3D.new()
		cam.fov = 64.0
		cam.near = 0.1
		cam.far = 700.0
		cam.doppler_tracking = Camera3D.DOPPLER_TRACKING_PHYSICS_STEP
		v.dof = CameraAttributesPractical.new()
		cam.attributes = v.dof
		parent.add_child(cam)
		cam.current = true
		cam.global_position = _intro_from
		cam.look_at(_intro_look, Vector3.UP)
		v.camera = cam
		var h := RaceHud.new()
		parent.add_child(h)
		h.setup(track, racers, humans[i])
		h.show_title(true)
		v.hud = h
		v.audio = CarAudio.new()
		add_child(v.audio)
		v.audio.setup(humans[i], 0.0)
		for n: Node in [cam, h]:
			n.process_mode = Node.PROCESS_MODE_PAUSABLE
		views.append(v)


func _add_flame(r: Racer) -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.22
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3(0, 0.3, 1).normalized()
	p.spread = 15.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.22
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 0.6, 1.0))
	grad.set_color(1, Color(1.0, 0.2, 0.0, 0.0))
	grad.add_point(0.4, Color(1.0, 0.55, 0.1, 0.9))
	p.color_ramp = grad
	p.position = Vector3(0, 0.45, 1.15)
	r.add_child(p)
	_flames[r] = p


func _view_for(r: Racer) -> View:
	for v in views:
		if v.racer == r:
			return v
	return null


# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

func _set_state(s: State) -> void:
	state = s
	_state_time = 0.0
	match s:
		State.INTRO:
			for v in views:
				v.cam_mode = CamMode.INTRO
		State.COUNTDOWN:
			_countdown_step = -1
			for v in views:
				v.cam_mode = CamMode.CHASE
				v.hud.hide_title()
				v.hud.set_race_ui_visible(true)
		State.RACING:
			for r in racers:
				r.controls_enabled = true
			for v in views:
				v.hud.fade_hint()
		State.FINISHED:
			pass


func _all_huds(f: Callable) -> void:
	for v in views:
		f.call(v.hud)


func _process(delta: float) -> void:
	var quiet := state == State.INTRO or get_tree().paused
	for v in views:
		v.audio.update(quiet, state == State.RACING)
	_update_ai_sounds()
	if get_tree().paused:
		return
	_state_time += delta
	match state:
		State.INTRO:
			# Online, everyone waits for the host so the countdown is together.
			if _state_time > INTRO_HOLD + INTRO_ZOOM and (not online or _net_go):
				_set_state(State.COUNTDOWN)
			elif online and _state_time > INTRO_HOLD + INTRO_ZOOM:
				_all_huds(func(h: RaceHud): h.flash_message("Waiting for the others...", Color(0.7, 0.9, 1.0), 0.3))
		State.COUNTDOWN:
			var step := int(floor(_state_time / 1.0))
			if step != _countdown_step:
				_countdown_step = step
				match step:
					0:
						_all_huds(func(h: RaceHud): h.show_countdown("READY", Color(1.0, 0.35, 0.3)))
						track.set_start_lights(2)
						Sfx.play("beep")
						Sfx.play("voice_ready")
					1:
						_all_huds(func(h: RaceHud): h.show_countdown("SET", Color(1.0, 0.8, 0.25)))
						track.set_start_lights(3)
						Sfx.play("beep")
						Sfx.play("voice_set")
					2:
						_all_huds(func(h: RaceHud): h.show_countdown("GO!", Color(0.35, 1.0, 0.4)))
						track.set_start_lights(4)
						Sfx.play("voice_go")
						Sfx.play("go")
						for h in humans:
							if Input.is_action_pressed(h.action("accelerate")):
								Sfx.play("rev")
								break
						_set_state(State.RACING)
		State.RACING:
			if _first_human_done >= 0.0 and _race_clock - _first_human_done > RESULTS_WAIT:
				_set_state(State.FINISHED)
		State.FINISHED:
			if not _results_shown and _state_time > 3.0:
				_show_results()
			elif _results_shown:
				_refresh_results()
	_update_flames()
	for v in views:
		_update_view_extras(v, delta)
		_update_camera(v, delta)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if state == State.RACING or state == State.FINISHED:
		_race_clock += delta
		for r in racers:
			if not r.has_finished:
				r.race_time = _race_clock
	_update_rubber_band(delta)
	if powerups and (state == State.RACING or state == State.FINISHED):
		powerups.update(delta)
	for i in racers.size():
		for j in range(i + 1, racers.size()):
			if racers[i].remote and racers[j].remote:
				continue   # their own computers sort that out
			racers[i].bump_with(racers[j])
	_update_places()
	if online:
		_send_timer -= delta
		if _send_timer <= 0.0:
			_send_timer = Net.SEND_RATE
			var states: Array = []
			for r in racers:
				if not r.remote:
					states.append(r.net_state())
			Net.send_states(states)


func _update_places() -> void:
	var sorted := racers.duplicate()
	sorted.sort_custom(func(a: Racer, b: Racer) -> bool: return a.progress() > b.progress())
	for i in sorted.size():
		(sorted[i] as Racer).place = i + 1


## Keeps the computer cars close to the leading human so races stay exciting.
func _update_rubber_band(delta: float) -> void:
	var base: float = [0.85, 0.93, 1.0][Game.difficulty]
	var people := racers.filter(func(r: Racer) -> bool: return r.human)
	var lead: Racer = people[0] if not people.is_empty() else humans[0]
	for h: Racer in people:
		if h.total > lead.total:
			lead = h
	var all_done := people.all(func(h: Racer) -> bool: return h.has_finished)
	for r in racers:
		if r.is_player or r.human or r.remote:
			continue
		var gap := r.total - lead.total
		var target := base
		if all_done:
			target = 1.0
		elif gap > 30.0:
			target = base - clampf((gap - 30.0) / 150.0, 0.0, 0.18)
		elif gap < -25.0:
			target = base + clampf((-gap - 25.0) / 120.0, 0.0, 0.15)
		r.rubber_band = lerpf(r.rubber_band, target, minf(1.0, delta * 0.8))


func _unhandled_input(event: InputEvent) -> void:
	# Online: number keys 1-6 send a quick emote.
	if online and event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_6:
			Net.send_emote(k - KEY_1)
			return
	if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and not _results_shown:
		_toggle_pause()
		return
	if state != State.RACING and state != State.COUNTDOWN:
		return
	if event.is_action_pressed("camera"):
		for v in views:
			if v.cam_mode == CamMode.CHASE or v.cam_mode == CamMode.HIGH:
				v.cam_mode = CamMode.HIGH if v.cam_mode == CamMode.CHASE else CamMode.CHASE
	for h in humans:
		if event.is_action_pressed(h.action("respawn")) and not h.has_finished:
			h.manual_respawn()
		if powerups and state == State.RACING and event.is_action_pressed(h.action("use_item")) and h.item != "":
			var used := h.item
			powerups.use_item(h)
			Game.add_stat("items")
			var v := _view_for(h)
			if v:
				v.hud.flash_message(PowerUps.NAMES[used].to_upper() + "!", PowerUps.COLORS[used], 0.6)


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func _on_lap(r: Racer, lap: int, lap_time: float) -> void:
	if r == player and ghost:
		ghost.lap_finished(lap_time)
	var v := _view_for(r)
	if v == null or r.has_finished or lap >= r.laps_to_win:
		return
	if lap == r.laps_to_win - 1:
		v.hud.flash_message("FINAL LAP!", Color(1.0, 0.4, 0.3))
		Sfx.play("final_lap")
		Sfx.play("voice_final")
	else:
		v.hud.flash_message("LAP %d" % (lap + 1), Color(1.0, 0.95, 0.4))
		Sfx.play("lap")


func _on_finished(r: Racer) -> void:
	_finish_order.append(r)
	var v := _view_for(r)
	if v == null:
		return
	r.controls_enabled = false
	if r.place == 1:
		v.hud.flash_message("YOU WIN!!!" if humans.size() == 1 else "%s WINS!!!" % r.racer_name.to_upper(), Color(1.0, 0.85, 0.15), 2.5)
		Sfx.play("win")
		get_tree().create_timer(1.2).timeout.connect(func(): Sfx.play("voice_win"))
		_spawn_confetti(r)
	else:
		v.hud.flash_message("FINISHED %s!" % Game.ordinal(r.place), Color(0.6, 0.9, 1.0), 2.5)
		Sfx.play("finish")
	v.cam_mode = CamMode.ORBIT
	v.orbit_angle = 0.0
	_rumble(v, 0.3, 0.3, 0.4)
	if _first_human_done < 0.0:
		_first_human_done = _race_clock
	if humans.all(func(h: Racer) -> bool: return h.has_finished):
		_set_state(State.FINISHED)


const CRASH_MESSAGES := {
	"loop": "MAYHEM!  Too slow for the loop!",
	"jump": "WHOOPS!  Missed the jump!",
	"corner": "WHOA!  Too fast for that turn!",
	"wall": "BONK!  Slow down for the turns!",
	"wall_hard": "SPIN OUT!  Way too fast!",
}


func _on_crash(r: Racer, reason: String) -> void:
	var v := _view_for(r)
	if r == player:
		_wall_bumps += 1
	if reason.begins_with("wall"):
		# Bounced off the rail: no fade, the car is still on the track.
		if v:
			v.hud.flash_message(CRASH_MESSAGES[reason], Color(1.0, 0.6, 0.3), 0.7)
			v.shake = maxf(v.shake, 0.3 if reason == "wall_hard" else 0.18)
			_rumble(v, 0.6, 0.4, 0.3)
			Sfx.play("bump", 0.8)
			if reason == "wall_hard":
				Sfx.play("skid", 1.0, -4.0)
		return
	if v:
		v.hud.flash_message(CRASH_MESSAGES.get(reason, "MAYHEM!"), Color(1.0, 0.45, 0.3), 0.9)
		Sfx.play("crash")
		v.shake = 0.4
		_rumble(v, 0.8, 0.6, 0.5)
		if r == player and ghost:
			ghost.lap_spoiled()
		# Fade to black while the car tumbles, then back in once it's on the track.
		get_tree().create_timer(0.8).timeout.connect(func(): v.hud.fade_out())
	else:
		Sfx.play("crash", 1.2, -10.0)


func _on_respawned(r: Racer) -> void:
	var v := _view_for(r)
	if v == null:
		return
	var pose := _chase_pose(r)
	v.camera.global_position = pose[0]
	v.cam_up = pose[2]
	v.hud.fade_in()
	if r.skipped_ahead:
		r.skipped_ahead = false
		v.hud.flash_message("Tricky! Let's hop past that bit!", Color(0.5, 1.0, 0.6), 1.6)
	else:
		v.hud.flash_message("Get Back to the Race!", Color(0.5, 1.0, 0.6), 1.4)
	if r == player and ghost:
		ghost.lap_spoiled()


func _on_boost(r: Racer) -> void:
	var v := _view_for(r)
	if v:
		Sfx.play("boost")
		v.hud.flash_message("BOOST!", Color(0.4, 1.0, 1.0), 0.5)
		_rumble(v, 0.3, 0.0, 0.25)


func _on_item_got(r: Racer, kind: String) -> void:
	if _view_for(r):
		Sfx.play("pickup")


const HIT_MESSAGES := {
	"bubble": "BUBBLED!",
	"ball": "BONK!",
	"balloon": "SPLASH!",
	"shield": "Your shield saved you!",
}


func _on_item_hit(victim: Racer, kind: String, by: Racer) -> void:
	var v := _view_for(victim)
	if v:
		v.hud.flash_message(HIT_MESSAGES.get(kind, "WHOA!"), Color(0.6, 0.9, 1.0) if kind == "shield" else Color(1.0, 0.5, 0.4), 1.0)
		v.shake = maxf(v.shake, 0.25)
		_rumble(v, 0.5, 0.4, 0.3)
	var a := _view_for(by)
	if a and by != victim and kind != "shield":
		a.hud.flash_message("GOT 'EM!", Color(1.0, 0.9, 0.3), 0.8)


func _on_landed(r: Racer, h: float) -> void:
	if r == player:
		Game.add_stat("jumps")
	var v := _view_for(r)
	if v:
		v.shake = maxf(v.shake, clampf(h * 0.12, 0.1, 0.45))
		_rumble(v, 0.2, clampf(h * 0.3, 0.2, 0.8), 0.2)


func _on_bumped(r: Racer, h: float) -> void:
	var v := _view_for(r)
	if v:
		v.shake = maxf(v.shake, clampf(h * 0.15, 0.08, 0.3))
		_rumble(v, clampf(h * 0.5, 0.2, 0.7), 0.1, 0.15)


## Controller rumble for a player (their own controller in 2-player mode).
func _rumble(v: View, weak: float, strong: float, seconds: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var device: int = pads[0] if humans.size() == 1 else (v.index if pads.has(v.index) else -1)
	if device >= 0:
		Input.start_joy_vibration(device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), seconds)


func _update_flames() -> void:
	for r: Racer in _flames:
		var p: CPUParticles3D = _flames[r]
		p.emitting = (r.boost_timer > 0.0 or r.turbo_on) and r.mode != Racer.Mode.FALLING


## Wrong-way warning and arrows for cars right behind you.
func _update_view_extras(v: View, delta: float) -> void:
	var r := v.racer
	if state == State.RACING and not r.has_finished and r.speed < -2.0 and r.mode == Racer.Mode.DRIVING:
		v.reverse_time += delta
	else:
		v.reverse_time = 0.0
	v.hud.set_wrong_way(v.reverse_time > 1.2)
	var near: Array = []
	if state == State.RACING and not r.has_finished:
		for o in racers:
			if o == r or o.mode != Racer.Mode.DRIVING:
				continue
			var behind := r.total - o.total
			if behind > 1.5 and behind < 14.0:
				near.append([clampf((o.lateral - r.lateral) / Track.HALF_WIDTH, -1.0, 1.0), 1.0 - behind / 14.0, o.car["body"]])
	v.hud.set_nearby(near)
	v.hud.set_item(r.item if powerups else "", r.shield_timer > 0.0)
	if touch:
		touch.visible = state != State.INTRO and not _results_shown and not _pause_menu.visible
		touch.set_item_ready(r.item != "")
	v.hud.set_incoming(powerups.incoming_for(r) if powerups and state == State.RACING and not r.has_finished else {})
	if r == player and ghost:
		ghost.follow(r.race_time - r.lap_start_time, state == State.RACING and not r.has_finished)


func _spawn_confetti(r: Racer) -> void:
	var p := CPUParticles3D.new()
	p.amount = 300
	p.lifetime = 4.0
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 22.0
	p.gravity = Vector3(0, -9.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.35, 0.25)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	p.mesh = mesh
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	grad.colors = PackedColorArray([Color.RED, Color.YELLOW, Color(0.2, 1, 0.3), Color(0.2, 0.6, 1), Color.MAGENTA])
	p.color_initial_ramp = grad
	add_child(p)
	p.global_position = r.global_position + Vector3.UP * 1.0
	p.emitting = true


# ---------------------------------------------------------------------------
# Cameras
# ---------------------------------------------------------------------------

func _chase_pose(r: Racer) -> Array:
	var frame := track.sample(r.s)
	var fwd := -frame.basis.z
	var up := frame.basis.y
	var car_pos := r.global_position
	var pos := car_pos - fwd * 5.8 + up * 2.7
	var look := car_pos + fwd * 3.0 + up * 0.7
	return [pos, look, up]


func _update_camera(v: View, delta: float) -> void:
	var r := v.racer
	var cam := v.camera
	var k := 1.0 - exp(-delta * 10.0)
	match v.cam_mode:
		CamMode.INTRO:
			var pose := _chase_pose(r)
			var t := clampf((_state_time - INTRO_HOLD) / INTRO_ZOOM, 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)   # smooth start & stop
			e = e * e * (3.0 - 2.0 * e)
			# Swoop: fly in on a curve rather than a straight line.
			var goal: Vector3 = pose[0]
			var mid := (_intro_from + goal) * 0.5 + Vector3(0, 18.0, 0)
			var a := _intro_from.lerp(mid, e)
			var b := mid.lerp(goal, e)
			cam.global_position = a.lerp(b, e)
			var look: Vector3 = _intro_look.lerp(pose[1], e)
			v.cam_up = Vector3.UP
			cam.fov = lerpf(55.0, 64.0, e)
			cam.look_at(look, v.cam_up)
			# Tilt-shift blur: everything looks like a tiny model.
			_set_tilt_shift(v, cam.global_position.distance_to(look), 1.0 - e * 0.85)
		CamMode.CHASE:
			_set_tilt_shift(v, 0.0, 0.0)
			var pose := _chase_pose(r)
			if r.mode == Racer.Mode.FALLING:
				_safe_look_at(cam, r.global_position, v.cam_up)
				return
			cam.global_position = cam.global_position.lerp(pose[0], k)
			v.cam_up = v.cam_up.slerp(pose[2], 1.0 - exp(-delta * 4.0)).normalized()
			var fov_target := 64.0 + clampf(r.speed - 25.0, 0.0, 30.0) * 0.35
			cam.fov = lerpf(cam.fov, fov_target, k * 0.5)
			_safe_look_at(cam, pose[1], v.cam_up)
			if v.shake > 0.0:
				cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * v.shake
				v.shake = maxf(0.0, v.shake - delta * 1.5)
			v.hud.speed_effect = clampf((r.speed - 38.0) / 20.0, 0.0, 1.0) if (r.boost_timer > 0.0 or r.turbo_on or r.speed > 45.0) else 0.0
		CamMode.HIGH:
			_set_tilt_shift(v, 30.0, 0.5)
			var target := r.global_position + Vector3(0, 26.0, 22.0)
			cam.global_position = cam.global_position.lerp(target, k)
			v.cam_up = v.cam_up.slerp(Vector3.UP, k).normalized()
			cam.fov = lerpf(cam.fov, 60.0, k)
			_safe_look_at(cam, r.global_position, v.cam_up)
		CamMode.ORBIT:
			v.orbit_angle += delta * 0.4
			var target := r.global_position + Vector3(sin(v.orbit_angle) * 9.0, 4.5, cos(v.orbit_angle) * 9.0)
			cam.global_position = cam.global_position.lerp(target, k * 0.5)
			v.cam_up = v.cam_up.slerp(Vector3.UP, k).normalized()
			_safe_look_at(cam, r.global_position + Vector3.UP * 0.6, v.cam_up)
			_set_tilt_shift(v, cam.global_position.distance_to(r.global_position), 1.0)


## Depth-of-field that keeps `focus` sharp and blurs what's nearer and further,
## which makes the scene look like a photo of real toys. Needs the full renderer.
func _set_tilt_shift(v: View, focus: float, amount: float) -> void:
	var d := v.dof
	if amount <= 0.01 or not Game.fancy_renderer() or Game.quality == 0:
		d.dof_blur_far_enabled = false
		d.dof_blur_near_enabled = false
		return
	d.dof_blur_far_enabled = true
	d.dof_blur_near_enabled = true
	d.dof_blur_far_distance = focus * 1.45 + 5.0
	d.dof_blur_far_transition = maxf(6.0, focus * 1.2)
	d.dof_blur_near_distance = maxf(0.5, focus * 0.45)
	d.dof_blur_near_transition = maxf(0.5, focus * 0.35)
	d.dof_blur_amount = 0.05 * amount


func _safe_look_at(cam: Camera3D, target: Vector3, up: Vector3) -> void:
	var dir := target - cam.global_position
	if dir.length() < 0.01 or absf(dir.normalized().dot(up.normalized())) > 0.999:
		return
	cam.look_at(target, up)


# ---------------------------------------------------------------------------
# Computer cars' engine sounds (3D, heard through player 1's camera)
# ---------------------------------------------------------------------------

## Each computer car hums with its own 3D engine sound, so you hear them
## coming up behind you and zooming past (with a Doppler pitch drop).
func _setup_ai_engines() -> void:
	for r in racers:
		if r.is_player:
			continue
		var st := Sfx.loop_stream("engine")
		if st == null:
			continue
		var p := AudioStreamPlayer3D.new()
		p.stream = st
		p.bus = "SFX"
		p.unit_size = 6.0
		p.max_distance = 70.0
		p.volume_db = -60.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		r.add_child(p)
		p.play(randf() * 2.0)
		_ai_engines[r] = p
		_pass_side[r] = r.total > player.total


func _update_ai_sounds() -> void:
	var live := state == State.RACING or state == State.COUNTDOWN or state == State.FINISHED
	for r: Racer in _ai_engines:
		var p: AudioStreamPlayer3D = _ai_engines[r]
		var rev := absf(r.speed) / 45.0
		p.pitch_scale = lerpf(p.pitch_scale, 0.8 + rev * 0.75, 0.15)
		p.volume_db = lerpf(p.volume_db, -8.0 if live and r.mode != Racer.Mode.FALLING else -60.0, 0.1)
		# Whoosh when a car zooms past you (or you zoom past it).
		var ahead := r.total > player.total
		var gap := absf(r.total - player.total)
		if ahead != _pass_side[r] and gap < 6.0 and absf(r.speed - player.speed) > 3.0 and state == State.RACING:
			Sfx.play("whoosh", randf_range(0.9, 1.15))
		_pass_side[r] = ahead


# ---------------------------------------------------------------------------
# Pause menu
# ---------------------------------------------------------------------------

func _build_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_pause_menu = _centered_panel(layer, "PAUSED")
	var box: VBoxContainer = _pause_menu.get_meta("box")
	_add_button(box, "Keep Racing", _toggle_pause)
	if online:
		_add_button(box, "Leave Online Race", func():
			Net.leave("")
			Game.goto_menu())
		_pause_menu.visible = false
		return
	if not Game.gp_active:
		_add_button(box, "Restart Race", func(): Game.goto_race())
		_add_button(box, "Change Car", func(): Game.goto_garage())
	else:
		_add_button(box, "Quit Grand Prix", func():
			Game.end_grand_prix()
			Game.goto_menu())
	_add_button(box, "Main Menu", func():
		Game.end_grand_prix()
		Game.goto_menu())
	_pause_menu.visible = false


func _toggle_pause() -> void:
	if online:
		# Online races can't stop for everyone: just show the menu.
		_pause_menu.visible = not _pause_menu.visible
		if _pause_menu.visible:
			Sfx.play("click")
			(_pause_menu.get_meta("box").get_child(1) as Button).grab_focus()
		return
	var p := not get_tree().paused
	get_tree().paused = p
	_pause_menu.visible = p
	if p:
		Sfx.play("click")
		var first: Button = _pause_menu.get_meta("box").get_child(1)
		first.grab_focus()


func _centered_panel(parent: Node, title: String) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.theme = Game.ui_theme
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(420, 0)
	panel.add_child(box)
	var t := RaceHud.make_label(title, 56, Color(1.0, 0.85, 0.2), 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	dim.set_meta("box", box)
	return dim


func _add_button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	box.add_child(b)
	return b


# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------

## Finished racers in finishing order, then the rest by how far they got.
func _final_order() -> Array[Racer]:
	var rows: Array[Racer] = _finish_order.duplicate()
	if online:   # messages arrive in any order: sort by the actual times
		rows.sort_custom(func(a: Racer, b: Racer) -> bool: return a.finish_time < b.finish_time)
	var rest: Array[Racer] = []
	for r in racers:
		if not rows.has(r):
			rest.append(r)
	rest.sort_custom(func(a: Racer, b: Racer) -> bool: return a.total > b.total)
	rows.append_array(rest)
	return rows


func _show_results() -> void:
	_results_shown = true
	Sfx.play_music("results", -8.0)
	var order := _final_order()
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	var title := "RACE RESULTS"
	if Game.gp_active:
		title = "GRAND PRIX  -  RACE %d of %d" % [Game.gp_race + 1, Track.TRACKS.size()]
	_results_panel = _centered_panel(layer, title)
	_results_panel.color = Color(0, 0, 0, 0.3)
	var box: VBoxContainer = _results_panel.get_meta("box")
	box.custom_minimum_size = Vector2(700, 0)
	var grid := GridContainer.new()
	grid.columns = 4 if Game.gp_active else 3
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	_results_panel.set_meta("grid", grid)

	# Grand Prix points for this race.
	if Game.gp_active:
		for i in order.size():
			var nm := order[i].racer_name
			Game.gp_points[nm] = int(Game.gp_points.get(nm, 0)) + int(Game.GP_POINTS[mini(i, Game.GP_POINTS.size() - 1)])

	# Records and the ghost (single player only).
	var beat_record := false
	if humans.size() == 1:
		var best := Game.best_time_for_current()
		var new_record := player.has_finished and Game.submit_result(player.finish_time, player.best_lap)
		beat_record = new_record and best > 0.0
		var rec_text := ("NEW RECORD!  " + Game.format_time(player.finish_time)) if new_record else ("Record: " + Game.format_time(best))
		var rec := RaceHud.make_label(rec_text, 26, Color(0.5, 1.0, 0.6) if new_record else Color(0.85, 0.85, 1.0), 8)
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(rec)
		if new_record:
			Sfx.play("voice_record")
		if ghost:
			ghost.save_if_better()

	# Stars for every human who finished, and anything that unlocks.
	var earned := 0
	for h in humans:
		if h.has_finished:
			earned = maxi(earned, Game.stars_for_place(order.find(h) + 1))
	var fresh := Game.award_stars(earned) if earned > 0 else []
	# Finishing the holiday track unlocks Santa's Sleigh.
	if Game.selected_track == Game.HOLIDAY_TRACK and player.has_finished and Game.grant("car_sleigh"):
		fresh.append("car_sleigh")
	var new_badges := _count_badges(order, beat_record)
	var star_line := RaceHud.make_label("+%d ★   (%d stars)" % [earned, Game.stars], 26, Color(1.0, 0.9, 0.3), 8)
	star_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(star_line)
	_add_unlock_lines(box, fresh)
	_add_badge_lines(box, new_badges)
	_online_times(box)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)
	var first: Button
	if Game.gp_active:
		if Game.gp_race + 1 < Track.TRACKS.size():
			first = _add_button(buttons, "Next Race  >", func():
				Game.gp_race += 1
				Game.selected_track = Game.gp_race
				Game.goto_race())
		else:
			first = _add_button(buttons, "Trophy Ceremony!", func(): Game.goto("res://scenes/podium.tscn"))
		_add_button(buttons, "Quit Cup", func():
			Game.end_grand_prix()
			Game.goto_menu())
	elif online:
		if Net.is_host:
			first = _add_button(buttons, "Race Again!", func(): Net.start_race())
			_add_button(buttons, "Back to Lobby", func(): Net.back_to_lobby())
		else:
			var vote := _add_button(buttons, "Rematch!", func(): Net.vote_rematch())
			vote.pressed.connect(func():
				vote.text = "Asked for a rematch!"
				vote.disabled = true)
			first = vote
		var leave := _add_button(buttons, "Leave", func():
			Net.leave("")
			Game.goto_menu())
		if first == null:
			first = leave
		# Quick cheers after the race (also keys 1-6 during it).
		var cheers := HBoxContainer.new()
		cheers.alignment = BoxContainer.ALIGNMENT_CENTER
		cheers.add_theme_constant_override("separation", 8)
		box.add_child(cheers)
		for i in Net.EMOTES.size():
			var idx := i
			var e := _add_button(cheers, Net.EMOTES[i], func(): Net.send_emote(idx))
			e.add_theme_font_size_override("font_size", 18)
			e.add_theme_color_override("font_color", Net.EMOTE_COLORS[i])
	else:
		first = _add_button(buttons, "Race Again!", func(): Game.goto_race())
		_add_button(buttons, "Change Car", func(): Game.goto_garage())
		_add_button(buttons, "Menu", func(): Game.goto_menu())
	first.grab_focus()
	for v in views:
		v.hud.set_race_ui_visible(false)
	_refresh_results()


## Sends your time to the track's online top 10 and shows where you placed.
func _online_times(box: Container) -> void:
	if not Game.online_times or humans.size() != 1 or not player.has_finished or player.finish_time < 5.0:
		return
	var line := RaceHud.make_label("Checking the online top 10...", 22, Color(0.7, 0.9, 1.0), 6)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)   # the buttons are added after this, so it sits above them
	var board := Game.board_key(Game.selected_track, Game.laps)
	var res: Dictionary = await Net.submit_time(board, player.racer_name, player.finish_time, String(player.car.get("name", "")))
	if not is_instance_valid(line):
		return
	if res.has("error") or not res.has("top"):
		line.text = "(Couldn't reach the online top 10.)"
		line.modulate.a = 0.6
		return
	var rank := int(res.get("rank", 0))
	var top: Array = res["top"]
	var leader := ""
	if not top.is_empty():
		leader = "   Record: %s %s" % [top[0]["name"], Game.format_time(float(top[0]["time"]))]
	if rank == 1:
		line.text = "ONLINE RECORD! You're #1 in the world!"
		line.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		Sfx.play("voice_record")
	elif rank > 0:
		line.text = "Online top 10: you're #%d!%s" % [rank, leader]
		line.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	else:
		line.text = "Online top 10: not this time.%s" % leader


func _add_unlock_lines(box: Container, fresh: Array) -> void:
	for id in fresh:
		var it := Unlocks.get_item(id)
		if it.is_empty():
			continue
		var kind: String = {"paint": "paint", "sticker": "sticker", "wheels": "wheels", "car": "SECRET CAR"}.get(it["kind"], "")
		var l := RaceHud.make_label("NEW!  %s %s unlocked!" % [it["name"], kind], 26, Color(1.0, 0.6, 0.95), 8)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		var tw := l.create_tween().set_loops()
		tw.tween_property(l, "modulate", Color(1, 1, 1, 0.55), 0.5)
		tw.tween_property(l, "modulate", Color.WHITE, 0.5)
	if not fresh.is_empty():
		Sfx.play("voice_unlock")


## Counts this race toward the badges and returns the ones just earned.
func _count_badges(order: Array, new_record: bool) -> Array:
	if player == null or not player.has_finished:
		return Game.check_badges(true)
	var won := order.find(player) == 0
	Game.add_stat("races")
	if won:
		Game.add_stat("wins")
		if Game.difficulty == 2:
			Game.add_stat("hard_wins")
	if new_record:
		Game.add_stat("records")
	if _wall_bumps == 0:
		Game.add_stat("clean_races")
	if online:
		Game.add_stat("online_races")
		if won and racers.size() > 1:
			Game.add_stat("online_wins")
	match Game.selected_track:
		Game.WEEKLY_TRACK:
			Game.add_stat("weekly")
		Game.HOLIDAY_TRACK:
			Game.add_stat("holiday")
		_:
			if Game.selected_track < Track.TRACKS.size() and not online:
				Game.note_track(Track.TRACKS[Game.selected_track]["id"])
	return Game.check_badges(true)


func _add_badge_lines(box: Container, ids: Array) -> void:
	if ids.is_empty():
		return
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 18)
	box.add_child(row)
	for id in ids:
		var b := Badges.get_badge(id)
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 8)
		item.add_child(BadgeMedal.make(b, true, 46))
		var l := RaceHud.make_label("NEW BADGE!\n" + b["name"], 20, b["color"].lightened(0.3), 6)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item.add_child(l)
		row.add_child(item)
	Sfx.play("voice_unlock")


func _refresh_results() -> void:
	if _results_panel == null:
		return
	var grid: GridContainer = _results_panel.get_meta("grid")
	var rows := _final_order()
	var cols := grid.columns
	while grid.get_child_count() < rows.size() * cols:
		grid.add_child(RaceHud.make_label("", 28, Color.WHITE, 8))
	for i in rows.size():
		var r := rows[i]
		var col := Color(1.0, 0.85, 0.2) if r.player_index == 1 else (Color(0.5, 0.9, 1.0) if r.player_index == 2 or r.human else Color.WHITE)
		var cells: Array[Label] = []
		for c in cols:
			cells.append(grid.get_child(i * cols + c) as Label)
		cells[0].text = Game.ordinal(i + 1)
		cells[1].text = "%s  (%s)" % [r.racer_name, r.car["name"]]
		cells[2].text = Game.format_time(r.finish_time) if r.has_finished else "racing..."
		if cols == 4:
			cells[3].text = "%d pts" % int(Game.gp_points.get(r.racer_name, 0))
		for l in cells:
			l.add_theme_color_override("font_color", col)


# ---------------------------------------------------------------------------
# Online
# ---------------------------------------------------------------------------

## A speech bubble over the car of whoever sent the emote (and a line on the HUD).
func _on_emote(peer_id: int, text: String) -> void:
	var r: Racer = _by_key.get("p%d" % peer_id)
	if r == null or not is_instance_valid(r):
		return
	var bubble := Label3D.new()
	bubble.text = text
	bubble.font_size = 72
	bubble.pixel_size = 0.012
	bubble.outline_size = 18
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.modulate = Net.EMOTE_COLORS[Net.EMOTES.find(text)] if Net.EMOTES.has(text) else Color.WHITE
	bubble.position = Vector3(0, 2.6, 0)
	r.add_child(bubble)
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "position:y", 3.4, 2.2)
	tw.parallel().tween_property(bubble, "modulate:a", 0.0, 2.2).set_delay(1.2)
	tw.tween_callback(bubble.queue_free)
	if r != player:
		Sfx.play("click", 1.5, -6.0)


var _rematch_votes: Dictionary = {}

func _on_rematch_vote(peer_id: int) -> void:
	_rematch_votes[peer_id] = true
	var names := PackedStringArray()
	for id in _rematch_votes:
		names.append(Net.player_name_of(int(id)))
	for v in views:
		v.hud.flash_message("%s want%s a rematch!" % [", ".join(names), "s" if names.size() == 1 else ""], Color(1.0, 0.85, 0.3), 2.5)
	Sfx.play("select")

func _on_net_states(states: Array) -> void:
	for st in states:
		if not (st is Array) or st.size() < 12:
			continue
		var r: Racer = _by_key.get(st[0])
		if r and r.remote:
			r.apply_net_state(st)


## Someone on another computer used a power-up: show it here too.
func _on_net_item(key: String, kind: String, side: float) -> void:
	var r: Racer = _by_key.get(key)
	if r and r.remote and powerups:
		powerups.use_remote(r, kind, side)


## A hit that counted on another computer: show the message here.
func _on_net_hit(victim_key: String, kind: String, by_key: String) -> void:
	var v: Racer = _by_key.get(victim_key)
	var by: Racer = _by_key.get(by_key)
	if v and by and not by.remote and v.remote:
		_on_item_hit(v, kind, by)


func _on_player_left(peer_id: int) -> void:
	var r: Racer = _by_key.get("p%d" % peer_id)
	if r == null:
		return
	_by_key.erase(r.net_key)
	racers.erase(r)
	if powerups:
		powerups.racers.erase(r)
	_finish_order.erase(r)
	_ai_engines.erase(r)
	_flames.erase(r)
	_pass_side.erase(r)
	for v in views:
		v.hud.flash_message("%s left the race" % r.racer_name, Color(0.8, 0.85, 1.0), 1.5)
	r.queue_free()
