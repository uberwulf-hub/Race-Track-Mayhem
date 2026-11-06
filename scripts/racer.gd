class_name Racer
extends Node3D
## One car on the track - either driven by the player or by the computer.
##
## Cars are clipped onto the track like real toy cars: they have a distance
## along the track (`s`), a sideways offset (`lateral`) and a speed. That makes
## loops and banked turns simple and very hard to fall off... unless you go
## too slowly upside down in the loop. MAYHEM!

signal lap_completed(racer: Racer, lap: int, lap_time: float)
signal finished(racer: Racer)
signal crashed(racer: Racer)
signal boosted(racer: Racer)

enum Mode { DRIVING, FALLING }

const GRAVITY := 32.0          # used when flying off the loop
const SLOPE_GRAVITY := 16.0    # how much hills slow you down / speed you up
const LOOP_MIN_SPEED := 11.0   # slower than this upside down = fall off!
const RIDE_HEIGHT := 0.0
const CAR_HALF_WIDTH := 0.65
const BOOST_SPEED_BONUS := 1.45
const TURBO_SPEED_BONUS := 1.28

var track: Track
var car: Dictionary
var stats: Dictionary
var racer_name := "Racer"
var is_player := false
var controls_enabled := false   # false during intro / countdown / after finish

# Track position
var s := 0.0                    # distance along the track, wraps 0..length
var total := 0.0                # distance travelled including laps (can be < 0 on the grid)
var lateral := 0.0
var lateral_vel := 0.0
var speed := 0.0
var steer_input := 0.0
var throttle_input := 0.0

# Race progress
var lap := 0                    # completed laps
var laps_to_win := 3
var race_time := 0.0
var lap_start_time := 0.0
var best_lap := -1.0
var has_finished := false
var finish_time := 0.0
var place := 1

# Effects
var boost_timer := 0.0
var turbo := 1.0                # 0..1 turbo tank (player)
var turbo_on := false
var air_height := 0.0
var in_air := false
var mode := Mode.DRIVING
var _fall_vel := Vector3.ZERO
var _fall_spin := Vector3.ZERO
var _fall_timer := 0.0
var _respawn_s := 0.0
var _invuln := 0.0
var _bump_cooldown := 0.0

# AI
var ai_skill := 0.9
var ai_line := 0.0
var ai_wobble_phase := 0.0
var rubber_band := 1.0

var model: ToyCarModel
var _visual_basis := Basis.IDENTITY


func setup(p_track: Track, car_def: Dictionary, p_is_player: bool, p_name: String) -> Racer:
	track = p_track
	car = car_def
	stats = CarData.physics_for(car_def)
	is_player = p_is_player
	racer_name = p_name
	name = p_name.replace(" ", "")
	model = ToyCarModel.new().setup(car_def)
	add_child(model)
	ai_wobble_phase = randf() * TAU
	ai_line = randf_range(-1.2, 1.2)
	return self


func place_on_grid(start_total: float, start_lateral: float) -> void:
	total = start_total
	s = fposmod(total, track.length)
	lateral = start_lateral
	speed = 0.0
	lap = 0
	_update_transform(1.0, true)


func progress() -> float:
	if has_finished:
		return 1.0e9 - finish_time   # finished cars stay ahead, earliest first
	return total


# ---------------------------------------------------------------------------
# Driving
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if track == null:
		return
	_bump_cooldown = maxf(0.0, _bump_cooldown - delta)
	_invuln = maxf(0.0, _invuln - delta)
	if mode == Mode.FALLING:
		_process_falling(delta)
		return

	var throttle := 0.0
	var brake := 0.0
	var steer := 0.0
	var want_turbo := false
	if controls_enabled and not has_finished:
		if is_player:
			throttle = Input.get_action_strength("accelerate")
			brake = Input.get_action_strength("brake")
			steer = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
			want_turbo = Input.is_action_pressed("turbo")
		else:
			var ai := _ai_inputs()
			throttle = ai.x
			brake = ai.y
			steer = ai.z
	elif has_finished:
		throttle = 0.35 # cruise past the line
		steer = clampf(-lateral * 0.5, -1.0, 1.0)

	steer_input = steer
	throttle_input = throttle
	var frame := track.sample(s)
	var fwd := -frame.basis.z
	var up := frame.basis.y
	var f := track.flags_at(s)

	# --- speed ---
	var top: float = stats["top_speed"] * (rubber_band if not is_player else 1.0)
	if boost_timer > 0.0:
		top *= BOOST_SPEED_BONUS
		boost_timer -= delta
	turbo_on = false
	if is_player:
		if want_turbo and turbo > 0.02 and throttle > 0.1:
			turbo_on = true
			turbo = maxf(0.0, turbo - delta * 0.45)
			top *= TURBO_SPEED_BONUS
		else:
			turbo = minf(1.0, turbo + delta * 0.08)

	var accel := 0.0
	if throttle > 0.0 and speed < top:
		accel += float(stats["accel"]) * throttle * (1.0 - clampf(speed / top, 0.0, 1.0) * 0.6)
		if turbo_on or boost_timer > 0.0:
			accel += 25.0
	if brake > 0.0:
		if speed > 0.5:
			accel -= 40.0 * brake
		else:
			accel -= 10.0 * brake   # reverse slowly
	if throttle <= 0.0 and brake <= 0.0:
		accel -= speed * 0.6        # rolling to a stop
	if speed > top:
		accel -= (speed - top) * 2.5
	accel -= SLOPE_GRAVITY * fwd.y  # uphill slows, downhill speeds up
	speed = clampf(speed + accel * delta, -9.0, 80.0)

	# --- boost pads ---
	if (f & Track.FLAG_BOOST) != 0 and boost_timer <= 0.2:
		boost_timer = 1.6
		speed = maxf(speed, float(stats["top_speed"]) * 1.15)
		boosted.emit(self)

	# --- steering & sliding ---
	var air_t := Track.range_progress(track.gaps, s)
	var grip := 0.15 if air_t >= 0.0 else 1.0
	var speed_factor := clampf(absf(speed) / 12.0, 0.0, 1.0)
	var target_lat_vel := steer * float(stats["steer"]) * speed_factor * grip * signf(speed + 0.01)
	lateral_vel = lerpf(lateral_vel, target_lat_vel, minf(1.0, delta * 10.0))
	# Turns try to push you to the outside; good handling holds you in.
	var curve := track.curvature_at(s)
	var bank := up.y if up.y > 0.0 else 1.0
	var slide := -curve * speed * speed * 0.055 * (1.0 - float(stats["grip"])) * bank
	if (f & Track.FLAG_LOOP) != 0:
		slide = 0.0
	lateral += (lateral_vel + slide * grip) * delta

	var limit := Track.HALF_WIDTH - CAR_HALF_WIDTH
	if absf(lateral) > limit:
		lateral = clampf(lateral, -limit, limit)
		lateral_vel = 0.0
		speed *= pow(0.55, delta)     # scraping the wall slows you down

	# --- jumps ---
	in_air = air_t >= 0.0
	if in_air:
		var hop := clampf((speed - 18.0) * 0.12, 0.3, 3.0)
		air_height = 4.0 * hop * air_t * (1.0 - air_t)
	else:
		if air_height > 0.4:
			Sfx.play("land", 1.0, -6.0 if not is_player else 0.0)
		air_height = 0.0

	# --- loop: too slow upside down and you fall off! ---
	if up.y < -0.3 and speed < LOOP_MIN_SPEED and _invuln <= 0.0:
		_start_fall(frame)
		return

	# --- move along ---
	var ds := speed * delta
	s += ds
	total += ds
	if s >= track.length:
		s -= track.length
	elif s < 0.0:
		s += track.length
	_check_laps()
	_update_transform(delta, false)
	if model:
		model.animate(speed, steer, delta)


func _check_laps() -> void:
	var completed := int(floor(total / track.length))
	if completed > lap and not has_finished:
		lap = completed
		var lap_time := race_time - lap_start_time
		lap_start_time = race_time
		if lap_time > 1.0 and (best_lap < 0.0 or lap_time < best_lap):
			best_lap = lap_time
		lap_completed.emit(self, lap, lap_time)
		if lap >= laps_to_win:
			has_finished = true
			finish_time = race_time
			finished.emit(self)


func _update_transform(delta: float, snap: bool) -> void:
	var frame := track.sample(s)
	var up := frame.basis.y
	var pos := frame.origin + frame.basis.x * lateral + up * (RIDE_HEIGHT + air_height)
	# Point the car a little in the direction it's sliding.
	var yaw := 0.0
	if absf(speed) > 1.0:
		yaw = -atan2(lateral_vel, absf(speed)) * 0.9
	var b := frame.basis.rotated(up, yaw)
	if in_air:
		# nose up on take-off, nose down on landing
		var t := Track.range_progress(track.gaps, s)
		b = b.rotated(b.x, lerpf(0.15, -0.25, t))
	if snap:
		_visual_basis = b.orthonormalized()
	else:
		var q_from := _visual_basis.get_rotation_quaternion()
		var q_to := b.orthonormalized().get_rotation_quaternion()
		_visual_basis = Basis(q_from.slerp(q_to, minf(1.0, delta * 14.0)))
	global_transform = Transform3D(_visual_basis, pos)


# ---------------------------------------------------------------------------
# Falling off the loop (and respawning)
# ---------------------------------------------------------------------------

func _start_fall(frame: Transform3D) -> void:
	mode = Mode.FALLING
	_fall_vel = -frame.basis.z * speed + frame.basis.y * -2.0
	_fall_spin = Vector3(randf_range(-6, 6), randf_range(-4, 4), randf_range(-6, 6))
	_fall_timer = 1.6
	# Respawn back before the boost pad leading into the loop.
	var loop_start := float(track.loops[0][0]) if track.loops.size() > 0 else s
	_respawn_s = loop_start - 26.0
	crashed.emit(self)


func _process_falling(delta: float) -> void:
	_fall_vel.y -= GRAVITY * delta
	var p := global_position + _fall_vel * delta
	if p.y < 0.3:
		p.y = 0.3
		_fall_vel = Vector3(_fall_vel.x * 0.5, absf(_fall_vel.y) * 0.4, _fall_vel.z * 0.5)
		_fall_spin *= 0.6
	var b := global_transform.basis
	b = b.rotated(Vector3.RIGHT, _fall_spin.x * delta).rotated(Vector3.UP, _fall_spin.y * delta).rotated(Vector3.FORWARD, _fall_spin.z * delta)
	global_transform = Transform3D(b.orthonormalized(), p)
	_fall_timer -= delta
	if _fall_timer <= 0.0:
		respawn_at(_respawn_s)


## Puts the car back on the track at distance `at` (moving `total` back too).
func respawn_at(at: float) -> void:
	var back := fposmod(s - at, track.length)
	if back > track.length * 0.5:
		back = 0.0
	total -= back
	s = fposmod(total, track.length)
	lateral = 0.0
	lateral_vel = 0.0
	speed = 0.0
	air_height = 0.0
	boost_timer = 0.0
	mode = Mode.DRIVING
	_invuln = 2.0
	_update_transform(1.0, true)


## Player pressed the respawn button: hop back to the middle of the road.
func manual_respawn() -> void:
	if mode == Mode.FALLING:
		return
	if track.flags_at(s) & (Track.FLAG_LOOP | Track.FLAG_GAP):
		respawn_at(s - 30.0)
	else:
		respawn_at(s)


# ---------------------------------------------------------------------------
# Bumping into each other
# ---------------------------------------------------------------------------

func bump_with(other: Racer) -> void:
	if mode != Mode.DRIVING or other.mode != Mode.DRIVING:
		return
	var d := other.s - s
	if d > track.length * 0.5:
		d -= track.length
	elif d < -track.length * 0.5:
		d += track.length
	var dl := other.lateral - lateral
	var car_len := 2.1
	var car_w := CAR_HALF_WIDTH * 2.0
	if absf(d) > car_len or absf(dl) > car_w:
		return
	var m1: float = stats["mass"]
	var m2: float = other.stats["mass"]
	var share1 := m2 / (m1 + m2)
	var share2 := m1 / (m1 + m2)
	# Push apart sideways...
	var overlap_l := car_w - absf(dl)
	var dir := signf(dl) if absf(dl) > 0.01 else (1.0 if randf() < 0.5 else -1.0)
	if overlap_l < car_w * 0.8 or absf(d) > car_len * 0.6:
		lateral -= dir * overlap_l * share1 * 0.6
		other.lateral += dir * overlap_l * share2 * 0.6
		lateral_vel -= dir * 4.0 * share1
		other.lateral_vel += dir * 4.0 * share2
	# ...and the car behind can't drive through the one in front.
	var overlap_s := car_len - absf(d)
	var behind := self if d > 0.0 else other
	var front := other if d > 0.0 else self
	if behind.speed > front.speed:
		var total_m: float = float(behind.stats["mass"]) + float(front.stats["mass"])
		var v := (behind.speed * float(behind.stats["mass"]) + front.speed * float(front.stats["mass"])) / total_m
		behind.speed = v - 1.0
		front.speed = v + 1.0
	behind.s -= overlap_s * 0.5
	behind.total -= overlap_s * 0.5
	behind.s = fposmod(behind.s, track.length)
	if _bump_cooldown <= 0.0 and (is_player or other.is_player):
		Sfx.play("bump", randf_range(0.9, 1.2))
		_bump_cooldown = 0.35
		other._bump_cooldown = 0.35


# ---------------------------------------------------------------------------
# Computer driver
# ---------------------------------------------------------------------------

## Returns Vector3(throttle, brake, steer).
func _ai_inputs() -> Vector3:
	ai_wobble_phase += get_physics_process_delta_time() * 0.7
	# Look ahead and aim for the inside of upcoming turns.
	var look := 0.0
	for k in [6.0, 12.0, 18.0]:
		look += track.curvature_at(s + k + speed * 0.3)
	look /= 3.0
	var target := clampf(look * 70.0, -2.4, 2.4) + ai_line + sin(ai_wobble_phase) * 0.6
	# In loops and jumps just go straight down the middle.
	var f := track.flags_at(s + 6.0)
	if (f & (Track.FLAG_LOOP | Track.FLAG_GAP)) != 0:
		target = ai_line * 0.3
	target = clampf(target, -2.6, 2.6)
	var steer := clampf((target - lateral) * 0.9 - lateral_vel * 0.12, -1.0, 1.0)
	var throttle := ai_skill
	return Vector3(throttle, 0.0, steer)
