class_name GarageRoom
extends Room
## Workshop Wheelie's room: Dad's garage. A concrete floor with painted
## parking lines, pegboard walls full of tools, a workbench with a vise, a big
## red tool chest, stacks of tyres, oil cans, traffic cones, a bike and
## buzzing strip lights.

const TOOL_COLORS := [Color(0.9, 0.2, 0.15), Color(0.2, 0.45, 0.9), Color(0.95, 0.75, 0.1), Color(0.3, 0.7, 0.3)]


func _configure() -> void:
	background_color = Color(0.7, 0.75, 0.8)
	ambient_color = Color(0.95, 0.97, 1.0)
	ambient_energy = 0.4
	sun_energy = 0.75
	sun_color = Color(0.95, 0.97, 1.0)
	curtain_color = Color(0.45, 0.5, 0.55)
	door_color = Color(0.75, 0.78, 0.8)
	floor_tile_size = 28.0
	floor_roughness = 0.6
	wall_tile_size = 10.0
	saturation = 1.05


func _floor_image() -> Image:
	# Smooth grey concrete with saw-cut joints and a few old oil stains.
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var stains: Array = []
	for i in 3:
		stains.append([Vector2(rng.randf_range(30, 226), rng.randf_range(30, 226)), rng.randf_range(10, 22)])
	for x in 256:
		for y in 256:
			var n := 0.04 * sin(x * 0.37 + y * 0.11) * sin(y * 0.29 - x * 0.05) + rng.randf_range(-0.025, 0.025)
			var c := Color(0.62, 0.63, 0.65) * (1.0 + n)
			for s: Array in stains:
				var d: float = Vector2(x, y).distance_to(s[0])
				if d < float(s[1]):
					c = c.lerp(Color(0.38, 0.38, 0.4), 0.35 * (1.0 - d / float(s[1])))
			if x % 128 < 2 or y % 128 < 2:
				c = Color(0.48, 0.49, 0.51)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


func _wall_image() -> Image:
	# Pegboard: brown board with rows of little holes.
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for x in 128:
		for y in 128:
			var c := Color(0.72, 0.56, 0.38) * (0.97 + 0.03 * sin(x * 0.5) * sin(y * 0.43))
			var dx := (x % 16) - 8
			var dy := (y % 16) - 8
			if dx * dx + dy * dy < 5:
				c = Color(0.25, 0.18, 0.12)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


func _build_props() -> void:
	_parking_lines()
	_workbench()
	_tool_wall()
	_tool_chest()
	_tyre_stacks()
	_oil_cans()
	_cones()
	_bike()
	_strip_lights()


## Painted yellow parking lines on the concrete.
func _parking_lines() -> void:
	var r := room_rect
	var paint := _mat(Color(1.0, 0.82, 0.15), 0.7)
	for i in 3:
		var x := r.position.x + r.size.x * (0.2 + i * 0.3)
		var line := _box(Vector3(1.6, 0.05, r.size.y * 0.6), Vector3(x, 0.03, r.position.y + r.size.y * 0.55), paint, false, null, 0.0)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _workbench() -> void:
	var r := room_rect
	var bench := _node("Workbench", Vector3(r.position.x + r.size.x * 0.35, 0.0, r.position.y + 10.0))
	var wood := _mat(Color(0.65, 0.45, 0.25), 0.7)
	var steel := _shiny(Color(0.35, 0.38, 0.42))
	_box(Vector3(60.0, 2.5, 16.0), Vector3(0, 22.0, 0), wood, true, bench)
	for x: float in [-27.0, 27.0]:
		for z: float in [-6.0, 6.0]:
			_box(Vector3(2.0, 21.0, 2.0), Vector3(x, 10.5, z), steel, true, bench)
	_box(Vector3(56.0, 1.5, 14.0), Vector3(0, 6.0, 0), wood, true, bench)   # shelf
	# A vise on the corner
	_box(Vector3(6.0, 4.0, 5.0), Vector3(-24.0, 25.5, 4.0), _shiny(Color(0.2, 0.4, 0.8)), true, bench)
	var handle := _cylinder(0.4, 7.0, Vector3(-24.0, 25.5, 7.5), steel, bench)
	handle.rotation.z = PI * 0.5
	# Paint cans and a radio on top
	for i in 3:
		_cylinder(2.2, 4.5, Vector3(4.0 + i * 5.5, 25.5, -2.0), _mat(TOOL_COLORS[i], 0.35), bench)
	_box(Vector3(9.0, 6.0, 4.0), Vector3(20.0, 26.2, 0.0), _mat(Color(0.15, 0.15, 0.18), 0.4), true, bench)
	_cylinder(1.8, 0.5, Vector3(18.0, 26.2, 2.1), _shiny(Color(0.7, 0.7, 0.72)), bench).rotation.x = PI * 0.5


## Tools hanging on the pegboard above the bench.
func _tool_wall() -> void:
	var r := room_rect
	var z := r.position.y + 0.6
	var x0 := r.position.x + r.size.x * 0.35 - 24.0
	var steel := _shiny(Color(0.75, 0.77, 0.8))
	for i in 7:
		var x := x0 + i * 8.0
		var grip := _mat(TOOL_COLORS[i % TOOL_COLORS.size()], 0.4)
		match i % 3:
			0:  # wrench
				_box(Vector3(1.4, 12.0, 0.6), Vector3(x, 38.0, z), steel, false)
				_torus(1.0, 2.2, Vector3(x, 44.5, z), steel)
			1:  # screwdriver
				_box(Vector3(1.8, 5.0, 1.8), Vector3(x, 41.0, z + 0.5), grip, false)
				_box(Vector3(0.5, 7.0, 0.5), Vector3(x, 35.0, z + 0.5), steel, false)
			2:  # hammer
				_box(Vector3(1.2, 11.0, 1.2), Vector3(x, 37.0, z + 0.5), _mat(Color(0.6, 0.4, 0.2), 0.6), false)
				_box(Vector3(6.0, 2.0, 2.0), Vector3(x, 43.0, z + 0.8), _shiny(Color(0.3, 0.3, 0.33)), false)


## The big red rolling tool chest.
func _tool_chest() -> void:
	var r := room_rect
	var chest := _node("ToolChest", Vector3(r.end.x - 16.0, 0.0, r.position.y + 14.0), -0.2)
	var red := _shiny(Color(0.85, 0.12, 0.1))
	_box(Vector3(24.0, 34.0, 14.0), Vector3(0, 19.0, 0), red, true, chest)
	for i in 6:
		_box(Vector3(22.0, 0.4, 0.4), Vector3(0, 8.0 + i * 5.0, 7.1), _shiny(Color(0.85, 0.85, 0.88)), false, chest)
	for x: float in [-10.0, 10.0]:
		for zz: float in [-5.0, 5.0]:
			_upright(_cylinder(1.4, 1.2, Vector3(x, 1.4, zz), _mat(Color(0.1, 0.1, 0.1), 0.5), chest))
	_label("TOOLS", Vector3(0, 32.0, 7.1), 160, 0.03, Color(1.0, 0.95, 0.85), chest, 18)


func _tyre_stacks() -> void:
	var rubber := _mat(Color(0.08, 0.08, 0.09), 0.85)
	for p in _free_spots(3, 9.0):
		var n := 2 + _rng.randi() % 3
		for k in n:
			var t := _torus(3.5, 7.5, p + Vector3(_rng.randf_range(-0.6, 0.6), 2.2 + k * 4.2, 0), rubber)
			t.scale = Vector3(1.0, 1.4, 1.0)


func _oil_cans() -> void:
	for p in _free_spots(4, 3.5):
		var col: Color = TOOL_COLORS[_rng.randi() % TOOL_COLORS.size()]
		_cylinder(2.6, 7.0, p + Vector3(0, 3.5, 0), _shiny(col))
		_cylinder(0.7, 1.6, p + Vector3(1.2, 7.8, 0), _shiny(Color(0.8, 0.8, 0.82)))


func _cones() -> void:
	var orange := _mat(Color(1.0, 0.45, 0.05), 0.5)
	var white := _mat(Color(0.97, 0.97, 0.97), 0.5)
	for p in _free_spots(5, 4.0):
		_box(Vector3(7.0, 0.8, 7.0), p + Vector3(0, 0.4, 0), orange, true, null, 0.1)
		_cylinder(0.6, 9.0, p + Vector3(0, 5.2, 0), orange, null, 3.0).rotation.x = PI   # wide at the bottom
		_cylinder(2.2, 1.5, p + Vector3(0, 5.0, 0), white, null, 1.9)


## A kid's bike leaning against the wall.
func _bike() -> void:
	var r := room_rect
	var bike := _node("Bike", Vector3(r.position.x + 6.0, 0.0, r.position.y + r.size.y * 0.6), PI * 0.5)
	var frame := _shiny(Color(0.2, 0.75, 0.95))
	var tyre := _mat(Color(0.08, 0.08, 0.09), 0.8)
	for x: float in [-9.0, 9.0]:
		var w := _torus(4.5, 5.5, Vector3(x, 5.5, 0), tyre, bike)
		w.rotation.x = PI * 0.5
	_box(Vector3(18.0, 1.2, 1.2), Vector3(0, 8.0, 0), frame, true, bike)
	var seat_post := _box(Vector3(1.2, 7.0, 1.2), Vector3(-3.0, 10.0, 0), frame, true, bike)
	seat_post.rotation.z = 0.3
	_box(Vector3(4.0, 1.0, 2.5), Vector3(-4.0, 13.5, 0), _mat(Color(0.1, 0.1, 0.1), 0.6), true, bike)
	_box(Vector3(1.0, 1.0, 7.0), Vector3(8.0, 14.0, 0), _shiny(Color(0.8, 0.8, 0.82)), true, bike)
	bike.rotation.z = 0.15


## Glowing strip lights hanging from the ceiling.
func _strip_lights() -> void:
	var r := room_rect
	for i in 3:
		var x := r.position.x + r.size.x * (0.25 + i * 0.25)
		_box(Vector3(3.0, 1.2, 40.0), Vector3(x, WALL_HEIGHT - 6.0, r.get_center().y), _mat(Color(0.85, 0.85, 0.88), 0.4), false)
		_box(Vector3(2.0, 0.6, 38.0), Vector3(x, WALL_HEIGHT - 6.9, r.get_center().y), _glow(Color(0.95, 0.98, 1.0), 2.0), false)
