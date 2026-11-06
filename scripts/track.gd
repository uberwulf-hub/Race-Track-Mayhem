class_name Track
extends Node3D
## Builds a classic orange plastic toy race track out of simple pieces
## (straights, banked turns, a loop-de-loop, a jump ramp, a hill...).
##
## The layout is described like "turtle graphics" in `_layout()`: a little
## builder walks forward, turns, climbs and loops while dropping points.
## Two of the straights are stretched automatically so the circuit always
## closes perfectly back at the start line - so it's safe to tinker with!
##
## Cars don't use a physics engine: they ride the track like a real toy car
## clipped into its groove, using `sample(distance)` to find where they are.

const HALF_WIDTH := 3.6
const RAIL_HEIGHT := 0.75
const RAIL_THICK := 0.35
const THICKNESS := 0.3
const BASE_HEIGHT := 0.35         # the track lies on the floor
const SPACING := 0.5              # distance between final samples
const RAW_STEP := 0.2             # step length while "walking" the layout
const CONNECTOR_EVERY := 24       # toy track piece joints (in samples)

const FLAG_GAP := 1               # no track here (jump!)
const FLAG_BOOST := 2             # speed boost pad
const FLAG_LOOP := 4              # inside the loop-de-loop
const FLAG_START := 8             # start / finish line
const FLAG_TWIST := 16            # corkscrew (also flagged as a loop)

## The tracks you can race on. `layout` picks the builder function below.
const TRACKS: Array[Dictionary] = [
	{
		"id": "bedroom_speedway",
		"name": "Bedroom Speedway",
		"room": "bedroom",
		"room_name": "The Bedroom",
		"blurb": "The classic! A loop-de-loop, a big jump and a hill.",
		"features": ["Loop-de-loop", "Ramp jump", "Hill", "Chicane"],
		"stars": 1,
		"color": Color(0.35, 0.55, 0.95),
	},
	{
		"id": "toy_box_twister",
		"name": "Toy Box Twister",
		"room": "playroom",
		"room_name": "The Playroom",
		"blurb": "A figure-8 that flies over itself, with a corkscrew!",
		"features": ["Corkscrew", "Figure-8 bridge", "Loop-de-loop", "Jump"],
		"stars": 2,
		"color": Color(0.95, 0.45, 0.2),
	},
	{
		"id": "kitchen_kerfuffle",
		"name": "Kitchen Kerfuffle",
		"room": "kitchen",
		"room_name": "The Kitchen",
		"blurb": "Spiral up high, zoom back down, then jump twice!",
		"features": ["Spiral climb", "Big drop", "Double jump", "S-bends"],
		"stars": 2,
		"color": Color(0.3, 0.7, 0.6),
	},
	{
		"id": "bubble_bath_bash",
		"name": "Bubble Bath Bash",
		"room": "bathroom",
		"room_name": "The Bathroom",
		"blurb": "Two loops in a row, wobbly waves and a duck to dodge!",
		"features": ["Double loop", "Wavy bumps", "Zig-zags", "Jump"],
		"stars": 2,
		"color": Color(0.35, 0.7, 0.95),
	},
	{
		"id": "sofa_slalom",
		"name": "Sofa Slalom",
		"room": "living_room",
		"room_name": "The Living Room",
		"blurb": "The ultimate challenge: wiggles, a spiral, a corkscrew AND a loop.",
		"features": ["Slalom", "Spiral", "Corkscrew", "Loop", "Jump"],
		"stars": 3,
		"color": Color(0.75, 0.35, 0.55),
	},
]

var layout_id := 0
var stretch := Vector2.ZERO   # how long the auto-sized straights came out

const TRACK_COLOR := Color(1.0, 0.45, 0.05)
const TRACK_DARK := Color(0.85, 0.32, 0.02)
const TRACK_EDGE := Color(1.0, 0.56, 0.18)

# Final, evenly spaced samples along the centre line of the road surface.
var points := PackedVector3Array()
var forwards := PackedVector3Array()
var ups := PackedVector3Array()
var curvature := PackedFloat32Array()  # + means turning right
var flags := PackedInt32Array()
var length := 0.0
var spacing := SPACING
var count := 0
var gaps: Array = []    # [[start_s, end_s], ...]
var loops: Array = []   # [[start_s, end_s], ...]
var boosts: Array = []  # [[start_s, end_s], ...]

# Turtle state while building.
var _pos := Vector3.ZERO
var _fwd := Vector3.FORWARD
var _up := Vector3.UP
var _roll := 0.0
var _raw_pos: Array[Vector3] = []
var _raw_fwd: Array[Vector3] = []
var _raw_up: Array[Vector3] = []
var _raw_flags: Array[int] = []
var _marks: Dictionary = {}
var _start_lights: Array[StandardMaterial3D] = []


func build() -> void:
	_build_closed_layout()
	_resample()
	_find_ranges()
	_build_mesh()
	_build_boost_pads()
	_build_start_line()
	_build_road_details()
	_build_supports()
	_build_loop_stand()


# ---------------------------------------------------------------------------
# The layout. Positive turn angles go right, positive pitch goes up,
# bank tilts the road into the turn.
# ---------------------------------------------------------------------------

func _layout(stretch_a: float, stretch_b: float) -> void:
	match layout_id:
		1:
			_layout_twister(stretch_a, stretch_b)
		2:
			_layout_kitchen(stretch_a, stretch_b)
		3:
			_layout_bathroom(stretch_a, stretch_b)
		4:
			_layout_living_room(stretch_a, stretch_b)
		_:
			_layout_speedway(stretch_a, stretch_b)


## Track 1: Bedroom Speedway.
func _layout_speedway(stretch_a: float, stretch_b: float) -> void:
	_mark("A")
	_straight(stretch_a)                # start / finish straight
	_straight(9.0, FLAG_BOOST)          # boost pad before the loop
	_straight(7.0)
	_loop(8.5, 10.0)                    # LOOP-DE-LOOP!
	_straight(12.0)
	_turn(90.0, 18.0, 22.0)             # big banked right-hander
	_straight(10.0)
	_jump()                             # ramp jump over a gap
	_straight(14.0)
	_turn(90.0, 15.0, 20.0)
	_straight(4.0)
	_turn(-55.0, 13.0, -16.0)           # wiggly chicane
	_turn(110.0, 13.0, 22.0)
	_turn(-55.0, 13.0, -16.0)
	_straight(6.0)
	_hill()                             # big hill bridge
	_straight(6.0)
	_turn(90.0, 17.0, 22.0)
	_mark("B")
	_straight(stretch_b)                # back straight
	_straight(8.0, FLAG_BOOST)
	_straight(6.0)
	_turn(90.0, 17.0, 22.0)
	_straight(26.0)                     # run up to the line (starting grid)


## Track 2: Toy Box Twister. A figure-8: the right-hand loop has a corkscrew,
## then the track climbs over a bridge, crossing above the start straight,
## and the left-hand loop has a chicane, a jump and a loop-de-loop.
func _layout_twister(stretch_a: float, stretch_b: float) -> void:
	_straight(14.0)                     # start line -> north
	_straight(8.0, FLAG_BOOST)
	_straight(40.0)                     # the bridge crosses over this bit
	_turn(90.0, 14.0, 22.0)             # -> east
	_straight(8.0)
	_straight(8.0, FLAG_BOOST)
	_corkscrew(62.0, 5.5)               # CORKSCREW!
	_straight(8.0)
	_turn(90.0, 14.0, 22.0)             # -> south
	_straight(10.0)
	_turn(90.0, 14.0, 22.0)             # -> west
	_straight_to_x(_bridge_half_length())
	_bridge()                           # flies over the start straight
	_straight(8.0)
	_turn(-40.0, 12.0, -14.0)           # chicane
	_turn(80.0, 12.0, 18.0)
	_turn(-40.0, 12.0, -14.0)
	_straight(6.0)
	_turn(-90.0, 15.0, -22.0)           # -> south (left-hand half of the 8)
	_mark("A")
	_straight(stretch_a)
	_jump()
	_straight(10.0)
	_turn(-90.0, 15.0, -22.0)           # -> east
	_mark("B")
	_straight(stretch_b)
	_straight(8.0, FLAG_BOOST)
	_straight(6.0)
	_loop(8.5, -10.0)                   # loop drifts north, away from the wall
	_straight(10.0)
	_turn(-90.0, 15.0, -22.0)           # -> north, back to the line
	_straight(16.0)


## Track 3: Kitchen Kerfuffle. Spirals up high, drops back down, S-bends,
## then two jumps in a row.
func _layout_kitchen(stretch_a: float, stretch_b: float) -> void:
	_mark("A")
	_straight(stretch_a)                # north
	_straight(8.0, FLAG_BOOST)
	_turn(90.0, 16.0, 20.0)             # -> east
	_straight(22.0)
	_helix(360.0, 13.0, 7.5, 12.0)      # spiral climb
	_straight(6.0)
	_ramp_down(7.5)                     # big drop
	_straight(8.0, FLAG_BOOST)
	_straight(24.0)
	_turn(90.0, 15.0, 22.0)             # -> south
	_turn(-60.0, 14.0, -16.0)           # S-bends
	_turn(120.0, 14.0, 22.0)
	_turn(-60.0, 14.0, -16.0)
	_straight(8.0)
	_turn(90.0, 15.0, 22.0)             # -> west
	_mark("B")
	_straight(stretch_b)
	_straight(6.0, FLAG_BOOST)
	_jump()
	_straight(7.0)
	_jump()                             # double jump!
	_straight(8.0)
	_turn(90.0, 16.0, 22.0)             # -> north
	_straight(22.0)


## Track 4: Bubble Bath Bash. Two loops back to back, wavy bumps,
## zig-zags and a jump.
func _layout_bathroom(stretch_a: float, stretch_b: float) -> void:
	_mark("A")
	_straight(stretch_a)                # north
	_straight(8.0, FLAG_BOOST)
	_straight(4.0)
	_loop(8.0, 9.5)                     # loop one...
	_straight(5.0)
	_straight(6.0, FLAG_BOOST)
	_loop(8.0, 9.5)                     # ...loop two!
	_straight(10.0)
	_turn(90.0, 17.0, 22.0)             # -> east
	_waves(3)
	_straight(6.0)
	_turn(90.0, 15.0, 22.0)             # -> south
	_straight(22.0)
	_turn(-90.0, 12.0, -20.0)           # zig...
	_turn(90.0, 12.0, 20.0)             # ...zag
	_straight(24.0)
	_turn(90.0, 15.0, 22.0)             # -> west
	_mark("B")
	_straight(stretch_b)
	_jump()
	_straight(8.0)
	_turn(90.0, 15.0, 22.0)             # -> north
	_straight(24.0)


## Track 5: Sofa Slalom. Everything at once: slalom, spiral, big drop,
## corkscrew, loop, more slalom and a jump.
func _layout_living_room(stretch_a: float, stretch_b: float) -> void:
	_mark("A")
	_straight(stretch_a)                # north
	_straight(8.0, FLAG_BOOST)
	_turn(90.0, 15.0, 22.0)             # -> east
	_slalom(5, 34.0, 13.0)
	_straight(6.0)
	_helix(-360.0, 12.0, 7.5, -12.0)    # spiral climb (to the left)
	_straight(4.0)
	_ramp_down(7.5)
	_straight(6.0, FLAG_BOOST)
	_corkscrew(60.0, 5.5)
	_straight(6.0)
	_turn(90.0, 15.0, 22.0)             # -> south
	_straight(14.0)
	_straight(6.0, FLAG_BOOST)
	_loop(8.5, 10.0)
	_straight(24.0)
	_turn(90.0, 15.0, 22.0)             # -> west
	_mark("B")
	_straight(stretch_b)
	_slalom(3, 30.0, 14.0)
	_straight(4.0)
	_jump()
	_straight(6.0)
	_turn(90.0, 16.0, 22.0)             # -> north
	_straight(22.0)


## A spiral: turns `deg` while climbing `rise` (gentle at both ends).
func _helix(deg: float, radius: float, rise: float, bank: float = 0.0) -> void:
	var arc := deg_to_rad(absf(deg)) * radius
	var n := maxi(8, ceili(arc / RAW_STEP))
	var step := arc / n
	var dyaw := -deg_to_rad(deg) / n
	var heading := Vector3(_fwd.x, 0.0, _fwd.z).normalized()
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var dy := rise * (smoothstep(0.0, 1.0, t1) - smoothstep(0.0, 1.0, t0))
		heading = heading.rotated(Vector3.UP, dyaw * 0.5)
		_pos += heading * step + Vector3.UP * dy
		var f := (heading * step + Vector3.UP * dy).normalized()
		heading = heading.rotated(Vector3.UP, dyaw * 0.5)
		var right := f.cross(Vector3.UP).normalized()
		_fwd = f
		_up = right.cross(f).normalized()
		_roll = bank * sin(PI * t1)
		_emit(0)
	_roll = 0.0
	_fwd = heading
	_up = Vector3.UP


## A straight ramp that goes down exactly `height` and levels out again.
func _ramp_down(height: float, angle: float = 12.0, radius: float = 25.0) -> void:
	var th := deg_to_rad(angle)
	var curve_drop := 2.0 * radius * (1.0 - cos(th))
	var len := maxf(0.0, (height - curve_drop) / sin(th))
	_pitch(-angle, radius)
	_straight(len)
	_pitch(angle, radius)


## Little bumps in a row, like waves.
func _waves(count: int, angle: float = 9.0, radius: float = 22.0) -> void:
	for i in count:
		_pitch(angle, radius)
		_pitch(-angle * 2.0, radius)
		_pitch(angle, radius)


## Wiggles left and right, ending up pointing the same way.
func _slalom(wiggles: int, deg: float, radius: float) -> void:
	_turn(deg * 0.5, radius, deg * 0.4)
	var dir := -1.0
	for i in wiggles - 1:
		_turn(deg * dir, radius, deg * 0.5 * dir)
		dir = -dir
	_turn(deg * 0.5 * dir, radius, deg * 0.4 * dir)


const BRIDGE_ANGLE := 14.0
const BRIDGE_RADIUS := 25.0
const BRIDGE_RAMP := 16.0
const BRIDGE_TOP := 14.0


func _bridge() -> void:
	_pitch(BRIDGE_ANGLE, BRIDGE_RADIUS)
	_straight(BRIDGE_RAMP)
	_pitch(-BRIDGE_ANGLE, BRIDGE_RADIUS)
	_straight(BRIDGE_TOP)
	_pitch(-BRIDGE_ANGLE, BRIDGE_RADIUS)
	_straight(BRIDGE_RAMP)
	_pitch(BRIDGE_ANGLE, BRIDGE_RADIUS)


func _bridge_half_length() -> float:
	var th := deg_to_rad(BRIDGE_ANGLE)
	return 2.0 * BRIDGE_RADIUS * sin(th) + BRIDGE_RAMP * cos(th) + BRIDGE_TOP * 0.5


## Drives straight on until the turtle reaches world x = `x` (heading must be
## roughly along the x axis).
func _straight_to_x(x: float) -> void:
	if absf(_fwd.x) < 0.5:
		push_warning("_straight_to_x needs an east/west heading")
		return
	var len := (x - _pos.x) / _fwd.x
	if len > 0.0:
		_straight(len)
	else:
		push_warning("Track piece overlaps: _straight_to_x went backwards (%.1f)" % len)


## A corkscrew: the road twists all the way around while going forward.
## The car spirals around a line `radius` above the road.
func _corkscrew(length: float, radius: float) -> void:
	var f0 := _fwd
	var u0 := _up
	var axis := _pos + u0 * radius
	var n := maxi(16, ceili((length + TAU * radius) * 1.3 / RAW_STEP))
	for i in n:
		var t := float(i + 1) / n
		var e := t * t * (3.0 - 2.0 * t)          # ease in and out
		var de := 6.0 * t * (1.0 - t)             # how fast it's twisting
		var a := TAU * e
		var d := (-u0).rotated(f0, a)             # from the axis out to the road
		_pos = axis + f0 * length * t + d * radius
		_fwd = (f0 * length + f0.cross(d) * TAU * radius * de).normalized()
		_up = -d
		_emit(FLAG_LOOP | FLAG_TWIST)
	_fwd = f0
	_up = u0


func _jump() -> void:
	_pitch(18.0, 14.0)
	_straight(5.0)
	_pitch(-36.0, 24.0, FLAG_GAP)       # flying through the air
	_straight(5.0)
	_pitch(18.0, 14.0)


func _hill() -> void:
	_pitch(15.0, 22.0)
	_straight(7.0)
	_pitch(-30.0, 26.0)
	_straight(7.0)
	_pitch(15.0, 22.0)


# ---------------------------------------------------------------------------
# Turtle helpers
# ---------------------------------------------------------------------------

func _emit(flag: int) -> void:
	# A banked road tilts around its middle, so lift it up enough that the
	# low edge never dips into the floor.
	var tilt := deg_to_rad(absf(_roll))
	var lift := (HALF_WIDTH + RAIL_THICK) * sin(tilt) + THICKNESS * (1.0 - cos(tilt))
	_raw_pos.append(_pos + Vector3.UP * lift)
	_raw_fwd.append(_fwd)
	_raw_up.append(_up.rotated(_fwd, deg_to_rad(_roll)).normalized())
	_raw_flags.append(flag)


func _mark(tag: String) -> void:
	_marks[tag] = _fwd


func _straight(len: float, flag: int = 0) -> void:
	var n := maxi(1, ceili(len / RAW_STEP))
	var step := len / n
	for i in n:
		_pos += _fwd * step
		_emit(flag)


func _turn(deg: float, radius: float, bank: float = 0.0, flag: int = 0) -> void:
	var arc := deg_to_rad(absf(deg)) * radius
	var n := maxi(1, ceili(arc / RAW_STEP))
	var step := arc / n
	var dtheta := -deg_to_rad(deg) / n
	for i in n:
		_fwd = _fwd.rotated(_up, dtheta * 0.5).normalized()
		_pos += _fwd * step
		_fwd = _fwd.rotated(_up, dtheta * 0.5).normalized()
		var t := float(i + 1) / n
		_roll = bank * sin(PI * t)
		_emit(flag)
	_roll = 0.0


func _pitch(deg: float, radius: float, flag: int = 0) -> void:
	var arc := deg_to_rad(absf(deg)) * radius
	var n := maxi(1, ceili(arc / RAW_STEP))
	var step := arc / n
	var dtheta := deg_to_rad(deg) / n
	var right := _fwd.cross(_up).normalized()
	for i in n:
		_fwd = _fwd.rotated(right, dtheta * 0.5).normalized()
		_up = _up.rotated(right, dtheta * 0.5).normalized()
		_pos += _fwd * step
		_fwd = _fwd.rotated(right, dtheta * 0.5).normalized()
		_up = _up.rotated(right, dtheta * 0.5).normalized()
		_emit(flag)


## A full vertical loop. It drifts sideways by `shift` so the exit lane
## passes beside the entry lane, just like a real toy loop.
func _loop(radius: float, shift: float) -> void:
	var arc := TAU * radius
	var n := maxi(8, ceili(arc / RAW_STEP))
	var step := arc / n
	var dtheta := TAU / n
	var right := _fwd.cross(_up).normalized()
	var prev_s := 0.0
	for i in n:
		var t := float(i + 1) / n
		var s := smoothstep(0.0, 1.0, t)
		_fwd = _fwd.rotated(right, dtheta * 0.5).normalized()
		_up = _up.rotated(right, dtheta * 0.5).normalized()
		_pos += _fwd * step + right * shift * (s - prev_s)
		_fwd = _fwd.rotated(right, dtheta * 0.5).normalized()
		_up = _up.rotated(right, dtheta * 0.5).normalized()
		prev_s = s
		_emit(FLAG_LOOP)
	# Snap away tiny rounding errors so the road is perfectly level again.
	_fwd = Vector3(_fwd.x, 0.0, _fwd.z).normalized()
	_up = Vector3.UP


func _reset_turtle() -> void:
	_pos = Vector3(0.0, BASE_HEIGHT, 0.0)
	_fwd = Vector3.FORWARD
	_up = Vector3.UP
	_roll = 0.0
	_raw_pos.clear()
	_raw_fwd.clear()
	_raw_up.clear()
	_raw_flags.clear()
	_marks.clear()
	_emit(FLAG_START)


## Builds the layout once, measures how far from the start it ended up, then
## stretches straights A and B so the ends meet exactly.
func _build_closed_layout() -> void:
	var a := 30.0
	var b := 30.0
	_reset_turtle()
	_layout(a, b)
	var err := _pos - Vector3(0.0, BASE_HEIGHT, 0.0)
	var da: Vector3 = _marks["A"]
	var db: Vector3 = _marks["B"]
	# Solve  x * da + y * db = -err  on the floor plane.
	var det := da.x * db.z - db.x * da.z
	if absf(det) > 0.001:
		var x := (-err.x * db.z + db.x * err.z) / det
		var y := (-da.x * err.z + err.x * da.z) / det
		a = maxf(4.0, a + x)
		b = maxf(4.0, b + y)
	stretch = Vector2(a, b)
	_reset_turtle()
	_layout(a, b)
	var closing := _pos.distance_to(Vector3(0.0, BASE_HEIGHT, 0.0))
	if closing > 0.5:
		push_warning("Track does not close nicely (gap %.2f). Check the layout." % closing)
	# Replace the last point with the exact start so the circuit is seamless.
	_raw_pos[_raw_pos.size() - 1] = Vector3(0.0, BASE_HEIGHT, 0.0)


# ---------------------------------------------------------------------------
# Resampling into evenly spaced points
# ---------------------------------------------------------------------------

func _resample() -> void:
	var cum := PackedFloat32Array()
	cum.resize(_raw_pos.size())
	cum[0] = 0.0
	for i in range(1, _raw_pos.size()):
		cum[i] = cum[i - 1] + _raw_pos[i].distance_to(_raw_pos[i - 1])
	length = cum[cum.size() - 1]
	count = int(round(length / SPACING))
	spacing = length / count

	points.resize(count)
	forwards.resize(count)
	ups.resize(count)
	flags.resize(count)
	curvature.resize(count)

	var j := 0
	for k in count:
		var s := k * spacing
		while j < cum.size() - 2 and cum[j + 1] < s:
			j += 1
		var seg := maxf(0.0001, cum[j + 1] - cum[j])
		var t := clampf((s - cum[j]) / seg, 0.0, 1.0)
		var f := _raw_fwd[j].lerp(_raw_fwd[j + 1], t).normalized()
		var u := _raw_up[j].lerp(_raw_up[j + 1], t)
		var r := f.cross(u).normalized()
		points[k] = _raw_pos[j].lerp(_raw_pos[j + 1], t)
		forwards[k] = f
		ups[k] = r.cross(f).normalized()
		flags[k] = _raw_flags[j] if t < 0.5 else _raw_flags[j + 1]
	flags[0] |= FLAG_START

	for k in count:
		var a := forwards[(k - 1 + count) % count]
		var b := forwards[(k + 1) % count]
		var r := forwards[k].cross(ups[k]).normalized()
		curvature[k] = (b - a).dot(r) / (2.0 * spacing)


func _find_ranges() -> void:
	gaps = _ranges_for(FLAG_GAP)
	loops = _ranges_for(FLAG_LOOP)
	boosts = _ranges_for(FLAG_BOOST)


func _ranges_for(flag: int) -> Array:
	var out: Array = []
	var start := -1
	for k in count + 1:
		var on := k < count and (flags[k] & flag) != 0
		if on and start < 0:
			start = k
		elif not on and start >= 0:
			out.append([start * spacing, k * spacing])
			start = -1
	return out


# ---------------------------------------------------------------------------
# Queries used by the cars, camera and minimap
# ---------------------------------------------------------------------------

## Returns a transform at distance `s` along the track: basis.x = right,
## basis.y = up (out of the road), -basis.z = forward.
func sample(s: float) -> Transform3D:
	var f := fposmod(s, length) / spacing
	var i := int(f) % count
	var j := (i + 1) % count
	var t := f - floorf(f)
	var p := points[i].lerp(points[j], t)
	var fw := forwards[i].lerp(forwards[j], t).normalized()
	var up := ups[i].lerp(ups[j], t)
	var r := fw.cross(up).normalized()
	up = r.cross(fw).normalized()
	return Transform3D(Basis(r, up, -fw), p)


func flags_at(s: float) -> int:
	var i := int(round(fposmod(s, length) / spacing)) % count
	return flags[i]


func curvature_at(s: float) -> float:
	var i := int(round(fposmod(s, length) / spacing)) % count
	return curvature[i]


## If `s` is inside one of the ranges, returns how far through it (0..1), else -1.
static func range_progress(ranges: Array, s: float) -> float:
	for r in ranges:
		if s >= r[0] and s < r[1]:
			return (s - r[0]) / maxf(0.001, r[1] - r[0])
	return -1.0


## Finds the track distance nearest to a world position (rough, for respawns).
func closest_distance(world_pos: Vector3) -> float:
	var best := 0
	var best_d := INF
	for k in count:
		var d := points[k].distance_squared_to(world_pos)
		if d < best_d:
			best_d = d
			best = k
	return best * spacing


func get_aabb_xz() -> Rect2:
	var r := Rect2(Vector2(points[0].x, points[0].z), Vector2.ZERO)
	for p in points:
		r = r.expand(Vector2(p.x, p.z))
	return r


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------

func _profile() -> PackedVector2Array:
	# Cross section, walked clockwise (x = sideways, y = up).
	var hw := HALF_WIDTH
	return PackedVector2Array([
		Vector2(-hw - RAIL_THICK, RAIL_HEIGHT),
		Vector2(-hw, RAIL_HEIGHT),
		Vector2(-hw, 0.0),
		Vector2(hw, 0.0),
		Vector2(hw, RAIL_HEIGHT),
		Vector2(hw + RAIL_THICK, RAIL_HEIGHT),
		Vector2(hw + RAIL_THICK, -THICKNESS),
		Vector2(-hw - RAIL_THICK, -THICKNESS),
	])


static func _plastic(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.35
	m.metallic_specular = 0.6
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.6
	return m


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	# Godot treats clockwise triangles as front faces.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


func _build_mesh() -> void:
	var prof := _profile()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var j := (i + 1) % count
		if (flags[i] & FLAG_GAP) != 0 or (flags[j] & FLAG_GAP) != 0:
			continue
		var ti := sample(i * spacing)
		var tj := sample(j * spacing)
		var joint := (i % CONNECTOR_EVERY) == 0
		for e in prof.size():
			var a := prof[e]
			var b := prof[(e + 1) % prof.size()]
			var d := b - a
			var n2 := Vector2(-d.y, d.x).normalized()
			var col := TRACK_COLOR
			if e == 2:
				col = TRACK_DARK if joint else TRACK_COLOR
			elif e == 0 or e == 4:
				col = TRACK_EDGE
			else:
				col = TRACK_DARK
			var ai := ti.origin + ti.basis.x * a.x + ti.basis.y * a.y
			var bi := ti.origin + ti.basis.x * b.x + ti.basis.y * b.y
			var aj := tj.origin + tj.basis.x * a.x + tj.basis.y * a.y
			var bj := tj.origin + tj.basis.x * b.x + tj.basis.y * b.y
			var ni := (ti.basis.x * n2.x + ti.basis.y * n2.y).normalized()
			_add_tri(st, ai, bi, bj, ni, col)
			_add_tri(st, ai, bj, aj, ni, col)

	# End caps where the track stops at the jump.
	var tris := Geometry2D.triangulate_polygon(prof)
	for i in count:
		var j := (i + 1) % count
		var gi := (flags[i] & FLAG_GAP) != 0
		var gj := (flags[j] & FLAG_GAP) != 0
		if gi == gj:
			continue
		var k := i if gj else j
		var tk := sample(k * spacing)
		var n := -tk.basis.z if gj else tk.basis.z
		for t in range(0, tris.size(), 3):
			var v: Array[Vector3] = []
			for q in 3:
				var p := prof[tris[t + q]]
				v.append(tk.origin + tk.basis.x * p.x + tk.basis.y * p.y)
			_add_tri(st, v[0], v[1], v[2], n, TRACK_DARK)

	var mi := MeshInstance3D.new()
	mi.name = "TrackMesh"
	mi.mesh = st.commit()
	mi.material_override = _plastic(Color.WHITE)
	add_child(mi)


func _build_boost_pads() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := 10
	var hw := HALF_WIDTH - 0.3
	for i in count:
		var j := (i + 1) % count
		if (flags[i] & FLAG_BOOST) == 0 or (flags[j] & FLAG_BOOST) == 0:
			continue
		var ti := sample(i * spacing)
		var tj := sample(j * spacing)
		for c in cells:
			var x0 := lerpf(-hw, hw, float(c) / cells)
			var x1 := lerpf(-hw, hw, float(c + 1) / cells)
			var centre := absf(float(c) + 0.5 - cells * 0.5)
			var stripe := posmod(i - int(centre * 1.2), 6) < 3
			var col := Color(0.2, 0.95, 1.0) if stripe else Color(1.0, 1.0, 0.3)
			var lift := 0.03
			var a := ti.origin + ti.basis.x * x0 + ti.basis.y * lift
			var b := ti.origin + ti.basis.x * x1 + ti.basis.y * lift
			var cc := tj.origin + tj.basis.x * x1 + tj.basis.y * lift
			var d := tj.origin + tj.basis.x * x0 + tj.basis.y * lift
			_add_tri(st, a, b, cc, ti.basis.y, col)
			_add_tri(st, a, cc, d, ti.basis.y, col)
	var mi := MeshInstance3D.new()
	mi.name = "BoostPads"
	mi.mesh = st.commit()
	mi.material_override = _plastic(Color.WHITE, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_start_line() -> void:
	# Chequered flag pattern painted across the road.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 12
	var rows := 3
	var sq := (HALF_WIDTH * 2.0) / cols
	var t := sample(0.0)
	for r in rows:
		for c in cols:
			var col := Color.WHITE if (r + c) % 2 == 0 else Color(0.05, 0.05, 0.05)
			var x0 := -HALF_WIDTH + c * sq
			var z0 := -sq * rows * 0.5 + r * sq
			var o := t.origin + t.basis.y * 0.035
			var a := o + t.basis.x * x0 - t.basis.z * z0
			var b := o + t.basis.x * (x0 + sq) - t.basis.z * z0
			var cc := o + t.basis.x * (x0 + sq) - t.basis.z * (z0 + sq)
			var d := o + t.basis.x * x0 - t.basis.z * (z0 + sq)
			_add_tri(st, a, b, cc, t.basis.y, col)
			_add_tri(st, a, cc, d, t.basis.y, col)
	var mi := MeshInstance3D.new()
	mi.name = "StartLine"
	mi.mesh = st.commit()
	mi.material_override = _plastic(Color.WHITE)
	add_child(mi)

	# A toy start arch with a banner.
	var arch := Node3D.new()
	arch.name = "StartArch"
	arch.transform = t
	add_child(arch)
	var pole_mat := _plastic(Color(0.95, 0.95, 0.95))
	pole_mat.vertex_color_use_as_albedo = false
	for side: float in [-1.0, 1.0]:
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.35
		cyl.height = 9.0
		pole.mesh = cyl
		pole.material_override = pole_mat
		pole.position = Vector3(side * (HALF_WIDTH + 1.2), 4.5 - BASE_HEIGHT, 0.0)
		arch.add_child(pole)
	var banner := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(HALF_WIDTH * 2.0 + 3.4, 1.8, 0.3)
	banner.mesh = box
	var banner_mat := StandardMaterial3D.new()
	banner_mat.albedo_color = Color(0.85, 0.1, 0.15)
	banner.material_override = banner_mat
	banner.position = Vector3(0.0, 8.4 - BASE_HEIGHT, 0.0)
	arch.add_child(banner)
	# Three start lights under the banner (see set_start_lights).
	for i in 3:
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.45
		sm.height = 0.9
		bulb.mesh = sm
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.25, 0.05, 0.05)
		lm.emission_enabled = true
		lm.emission = Color.BLACK
		bulb.material_override = lm
		bulb.position = Vector3((i - 1) * 1.3, 7.0 - BASE_HEIGHT, 0.0)
		arch.add_child(bulb)
		_start_lights.append(lm)
	for face: float in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = "START  *  FINISH"
		label.font_size = 96
		label.pixel_size = 0.009
		label.outline_size = 18
		label.modulate = Color(1.0, 0.95, 0.4)
		label.position = Vector3(0.0, 8.4 - BASE_HEIGHT, face * 0.17)
		label.rotation.y = 0.0 if face > 0.0 else PI
		arch.add_child(label)


## Countdown lights on the start arch: 0 = off, 1..3 = that many red, 4 = all green.
func set_start_lights(stage: int) -> void:
	for i in _start_lights.size():
		var m := _start_lights[i]
		var col := Color.BLACK
		if stage >= 4:
			col = Color(0.2, 1.0, 0.3)
		elif i < stage:
			col = Color(1.0, 0.15, 0.1)
		m.albedo_color = col if col != Color.BLACK else Color(0.25, 0.05, 0.05)
		m.emission = col
		m.emission_energy_multiplier = 3.0


## Grooves down the road and little blue clips joining the track pieces.
func _build_road_details() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var groove := Color(0.78, 0.3, 0.02)
	for i in count:
		var j := (i + 1) % count
		if ((flags[i] | flags[j]) & (FLAG_GAP | FLAG_BOOST)) != 0:
			continue
		var ti := sample(i * spacing)
		var tj := sample(j * spacing)
		for x: float in [-HALF_WIDTH * 0.42, HALF_WIDTH * 0.42]:
			var w := 0.09
			var a := ti.origin + ti.basis.x * (x - w) + ti.basis.y * 0.015
			var b := ti.origin + ti.basis.x * (x + w) + ti.basis.y * 0.015
			var c := tj.origin + tj.basis.x * (x + w) + tj.basis.y * 0.015
			var d := tj.origin + tj.basis.x * (x - w) + tj.basis.y * 0.015
			_add_tri(st, a, b, c, ti.basis.y, groove)
			_add_tri(st, a, c, d, ti.basis.y, groove)
	var mi := MeshInstance3D.new()
	mi.name = "Grooves"
	mi.mesh = st.commit()
	mi.material_override = _plastic(Color.WHITE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var clip_mat := StandardMaterial3D.new()
	clip_mat.albedo_color = Color(0.15, 0.45, 1.0)
	clip_mat.roughness = 0.3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = MeshKit.rounded_box(Vector3(RAIL_THICK + 0.18, 0.22, 0.55), 0.08, 2)
	var xforms: Array[Transform3D] = []
	for i in range(0, count, CONNECTOR_EVERY):
		if (flags[i] & FLAG_GAP) != 0:
			continue
		var t := sample(i * spacing)
		for side: float in [-1.0, 1.0]:
			var p := t.origin + t.basis.x * side * (HALF_WIDTH + RAIL_THICK * 0.5) + t.basis.y * (RAIL_HEIGHT + 0.1)
			xforms.append(Transform3D(t.basis, p))
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Clips"
	mmi.multimesh = mm
	mmi.material_override = clip_mat
	add_child(mmi)


func _build_supports() -> void:
	# Little plastic stands under any raised part of the track.
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.28
	mesh.bottom_radius = 0.45
	mesh.height = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.55, 1.0)
	mat.roughness = 0.35
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var xforms: Array[Transform3D] = []
	var i := 0
	while i < count:
		var p := points[i]
		var raised := p.y - THICKNESS - 0.05
		var ok := (flags[i] & (FLAG_GAP | FLAG_LOOP)) == 0 and ups[i].y > 0.8 and raised > 0.9
		var twist_side := (flags[i] & FLAG_TWIST) != 0 and absf(ups[i].y) < 0.25
		if twist_side:
			var tw := sample(i * spacing)
			var under := tw.origin - tw.basis.y * (THICKNESS + 0.4)
			xforms.append(Transform3D(Basis().scaled(Vector3(1.2, under.y, 1.2)), Vector3(under.x, under.y * 0.5, under.z)))
			i += 14
			continue
		if ok:
			for side: float in [-1.0, 1.0]:
				var t := sample(i * spacing)
				var base := t.origin + t.basis.x * side * (HALF_WIDTH - 0.6) - t.basis.y * THICKNESS
				if _track_below(base):
					continue
				var h := base.y
				var xf := Transform3D(Basis().scaled(Vector3(1.0, h, 1.0)), Vector3(base.x, h * 0.5, base.z))
				xforms.append(xf)
			i += 10
		else:
			i += 1
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Supports"
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


## True if another (lower) part of the track runs underneath this point.
func _track_below(p: Vector3) -> bool:
	for k in range(0, count, 2):
		var q := points[k]
		if q.y < p.y - 1.5 and Vector2(q.x - p.x, q.z - p.z).length() < HALF_WIDTH + RAIL_THICK + 1.0:
			return true
	return false


func _build_loop_stand() -> void:
	# A chunky blue clamp under each loop holds the entry and exit lanes together.
	for r in loops:
		if (flags_at(r[0] + 1.0) & FLAG_TWIST) != 0:
			continue
		var a := sample(r[0])
		var b := sample(r[1])
		var centre := (a.origin + b.origin) * 0.5
		var lanes := a.origin.distance_to(b.origin) + HALF_WIDTH * 2.0 + 2.0
		var foot := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(lanes, 0.3, 5.0)
		foot.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.55, 1.0)
		mat.roughness = 0.35
		foot.material_override = mat
		var fwd := -a.basis.z
		var side := Vector3(a.basis.x.x, 0.0, a.basis.x.z).normalized()
		foot.transform = Transform3D(Basis(side, Vector3.UP, -fwd), Vector3(centre.x, 0.15, centre.z))
		add_child(foot)
