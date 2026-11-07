extends CharacterBody3D
## You. First-person movement, the flashlight, hiding in lockers and holding
## your breath. Everything you do makes some amount of NOISE, and the Listener
## hunts by noise.

const WALK := 3.2
const SPRINT := 5.6
const CROUCH := 1.6
const STAND_H := 1.8
const CROUCH_H := 1.0

var sector: Node
var cam: Camera3D
var flashlight: SpotLight3D
var ray: RayCast3D
var capsule: CapsuleShape3D
var shape: CollisionShape3D

var yaw := 0.0
var pitch := 0.0
var crouching := false
var sprinting := false
var stamina := 100.0
var battery := 100.0
var breath := 100.0
var holding_breath := false
var hidden_in: Node = null
var frozen := false
var noise := 0.0           # how loud you are right now (metres the sound carries)
var _gasp_lock := 0.0
var _step_t := 0.0
var _noise_t := 0.0
var _bob := 0.0
var _eye := 1.6
var _exhausted := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = STAND_H
	shape = CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = STAND_H / 2.0
	add_child(shape)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	cam.position.y = _eye
	add_child(cam)
	flashlight = SpotLight3D.new()
	flashlight.spot_range = 20.0
	flashlight.spot_angle = 26.0
	flashlight.spot_attenuation = 0.8
	flashlight.light_energy = 3.0
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.18, -0.15, 0.0)
	cam.add_child(flashlight)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.4)
	ray.collision_mask = 3
	ray.exclude_parent = true
	cam.add_child(ray)


func look_at_yaw(y: float) -> void:
	yaw = y
	pitch = 0.0
	_apply_look()


func _apply_look() -> void:
	rotation.y = yaw
	cam.rotation.x = pitch


func _unhandled_input(event: InputEvent) -> void:
	if frozen or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var inv := -1.0 if Game.invert_y else 1.0
		yaw -= event.relative.x * Game.mouse_sensitivity * 0.01
		pitch -= event.relative.y * Game.mouse_sensitivity * 0.01 * inv
		pitch = clampf(pitch, -1.45, 1.45)
		_apply_look()
	elif event.is_action_pressed("flashlight"):
		if battery > 1.0:
			flashlight.visible = not flashlight.visible
			Sound.play("click", -12.0)
	elif event.is_action_pressed("interact"):
		if hidden_in:
			leave_locker()
		else:
			var hit := ray.get_collider()
			if hit and hit.has_method("interact"):
				hit.interact(self)


func _physics_process(delta: float) -> void:
	if frozen:
		noise = 0.0
		return
	_gamepad_look(delta)
	_update_battery(delta)
	if hidden_in:
		_update_breath(delta)
		noise = 0.0
		sector.hud.set_prompt("Leave locker" if not holding_breath else "")
		return
	breath = minf(breath + 30.0 * delta, 100.0)

	# Crouch (hold). You stay crouched if there's no room to stand up (vents).
	var want_crouch := Input.is_action_pressed("crouch")
	if want_crouch != crouching:
		if want_crouch or not test_move(global_transform, Vector3(0, STAND_H - CROUCH_H + 0.05, 0)):
			crouching = want_crouch
			capsule.height = CROUCH_H if crouching else STAND_H
			shape.position.y = capsule.height / 2.0

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var moving_input := input.length() > 0.1
	if stamina <= 0.0:
		_exhausted = true
	elif stamina > 30.0:
		_exhausted = false
	sprinting = Input.is_action_pressed("sprint") and moving_input and not crouching and not _exhausted
	var speed := CROUCH if crouching else (SPRINT if sprinting else WALK)
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var target := dir * speed
	var accel := 14.0 if moving_input else 18.0
	velocity.x = move_toward(velocity.x, target.x, accel * delta * speed)
	velocity.z = move_toward(velocity.z, target.z, accel * delta * speed)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()

	# Stamina.
	if sprinting:
		stamina = maxf(stamina - 20.0 * delta, 0.0)
		Game.sprint_time += delta
		sector.note_sprint(global_position, delta)
	else:
		stamina = minf(stamina + 13.0 * delta, 100.0)

	# Noise: how far your footsteps carry.
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var on_grate: bool = sector.is_grate(global_position)
	var loud := 0.0
	if hspeed > 0.6:
		if crouching:
			loud = 2.6 if on_grate else 1.0
		elif sprinting:
			loud = 20.0 if on_grate else 12.0
		else:
			loud = 10.0 if on_grate else 4.5
	noise = lerpf(noise, loud, minf(delta * 8.0, 1.0))
	_noise_t -= delta
	if loud > 0.0 and _noise_t <= 0.0:
		_noise_t = 0.35
		sector.emit_noise(global_position, loud, true)

	# Footstep sounds and head bob.
	if hspeed > 0.6 and is_on_floor():
		_step_t -= delta * hspeed
		_bob += delta * hspeed * 2.4
		if _step_t <= 0.0:
			_step_t = 2.1
			var vol := -18.0 if crouching else (-4.0 if sprinting else -10.0)
			Sound.play("step_grate" if on_grate else "step", vol, randf_range(0.85, 1.15))
	var eye_target := 0.85 if crouching else 1.6
	_eye = lerpf(_eye, eye_target, minf(delta * 10.0, 1.0))
	var bob_amt := 0.05 if sprinting else 0.025
	cam.position.y = _eye + sin(_bob) * bob_amt * minf(hspeed, 1.0)

	# What am I looking at?
	var hit := ray.get_collider()
	if hit and hit.has_method("prompt"):
		sector.hud.set_prompt(hit.prompt())
	else:
		sector.hud.set_prompt("")


func _gamepad_look(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() < 0.05:
		return
	var inv := -1.0 if Game.invert_y else 1.0
	yaw -= look.x * delta * 3.0 * Game.mouse_sensitivity * 4.0
	pitch -= look.y * delta * 2.2 * Game.mouse_sensitivity * 4.0 * inv
	pitch = clampf(pitch, -1.45, 1.45)
	_apply_look()


func _update_battery(delta: float) -> void:
	var m := Game.mode_data()
	if flashlight.visible:
		battery = maxf(battery - float(m["battery_drain"]) * delta, 0.0)
		if battery <= 0.0:
			flashlight.visible = false
		flashlight.light_energy = 3.0 if battery > 15.0 else (3.0 if randf() > 0.1 else 0.4)
	else:
		battery = minf(battery + 0.9 * delta, 100.0)


func _update_breath(delta: float) -> void:
	_gasp_lock = maxf(_gasp_lock - delta, 0.0)
	holding_breath = Input.is_action_pressed("hold_breath") and _gasp_lock <= 0.0 and breath > 0.0
	if holding_breath:
		breath = maxf(breath - float(Game.mode_data()["breath_drain"]) * delta, 0.0)
		if breath <= 0.0:
			# Ran out of air: a loud gasp the Listener can hear.
			holding_breath = false
			_gasp_lock = 2.0
			Sound.play("gasp", -2.0)
			sector.emit_noise(global_position, 9.0, true)
	else:
		breath = minf(breath + 22.0 * delta, 100.0)


# ------------------------------------------------------------------ lockers

func enter_locker(locker: Node) -> void:
	hidden_in = locker
	locker.set_occupied(true)
	shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	crouching = false
	capsule.height = STAND_H
	shape.position.y = STAND_H / 2.0
	global_position = locker.inside_pos()
	look_at_yaw(atan2(-locker.facing.x, -locker.facing.z))
	_eye = 1.6
	cam.position.y = _eye
	breath = 100.0
	Sound.play("locker", -6.0)
	sector.on_player_hid(locker)
	sector.hud.show_locker(true)


func leave_locker() -> void:
	if hidden_in == null:
		return
	var locker := hidden_in
	hidden_in = null
	holding_breath = false
	locker.set_occupied(false)
	global_position = locker.front_pos()
	shape.set_deferred("disabled", false)
	Sound.play("locker", -6.0)
	sector.emit_noise(global_position, 3.0, true)
	sector.hud.show_locker(false)


# ------------------------------------------------------------------- sight

## Can you see this point? Used by the Replacement (it only moves when you can't).
func can_see(point: Vector3) -> bool:
	if not cam.is_position_in_frustum(point):
		return false
	var from := cam.global_position
	var dist := from.distance_to(point)
	if dist > 26.0:
		return false
	var lit: bool = (flashlight.visible and dist < 20.0) or (sector.power_on and dist < 14.0) or dist < 5.0
	if not lit:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, point, 1)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func eye_position() -> Vector3:
	return cam.global_position
