class_name Replay
extends Node
## Records every car during a race, then plays it back like TV: chase cams,
## trackside cams, swoops round the cars and slow motion. Photo mode freezes
## the moment so you can turn the camera and snap a picture.

const RATE := 30.0                 # recorded frames per second
const MAX_SECONDS := 900.0         # stop recording after 15 minutes
const STRIDE := 10                 # floats per car per frame
const SHOT_KINDS := ["chase", "trackside", "orbit", "trackside", "front", "high", "trackside"]

var race: Node                     # the race scene (race.gd)
var racers: Array[Racer] = []
var frames: Array[PackedFloat32Array] = []
var playing := false

var _acc := 0.0
var _t := 0.0                      # playback time (seconds)
var _speed := 1.0
var _photo := false
var _cam: Camera3D
var _view                          # race View for player 1
var _layer: CanvasLayer
var _bar: ProgressBar
var _replay_box: Control
var _photo_box: Control
var _rec_label: Label
var _msg: Label
var _slow_button: Button
var _done_cb: Callable

# Camera director
var _shot := ""
var _shot_time := 0.0
var _shot_len := 4.0
var _shot_i := 0
var _target: Racer
var _fixed_pos := Vector3.ZERO
var _orbit := 0.0
# Photo camera
var _yaw := 0.0
var _pitch := 0.35
var _dist := 9.0


func setup(p_race: Node, p_racers: Array[Racer]) -> Replay:
	race = p_race
	racers = p_racers
	process_mode = Node.PROCESS_MODE_ALWAYS
	return self


## Called every physics frame during the race.
func record(delta: float) -> void:
	if playing or frames.size() >= int(MAX_SECONDS * RATE):
		return
	_acc += delta
	if _acc < 1.0 / RATE and not frames.is_empty():
		return
	_acc = 0.0
	var f := PackedFloat32Array()
	f.resize(racers.size() * STRIDE)
	for i in racers.size():
		var r := racers[i]
		var q := r.global_transform.basis.get_rotation_quaternion()
		var p := r.global_position
		var o := i * STRIDE
		f[o] = p.x; f[o + 1] = p.y; f[o + 2] = p.z
		f[o + 3] = q.x; f[o + 4] = q.y; f[o + 5] = q.z; f[o + 6] = q.w
		f[o + 7] = r.speed
		f[o + 8] = r.s
		f[o + 9] = 1.0 if (r.model and r.model.shadow and r.model.shadow.visible) else 0.0
	frames.append(f)


func duration() -> float:
	return maxf(0.0, (frames.size() - 1) / RATE)


func can_play() -> bool:
	return frames.size() > int(RATE * 2.0)


# ---------------------------------------------------------------------------
# Playback
# ---------------------------------------------------------------------------

func start(view, done: Callable) -> void:
	if not can_play():
		return
	_view = view
	_cam = view.camera
	_done_cb = done
	playing = true
	_t = 0.0
	_speed = 1.0
	_photo = false
	for r in racers:
		r.process_mode = Node.PROCESS_MODE_DISABLED
	_target = view.racer
	_shot_i = 0
	_next_shot()
	_build_ui()
	Sfx.play_music("race_" + String(Game.track_info(Game.selected_track)["room"]), -10.0)


func stop() -> void:
	playing = false
	_photo = false
	for r in racers:
		r.process_mode = Node.PROCESS_MODE_INHERIT
	if _layer:
		_layer.queue_free()
		_layer = null
	Sfx.play_music("results", -8.0)
	if _done_cb.is_valid():
		_done_cb.call()


func _process(delta: float) -> void:
	if not playing:
		return
	if not _photo:
		_t += delta * _speed
		if _t >= duration():
			_t = 0.0          # loop round
			_next_shot()
		_shot_time += delta * _speed
		if _shot_time > _shot_len:
			_next_shot()
	_apply(_t, delta * (0.0 if _photo else _speed))
	if _photo:
		_photo_camera(delta)
	else:
		_direct_camera(delta)
	if _bar:
		_bar.value = _t / maxf(0.01, duration()) * 100.0
	if _rec_label:
		_rec_label.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.006)


## Puts every car where it was at time t.
func _apply(t: float, delta: float) -> void:
	var fi := t * RATE
	var i0 := clampi(int(fi), 0, frames.size() - 1)
	var i1 := mini(i0 + 1, frames.size() - 1)
	var w := clampf(fi - i0, 0.0, 1.0)
	var a := frames[i0]
	var b := frames[i1]
	for i in racers.size():
		var r := racers[i]
		var o := i * STRIDE
		if o + STRIDE > a.size():
			continue
		var pa := Vector3(a[o], a[o + 1], a[o + 2])
		var pb := Vector3(b[o], b[o + 1], b[o + 2])
		var qa := Quaternion(a[o + 3], a[o + 4], a[o + 5], a[o + 6])
		var qb := Quaternion(b[o + 3], b[o + 4], b[o + 5], b[o + 6])
		if pa.distance_to(pb) > 15.0:
			w = 0.0          # a respawn jump: don't slide across the room
		r.global_transform = Transform3D(Basis(qa.slerp(qb, w)), pa.lerp(pb, w))
		r.speed = lerpf(a[o + 7], b[o + 7], w)
		r.s = a[o + 8]
		if r.model:
			if r.model.shadow:
				r.model.shadow.visible = a[o + 9] > 0.5
			if delta > 0.0:
				r.model.animate(r.speed, 0.0, delta)


# ---------------------------------------------------------------------------
# The camera director: a new shot every few seconds.
# ---------------------------------------------------------------------------

func _next_shot() -> void:
	_shot_time = 0.0
	_shot = SHOT_KINDS[_shot_i % SHOT_KINDS.size()]
	_shot_i += 1
	_shot_len = randf_range(3.5, 5.5)
	# Mostly follow you; now and then whoever is nearest to you.
	_target = _view.racer
	if randf() < 0.3:
		var best := 1e9
		for r in racers:
			var d := r.global_position.distance_to(_view.racer.global_position)
			if r != _view.racer and d < best:
				best = d
				_target = r
	var tr: Track = race.track
	match _shot:
		"trackside":
			# Stand by the track a little ahead and watch the car go by.
			var ahead := fposmod(_target.s + clampf(_target.speed, 10.0, 50.0) * 1.6, tr.length)
			var f := tr.sample(ahead)
			var side := 1.0 if randf() < 0.5 else -1.0
			_fixed_pos = f.origin + f.basis.x * side * (Track.HALF_WIDTH + randf_range(3.0, 7.0)) + Vector3.UP * randf_range(3.0, 6.0)
			_fixed_pos.y = maxf(_fixed_pos.y, 1.0)
		"orbit":
			_orbit = randf() * TAU
	_cam.fov = 55.0


func _direct_camera(delta: float) -> void:
	var r := _target
	var k := 1.0 - exp(-delta * 6.0)
	var focus := r.global_position + Vector3.UP * 0.6
	match _shot:
		"chase":
			var pose: Array = race._chase_pose(r)
			_cam.global_position = _cam.global_position.lerp(pose[0], k) if _shot_time > 0.05 else pose[0]
			race._safe_look_at(_cam, pose[1], pose[2])
			race._set_tilt_shift(_view, 0.0, 0.0)
			return
		"trackside":
			_cam.global_position = _fixed_pos
			_cam.fov = lerpf(_cam.fov, clampf(70.0 - _fixed_pos.distance_to(focus) * 0.8, 25.0, 60.0), k)
		"orbit":
			_orbit += delta * 0.5 * _speed
			_cam.global_position = focus + Vector3(sin(_orbit) * 8.0, 3.0, cos(_orbit) * 8.0)
		"front":
			var f: Transform3D = race.track.sample(fposmod(r.s + 7.0, race.track.length))
			var want := f.origin + f.basis.y * 1.6
			_cam.global_position = want if _shot_time < 0.05 else _cam.global_position.lerp(want, k)
		"high":
			var want := focus + Vector3(0, 30.0, 18.0)
			_cam.global_position = want if _shot_time < 0.05 else _cam.global_position.lerp(want, k)
			_cam.fov = 45.0
	race._safe_look_at(_cam, focus, Vector3.UP)
	race._set_tilt_shift(_view, _cam.global_position.distance_to(focus), 0.8)


# ---------------------------------------------------------------------------
# Photo mode
# ---------------------------------------------------------------------------

func _enter_photo() -> void:
	_photo = true
	var to := _cam.global_position - _target.global_position
	_dist = clampf(to.length(), 4.0, 30.0)
	_yaw = atan2(to.x, to.z)
	_pitch = clampf(asin(clampf(to.y / maxf(0.01, to.length()), -1.0, 1.0)), 0.05, 1.4)
	_replay_box.visible = false
	_photo_box.visible = true
	_say("Drag to turn the camera.  Snap to take a photo!")


func _leave_photo() -> void:
	_photo = false
	_replay_box.visible = true
	_photo_box.visible = false
	_msg.text = ""


func _photo_camera(delta: float) -> void:
	var turn := Input.get_axis("ui_left", "ui_right")
	var tilt := Input.get_axis("ui_down", "ui_up")
	_yaw += turn * delta * 1.6
	_pitch = clampf(_pitch + tilt * delta * 1.2, 0.05, 1.4)
	var focus := _target.global_position + Vector3.UP * 0.6
	_cam.global_position = focus + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_cam.fov = 50.0
	race._safe_look_at(_cam, focus, Vector3.UP)
	race._set_tilt_shift(_view, _dist, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _photo:
			_leave_photo()
		else:
			stop()
		return
	if not _photo:
		return
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		_turn((event as InputEventMouseMotion).relative)
	elif event is InputEventScreenDrag:
		_turn((event as InputEventScreenDrag).relative)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1)


func _turn(rel: Vector2) -> void:
	_yaw -= rel.x * 0.008
	_pitch = clampf(_pitch + rel.y * 0.006, 0.05, 1.4)


func _zoom(d: int) -> void:
	_dist = clampf(_dist * (1.15 if d > 0 else 1.0 / 1.15), 3.0, 40.0)


func _snap() -> void:
	_layer.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_layer.visible = true
	var path := save_photo(img)
	Sfx.play("click", 1.6)
	Game.add_stat_now("photos")
	_flash()
	_say(("Saved!  " + path) if path != "" else "Couldn't save the photo, sorry!")


## Saves a photo in your Pictures folder (or the game's own folder if that
## doesn't work). Returns where it went, "" if it failed.
static func save_photo(img: Image) -> String:
	var name := "race_%s.png" % Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var dirs: Array[String] = []
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pics != "":
		dirs.append(pics.path_join("Race Track Mayhem"))
	dirs.append(ProjectSettings.globalize_path("user://photos"))
	for d in dirs:
		if DirAccess.make_dir_recursive_absolute(d) != OK and not DirAccess.dir_exists_absolute(d):
			continue
		var p := d.path_join(name)
		if img.save_png(p) == OK:
			return p
	return ""


func _flash() -> void:
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0.9)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(white)
	var tw := white.create_tween()
	tw.tween_property(white, "color:a", 0.0, 0.35)
	tw.tween_callback(white.queue_free)


func _say(text: String) -> void:
	_msg.text = text


# ---------------------------------------------------------------------------
# On-screen buttons
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.ui_theme
	_layer.add_child(root)

	_rec_label = RaceHud.make_label("● REPLAY", 34, Color(1.0, 0.35, 0.3), 10)
	RaceHud.pin(_rec_label, Vector2(0, 0), Vector2(24, 18), Vector2(300, 50))
	root.add_child(_rec_label)
	_msg = RaceHud.make_label("", 22, Color(1.0, 0.95, 0.6), 8)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RaceHud.pin(_msg, Vector2(0.5, 0), Vector2(-450, 20), Vector2(900, 70))
	root.add_child(_msg)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	RaceHud.pin(_bar, Vector2(0.5, 1), Vector2(-400, -130), Vector2(800, 14))
	root.add_child(_bar)

	_replay_box = _row(root)
	_button(_replay_box, "Photo!", _enter_photo).grab_focus.call_deferred()
	_slow_button = _button(_replay_box, "Slow-Mo", func():
		_speed = 0.35 if _speed > 0.5 else 1.0
		_slow_button.text = "Normal Speed" if _speed < 1.0 else "Slow-Mo")
	_button(_replay_box, "Next Camera", _next_shot)
	_button(_replay_box, "Start Again", func():
		_t = 0.0
		_next_shot())
	_button(_replay_box, "Done", stop)

	_photo_box = _row(root)
	_photo_box.visible = false
	var snap := _button(_photo_box, "SNAP!", _snap)
	snap.add_theme_font_size_override("font_size", 40)
	_button(_photo_box, " - ", func(): _zoom(1))
	_button(_photo_box, " + ", func(): _zoom(-1))
	_button(_photo_box, "Other Car", func():
		var i := racers.find(_target)
		_target = racers[(i + 1) % racers.size()])
	_button(_photo_box, "Back", _leave_photo)


func _row(root: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	RaceHud.pin(row, Vector2(0.5, 1), Vector2(-600, -100), Vector2(1200, 84))
	root.add_child(row)
	return row


func _button(parent: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	parent.add_child(b)
	return b
