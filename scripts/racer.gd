class_name Racer
extends Node3D
## One car on the track - either driven by the player or by the computer.
##
## Cars are clipped onto the track like real toy cars: they have a distance
## along the track (`s`), a sideways offset (`lateral`) and a speed. That makes
## loops and banked turns simple. But you can still come off:
##  - go too slowly upside down in a loop,
##  - take a turn too fast and smack the outside rail without steering in,
##  - mess up a jump (too slow, or land beside the track).
## Then the screen fades and you're put back where you came off. MAYHEM!

signal lap_completed(racer: Racer, lap: int, lap_time: float)
signal finished(racer: Racer)
signal crashed(racer: Racer, reason: String)
signal respawned(racer: Racer)
signal boosted(racer: Racer)
signal landed(racer: Racer, strength: float)
signal bumped(racer: Racer, strength: float)

enum Mode { DRIVING, AIRBORNE, FALLING }

const GRAVITY := 32.0          # used when flying off the track
const AIR_GRAVITY := 26.0      # used for jumps (a bit floaty, it's a toy!)
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
var _respawn_speed := 0.0
var braking := false           # for brake sounds
var skipped_ahead := false     # set when a car was helped past a spot it kept falling at
# Power-ups (see PowerUps)
var item := ""                 # the power-up this car is holding
var shield_timer := 0.0        # bubble shield blocks the next hit
var bubble_timer := 0.0        # trapped in a soap bubble: floats along slowly
var _shield_mesh: MeshInstance3D
var _bubble_mesh: MeshInstance3D
var _same_spot_falls := 0
var _last_fall_at := -1000.0
# Bump physics: a sideways shove and a spin that fade away.
var knock := 0.0               # extra sideways speed from being hit
var spin := 0.0                # how far the car is twisted (radians)
var spin_vel := 0.0
# Jump state
var _air_pos := Vector3.ZERO
var _air_vel := Vector3.ZERO
var _air_launch := Vector3.ZERO
var _air_dir := Vector3.FORWARD
var _air_right := Vector3.RIGHT
var _air_s0 := 0.0
var _air_total0 := 0.0
var _air_lat0 := 0.0
var _air_gap_start := 0.0
var _air_gap_end := 0.0
var _invuln := 0.0
var _bump_cooldown := 0.0
var _wall_cooldown := 0.0

# AI
var ai_skill := 0.9
var ai_line := 0.0
var ai_wobble_phase := 0.0
var rubber_band := 1.0

var model: ToyCarModel
var _sparks: CPUParticles3D
var scraping := false
var _visual_basis := Basis.IDENTITY
var player_index := 0           # 0 = computer, 1 = player 1, 2 = player 2

# Online races
var net_key := ""               # who this car is on every computer ("p<peer>" or "ai<n>")
var remote := false             # driven by another computer; we just show it
var human := false              # a person drives it (here or on another computer)
var _net_pos := Vector3.ZERO
var _net_rot := Quaternion.IDENTITY
var _net_seen := false
var skid_marks: SkidMarks
var _mark_dist := 0.0
var _last_speed := 0.0
var _dust: CPUParticles3D


func setup(p_track: Track, car_def: Dictionary, p_is_player: bool, p_name: String, look: Dictionary = {}) -> Racer:
	track = p_track
	car = car_def
	var nick := CarData.nickname(look)
	if nick != "":
		car = car_def.duplicate()
		car["name"] = nick   # the name you gave it in the Car Designer
	stats = CarData.physics_for(car_def)
	is_player = p_is_player
	racer_name = p_name
	name = p_name.replace(" ", "")
	model = ToyCarModel.new().setup(car_def, true, look)
	add_child(model)
	_sparks = _make_sparks()
	add_child(_sparks)
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
	if remote:
		_process_remote(delta)
		return
	_bump_cooldown = maxf(0.0, _bump_cooldown - delta)
	_wall_cooldown = maxf(0.0, _wall_cooldown - delta)
	_invuln = maxf(0.0, _invuln - delta)
	shield_timer = maxf(0.0, shield_timer - delta)
	bubble_timer = maxf(0.0, bubble_timer - delta)
	_update_item_visuals(delta)
	if mode == Mode.FALLING:
		_process_falling(delta)
		return

	var throttle := 0.0
	var brake := 0.0
	var steer := 0.0
	var want_turbo := false
	if controls_enabled and not has_finished:
		if is_player:
			throttle = Input.get_action_strength(action("accelerate"))
			brake = Input.get_action_strength(action("brake"))
			steer = Input.get_action_strength(action("steer_right")) - Input.get_action_strength(action("steer_left"))
			if Game.auto_go and brake < 0.1:
				throttle = 1.0          # Auto-Go: the car drives itself forward
			if Game.tilt_steer > 0 and absf(steer) < 0.05:
				steer = Game.tilt_amount()
			want_turbo = Input.is_action_pressed(action("turbo"))
			if Game.steer_assist:
				steer = clampf(steer + _steer_help(steer), -1.0, 1.0)
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
	braking = brake > 0.1 and speed > 12.0
	if mode == Mode.AIRBORNE:
		_process_air(delta, steer)
		return
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
	if bubble_timer > 0.0:
		speed = minf(speed, 9.0)    # floating along in a soap bubble

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
	var slide := slide_for(curve, speed, up)
	if (f & Track.FLAG_LOOP) != 0:
		slide = 0.0
	# Recover from bumps: the shove and the twist settle down.
	knock *= exp(-2.5 * delta)
	spin_vel *= exp(-3.0 * delta)
	spin += spin_vel * delta
	spin *= exp(-2.2 * delta)
	lateral += (lateral_vel + slide * grip + knock) * delta

	var limit := Track.HALF_WIDTH - CAR_HALF_WIDTH
	scraping = false
	if absf(lateral) > limit:
		var side := signf(lateral)
		# Slamming into the outside rail in a turn too fast: BONK! The car
		# bounces off and slows right down (a really hard hit spins it out),
		# but it stays on the track.
		var outward := slide * side + maxf(0.0, lateral_vel * side) * 0.5 + maxf(0.0, knock * side)
		if absf(curve) > 0.02 and absf(speed) > 22.0 and outward > _fly_off_limit() and _wall_cooldown <= 0.0 \
				and (f & (Track.FLAG_LOOP | Track.FLAG_GAP)) == 0:
			_wall_cooldown = 0.6
			var hard := outward > _fly_off_limit() * 2.0
			speed *= 0.4 if hard else 0.6
			knock = -side * clampf(outward * 0.9, 3.0, 9.0)            # pushed back towards the middle
			spin_vel += -side * (11.0 if hard else 5.0)                 # spin out (or a little twist)
			bumped.emit(self, 1.0 if hard else 0.6)
			crashed.emit(self, "wall_hard" if hard else "wall")
		lateral = clampf(lateral, -limit, limit)
		lateral_vel = 0.0
		if knock * side > 0.0:
			knock = -knock * 0.3        # bounce off the rail
		speed *= pow(0.55, delta)     # scraping the wall slows you down
		scraping = absf(speed) > 8.0 and air_t < 0.0
	_sparks.emitting = scraping
	_sparks.position = Vector3(signf(lateral) * 0.7, 0.25, 0.2)

	# --- jumps: leaving the ramp lip launches the car for real ---
	if air_t >= 0.0:
		_launch(frame)
		return

	# --- loop: too slow upside down and you fall off! ---
	if up.y < -0.3 and speed < LOOP_MIN_SPEED and _invuln <= 0.0:
		var loop_start := s
		for r in track.loops:
			if s >= float(r[0]) - 1.0 and s <= float(r[1]) + 1.0:
				loop_start = float(r[0])
		_fall_off(-frame.basis.z * speed + frame.basis.y * -2.0, loop_start - 26.0, 0.0, "loop")
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
		# Lean into turns and nod when speeding up or braking.
		var accel_now := (speed - _last_speed) / maxf(delta, 0.001)
		model.set_motion(accel_now, slide + lateral_vel * 0.3, delta)
	_last_speed = speed
	_leave_skid_marks(ds, slide, frame)


## Name of an input action for this player.
func action(action_name: String) -> String:
	return action_name


## Steering help for little drivers: leans against the turn's push and keeps
## the car away from the rails. The player's own steering always wins.
func _steer_help(player_steer: float) -> float:
	var frame := track.sample(s + 3.0)
	var slide := slide_for(track.curvature_at(s + 3.0), speed, frame.basis.y)
	var help := -slide / maxf(1.0, float(stats["steer"])) * 0.85
	if absf(player_steer) < 0.15:
		var edge := Track.HALF_WIDTH - CAR_HALF_WIDTH - 0.6
		if absf(lateral) > edge * 0.6:
			help += -signf(lateral) * 0.35
	return help


## Dark rubber streaks when skidding through turns, braking hard or scraping.
func _leave_skid_marks(ds: float, slide: float, frame: Transform3D) -> void:
	if skid_marks == null or in_air or mode != Mode.DRIVING:
		return
	var strength := 0.0
	if scraping:
		strength = 0.8
	elif braking and speed > 15.0:
		strength = 0.7
	elif absf(slide) > 3.0 and speed > 25.0:
		strength = clampf((absf(slide) - 3.0) / 4.0, 0.3, 0.9)
	elif absf(spin) > 0.25:
		strength = 0.6
	if strength <= 0.0:
		_mark_dist = 0.0
		return
	_mark_dist += absf(ds)
	if _mark_dist < 0.45:
		return
	_mark_dist = 0.0
	var b := global_transform.basis
	for side: float in [-0.55, 0.55]:
		var p := global_position + b.x * side + b.z * 0.65
		skid_marks.add_mark(p, Basis(b.x, frame.basis.y, b.z), strength)


# ---------------------------------------------------------------------------
# Online: sending and showing cars driven on other computers
# ---------------------------------------------------------------------------

const NET_AIR := 1
const NET_FALLING := 2
const NET_FLAME := 4
const NET_SHIELD := 8
const NET_BUBBLE := 16
const NET_FINISHED := 32
const NET_BRAKING := 64


## This car's state, to send to the other computers.
func net_state() -> Array:
	var f := 0
	if mode == Mode.AIRBORNE:
		f |= NET_AIR
	if mode == Mode.FALLING:
		f |= NET_FALLING
	if boost_timer > 0.0 or turbo_on:
		f |= NET_FLAME
	if shield_timer > 0.0:
		f |= NET_SHIELD
	if bubble_timer > 0.0:
		f |= NET_BUBBLE
	if has_finished:
		f |= NET_FINISHED
	if braking:
		f |= NET_BRAKING
	return [net_key, global_position, global_transform.basis.get_rotation_quaternion(),
		speed, s, total, lateral, steer_input, f, lap, finish_time, best_lap]


## Takes in a state sent by the computer that drives this car.
func apply_net_state(st: Array) -> void:
	_net_pos = st[1]
	_net_rot = st[2]
	speed = st[3]
	s = st[4]
	total = st[5]
	lateral = st[6]
	steer_input = st[7]
	var f: int = st[8]
	lap = st[9]
	best_lap = st[11]
	mode = Mode.FALLING if f & NET_FALLING else (Mode.AIRBORNE if f & NET_AIR else Mode.DRIVING)
	in_air = mode == Mode.AIRBORNE
	boost_timer = 0.2 if f & NET_FLAME else 0.0
	shield_timer = 1.0 if f & NET_SHIELD else 0.0
	bubble_timer = 1.0 if f & NET_BUBBLE else 0.0
	braking = (f & NET_BRAKING) != 0
	if not _net_seen:
		_net_seen = true
		global_transform = Transform3D(Basis(_net_rot), _net_pos)
	if (f & NET_FINISHED) and not has_finished:
		has_finished = true
		finish_time = st[10]
		finished.emit(self)


func _process_remote(delta: float) -> void:
	_update_item_visuals(delta)
	if not _net_seen:
		return
	# Glide towards where the car was last seen, a little ahead along its way.
	var k := minf(1.0, delta * 14.0)
	var guess := _net_pos
	var t := global_transform
	t.origin = t.origin.lerp(guess, k)
	t.basis = Basis(t.basis.get_rotation_quaternion().slerp(_net_rot, k))
	global_transform = t
	if model:
		model.animate(speed, steer_input, delta)
		if model.shadow:
			model.shadow.visible = mode != Mode.FALLING


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
	var yaw := -spin
	if absf(speed) > 1.0:
		yaw -= atan2(lateral_vel + knock, absf(speed)) * 0.9
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
	if model and model.shadow:
		model.shadow.visible = true
		model.shadow.position.y = 0.03 - air_height
		var shrink := clampf(1.0 - air_height * 0.15, 0.5, 1.0)
		model.shadow.scale = Vector3(shrink, 1.0, shrink)


# ---------------------------------------------------------------------------
# Falling off the loop (and respawning)
# ---------------------------------------------------------------------------

## How hard a turn pushes the car towards the outside (sideways units/second).
## Good handling and banked turns push less. Easy mode is gentler.
func slide_for(curve: float, spd: float, up: Vector3) -> float:
	var bank := clampf(up.y, 0.6, 1.0) if up.y > 0.0 else 1.0
	var diff: float = [0.8, 1.0, 1.15][Game.difficulty]
	return -curve * spd * spd * 0.07 * (1.3 - float(stats["grip"])) * bank * diff


func _fly_off_limit() -> float:
	var base: float = [4.6, 3.6, 2.9][Game.difficulty]
	return base if is_player else base + 2.5


# ---------------------------------------------------------------------------
# Jumping
# ---------------------------------------------------------------------------

func _launch(frame: Transform3D) -> void:
	var gap_start := s
	var gap_end := s
	for r in track.gaps:
		if s >= float(r[0]) - 0.5 and s < float(r[1]):
			gap_start = float(r[0])
			gap_end = float(r[1])
	mode = Mode.AIRBORNE
	in_air = true
	_air_gap_start = gap_start
	_air_gap_end = gap_end
	_air_s0 = s
	_air_total0 = total
	_air_lat0 = lateral
	_air_launch = frame.origin + frame.basis.x * lateral
	_air_pos = _air_launch
	_air_vel = -frame.basis.z * speed + frame.basis.x * lateral_vel * 0.5
	# Super-fast cars fly a bit less far so they still land on the runway
	# (too-slow cars still fall short).
	var gap_len := Vector2(track.sample(gap_end).origin.x - frame.origin.x, track.sample(gap_end).origin.z - frame.origin.z).length()
	var angle := asin(clampf(-frame.basis.z.y, 0.05, 0.9))
	var max_speed := sqrt((gap_len + 10.0) * AIR_GRAVITY / maxf(sin(2.0 * angle), 0.2))
	if _air_vel.length() > max_speed:
		_air_vel = _air_vel.normalized() * max_speed
	_air_dir = Vector3(-frame.basis.z.x, 0.0, -frame.basis.z.z).normalized()
	_air_right = Vector3(frame.basis.x.x, 0.0, frame.basis.x.z).normalized()
	_sparks.emitting = false
	scraping = false
	Sfx.play("jump", randf_range(0.95, 1.1), 0.0 if is_player else -9.0)


func _process_air(delta: float, steer: float) -> void:
	# A little air control so you can line up the landing.
	_air_vel += _air_right * steer * 7.0 * delta
	_air_vel.y -= AIR_GRAVITY * delta
	_air_pos += _air_vel * delta
	var rel := _air_pos - _air_launch
	var along := rel.dot(_air_dir)
	var new_s := _air_s0 + along
	lateral = _air_lat0 + rel.dot(_air_right)
	var past_gap := new_s >= _air_gap_end
	if past_gap:
		# The track may curve after the landing ramp: measure against the
		# nearest bit of track under the car, not a straight line.
		new_s = _nearest_s(_air_pos, maxf(_air_gap_end, new_s - 15.0), new_s + 15.0)
		var f := track.sample(new_s)
		lateral = (_air_pos - f.origin).dot(f.basis.x)
	var surf := track.sample(new_s)
	var height := (_air_pos - surf.origin).dot(surf.basis.y)
	var landing_top := track.sample(_air_gap_end).origin.y

	if not past_gap and _air_pos.y < landing_top - 0.8:
		# Too slow: dropped into the gap!
		_set_track_pos(new_s)
		_fall_off(_air_vel, _air_gap_start - 24.0, float(stats["top_speed"]) * 0.8, "jump")
		return
	if past_gap and height <= 0.05:
		if absf(lateral) <= Track.HALF_WIDTH - 0.2:
			# Nice landing!
			_set_track_pos(new_s)
			lateral = clampf(lateral, -(Track.HALF_WIDTH - CAR_HALF_WIDTH), Track.HALF_WIDTH - CAR_HALF_WIDTH)
			speed = maxf(0.0, _air_vel.dot(-surf.basis.z))
			lateral_vel = 0.0
			mode = Mode.DRIVING
			in_air = false
			air_height = 0.0
			var impact := absf(_air_vel.dot(surf.basis.y))
			Sfx.play("land", 1.0, -6.0 if not is_player else 0.0)
			landed.emit(self, impact * 0.15)
			if model:
				model.squash(clampf(impact * 0.04, 0.15, 0.6))
			_puff_dust()
			_update_transform(delta, false)
			return
		# Landed beside the track - over the edge you go!
		_set_track_pos(new_s)
		_fall_off(_air_vel, _air_gap_start - 24.0, float(stats["top_speed"]) * 0.8, "jump")
		return

	_set_track_pos(new_s)
	_check_laps()
	# Point the car along its flight path.
	var f := _air_vel.normalized()
	var r := f.cross(Vector3.UP).normalized()
	var b := Basis(r, r.cross(f).normalized(), -f)
	_visual_basis = Basis(_visual_basis.get_rotation_quaternion().slerp(b.get_rotation_quaternion(), minf(1.0, delta * 8.0)))
	global_transform = Transform3D(_visual_basis, _air_pos)
	if model:
		model.animate(speed, steer, delta)
		if model.shadow:
			var ground := surf.origin.y if past_gap and absf(lateral) < Track.HALF_WIDTH else 0.03
			model.shadow.global_transform = Transform3D(Basis(), Vector3(_air_pos.x, ground + 0.03, _air_pos.z))


## The track distance between a and b whose centre line is closest to p
## (sideways distance only).
func _nearest_s(p: Vector3, a: float, b: float) -> float:
	var best := a
	var best_d := INF
	var t := a
	while t <= b:
		var q := track.sample(t).origin
		var d := Vector2(q.x - p.x, q.z - p.z).length_squared()
		if d < best_d:
			best_d = d
			best = t
		t += 0.5
	return best


func _set_track_pos(new_s: float) -> void:
	var moved := new_s - _air_s0
	total = _air_total0 + moved
	s = fposmod(new_s, track.length)


# ---------------------------------------------------------------------------
# Falling off the track (and respawning)
# ---------------------------------------------------------------------------

## Sends the car tumbling off the track. It reappears at `at` with `start_speed`.
func _fall_off(vel: Vector3, at: float, start_speed: float, reason: String) -> void:
	# Fell at the same spot twice in a row? Put the car just past the
	# tricky bit so nobody gets stuck forever.
	if absf(fposmod(at - _last_fall_at + track.length * 0.5, track.length) - track.length * 0.5) < 6.0:
		_same_spot_falls += 1
	else:
		_same_spot_falls = 0
	_last_fall_at = at
	if _same_spot_falls >= 2 and reason in ["jump", "loop"]:
		var past := _air_gap_end + 4.0 if reason == "jump" else at + 60.0
		if reason == "loop":
			for r in track.loops:
				if absf(fposmod(at + 26.0 - float(r[0]) + track.length * 0.5, track.length) - track.length * 0.5) < 2.0:
					past = float(r[1]) + 4.0
		skipped_ahead = true
		at = past
		start_speed = float(stats["top_speed"]) * 0.5
		_same_spot_falls = 0
		_last_fall_at = -1000.0
	mode = Mode.FALLING
	in_air = false
	_sparks.emitting = false
	scraping = false
	if model and model.shadow:
		model.shadow.visible = false
	_fall_vel = vel
	_fall_spin = Vector3(randf_range(-6, 6), randf_range(-4, 4), randf_range(-6, 6))
	_fall_timer = 1.7
	_respawn_s = at
	_respawn_speed = start_speed
	crashed.emit(self, reason)


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
		respawn_at(_respawn_s, _respawn_speed)


## Puts the car back on the track at distance `at` (moving `total` back too).
func respawn_at(at: float, start_speed: float = 0.0) -> void:
	var back := fposmod(s - at, track.length)
	if back > track.length * 0.5:
		back -= track.length   # a little way ahead (being helped past a tricky bit)
	total -= back
	s = fposmod(total, track.length)
	lateral = 0.0
	lateral_vel = 0.0
	knock = 0.0
	spin = 0.0
	spin_vel = 0.0
	speed = start_speed
	air_height = 0.0
	in_air = false
	boost_timer = 0.0
	mode = Mode.DRIVING
	_invuln = 2.0
	if model and model.shadow:
		model.shadow.visible = true
		model.shadow.transform = Transform3D(Basis(), Vector3(0, 0.03, 0))
	_update_transform(1.0, true)
	_puff_dust()
	respawned.emit(self)


## Player pressed the respawn button: hop back to the middle of the road.
func manual_respawn() -> void:
	if mode != Mode.DRIVING:
		return
	if track.flags_at(s) & (Track.FLAG_LOOP | Track.FLAG_GAP):
		respawn_at(s - 30.0)
	else:
		respawn_at(s)


# ---------------------------------------------------------------------------
# Bumping into each other
# ---------------------------------------------------------------------------

## Car-to-car collisions, done like a little 2D physics engine on the
## "unrolled" track (x = distance along the track, y = sideways):
##  1. Each car is two circles (nose and tail), turned by how twisted it is.
##  2. Find the closest pair of circles; if they overlap, that's a hit.
##  3. Push the cars apart (heavier cars move less).
##  4. Bounce: an impulse along the contact normal changes both speeds.
##  5. Spin: hitting a car off-centre twists it (torque = offset x impulse).
## So a hit on someone's back corner kicks their tail out sideways.
const CAR_RADIUS := 0.62
const CAR_AXLE := 0.5            # circle centres this far in front / behind
const BOUNCE := 0.35             # restitution: 0 = thud, 1 = super bouncy

func _circles(origin_s: float) -> Array[Vector2]:
	var yaw := spin + atan2(lateral_vel + knock, maxf(absf(speed), 1.0))
	var d := Vector2(cos(yaw), sin(yaw)) * CAR_AXLE
	var c := Vector2(origin_s, lateral)
	return [c + d, c - d]


func bump_with(other: Racer) -> void:
	if mode != Mode.DRIVING or other.mode != Mode.DRIVING:
		return
	var d := other.s - s
	if d > track.length * 0.5:
		d -= track.length
	elif d < -track.length * 0.5:
		d += track.length
	if absf(d) > 3.0 or absf(other.lateral - lateral) > 2.5:
		return
	# 1-2: closest pair of circles
	var mine := _circles(0.0)
	var theirs := other._circles(d)
	var best_dist := INF
	var pa := Vector2.ZERO
	var pb := Vector2.ZERO
	for a in mine:
		for b in theirs:
			var dist := a.distance_to(b)
			if dist < best_dist:
				best_dist = dist
				pa = a
				pb = b
	var min_dist := CAR_RADIUS * 2.0
	if best_dist >= min_dist:
		return
	var n := (pb - pa) / best_dist if best_dist > 0.001 else Vector2(signf(d) if d != 0.0 else 1.0, 0.0)
	var m1: float = stats["mass"]
	var m2: float = other.stats["mass"]
	var inv1 := 1.0 / m1
	var inv2 := 1.0 / m2
	# 3: separate (positional correction)
	var pen := min_dist - best_dist
	var push := n * pen / (inv1 + inv2)
	_shift(-push * inv1)
	other._shift(push * inv2)
	# 4: bounce impulse along the normal
	var v1 := Vector2(speed, lateral_vel + knock)
	var v2 := Vector2(other.speed, other.lateral_vel + other.knock)
	var vn := (v2 - v1).dot(n)
	if vn >= 0.0:
		return   # already moving apart
	var j := -(1.0 + BOUNCE) * vn / (inv1 + inv2)
	var impulse := n * j
	speed -= impulse.x * inv1
	knock -= impulse.y * inv1
	other.speed += impulse.x * inv2
	other.knock += impulse.y * inv2
	# 5: spin from off-centre hits. The contact point is between the circles;
	# its offset from each car's middle times the sideways impulse = torque.
	var contact := (pa + pb) * 0.5
	var r1 := contact - Vector2(0.0, lateral)
	var r2 := contact - Vector2(d, other.lateral)
	spin_vel += r1.cross(-impulse) * inv1 * 0.9
	other.spin_vel += r2.cross(impulse) * inv2 * 0.9
	spin_vel = clampf(spin_vel, -6.0, 6.0)
	other.spin_vel = clampf(other.spin_vel, -6.0, 6.0)
	knock = clampf(knock, -14.0, 14.0)
	other.knock = clampf(other.knock, -14.0, 14.0)
	if _bump_cooldown <= 0.0 and (is_player or other.is_player):
		Sfx.play("bump", randf_range(0.9, 1.2), clampf(-14.0 + j * 0.8, -14.0, 0.0))
		var me := self if is_player else other
		me.bumped.emit(me, clampf(j * 0.15, 0.2, 1.5))
		_bump_cooldown = 0.25
		other._bump_cooldown = 0.25


## Moves the car by (along the track, sideways).
func _shift(v: Vector2) -> void:
	s = fposmod(s + v.x, track.length)
	total += v.x
	lateral += v.y


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
	# Steer against the slide that the turn is about to cause.
	var frame := track.sample(s)
	var slide := slide_for(track.curvature_at(s + 2.0), speed, frame.basis.y)
	var counter := -slide / maxf(1.0, float(stats["steer"]))
	var steer := clampf((target - lateral) * 0.9 - lateral_vel * 0.12 + counter, -1.0, 1.0)
	var throttle := ai_skill
	return Vector3(throttle, 0.0, steer)


func _make_sparks() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.3
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3(0, 1, 1).normalized()
	p.spread = 40.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -20, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.1
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	mesh.material = mat
	p.mesh = mesh
	return p


## A little puff of dust (used on landings and respawns).
func _puff_dust() -> void:
	if _dust == null:
		_dust = CPUParticles3D.new()
		_dust.amount = 16
		_dust.one_shot = true
		_dust.explosiveness = 1.0
		_dust.lifetime = 0.6
		_dust.local_coords = false
		_dust.direction = Vector3.UP
		_dust.spread = 80.0
		_dust.initial_velocity_min = 2.0
		_dust.initial_velocity_max = 5.0
		_dust.gravity = Vector3(0, -3, 0)
		_dust.scale_amount_min = 0.3
		_dust.scale_amount_max = 0.6
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 8
		mesh.rings = 4
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mesh.material = mat
		_dust.mesh = mesh
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.95, 0.85, 0.7))
		grad.set_color(1, Color(1.0, 0.95, 0.85, 0.0))
		_dust.color_ramp = grad
		add_child(_dust)
	_dust.restart()


## The see-through shield and the soap bubble around the car.
func _update_item_visuals(delta: float) -> void:
	if model == null:
		return
	if shield_timer > 0.0 and _shield_mesh == null:
		_shield_mesh = _glass_ball(1.9, Color(0.5, 1.0, 0.7, 0.22))
	if _shield_mesh:
		_shield_mesh.visible = shield_timer > 0.0
		_shield_mesh.rotation.y += delta * 2.0
	if bubble_timer > 0.0 and _bubble_mesh == null:
		_bubble_mesh = _glass_ball(1.7, Color(0.75, 0.9, 1.0, 0.3))
	if _bubble_mesh:
		_bubble_mesh.visible = bubble_timer > 0.0
	# Bubbled cars float up and wobble.
	var lift := 1.4 if bubble_timer > 0.0 else 0.0
	model.position.y = lerpf(model.position.y, lift, minf(1.0, delta * 6.0))
	if bubble_timer > 0.0:
		model.rotation.z = sin(Time.get_ticks_msec() * 0.006) * 0.25
	else:
		model.rotation.z = lerpf(model.rotation.z, 0.0, minf(1.0, delta * 8.0))


func _glass_ball(radius: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.rim_enabled = true
	m.rim = 1.0
	m.roughness = 0.0
	m.metallic_specular = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.7, 0)
	model.add_child(mi)
	return mi
