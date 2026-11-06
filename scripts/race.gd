extends Node3D
## Runs a race: builds the bedroom and the track, puts cars on the grid,
## does the big zoom-in intro and the 3-2-1-GO countdown, then keeps score
## until everyone crosses the finish line.

enum State { INTRO, COUNTDOWN, RACING, FINISHED }
enum CamMode { CHASE, HIGH, INTRO, ORBIT }

const INTRO_HOLD := 1.6        # seconds looking at the whole room
const INTRO_ZOOM := 3.6        # seconds zooming down to the car
const RACER_NAMES := ["You", "Zoomy", "Vroomer", "Speedy", "Turbo Tom"]

var track: Track
var bedroom: Bedroom
var racers: Array[Racer] = []
var player: Racer
var hud: RaceHud
var camera: Camera3D

var state := State.INTRO
var cam_mode := CamMode.INTRO
var _state_time := 0.0
var _race_clock := 0.0
var _countdown_step := -1
var _cam_up := Vector3.UP
var _intro_from := Vector3.ZERO
var _intro_look := Vector3.ZERO
var _orbit_angle := 0.0
var _results_shown := false
var _finish_order: Array[Racer] = []

var _pause_menu: Control
var _results_panel: Control
var _flames: Dictionary = {}   # racer -> CPUParticles3D
var _engine_playback: AudioStreamGeneratorPlayback
var _engine_phase := 0.0
var _engine_phase2 := 0.0
var _engine_freq := 60.0
var _shake := 0.0


func _ready() -> void:
	# The race node keeps listening while paused (so ESC can un-pause);
	# everything that moves is pausable.
	process_mode = Node.PROCESS_MODE_ALWAYS
	track = Track.new()
	track.name = "Track"
	track.layout_id = Game.selected_track
	add_child(track)
	track.build()

	bedroom = Bedroom.new()
	bedroom.name = "Bedroom"
	add_child(bedroom)
	bedroom.build(track)

	_spawn_racers()

	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = 600.0
	add_child(camera)
	camera.current = true
	_intro_from = bedroom.overview_position()
	var tr := track.get_aabb_xz()
	_intro_look = Vector3(tr.get_center().x, 0.0, tr.get_center().y)
	camera.global_position = _intro_from
	camera.look_at(_intro_look, Vector3.UP)

	hud = RaceHud.new()
	add_child(hud)
	hud.setup(track, racers, player)
	hud.show_title(true)

	for n: Node in [track, bedroom, camera, hud]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
	for r in racers:
		r.process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_pause_menu()
	_setup_engine_sound()
	_set_state(State.INTRO)


func _spawn_racers() -> void:
	var player_idx := Game.selected_car
	var order: Array[int] = []
	for i in CarData.count():
		if i != player_idx:
			order.append(i)
	order.shuffle()
	# The player starts in the middle of the grid.
	order.insert(mini(2, order.size()), player_idx)

	var base_skill: float = [0.85, 0.93, 1.0][Game.difficulty]
	var ai_count := 0
	for slot in order.size():
		var car_idx := order[slot]
		var is_player := car_idx == player_idx
		var nm: String = RACER_NAMES[0] if is_player else RACER_NAMES[1 + ai_count]
		if not is_player:
			ai_count += 1
		var r := Racer.new()
		add_child(r)
		r.setup(track, CarData.get_car(car_idx), is_player, nm)
		r.laps_to_win = Game.laps
		r.ai_skill = clampf(base_skill + randf_range(-0.04, 0.04), 0.7, 1.0)
		r.rubber_band = base_skill
		var row := slot / 2
		var lane := -1.6 if slot % 2 == 0 else 1.6
		r.place_on_grid(-4.0 - row * 5.5 - (slot % 2) * 2.0, lane)
		r.lap_completed.connect(_on_lap)
		r.finished.connect(_on_finished)
		r.crashed.connect(_on_crash)
		r.boosted.connect(_on_boost)
		racers.append(r)
		_add_flame(r)
		if is_player:
			player = r
			r.landed.connect(func(_r: Racer, h: float): _shake = maxf(_shake, clampf(h * 0.12, 0.1, 0.45)))
			r.bumped.connect(func(_r: Racer, h: float): _shake = maxf(_shake, clampf(h * 0.15, 0.08, 0.3)))


func _add_flame(r: Racer) -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.22
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3(0, 0.3, 1)
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


# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

func _set_state(s: State) -> void:
	state = s
	_state_time = 0.0
	match s:
		State.INTRO:
			cam_mode = CamMode.INTRO
		State.COUNTDOWN:
			cam_mode = CamMode.CHASE
			_countdown_step = -1
			hud.hide_title()
			hud.set_race_ui_visible(true)
		State.RACING:
			for r in racers:
				r.controls_enabled = true
			hud.fade_hint()
		State.FINISHED:
			pass


func _process(delta: float) -> void:
	_update_engine_sound()
	if get_tree().paused:
		return
	_state_time += delta
	match state:
		State.INTRO:
			if _state_time > INTRO_HOLD + INTRO_ZOOM:
				_set_state(State.COUNTDOWN)
		State.COUNTDOWN:
			var step := int(floor(_state_time / 0.9))
			if step != _countdown_step:
				_countdown_step = step
				match step:
					0:
						hud.show_countdown("3", Color(1.0, 0.3, 0.25))
						track.set_start_lights(1)
						Sfx.play("beep")
					1:
						hud.show_countdown("2", Color(1.0, 0.75, 0.2))
						track.set_start_lights(2)
						Sfx.play("beep")
					2:
						hud.show_countdown("1", Color(1.0, 0.95, 0.3))
						track.set_start_lights(3)
						Sfx.play("beep")
					3:
						hud.show_countdown("GO!", Color(0.35, 1.0, 0.4))
						track.set_start_lights(4)
						Sfx.play("go")
						_set_state(State.RACING)
		State.FINISHED:
			if not _results_shown and _state_time > 3.0:
				_show_results()
			elif _results_shown:
				_refresh_results()
	_update_flames()
	_update_camera(delta)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if state == State.RACING or state == State.FINISHED:
		_race_clock += delta
		for r in racers:
			if not r.has_finished:
				r.race_time = _race_clock
	_update_rubber_band(delta)
	for i in racers.size():
		for j in range(i + 1, racers.size()):
			racers[i].bump_with(racers[j])
	_update_places()


func _update_places() -> void:
	var sorted := racers.duplicate()
	sorted.sort_custom(func(a: Racer, b: Racer) -> bool: return a.progress() > b.progress())
	for i in sorted.size():
		(sorted[i] as Racer).place = i + 1


## Keeps the computer cars close to the player so races stay exciting.
func _update_rubber_band(delta: float) -> void:
	var base: float = [0.85, 0.93, 1.0][Game.difficulty]
	for r in racers:
		if r.is_player:
			continue
		var gap := r.total - player.total
		var target := base
		if player.has_finished:
			target = 1.0
		elif gap > 30.0:
			target = base - clampf((gap - 30.0) / 150.0, 0.0, 0.18)
		elif gap < -25.0:
			target = base + clampf((-gap - 25.0) / 120.0, 0.0, 0.15)
		r.rubber_band = lerpf(r.rubber_band, target, minf(1.0, delta * 0.8))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _results_shown:
		_toggle_pause()
	elif event.is_action_pressed("camera") and (state == State.RACING or state == State.COUNTDOWN):
		cam_mode = CamMode.HIGH if cam_mode == CamMode.CHASE else CamMode.CHASE
	elif event.is_action_pressed("respawn") and state == State.RACING and not player.has_finished:
		player.manual_respawn()


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

func _on_lap(r: Racer, lap: int, _lap_time: float) -> void:
	if not r.is_player or r.has_finished or lap >= r.laps_to_win:
		return
	if lap == r.laps_to_win - 1:
		hud.flash_message("FINAL LAP!", Color(1.0, 0.4, 0.3))
		Sfx.play("final_lap")
	else:
		hud.flash_message("LAP %d" % (lap + 1), Color(1.0, 0.95, 0.4))
		Sfx.play("lap")


func _on_finished(r: Racer) -> void:
	_finish_order.append(r)
	if r != player:
		return
	r.controls_enabled = false
	if r.place == 1:
		hud.flash_message("YOU WIN!!!", Color(1.0, 0.85, 0.15), 2.5)
		Sfx.play("win")
		_spawn_confetti()
	else:
		hud.flash_message("FINISHED %s!" % Game.ordinal(r.place), Color(0.6, 0.9, 1.0), 2.5)
		Sfx.play("finish")
	cam_mode = CamMode.ORBIT
	_orbit_angle = 0.0
	_set_state(State.FINISHED)


func _on_crash(r: Racer) -> void:
	if r.is_player:
		hud.flash_message("MAYHEM!  Too slow for the loop!", Color(1.0, 0.45, 0.3), 1.4)
		Sfx.play("crash")
	else:
		Sfx.play("crash", 1.2, -10.0)


func _on_boost(r: Racer) -> void:
	if r.is_player:
		Sfx.play("boost")
		hud.flash_message("BOOST!", Color(0.4, 1.0, 1.0), 0.5)


func _update_flames() -> void:
	for r: Racer in _flames:
		var p: CPUParticles3D = _flames[r]
		p.emitting = (r.boost_timer > 0.0 or r.turbo_on) and r.mode == Racer.Mode.DRIVING


func _spawn_confetti() -> void:
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
	p.global_position = player.global_position + Vector3.UP * 1.0
	p.emitting = true


# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------

func _chase_pose(r: Racer) -> Array:
	var frame := track.sample(r.s)
	var fwd := -frame.basis.z
	var up := frame.basis.y
	var car_pos := r.global_position
	var pos := car_pos - fwd * 5.8 + up * 2.7
	var look := car_pos + fwd * 3.0 + up * 0.7
	return [pos, look, up]


func _update_camera(delta: float) -> void:
	if player == null:
		return
	var k := 1.0 - exp(-delta * 10.0)
	match cam_mode:
		CamMode.INTRO:
			var pose := _chase_pose(player)
			var t := clampf((_state_time - INTRO_HOLD) / INTRO_ZOOM, 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)   # smooth start & stop
			e = e * e * (3.0 - 2.0 * e)
			# Swoop: fly in on a curve rather than a straight line.
			var goal: Vector3 = pose[0]
			var mid := (_intro_from + goal) * 0.5 + Vector3(0, 18.0, 0)
			var a := _intro_from.lerp(mid, e)
			var b := mid.lerp(goal, e)
			camera.global_position = a.lerp(b, e)
			var look: Vector3 = _intro_look.lerp(pose[1], e)
			_cam_up = Vector3.UP
			camera.fov = lerpf(55.0, 64.0, e)
			camera.look_at(look, _cam_up)
		CamMode.CHASE:
			var pose := _chase_pose(player)
			if player.mode == Racer.Mode.FALLING:
				camera.look_at(player.global_position, _cam_up)
				return
			camera.global_position = camera.global_position.lerp(pose[0], k)
			_cam_up = _cam_up.slerp(pose[2], 1.0 - exp(-delta * 4.0)).normalized()
			var fov_target := 64.0 + clampf(player.speed - 25.0, 0.0, 30.0) * 0.35
			camera.fov = lerpf(camera.fov, fov_target, k * 0.5)
			_safe_look_at(pose[1], _cam_up)
			if _shake > 0.0:
				camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
				_shake = maxf(0.0, _shake - delta * 1.5)
			hud.speed_effect = clampf((player.speed - 38.0) / 20.0, 0.0, 1.0) if (player.boost_timer > 0.0 or player.turbo_on or player.speed > 45.0) else 0.0
		CamMode.HIGH:
			var target := player.global_position + Vector3(0, 26.0, 22.0)
			camera.global_position = camera.global_position.lerp(target, k)
			_cam_up = _cam_up.slerp(Vector3.UP, k).normalized()
			camera.fov = lerpf(camera.fov, 60.0, k)
			_safe_look_at(player.global_position, _cam_up)
		CamMode.ORBIT:
			_orbit_angle += delta * 0.4
			var target := player.global_position + Vector3(sin(_orbit_angle) * 9.0, 4.5, cos(_orbit_angle) * 9.0)
			camera.global_position = camera.global_position.lerp(target, k * 0.5)
			_cam_up = _cam_up.slerp(Vector3.UP, k).normalized()
			_safe_look_at(player.global_position + Vector3.UP * 0.6, _cam_up)


func _safe_look_at(target: Vector3, up: Vector3) -> void:
	var dir := target - camera.global_position
	if dir.length() < 0.01 or absf(dir.normalized().dot(up.normalized())) > 0.999:
		return
	camera.look_at(target, up)


# ---------------------------------------------------------------------------
# Engine sound (a buzzy toy motor that rises with speed)
# ---------------------------------------------------------------------------

func _setup_engine_sound() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	var p := AudioStreamPlayer.new()
	p.stream = gen
	p.volume_db = -16.0
	add_child(p)
	p.play()
	_engine_playback = p.get_stream_playback()


func _update_engine_sound() -> void:
	if _engine_playback == null:
		return
	var target := 55.0 + absf(player.speed) * 3.2 + player.throttle_input * 15.0
	if player.turbo_on or player.boost_timer > 0.0:
		target += 30.0
	if state == State.INTRO or get_tree().paused:
		target = 0.0
	var frames := _engine_playback.get_frames_available()
	for i in frames:
		_engine_freq = lerpf(_engine_freq, target, 0.0008)
		if _engine_freq < 5.0:
			_engine_playback.push_frame(Vector2.ZERO)
			continue
		_engine_phase = fmod(_engine_phase + _engine_freq / 22050.0, 1.0)
		_engine_phase2 = fmod(_engine_phase2 + _engine_freq * 0.503 / 22050.0, 1.0)
		var v := (_engine_phase * 2.0 - 1.0) * 0.35 + (0.25 if _engine_phase2 < 0.5 else -0.25)
		_engine_playback.push_frame(Vector2(v, v) * 0.5)


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
	_add_button(box, "Restart Race", func(): Game.goto_race())
	_add_button(box, "Change Car", func(): Game.goto_garage())
	_add_button(box, "Main Menu", func(): Game.goto_menu())
	_pause_menu.visible = false


func _toggle_pause() -> void:
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
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(420, 0)
	panel.add_child(box)
	var t := RaceHud.make_label(title, 60, Color(1.0, 0.85, 0.2), 14)
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

func _show_results() -> void:
	_results_shown = true
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	_results_panel = _centered_panel(layer, "RACE RESULTS")
	_results_panel.color = Color(0, 0, 0, 0.25)
	var box: VBoxContainer = _results_panel.get_meta("box")
	box.custom_minimum_size = Vector2(640, 0)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	_results_panel.set_meta("grid", grid)

	var best := Game.best_time_for_current()
	var new_record := Game.submit_result(player.finish_time, player.best_lap)
	var rec_text := "NEW RECORD!  " + Game.format_time(player.finish_time) if new_record else "Record: " + Game.format_time(best)
	var rec := RaceHud.make_label(rec_text, 30, Color(0.5, 1.0, 0.6) if new_record else Color(0.85, 0.85, 1.0), 8)
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rec)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var again := _add_button(buttons, "Race Again!", func(): Game.goto_race())
	_add_button(buttons, "Change Car", func(): Game.goto_garage())
	_add_button(buttons, "Menu", func(): Game.goto_menu())
	again.grab_focus()
	hud.set_race_ui_visible(false)
	_refresh_results()


func _refresh_results() -> void:
	if _results_panel == null:
		return
	var grid: GridContainer = _results_panel.get_meta("grid")
	# Finished racers in finishing order, then the rest by how far they got.
	var rows: Array[Racer] = _finish_order.duplicate()
	var rest: Array[Racer] = []
	for r in racers:
		if not rows.has(r):
			rest.append(r)
	rest.sort_custom(func(a: Racer, b: Racer) -> bool: return a.total > b.total)
	rows.append_array(rest)
	var needed := rows.size() * 3
	while grid.get_child_count() < needed:
		grid.add_child(RaceHud.make_label("", 32, Color.WHITE, 8))
	for i in rows.size():
		var r := rows[i]
		var col := Color(1.0, 0.85, 0.2) if r.is_player else Color.WHITE
		var a: Label = grid.get_child(i * 3)
		var b: Label = grid.get_child(i * 3 + 1)
		var c: Label = grid.get_child(i * 3 + 2)
		a.text = Game.ordinal(i + 1)
		b.text = "%s  (%s)" % [r.racer_name, r.car["name"]]
		c.text = Game.format_time(r.finish_time) if r.has_finished else "racing..."
		for l: Label in [a, b, c]:
			l.add_theme_color_override("font_color", col)
