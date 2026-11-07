extends Node3D
## THE LISTENER. It can't see you, but it hears everything.
##
## It wanders, goes to check out noises, and hunts you while you keep making
## noise close by. It LEARNS: hide in lockers too often and it starts checking
## them (hold your breath!); run too often and it sets tripwire chimes in the
## halls you run through.

enum State { WANDER, INVESTIGATE, LISTEN, HUNT, CHECK_LOCKER }

const WANDER_SPEED := 1.6
const INVESTIGATE_SPEED := 2.9
const HUNT_SPEED := 4.3

var sector: Node
var state := State.WANDER
var path: Array[Vector2i] = []
var last_heard := Vector3.ZERO
var _wait := 0.0
var _hunt_t := 0.0
var _repath_t := 0.0
var _click_t := 0.0
var _locker_queue: Array = []
var _checking: Node = null
var _audio: AudioStreamPlayer3D
var _breath: AudioStreamPlayer3D
var _body: Node3D
var _time := 0.0


func setup(s: Node) -> void:
	sector = s
	_build_body()
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = Sound.stream("listener_click")
	_audio.unit_size = 7.0
	_audio.max_distance = 40.0
	_audio.position.y = 2.0
	add_child(_audio)
	_breath = AudioStreamPlayer3D.new()
	_breath.stream = Sound.stream("listener_breath")
	_breath.unit_size = 3.0
	_breath.max_distance = 14.0
	_breath.position.y = 2.0
	add_child(_breath)


func _build_body() -> void:
	# Almost invisible: a tall, thin smudge of darkness. You notice it more by
	# its clicking than by seeing it.
	_body = Node3D.new()
	add_child(_body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.0, 0.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2
	mat.rim_enabled = true
	mat.rim = 0.6
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 2.2
	torso.mesh = cm
	torso.material_override = mat
	torso.position.y = 1.25
	_body.add_child(torso)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.32
	hm.height = 0.9
	head.mesh = hm
	head.material_override = mat
	head.position.y = 2.45
	head.rotation.x = 0.5
	_body.add_child(head)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.06
		am.height = 1.9
		arm.mesh = am
		arm.material_override = mat
		arm.position = Vector3(0.38 * side, 1.25, 0.05)
		arm.rotation.z = 0.12 * side
		_body.add_child(arm)
	var wisps := CPUParticles3D.new()
	wisps.amount = 24
	wisps.lifetime = 1.6
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	wisps.emission_sphere_radius = 0.5
	wisps.direction = Vector3.UP
	wisps.spread = 40.0
	wisps.initial_velocity_min = 0.1
	wisps.initial_velocity_max = 0.4
	wisps.gravity = Vector3.ZERO
	wisps.scale_amount_min = 0.2
	wisps.scale_amount_max = 0.5
	var wm := SphereMesh.new()
	wm.radius = 0.25
	wm.height = 0.5
	wisps.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0, 0, 0, 0.3)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wisps.material_override = wmat
	wisps.position.y = 1.4
	_body.add_child(wisps)


func reset_to(pos: Vector3) -> void:
	global_position = pos
	state = State.WANDER
	path.clear()
	_wait = 3.0
	_checking = null
	_locker_queue.clear()


## A noise happened. Can I hear it?
func hear(pos: Vector3, radius: float, from_player: bool) -> void:
	var m := Game.mode_data()
	var d := global_position.distance_to(pos)
	if d > radius * float(m["hearing"]):
		return
	last_heard = pos
	if state == State.CHECK_LOCKER and not from_player:
		return
	if from_player and d < 8.0 and not sector.player.hidden_in:
		if state != State.HUNT:
			sector.on_hunt_started()
		state = State.HUNT
		_hunt_t = 2.8
		return
	if state != State.HUNT:
		state = State.INVESTIGATE
		_go_to(pos)


func _go_to(pos: Vector3) -> void:
	path = sector.find_path(global_position, pos)


func _physics_process(delta: float) -> void:
	if sector == null or sector.paused_world:
		return
	_time += delta
	var m := Game.mode_data()
	var mult := float(m["listener_speed"])
	var player: Node = sector.player

	match state:
		State.WANDER:
			if path.is_empty():
				_wait -= delta
				if _wait <= 0.0:
					path = sector.find_path(global_position, sector.random_floor_pos())
					_wait = randf_range(1.0, 3.0)
			_follow(WANDER_SPEED * mult, delta)
		State.INVESTIGATE:
			_follow(INVESTIGATE_SPEED * mult, delta)
			if path.is_empty():
				state = State.LISTEN
				_wait = randf_range(2.0, 3.5)
				_breath.play()
		State.LISTEN:
			_wait -= delta
			if _wait <= 0.0:
				_after_listen()
		State.HUNT:
			_hunt_t -= delta
			_repath_t -= delta
			if player.hidden_in:
				# You vanished into a locker: go to where it last heard you.
				state = State.INVESTIGATE
				_go_to(last_heard)
			elif _hunt_t <= 0.0:
				state = State.INVESTIGATE
				_go_to(last_heard)
			else:
				if _repath_t <= 0.0:
					_repath_t = 0.4
					last_heard = player.global_position
					_go_to(player.global_position)
				_follow(HUNT_SPEED * mult, delta)
		State.CHECK_LOCKER:
			if not path.is_empty():
				_follow(INVESTIGATE_SPEED * mult, delta)
			else:
				_face(_checking.global_position, delta)
				_wait -= delta
				if player.hidden_in == _checking and not player.holding_breath:
					sector.on_caught("listener")
					return
				if _wait <= 0.0:
					_checking = null
					_next_locker()

	# Echolocation clicks: faster when it's on to you.
	_click_t -= delta
	if _click_t <= 0.0:
		var gap := {State.WANDER: 1.4, State.INVESTIGATE: 0.8, State.LISTEN: 0.6, State.HUNT: 0.32, State.CHECK_LOCKER: 0.5}
		_click_t = float(gap[state]) * randf_range(0.8, 1.2)
		_audio.pitch_scale = randf_range(0.9, 1.15)
		_audio.play()

	# Gentle sway so the shape looks alive.
	_body.rotation.z = sin(_time * 1.3) * 0.05
	_body.position.y = sin(_time * 2.1) * 0.04

	# Caught?
	if not player.hidden_in and not player.frozen:
		var flat := Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z)
		if flat.length() < 1.15:
			sector.on_caught("listener")


func _after_listen() -> void:
	if Game.learned_lockers:
		_locker_queue = sector.lockers_near(global_position, 10.0, 2)
		_next_locker()
	else:
		state = State.WANDER
		_wait = randf_range(0.5, 2.0)


func _next_locker() -> void:
	if _locker_queue.is_empty():
		state = State.WANDER
		_wait = 1.0
		return
	_checking = _locker_queue.pop_front()
	state = State.CHECK_LOCKER
	_wait = 3.2
	_go_to(_checking.front_pos())
	sector.on_locker_checked(_checking)


func _follow(speed: float, delta: float) -> void:
	if path.is_empty():
		return
	var target: Vector3 = sector.cell_to_world(path[0])
	var to := target - global_position
	to.y = 0.0
	var step := speed * delta
	if to.length() <= step:
		global_position = Vector3(target.x, global_position.y, target.z)
		path.remove_at(0)
		if not path.is_empty():
			sector.monster_entering(path[0])
		elif state == State.CHECK_LOCKER and _checking:
			_checking.rattle()
		return
	global_position += to.normalized() * step
	_face(target, delta)


func _face(target: Vector3, delta: float) -> void:
	var to := target - global_position
	if Vector2(to.x, to.z).length() < 0.01:
		return
	var want := atan2(to.x, to.z)
	rotation.y = lerp_angle(rotation.y, want, minf(delta * 6.0, 1.0))
