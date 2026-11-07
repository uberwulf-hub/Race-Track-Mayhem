extends Node3D
## SECTOR 1: INTAKE. Builds the facility from the text map below, then runs
## the story, puzzles, monsters, scares and checkpoints.
##
## The escape route:
##   1. Find the maintenance note (Break Room): the breaker order.
##   2. Find the security keycard (Office), open SECURITY off the main hall.
##   3. Flip the three breakers in the right order -> power comes back on.
##      (A voice that sounds like MERIDIAN lies to you about the order.)
##   4. The elevator door shows a colour order. Find the 4 painted numbers
##      (red, blue, green, yellow) around the sector and type in the code.
##   5. Get in the elevator.
## Secrets: 3 signal fragments, one behind a low vent you must crouch through.

const Player := preload("res://scripts/player.gd")
const Listener := preload("res://scripts/listener.gd")
const Replacement := preload("res://scripts/replacement.gd")
const Hud := preload("res://scripts/hud.gd")
const Door := preload("res://scripts/door.gd")
const Locker := preload("res://scripts/locker.gd")
const Interactable := preload("res://scripts/interactable.gd")

const S := 3.0         # one map cell is 3 x 3 metres
const WALL_H := 3.2
const VENT_H := 1.15

## Map legend:
##  #  wall           .  floor          P  you start here
##  D  door           K  keycard door   X  elevator door (power + code)
##  E  elevator       V  low vent (crouch)
##  L  locker         g  metal grate (LOUD to walk on)
##  i  intercom (checkpoint)            n  maintenance note
##  k  keycard        B  breaker panel  f  signal fragment (secret)
##  1-4  painted numbers for the exit code
##  M  the Listener starts here         R  the Replacement stands here
const MAP := [
	"###########################",
	"#.....#.L...L.#.....#.....#",
	"#.P...D...n...#..1..#..R..#",
	"#..i..#.......#.....D.....#",
	"#.....#.......#.L...#..f..#",
	"###D######D######D####D####",
	"#...L...ggg.......ggg..L..#",
	"#.......ggg...i...ggg.....#",
	"#.......ggg.......ggg.....#",
	"###D######D######K####D####",
	"#.....#.......#.....#....f#",
	"#..k..#...2...#..B..#..4..#",
	"#.....#.......#.....#....L#",
	"#L....#...M...#..3..#.....#",
	"###V####D############D#####",
	"#...#..........i.......#..#",
	"#.f.#..................X.E#",
	"#...#....L.......L.....#..#",
	"###########################",
]

const ROOMS := [
	["MED BAY", Rect2i(1, 1, 5, 4)],
	["BREAK ROOM", Rect2i(7, 1, 7, 4)],
	["RECORDS", Rect2i(15, 1, 5, 4)],
	["LAB 2", Rect2i(21, 1, 5, 4)],
	["MAIN HALL", Rect2i(1, 6, 25, 3)],
	["OFFICE", Rect2i(1, 10, 5, 4)],
	["STORAGE", Rect2i(7, 10, 7, 4)],
	["SECURITY", Rect2i(15, 10, 5, 4)],
	["PUMP ROOM", Rect2i(21, 10, 5, 4)],
	["LOWER HALL", Rect2i(5, 15, 18, 3)],
	["CRAWLSPACE", Rect2i(1, 15, 3, 3)],
	["ELEVATOR", Rect2i(24, 15, 2, 3)],
]

const CODE_COLORS := [
	["RED", Color(1.0, 0.25, 0.2)],
	["BLUE", Color(0.3, 0.55, 1.0)],
	["GREEN", Color(0.3, 0.95, 0.4)],
	["YELLOW", Color(1.0, 0.9, 0.2)],
]

const BREAKER_ORDER := ["RIGHT", "MIDDLE", "LEFT"]

const FRAGMENT_TEXT := [
	"\"Sector 13 isn't on any map because we never built it. So who is broadcasting from down there?\"",
	"\"MERIDIAN says it hears a second voice on its own channel. The second voice sounds exactly like MERIDIAN.\"",
	"\"Whatever you do, don't answer the signal. It learns your voice.\"",
]

var rows := 0
var cols := 0
var grid := AStarGrid2D.new()
var player: Player
var listener: Listener
var replacement: Replacement
var hud: Hud

var doors: Dictionary = {}       # Vector2i -> door
var lockers: Array = []
var grates: Dictionary = {}      # Vector2i -> true
var wander_cells: Array[Vector2i] = []
var lights: Array = []           # [{light, fixture, flicker}]
var intercoms: Array = []        # [{cell, lamp}]
var traps: Array = []

var start_cell := Vector2i.ZERO
var listener_home := Vector3.ZERO
var replacement_home := Vector3.ZERO
var checkpoint := Vector3.ZERO
var checkpoint_yaw := 0.0

# Puzzle state.
var has_keycard := false
var power_on := false
var exit_open := false
var breaker_seq: Array[String] = []
var levers: Dictionary = {}      # "LEFT"/"MIDDLE"/"RIGHT" -> lever mesh
var code_digits: Array[int] = []    # one digit per colour in CODE_COLORS
var code_order: Array[int] = []     # colour indexes in the order the elevator wants
var exit_code := ""
var digit_spots: Array = []      # [{pos, color, room, found}]
var exit_door: Node
var order_seen := false

# Run state.
var paused_world := false
var ended := false
var catching := false
var catches := 0
var fragments := 0
var fragment_total := 0
var run_time := 0.0
var visited: Dictionary = {}
var _env: Environment
var _event_t := 0.0
var _ambient_t := 0.0
var _clue_t := 0.0
var _last_cell := Vector2i(-1, -1)
var _hunt_warnings := 0
var _blackout_t := 0.0
var _hid_recently := 0.0


func _ready() -> void:
	Game.reset_run()
	rows = MAP.size()
	cols = String(MAP[0]).length()
	_make_code()
	_build_environment()
	_build_level()
	_build_grid()
	hud = Hud.new()
	hud.sector = self
	add_child(hud)
	_spawn_actors()
	hud.set_fragments(0, fragment_total)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sound.start_ambient(-11.0)
	var gap: Vector2 = Game.mode_data()["scare_gap"]
	_event_t = randf_range(gap.x, gap.y)
	_ambient_t = randf_range(8.0, 16.0)
	_intro()


func _intro() -> void:
	hud.set_objective("Find a way out of Sector 1.")
	await get_tree().create_timer(1.6).timeout
	hud.say("ai", "Good morning. You are awake eleven hours ahead of schedule.")
	hud.say("ai", "I am MERIDIAN, the facility assistant. Please remain calm.")
	hud.say("ai", "Sector 1 is sealed. The service elevator is the only way out. It has no power.")


# ===================================================================== map

func ch(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return "#"
	return String(MAP[c.y])[c.x]


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * S, 0.0, c.y * S)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / S), roundi(p.z / S))


func room_at(c: Vector2i) -> String:
	for r in ROOMS:
		var rect: Rect2i = r[1]
		if rect.has_point(c):
			return r[0]
	return ""


## The nearest wall in a straight line from this cell: [normal pointing into
## the room, distance in cells]. Checks west, east, north, south.
func nearest_wall(c: Vector2i) -> Array:
	var best: Array = [Vector3.FORWARD, 99]
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var n := 1
		while n < 10:
			var k := ch(c + d * n)
			if k == "#":
				if n < int(best[1]):
					best = [Vector3(-d.x, 0, -d.y), n]
				break
			if k in ["D", "K", "X", "V"]:
				break
			n += 1
	return best


## A point on the face of that wall, at height y.
func wall_point(c: Vector2i, y: float) -> Array:
	var w := nearest_wall(c)
	var normal: Vector3 = w[0]
	var dist: int = w[1]
	var p := cell_to_world(c) - normal * (dist * S - S / 2.0)
	p.y = y
	return [p, normal]


# ============================================================= environment

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0, 0, 0)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.35, 0.42, 0.55)
	_env.ambient_light_energy = float(Game.mode_data()["ambient"]) * 1.6
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.01, 0.015, 0.025)
	_env.fog_density = 0.035
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.adjustment_enabled = true
	_env.adjustment_brightness = Game.brightness
	_env.adjustment_saturation = 0.8
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)


func _mat(color: Color, rough := 0.85, metal := 0.0, scale := 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.035
	n.fractal_octaves = 4
	tex.noise = n
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.55, 0.55))
	g.set_color(1, Color(1, 1, 1))
	tex.color_ramp = g
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _glow(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _label(text: String, pos: Vector3, normal: Vector3, size: int, color: Color, px := 0.005) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 0
	l.position = pos + normal * 0.02
	l.rotation.y = atan2(normal.x, normal.z)
	add_child(l)
	return l


# =================================================================== level

func _build_level() -> void:
	var wall_mat := _mat(Color(0.32, 0.36, 0.4), 0.9, 0.0, 0.3)
	var floor_mat := _mat(Color(0.2, 0.21, 0.22), 0.95, 0.0, 0.5)
	var ceil_mat := _mat(Color(0.12, 0.13, 0.15), 0.95)
	var grate_mat := _mat(Color(0.42, 0.3, 0.2), 0.5, 0.7, 0.9)

	# Floor and ceiling.
	var center := Vector3((cols - 1) * S / 2.0, 0, (rows - 1) * S / 2.0)
	_box(Vector3(cols * S, 0.2, rows * S), center + Vector3(0, -0.1, 0), floor_mat)
	_box(Vector3(cols * S, 0.2, rows * S), center + Vector3(0, WALL_H + 0.1, 0), ceil_mat)
	var solid := StaticBody3D.new()
	solid.collision_layer = 1
	solid.collision_mask = 0
	add_child(solid)
	_shape(solid, Vector3(cols * S, 0.2, rows * S), center + Vector3(0, -0.1, 0))
	_shape(solid, Vector3(cols * S, 0.2, rows * S), center + Vector3(0, WALL_H + 0.1, 0))

	# Walls, as one MultiMesh (fast) plus collision boxes.
	var wall_cells: Array[Vector2i] = []
	for r in rows:
		for c in cols:
			if ch(Vector2i(c, r)) == "#":
				wall_cells.append(Vector2i(c, r))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(S, WALL_H, S)
	wall_mesh.material = wall_mat
	mm.mesh = wall_mesh
	mm.instance_count = wall_cells.size()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(S, WALL_H, S)
	for i in wall_cells.size():
		var p := cell_to_world(wall_cells[i]) + Vector3(0, WALL_H / 2.0, 0)
		mm.set_instance_transform(i, Transform3D(Basis(), p))
		var cs := CollisionShape3D.new()
		cs.shape = wall_shape
		cs.position = p
		solid.add_child(cs)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

	# A painted stripe along the walls of each room helps you find your way.
	var stripe_mat := _glow(Color(0.15, 0.35, 0.5), 0.6)

	for r in rows:
		for c in cols:
			var cell := Vector2i(c, r)
			var k := ch(cell)
			var p := cell_to_world(cell)
			match k:
				"P":
					start_cell = cell
				"M":
					listener_home = p
				"R":
					replacement_home = p
				"g":
					grates[cell] = true
					_box(Vector3(S, 0.04, S), p + Vector3(0, 0.02, 0), grate_mat)
					for s in 5:
						_box(Vector3(S, 0.05, 0.08), p + Vector3(0, 0.04, -S / 2.0 + 0.3 + s * 0.6), grate_mat)
				"D", "K", "X":
					_spawn_door(cell, k)
				"V":
					_box(Vector3(S, WALL_H - VENT_H, S), p + Vector3(0, VENT_H + (WALL_H - VENT_H) / 2.0, 0), wall_mat)
					_shape(solid, Vector3(S, WALL_H - VENT_H, S), p + Vector3(0, VENT_H + (WALL_H - VENT_H) / 2.0, 0))
					_box(Vector3(S * 0.96, 0.06, 0.06), p + Vector3(0, VENT_H - 0.05, -S / 2.0 + 0.05), _glow(Color(0.25, 0.25, 0.3), 0.3))
				"L":
					_spawn_locker(cell)
				"i":
					_spawn_intercom(cell)
				"n":
					_spawn_note(cell)
				"k":
					_spawn_keycard(cell)
				"B":
					_spawn_breakers(cell)
				"f":
					_spawn_fragment(cell)
				"1", "2", "3", "4":
					_spawn_digit(cell, int(k) - 1)
				"E":
					_spawn_exit(cell)
	_build_rooms(stripe_mat)


func _shape(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	body.add_child(cs)


func _build_rooms(stripe_mat: Material) -> void:
	var light_mult: float = [1.25, 1.0, 0.7][Game.mode]
	for room in ROOMS:
		var room_name: String = room[0]
		var rect: Rect2i = room[1]
		var center := Vector3((rect.position.x + (rect.size.x - 1) / 2.0) * S, 0, (rect.position.y + (rect.size.y - 1) / 2.0) * S)
		# The room's name stencilled on the floor.
		if room_name != "CRAWLSPACE":
			var l := Label3D.new()
			l.text = room_name if room_name != "MAIN HALL" else "SECTOR 1  -  INTAKE"
			l.font_size = 96
			l.pixel_size = 0.008
			l.modulate = Color(0.75, 0.8, 0.85, 0.35)
			l.rotation.x = -PI / 2.0
			l.position = center + Vector3(0, 0.03, 0)
			add_child(l)
		# Ceiling lights.
		if room_name == "CRAWLSPACE":
			continue
		var count := maxi(1, ceili(rect.size.x / 4.0))
		for i in count:
			var x := (rect.position.x - 0.5 + (i + 0.5) * rect.size.x / float(count)) * S
			var pos := Vector3(x, WALL_H - 0.35, center.z)
			var light := OmniLight3D.new()
			light.position = pos
			light.omni_range = 8.0
			light.omni_attenuation = 1.4
			light.light_color = Color(0.35, 0.5, 1.0)
			light.light_energy = 0.55 * light_mult
			if room_name == "ELEVATOR":
				light.light_color = Color(1.0, 0.85, 0.4)
			add_child(light)
			var fixture := _box(Vector3(1.2, 0.08, 0.3), pos + Vector3(0, 0.3, 0), _glow(Color(0.35, 0.5, 1.0), 1.5))
			lights.append({"light": light, "fixture": fixture, "flicker": randf() < 0.3, "mult": light_mult})
		# Pipes along the halls.
		if room_name.ends_with("HALL"):
			var pipe := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.12
			cyl.bottom_radius = 0.12
			cyl.height = rect.size.x * S
			pipe.mesh = cyl
			pipe.material_override = _mat(Color(0.3, 0.28, 0.25), 0.4, 0.8)
			pipe.rotation.z = PI / 2.0
			pipe.position = Vector3(center.x, WALL_H - 0.25, (rect.position.y - 0.5) * S + 0.25)
			add_child(pipe)
	# Wayfinding stripe on every wall face next to a floor cell.
	for r in rows:
		for c in cols:
			var cell := Vector2i(c, r)
			if ch(cell) == "#":
				continue
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if ch(cell + d) == "#":
					var n := Vector3(-d.x, 0, -d.y)
					var p := cell_to_world(cell) - n * (S / 2.0 - 0.01)
					var size := Vector3(S, 0.06, 0.02) if d.y != 0 else Vector3(0.02, 0.06, S)
					_box(size, p + Vector3(0, 1.0, 0), stripe_mat)


func _build_grid() -> void:
	grid.region = Rect2i(0, 0, cols, rows)
	grid.cell_size = Vector2(1, 1)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for r in rows:
		for c in cols:
			var cell := Vector2i(c, r)
			var k := ch(cell)
			if k in ["#", "V", "K", "X"]:
				grid.set_point_solid(cell, true)
			elif not (room_at(cell) in ["CRAWLSPACE", "ELEVATOR", ""]):
				wander_cells.append(cell)


func unlock_cell(cell: Vector2i) -> void:
	grid.set_point_solid(cell, false)


# ================================================================= objects

func _spawn_door(cell: Vector2i, k: String) -> void:
	var along_x := ch(cell + Vector2i(-1, 0)) == "#" and ch(cell + Vector2i(1, 0)) == "#"
	var d := Door.new()
	d.position = cell_to_world(cell)
	add_child(d)
	var kind := "door"
	if k == "K":
		kind = "keycard"
	elif k == "X":
		kind = "exit"
	d.setup(self, cell, along_x, kind)
	doors[cell] = d
	if kind == "exit":
		exit_door = d


func _spawn_locker(cell: Vector2i) -> void:
	var w := nearest_wall(cell)
	var normal: Vector3 = w[0]
	var l := Locker.new()
	l.position = cell_to_world(cell) - normal * (S / 2.0 - 0.33)
	add_child(l)
	l.setup(self, normal)
	lockers.append(l)


func _spawn_intercom(cell: Vector2i) -> void:
	var wp := wall_point(cell, 1.7)
	var p: Vector3 = wp[0]
	var n: Vector3 = wp[1]
	var box := _box(Vector3(0.5, 0.6, 0.12), p + n * 0.06, _mat(Color(0.25, 0.27, 0.3), 0.5, 0.6))
	box.rotation.y = atan2(n.x, n.z)
	var lamp := _box(Vector3(0.1, 0.1, 0.05), p + n * 0.14 + Vector3(0, 0.2, 0), _glow(Color(1.0, 0.2, 0.15), 3.0))
	_label("INTERCOM", p + n * 0.13 + Vector3(0, -0.15, 0), n, 24, Color(0.7, 0.8, 0.9), 0.003)
	intercoms.append({"cell": cell, "lamp": lamp, "used": false})


func _table(p: Vector3) -> void:
	var m := _mat(Color(0.3, 0.25, 0.2), 0.7)
	_box(Vector3(1.2, 0.06, 0.7), p + Vector3(0, 0.8, 0), m)
	for x in [-0.5, 0.5]:
		for z in [-0.28, 0.28]:
			_box(Vector3(0.05, 0.8, 0.05), p + Vector3(x, 0.4, z), m)


func _spawn_note(cell: Vector2i) -> void:
	var p := cell_to_world(cell)
	_table(p)
	var it := Interactable.new()
	it.position = p + Vector3(0, 0.86, 0)
	add_child(it)
	_box(Vector3(0.3, 0.01, 0.4), Vector3.ZERO, _glow(Color(0.9, 0.88, 0.75), 0.25), it)
	_shape_for(it, Vector3(0.6, 0.3, 0.6))
	it.prompt_text = "Read note"
	it.on_use = func():
		Sound.play("click", -6.0)
		hud.show_note("MAINTENANCE NOTE - BREAKER RESET",
			"If the power trips again, reset the 3 breakers in SECURITY:\n\n- NEVER start with the MIDDLE breaker.\n- The LEFT breaker always goes LAST.\n\n"
			+ "And don't listen to the intercom about this. It's been... saying things.\n   - J.")
		hud.add_clue("Breakers (in SECURITY): never start with MIDDLE. LEFT goes last.")
		if not has_keycard:
			hud.set_objective("Find a security keycard to get into SECURITY.")


func _shape_for(body: StaticBody3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)


func _spawn_keycard(cell: Vector2i) -> void:
	var p := cell_to_world(cell)
	_table(p)
	var it := Interactable.new()
	it.position = p + Vector3(0, 0.86, 0)
	add_child(it)
	_box(Vector3(0.22, 0.01, 0.14), Vector3.ZERO, _glow(Color(1.0, 0.55, 0.1), 2.0), it)
	_shape_for(it, Vector3(0.5, 0.3, 0.5))
	it.prompt_text = "Take security keycard"
	it.on_use = func():
		has_keycard = true
		Sound.play("pickup", -4.0)
		hud.toast("Got the SECURITY KEYCARD.")
		hud.add_clue("The keycard opens SECURITY (orange door off the main hall).")
		hud.set_objective("Open SECURITY and restore the power.")
		it.queue_free()
		_keycard_scare()


func _spawn_breakers(cell: Vector2i) -> void:
	var wp := wall_point(cell, 1.4)
	var p: Vector3 = wp[0]
	var n: Vector3 = wp[1]
	var right := (-n).cross(Vector3.UP)
	var panel := _box(Vector3(1.8, 1.0, 0.1), p + n * 0.05, _mat(Color(0.25, 0.27, 0.25), 0.6, 0.5))
	panel.rotation.y = atan2(n.x, n.z)
	_label("BREAKERS  -  RESET IN THE RIGHT ORDER", p + n * 0.11 + Vector3(0, 0.62, 0), n, 28, Color(1, 0.85, 0.3), 0.004)
	var names := ["LEFT", "MIDDLE", "RIGHT"]
	for i in 3:
		var side: String = names[i]
		var lp := p + n * 0.12 + right * ((i - 1) * 0.55)
		_label(side, lp + Vector3(0, -0.36, 0), n, 24, Color(0.85, 0.9, 1.0), 0.004)
		var it := Interactable.new()
		it.position = lp
		it.rotation.y = atan2(n.x, n.z)
		add_child(it)
		var lever := _box(Vector3(0.12, 0.42, 0.12), Vector3(0, 0.1, 0.06), _glow(Color(0.9, 0.2, 0.15), 1.2), it)
		levers[side] = lever
		_shape_for(it, Vector3(0.4, 0.6, 0.3))
		it.prompt_text = "Flip the %s breaker" % side
		it.on_use = func(): _flip_breaker(side, it)


func _spawn_fragment(cell: Vector2i) -> void:
	var idx := fragment_total
	fragment_total += 1
	var it := Interactable.new()
	it.position = cell_to_world(cell) + Vector3(0, 1.1, 0)
	add_child(it)
	var gem := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.4
	sm.radial_segments = 4
	sm.rings = 2
	gem.mesh = sm
	gem.material_override = _glow(Color(0.65, 0.4, 1.0), 2.5)
	it.add_child(gem)
	var spin := gem.create_tween().set_loops()
	spin.tween_property(gem, "rotation:y", TAU, 3.0).from(0.0)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.65, 0.4, 1.0)
	glow.light_energy = 0.4
	glow.omni_range = 2.5
	it.add_child(glow)
	_shape_for(it, Vector3(0.6, 0.6, 0.6))
	it.prompt_text = "Take signal fragment"
	it.on_use = func():
		fragments += 1
		Game.fragments_ever["s1_%d" % idx] = true
		Sound.play("pickup", -4.0, 0.8)
		hud.set_fragments(fragments, fragment_total)
		hud.show_note("SIGNAL FRAGMENT %d / %d" % [fragments, fragment_total], FRAGMENT_TEXT[idx % FRAGMENT_TEXT.size()])
		hud.add_clue("Fragment: " + FRAGMENT_TEXT[idx % FRAGMENT_TEXT.size()])
		it.queue_free()


func _spawn_digit(cell: Vector2i, spot: int) -> void:
	# Spot 1-4 shows the digit for one colour (which colour is random each game).
	var color_index := spot
	var wp := wall_point(cell, 1.9)
	var p: Vector3 = wp[0]
	var n: Vector3 = wp[1]
	var col: Color = CODE_COLORS[color_index][1]
	_label(str(code_digits[color_index]), p, n, 220, col, 0.006)
	var splash := _label("o", p + Vector3(0, -0.05, 0), n, 400, Color(col.r, col.g, col.b, 0.18), 0.006)
	splash.position -= n * 0.01
	digit_spots.append({"pos": p + n * 0.1, "color": color_index, "room": room_at(cell), "found": false})


func _spawn_exit(cell: Vector2i) -> void:
	var p := cell_to_world(cell)
	_label("EXIT", Vector3(p.x + S / 2.0 - 0.02, 2.2, p.z), Vector3(-1, 0, 0), 120, Color(1.0, 0.9, 0.3), 0.006)


func _make_code() -> void:
	code_digits.clear()
	for i in CODE_COLORS.size():
		code_digits.append(randi() % 10)
	code_order = [0, 1, 2, 3]
	code_order.shuffle()
	exit_code = ""
	for idx in code_order:
		exit_code += str(code_digits[idx])


# ================================================================== actors

func _spawn_actors() -> void:
	player = Player.new()
	player.sector = self
	add_child(player)
	player.global_position = cell_to_world(start_cell)
	player.look_at_yaw(-PI / 2.0)
	checkpoint = player.global_position
	checkpoint_yaw = -PI / 2.0

	listener = Listener.new()
	add_child(listener)
	listener.global_position = listener_home
	listener.setup(self)
	listener.set_physics_process(false)   # wakes up when you reach the main hall

	replacement = Replacement.new()
	add_child(replacement)
	replacement.global_position = replacement_home
	replacement.setup(self)
	replacement.rotation.y = PI / 2.0


func emit_noise(pos: Vector3, radius: float, from_player: bool) -> void:
	if listener and listener.is_physics_processing():
		listener.hear(pos, radius, from_player)


func is_grate(pos: Vector3) -> bool:
	return grates.has(world_to_cell(pos))


func find_path(from: Vector3, to: Vector3) -> Array[Vector2i]:
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	var empty: Array[Vector2i] = []
	if not grid.is_in_boundsv(a) or not grid.is_in_boundsv(b):
		return empty
	if grid.is_point_solid(b):
		var found := false
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			if grid.is_in_boundsv(b + d) and not grid.is_point_solid(b + d):
				b = b + d
				found = true
				break
		if not found:
			return empty
	if grid.is_point_solid(a):
		return empty
	var path := grid.get_id_path(a, b)
	if path.size() > 0:
		path.remove_at(0)
	return path


func random_floor_pos() -> Vector3:
	return cell_to_world(wander_cells[randi() % wander_cells.size()])


func lockers_near(pos: Vector3, radius: float, count: int) -> Array:
	var near: Array = []
	for l in lockers:
		if l.global_position.distance_to(pos) <= radius:
			near.append(l)
	near.sort_custom(func(a, b): return a.global_position.distance_to(pos) < b.global_position.distance_to(pos))
	# If you're hiding near here, your locker is one of the ones it checks.
	var mine: Node = player.hidden_in
	if mine and mine.global_position.distance_to(pos) <= radius and not (mine in near.slice(0, count)):
		near.insert(0, mine)
	return near.slice(0, count)


func monster_entering(cell: Vector2i) -> void:
	if doors.has(cell):
		doors[cell].monster_near()


func anyone_near(pos: Vector3, radius: float) -> bool:
	for n in [player, listener, replacement]:
		if n == null:
			continue
		var d := Vector2(n.global_position.x - pos.x, n.global_position.z - pos.z).length()
		if d < radius:
			if n == replacement and not replacement.active:
				continue
			return true
	return false


# ================================================== learning (the Listener)

func on_player_hid(_locker: Node) -> void:
	if _hid_recently > 0.0:
		return
	_hid_recently = 15.0
	Game.hide_count += 1
	var need: int = Game.mode_data()["learn_hide"]
	if need > 0 and not Game.learned_lockers and Game.hide_count >= need:
		Game.learned_lockers = true
		await get_tree().create_timer(2.5).timeout
		hud.say("ai", "It has noticed that you hide. It will start checking the lockers.")
		hud.say("ai", "If it stops at yours, hold your breath. SPACE.")
		hud.toast("THE LISTENER IS LEARNING: it now checks lockers.", 5.0)


func note_sprint(pos: Vector3, delta: float) -> void:
	var c := world_to_cell(pos)
	Game.sprint_cells[c] = float(Game.sprint_cells.get(c, 0.0)) + delta
	if Game.learned_traps or Game.sprint_time < float(Game.mode_data()["learn_sprint"]):
		return
	Game.learned_traps = true
	_place_traps()


func _place_traps() -> void:
	var cells: Array = Game.sprint_cells.keys()
	cells.sort_custom(func(a, b): return Game.sprint_cells[a] > Game.sprint_cells[b])
	var placed := 0
	for c in cells:
		if placed >= 3:
			break
		var cell: Vector2i = c
		if ch(cell) != "." or grates.has(cell):
			continue
		if cell_to_world(cell).distance_to(player.global_position) < 7.0:
			continue
		_spawn_trap(cell)
		placed += 1
	if placed > 0:
		hud.say("ai", "It knows which halls you run through. It has strung wires across them.")
		hud.say("ai", "Look for red wires near the floor. Crouch to step over them.")
		hud.toast("THE LISTENER IS LEARNING: tripwires in the halls you run.", 5.0)


func _spawn_trap(cell: Vector2i) -> void:
	var p := cell_to_world(cell)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 4
	area.position = p
	add_child(area)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(S, 1.0, 0.6)
	cs.shape = b
	cs.position.y = 0.5
	area.add_child(cs)
	var along_x := not (ch(cell + Vector2i(-1, 0)) == "#" and ch(cell + Vector2i(1, 0)) == "#")
	if not along_x:
		area.rotation.y = PI / 2.0
	var wire_mat := _glow(Color(1.0, 0.1, 0.1), 1.2 if Game.mode != Game.Mode.NIGHTMARE else 0.5)
	_box(Vector3(S, 0.02, 0.02), Vector3(0, 0.25, 0), wire_mat, area)
	for x in [-S / 2.0 + 0.1, S / 2.0 - 0.1]:
		_box(Vector3(0.06, 0.4, 0.06), Vector3(x, 0.2, 0), _mat(Color(0.3, 0.3, 0.3)), area)
	area.body_entered.connect(func(body):
		if body != player or not is_instance_valid(area):
			return
		if player.crouching:
			hud.toast("You step carefully over the wire.", 2.0)
			return
		Sound.play_at("trap", area.global_position, 2.0)
		emit_noise(area.global_position, 26.0, true)
		hud.toast("You hit a tripwire!", 2.5)
		area.queue_free())
	traps.append(area)


func on_hunt_started() -> void:
	if Game.is_explorer():
		if _hunt_warnings < 3:
			_hunt_warnings += 1
			hud.toast("It heard you! Move away quietly, or hide in a locker.", 3.0)
	else:
		Sound.play("heartbeat", -2.0)


func on_locker_checked(locker: Node) -> void:
	if player.hidden_in == locker:
		hud.toast("IT'S COMING TO YOUR LOCKER.  HOLD  SPACE!", 4.0)
		Sound.play("heartbeat", 0.0)


# ================================================================= puzzles

func _flip_breaker(side: String, it: Node) -> void:
	if power_on or side in breaker_seq:
		return
	Sound.play_at("breaker", it.global_position, 0.0)
	var lever: MeshInstance3D = levers[side]
	lever.rotation.x = -0.9
	lever.material_override = _glow(Color(0.2, 1.0, 0.4), 1.4)
	breaker_seq.append(side)
	var i := breaker_seq.size() - 1
	if breaker_seq[i] != BREAKER_ORDER[i]:
		# Wrong order: the breakers trip with a loud alarm.
		await get_tree().create_timer(0.4).timeout
		Sound.play_at("alarm", it.global_position, 4.0)
		emit_noise(it.global_position, 30.0, false)
		hud.toast("THE BREAKERS TRIPPED! They reset - and that was LOUD.", 4.0)
		breaker_seq.clear()
		for s in levers:
			var l: MeshInstance3D = levers[s]
			l.rotation.x = 0.0
			l.material_override = _glow(Color(0.9, 0.2, 0.15), 1.2)
		return
	if breaker_seq.size() == BREAKER_ORDER.size():
		_power_on()


func _power_on() -> void:
	power_on = true
	Sound.play("power_on", 0.0)
	for l in lights:
		var light: OmniLight3D = l["light"]
		light.light_color = Color(1.0, 0.93, 0.8)
		light.light_energy = 1.0 * float(l["mult"])
		light.omni_range = 9.0
		var fx: MeshInstance3D = l["fixture"]
		fx.material_override = _glow(Color(1.0, 0.93, 0.8), 2.0)
	_env.ambient_light_energy *= 1.6
	var names: Array[String] = []
	for idx in code_order:
		names.append(CODE_COLORS[idx][0])
	exit_door.set_display("EXIT CODE ORDER\n%s  %s\n%s  %s" % names, Color(1.0, 0.95, 0.6))
	emit_noise(player.global_position, 12.0, false)
	hud.set_objective("Power is on. Find the elevator (lower hall) and its exit code.")
	hud.say("ai", "Power restored. Thank you.")
	hud.say("ai", "The elevator needs a four-digit exit code. The night staff painted the numbers around the sector, in colours.")
	hud.say("unknown", "...you turned the lights on. now it can see you too.")
	replacement.active = true
	if Game.mode_data()["replacement_hunts"]:
		await get_tree().create_timer(14.0).timeout
		hud.say("ai", "The mannequin in Lab 2 was not there yesterday. If it moves, keep your light on it.")


func open_keypad() -> void:
	player.frozen = true
	hud.open_keypad(_on_code, close_keypad)


func close_keypad() -> void:
	hud.close_keypad()
	if not ended and not catching:
		player.frozen = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_code(code: String) -> void:
	if code == exit_code:
		Sound.play("key_ok", -2.0)
		close_keypad()
		exit_open = true
		exit_door.unlocked = true
		exit_door.stay_open = true
		exit_door.set_display("CODE ACCEPTED", Color(0.4, 1.0, 0.5))
		unlock_cell(exit_door.cell)
		exit_door.open(true)
		hud.set_objective("Get in the elevator!")
		hud.say("ai", "Exit code accepted. Goodbye, and thank you for your cooperation.")
		return
	Sound.play("key_bad", -2.0)
	hud.keypad_message("WRONG CODE")
	var mode := Game.mode_data()
	if mode["wrong_code_alarm"]:
		Sound.play_at("alarm", exit_door.global_position, 2.0)
		emit_noise(exit_door.global_position, 30.0, false)
	elif not Game.is_explorer():
		emit_noise(exit_door.global_position, 10.0, false)


# =================================================================== scares

func _keycard_scare() -> void:
	if not Game.mode_data()["scares"]:
		return
	await get_tree().create_timer(1.2).timeout
	_blackout(1.6)
	var was_on: bool = player.flashlight.visible
	player.flashlight.visible = false
	await get_tree().create_timer(0.7).timeout
	var fwd: Vector3 = -player.global_transform.basis.z
	var mq := Replacement.build_model()
	add_child(mq)
	mq.global_position = player.global_position + fwd * 2.2
	mq.rotation.y = atan2(-fwd.x, -fwd.z)
	player.flashlight.visible = true
	Sound.play("sting", -3.0)
	await get_tree().create_timer(0.5).timeout
	player.flashlight.visible = false
	mq.queue_free()
	await get_tree().create_timer(0.4).timeout
	player.flashlight.visible = was_on or player.battery > 1.0
	hud.say("unknown", "...not yet.")


func _blackout(seconds: float) -> void:
	_blackout_t = seconds
	for l in lights:
		l["light"].visible = false
		l["fixture"].visible = false


func _random_event() -> void:
	var m := Game.mode_data()
	var options := ["flicker", "whisper", "echo_call"]
	if not power_on and not replacement.active:
		options.append("glimpse")
	match options[randi() % options.size()]:
		"flicker":
			_blackout(randf_range(0.8, 1.6))
			Sound.play_at("creak", player.global_position + Vector3(randf_range(-6, 6), 1, randf_range(-6, 6)), 0.0)
		"whisper":
			var lines := ["...can you hear it too?", "it's behind the next door.", "thirteen. thirteen. thirteen.", "you weren't on the employee list."]
			hud.say("unknown", lines[randi() % lines.size()])
		"echo_call":
			var lines := ["Over here. Quickly. The exit is this way.", "Stop. Do not move. ...Now run.", "You can trust me. I am MERIDIAN."]
			hud.say("echo", lines[randi() % lines.size()])
		"glimpse":
			# The mannequin, standing in the dark ahead of you. Then it's gone.
			var fwd: Vector3 = -player.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var spot: Vector3 = player.global_position + fwd * 7.0
			var q := PhysicsRayQueryParameters3D.create(player.eye_position(), spot + Vector3(0, 1.5, 0), 1)
			if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				return
			var mq := Replacement.build_model()
			add_child(mq)
			mq.global_position = spot
			mq.rotation.y = atan2(-fwd.x, -fwd.z)
			Sound.play("sting", -6.0)
			await get_tree().create_timer(0.35).timeout
			_blackout(0.5)
			await get_tree().create_timer(0.3).timeout
			mq.queue_free()
	if m["name"] == "NIGHTMARE" and randf() < 0.4:
		emit_noise(random_floor_pos(), 6.0, false)   # it goes to look somewhere


# =================================================================== catch

func on_caught(by: String) -> void:
	if catching or ended:
		return
	catching = true
	catches += 1
	if hud.keypad_open():
		hud.close_keypad()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player.hidden_in:
		player.leave_locker()
	player.frozen = true
	paused_world = true
	var soft := Game.is_explorer()
	Sound.play("static", -12.0 if soft else -2.0)
	var tip := "Tip: crouch to stay quiet, and avoid the metal grates." if by == "listener" else "Tip: it only moves when you can't see it. Keep your light on it."
	var text := ("IT FOUND YOU.\nBack to the last checkpoint.\n\n" + tip) if soft else ("SIGNAL LOST\n\n" + tip)
	hud.show_caught(soft, text, _respawn)


func _respawn() -> void:
	player.global_position = checkpoint
	player.look_at_yaw(checkpoint_yaw)
	player.velocity = Vector3.ZERO
	player.stamina = 100.0
	player.breath = 100.0
	# Put the monsters somewhere far away from the checkpoint.
	var far := listener_home
	for i in 40:
		var p := random_floor_pos()
		if p.distance_to(checkpoint) > 20.0:
			far = p
			break
	listener.reset_to(far)
	replacement.reset_to(replacement_home)
	await get_tree().create_timer(0.8).timeout
	player.frozen = false
	paused_world = false
	catching = false


# ================================================================ main loop

func set_paused(on: bool) -> void:
	get_tree().paused = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if ended:
		return
	run_time += delta
	_hid_recently = maxf(_hid_recently - delta, 0.0)

	# Lights: flicker, and come back after a blackout.
	if _blackout_t > 0.0:
		_blackout_t -= delta
		if _blackout_t <= 0.0:
			for l in lights:
				l["light"].visible = true
				l["fixture"].visible = true
	else:
		for l in lights:
			if l["flicker"]:
				var on := randf() > 0.04
				l["light"].visible = on
				l["fixture"].visible = on

	_check_player_cell()

	# Spot painted numbers (you have to actually see them).
	_clue_t -= delta
	if _clue_t <= 0.0:
		_clue_t = 0.2
		_check_clues()

	# Distant facility sounds.
	_ambient_t -= delta
	if _ambient_t <= 0.0:
		_ambient_t = randf_range(10.0, 22.0)
		var where := player.global_position + Vector3(randf_range(-15, 15), 2.5, randf_range(-15, 15))
		var vol := -14.0 if Game.is_explorer() else -6.0
		Sound.play_at("bang" if randf() < 0.4 else "drip", where, vol, randf_range(0.8, 1.2))

	# Random scares (never in Explorer).
	if Game.mode_data()["scares"] and listener.is_physics_processing() and not catching:
		_event_t -= delta
		if _event_t <= 0.0:
			var gap: Vector2 = Game.mode_data()["scare_gap"]
			_event_t = randf_range(gap.x, gap.y)
			_random_event()


func _check_player_cell() -> void:
	var c := world_to_cell(player.global_position)
	if c == _last_cell:
		return
	_last_cell = c
	var room := room_at(c)
	if room != "" and not visited.has(room):
		visited[room] = true
		_entered_room(room)
	# Checkpoints at intercoms.
	for ic in intercoms:
		var ic_cell: Vector2i = ic["cell"]
		if absi(ic_cell.x - c.x) + absi(ic_cell.y - c.y) <= 1 and checkpoint.distance_to(cell_to_world(ic_cell)) > 0.5:
			checkpoint = cell_to_world(ic_cell)
			checkpoint_yaw = player.yaw
			ic["lamp"].material_override = _glow(Color(0.2, 1.0, 0.4), 3.0)
			if ic["used"] == false:
				ic["used"] = true
				Sound.play("checkpoint", -4.0)
				hud.toast("Checkpoint", 2.0)
	if ch(c) == "E" and exit_open:
		_win()


func _entered_room(room: String) -> void:
	match room:
		"MAIN HALL":
			listener.set_physics_process(true)
			hud.say("ai", "Walk softly. Something in this sector hunts by sound.")
			hud.say("ai", "Hold CTRL to crouch. The metal grates are loud. Running is louder.")
			if Game.is_explorer():
				hud.say("ai", "The NOISE bar, bottom left, shows how far your sound carries. Listen for its clicking.")
			hud.add_clue("The Listener is blind but hears everything. Crouch on grates. Hide in lockers.")
		"BREAK ROOM":
			if not visited.has("note_hint"):
				visited["note_hint"] = true
		"SECURITY":
			hud.say("echo", "Start with the MIDDLE breaker. Trust me.")
			if Game.mode_data()["echo_hint"]:
				hud.say("ai", "...That was not me. Something on this channel is copying my voice. Check the maintenance note.")
		"LAB 2":
			if not power_on:
				hud.say("unknown", "don't look away from it.")
		"LOWER HALL":
			if not power_on:
				hud.say("ai", "The service elevator is at the end of this hall. It needs power first.")
		"CRAWLSPACE":
			hud.toast("A secret room!", 2.5)


func _check_clues() -> void:
	for spot in digit_spots:
		if spot["found"]:
			continue
		var p: Vector3 = spot["pos"]
		if p.distance_to(player.eye_position()) < 9.0 and player.can_see(p):
			spot["found"] = true
			var color_name: String = CODE_COLORS[spot["color"]][0]
			hud.add_clue("%s number: %d  (painted in %s)" % [color_name, code_digits[spot["color"]], spot["room"]])
	if power_on and not order_seen:
		# A point just in front of the door's screen, on your side.
		var dp: Vector3 = exit_door.global_position + Vector3(0, 1.6, 0)
		var toward := player.eye_position() - dp
		toward.y = 0.0
		dp += toward.normalized() * 0.4
		if dp.distance_to(player.eye_position()) < 10.0 and player.can_see(dp):
			order_seen = true
			var names: Array[String] = []
			for idx in code_order:
				names.append(CODE_COLORS[idx][0])
			hud.add_clue("Elevator code order: " + ", ".join(names))
			hud.set_objective("Find the 4 painted numbers, then type the code at the elevator.")


func _win() -> void:
	ended = true
	paused_world = true
	player.frozen = true
	Sound.play("power_on", -4.0, 0.7)
	var mode_name := Game.mode_name()
	var best: float = Game.best_times.get(mode_name, 0.0)
	var new_best := best == 0.0 or run_time < best
	if new_best:
		Game.best_times[mode_name] = run_time
	Game.save_settings()
	var learned: Array[String] = []
	if Game.learned_lockers:
		learned.append("to check lockers")
	if Game.learned_traps:
		learned.append("to set tripwires where you run")
	var learned_text := "It never figured you out." if learned.is_empty() else "It learned " + " and ".join(learned) + "."
	var body := "Mode: %s\nTime: %d:%02d%s\nTimes caught: %d\nSignal fragments: %d / %d\nThe Listener: %s\n\nThe elevator goes down, not up.\nSomewhere below, a 13th sector that isn't on any map is still broadcasting.\n\nTO BE CONTINUED IN SECTOR 2." % [
		mode_name, int(run_time) / 60, int(run_time) % 60, "  (new best!)" if new_best else "",
		catches, fragments, fragment_total, learned_text]
	hud.fade_out(1.5, func(): hud.show_end("SECTOR 1 CLEAR", body))
