class_name AtticRoom
extends Room
## Attic Antics' room: the dusty attic under the roof. Wide floorboards,
## wooden rafters overhead, a round window with a sunbeam full of floating
## dust, cobwebs in the corners, a rocking horse, old trunks, piles of
## cardboard boxes, an armchair under a sheet, a telescope and a bare bulb.

const BOX_COLORS := [Color(0.72, 0.55, 0.35), Color(0.65, 0.5, 0.32), Color(0.78, 0.62, 0.4)]


func _configure() -> void:
	background_color = Color(0.35, 0.28, 0.22)
	ambient_color = Color(1.0, 0.85, 0.65)
	ambient_energy = 0.4
	sun_energy = 0.7
	sun_color = Color(1.0, 0.85, 0.6)
	sun_rotation = Vector3(-35.0, 60.0, 0.0)
	lamp_color = Color(1.0, 0.8, 0.5)
	lamp_energy = 0.6
	fog_color = Color(0.8, 0.65, 0.45)
	floor_tile_size = 30.0
	floor_roughness = 0.75
	wall_tile_size = 14.0
	trim_color = Color(0.45, 0.3, 0.18)
	ceiling_color = Color(0.55, 0.4, 0.26)
	door_color = Color(0.5, 0.35, 0.2)
	has_window = false
	saturation = 1.05


## Wide old floorboards with knots and nail dots.
func _floor_image() -> Image:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var shades: Array = []
	for i in 8:
		shades.append(rng.randf_range(0.85, 1.1))
	for x in 256:
		for y in 256:
			var plank := y / 32
			var grain := 0.06 * sin(x * 0.09 + plank * 1.7 + sin(y * 0.3) * 0.8) + rng.randf_range(-0.03, 0.03)
			var c := Color(0.58, 0.4, 0.24) * (float(shades[plank]) + grain)
			if y % 32 < 2:
				c = Color(0.25, 0.16, 0.09)   # gap between planks
			elif (x + plank * 70) % 256 < 2:
				c = Color(0.3, 0.2, 0.12)     # plank ends
			elif (x + plank * 70 + 9) % 128 < 3 and (y % 32 == 6 or y % 32 == 25):
				c = Color(0.2, 0.2, 0.22)     # nails
			c.a = 1.0
			img.set_pixel(x, y, c)
	for i in 5:   # knots
		var k := Vector2(rng.randf_range(10, 246), rng.randf_range(10, 246))
		for x in range(int(k.x) - 5, int(k.x) + 6):
			for y in range(int(k.y) - 3, int(k.y) + 4):
				var d := Vector2((x - k.x) / 5.0, (y - k.y) / 3.0).length()
				if d < 1.0 and x >= 0 and x < 256 and y >= 0 and y < 256 and y % 32 >= 2:
					img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.35 * (1.0 - d)))
	return img


## Rough wooden boards on the walls.
func _wall_image() -> Image:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for x in 128:
		for y in 128:
			var board := x / 21
			var c := Color(0.62, 0.46, 0.3) * (0.92 + 0.05 * sin(y * 0.15 + board * 2.0) + rng.randf_range(-0.03, 0.03))
			if x % 21 < 2:
				c = Color(0.32, 0.22, 0.13)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


func _build_props() -> void:
	_rafters()
	_round_window()
	_dust()
	_cobwebs()
	_rocking_horse()
	_trunks()
	_boxes()
	_armchair()
	_telescope()
	_bulb()
	_toy_blocks(5, "ATTIC", [Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.9), Color(0.95, 0.8, 0.2), Color(0.4, 0.8, 0.4)])


## Big wooden beams across the ceiling, like the inside of the roof.
func _rafters() -> void:
	var r := room_rect
	var wood := _mat(Color(0.45, 0.3, 0.18), 0.85)
	var n := int(r.size.x / 40.0) + 1
	for i in n:
		var x := r.position.x + 20.0 + i * 40.0
		var rafter := _box(Vector3(3.0, 4.0, r.size.y), Vector3(x, WALL_HEIGHT - 3.0, r.get_center().y), wood, false, null, 0.1)
		rafter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ridge := _box(Vector3(r.size.x, 5.0, 5.0), Vector3(r.get_center().x, WALL_HEIGHT - 2.0, r.get_center().y), wood, false, null, 0.1)   # ridge beam
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A round window high on the back wall, with a slanting sunbeam.
func _round_window() -> void:
	var r := room_rect
	var c := Vector3(r.position.x + r.size.x * 0.4, 46.0, r.position.y + 0.4)
	var frame := _torus(10.0, 12.5, c, _mat(Color(0.95, 0.93, 0.88), 0.5))
	frame.rotation.x = PI * 0.5
	var glass := _cylinder(10.2, 0.3, c, _glow(Color(1.0, 0.92, 0.7), 1.6))
	glass.rotation.x = PI * 0.5
	for k in 2:
		var bar := _box(Vector3(20.0, 0.8, 0.8), c + Vector3(0, 0, 0.4), _mat(Color(0.95, 0.93, 0.88), 0.5), false, null, 0.0)
		bar.rotation.z = k * PI * 0.5
	# The sunbeam: a soft see-through shaft slanting down to the floor.
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 9.0
	cm.bottom_radius = 16.0
	cm.height = 60.0
	beam.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.92, 0.6, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = c + Vector3(0, -22.0, 22.0)
	beam.rotation.x = 0.8
	add_child(beam)
	set_meta("beam_at", beam.position)


## Dust motes drifting slowly through the air.
func _dust() -> void:
	var p := CPUParticles3D.new()
	p.amount = 60 if Game.is_mobile() else 160
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(room_rect.size.x * 0.45, 25.0, room_rect.size.y * 0.45)
	p.position = center() + Vector3(0, 30.0, 0)
	p.direction = Vector3(0.3, 1.0, 0.1).normalized()
	p.spread = 180.0
	p.gravity = Vector3(0.0, -0.05, 0.0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	var mote := SphereMesh.new()
	mote.radius = 0.18
	mote.height = 0.36
	mote.radial_segments = 4
	mote.rings = 2
	p.mesh = mote
	var m := _mat(Color(1.0, 0.95, 0.8), 1.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)


## Cobwebs in the top corners (with a friendly spider).
func _cobwebs() -> void:
	var r := room_rect
	var silk := _mat(Color(0.92, 0.92, 0.95, 1.0), 0.5)
	var corners := [Vector3(r.position.x, WALL_HEIGHT - 8.0, r.position.y), Vector3(r.end.x, WALL_HEIGHT - 8.0, r.position.y),
		Vector3(r.position.x, WALL_HEIGHT - 8.0, r.end.y)]
	for corner: Vector3 in corners:
		var dx := 1.0 if corner.x < r.get_center().x else -1.0
		var dz := 1.0 if corner.z < r.get_center().y else -1.0
		for k in 5:
			var a := k * (PI * 0.5) / 4.0
			var dir := Vector3(cos(a) * dx, -0.3, sin(a) * dz).normalized()
			var strand := _box(Vector3(0.2, 0.2, 16.0), corner + dir * 8.0, silk, false, null, 0.0)
			strand.look_at_from_position(strand.position, corner + dir * 16.0, Vector3.UP)
		for ring in 3:
			var rad := 4.0 + ring * 4.0
			for k in 4:
				var a0 := k * (PI * 0.5) / 4.0
				var a1 := (k + 1) * (PI * 0.5) / 4.0
				var p0 := corner + Vector3(cos(a0) * dx, -0.3, sin(a0) * dz).normalized() * rad
				var p1 := corner + Vector3(cos(a1) * dx, -0.3, sin(a1) * dz).normalized() * rad
				var seg := _box(Vector3(0.15, 0.15, p0.distance_to(p1)), (p0 + p1) * 0.5, silk, false, null, 0.0)
				seg.look_at_from_position(seg.position, p1, Vector3.UP)
	var spider := _sphere(1.0, corners[0] + Vector3(6.0, -10.0, 6.0), _mat(Color(0.1, 0.08, 0.12), 0.4))
	var start := spider.position
	animate(func(t: float, _d: float): spider.position = start + Vector3(0, sin(t * 0.7) * 3.0, 0))


## A painted rocking horse that gently rocks.
func _rocking_horse() -> void:
	var spots := _free_spots(1, 12.0, _inner_area(10.0))
	if spots.is_empty():
		return
	var horse := _node("RockingHorse", spots[0], _rng.randf() * TAU)
	var rock := Node3D.new()
	horse.add_child(rock)
	var white := _mat(Color(0.97, 0.95, 0.9), 0.5)
	var red := _shiny(Color(0.85, 0.15, 0.15))
	var wood := _mat(Color(0.5, 0.3, 0.15), 0.6)
	for side: float in [-1.0, 1.0]:
		var rocker := _torus(15.0, 16.2, Vector3(side * 3.5, 15.5, 0), wood, rock)
		rocker.rotation.z = PI * 0.5
		rocker.scale = Vector3(1, 1, 1)
	_box(Vector3(6.0, 6.0, 14.0), Vector3(0, 9.0, 0), white, true, rock, 2.5)        # body
	_box(Vector3(4.0, 9.0, 4.0), Vector3(0, 14.0, -7.0), white, true, rock, 1.5)     # neck
	_box(Vector3(4.0, 4.0, 7.0), Vector3(0, 18.0, -9.5), white, true, rock, 1.5)     # head
	_box(Vector3(1.2, 7.0, 6.0), Vector3(0, 17.0, -5.5), red, true, rock, 0.5)       # mane
	_box(Vector3(6.4, 1.2, 5.0), Vector3(0, 12.2, 1.0), red, true, rock, 0.4)        # saddle
	for x: float in [-2.0, 2.0]:
		for z: float in [-5.0, 5.0]:
			_box(Vector3(1.4, 6.0, 1.4), Vector3(x, 4.0, z), white, true, rock, 0.4)
	_box(Vector3(1.0, 6.0, 1.0), Vector3(0, 10.0, 7.5), _mat(Color(0.2, 0.15, 0.1), 0.6), true, rock, 0.3)   # tail
	for side: float in [-1.0, 1.0]:
		_sphere(0.5, Vector3(side * 2.0, 19.0, -12.5), _mat(Color(0.05, 0.05, 0.05), 0.3), Vector3.ONE, rock)
	animate(func(t: float, _d: float): rock.rotation.x = sin(t * 1.4) * 0.12)


## Old travel trunks with metal corners and straps.
func _trunks() -> void:
	var cols := [Color(0.35, 0.22, 0.12), Color(0.2, 0.3, 0.45), Color(0.45, 0.15, 0.12)]
	for p in _free_spots(3, 12.0):
		var col: Color = cols[_rng.randi() % cols.size()]
		var trunk := _node("Trunk", p, _rng.randf() * TAU)
		_box(Vector3(18.0, 10.0, 11.0), Vector3(0, 5.0, 0), _mat(col, 0.6), true, trunk, 0.8)
		_cylinder(5.5, 18.0, Vector3(0, 10.0, 0), _mat(col.lightened(0.05), 0.6), trunk).rotation.z = PI * 0.5   # curved lid
		var brass := _shiny(Color(0.8, 0.62, 0.25))
		for x: float in [-6.0, 6.0]:
			_box(Vector3(1.4, 15.6, 11.4), Vector3(x, 7.0, 0), _mat(Color(0.25, 0.15, 0.08), 0.6), false, trunk, 0.2)   # straps
		_box(Vector3(2.0, 2.4, 0.6), Vector3(0, 9.0, -5.8), brass, false, trunk, 0.2)   # lock


## Stacks of cardboard boxes, some with tape and scribbled labels.
func _boxes() -> void:
	var labels := ["TOYS", "XMAS", "BOOKS", "OLD", "BABY", "LEGO"]
	for p in _free_spots(6, 8.0):
		var n := 1 + _rng.randi() % 3
		var rot := _rng.randf() * TAU
		for k in n:
			var s := _rng.randf_range(7.0, 10.0) * (1.0 - k * 0.12)
			var col: Color = BOX_COLORS[_rng.randi() % BOX_COLORS.size()]
			var b := _box(Vector3(s, s * 0.8, s), p + Vector3(_rng.randf_range(-0.8, 0.8), s * 0.4 + k * s * 0.78, _rng.randf_range(-0.8, 0.8)), _mat(col, 0.9), true, null, 0.2)
			b.rotation.y = rot + _rng.randf_range(-0.3, 0.3)
			_box(Vector3(s + 0.1, 0.1, s * 0.25), Vector3(0, s * 0.4, 0), _mat(Color(0.85, 0.75, 0.55), 0.6), false, b, 0.0)   # tape
			_label(labels[_rng.randi() % labels.size()], Vector3(0, 0, -s * 0.51), 80, 0.035, Color(0.15, 0.12, 0.1), b)


## An armchair hidden under a white dust sheet.
func _armchair() -> void:
	var spots := _free_spots(1, 13.0)
	if spots.is_empty():
		return
	var chair := _node("Armchair", spots[0], _rng.randf() * TAU)
	var sheet := _mat(Color(0.93, 0.93, 0.9), 0.95)
	_box(Vector3(20.0, 10.0, 18.0), Vector3(0, 5.0, 0), sheet, true, chair, 3.0)
	_box(Vector3(20.0, 16.0, 5.0), Vector3(0, 14.0, 7.0), sheet, true, chair, 2.5)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(4.0, 8.0, 18.0), Vector3(side * 9.0, 12.0, 0), sheet, true, chair, 2.0)
	_box(Vector3(22.0, 3.0, 20.0), Vector3(0, 1.5, 0), sheet, true, chair, 1.4)   # the sheet's hem on the floor


## A little brass telescope pointing at the round window.
func _telescope() -> void:
	var spots := _free_spots(1, 8.0)
	if spots.is_empty():
		return
	var scope := _node("Telescope", spots[0], _rng.randf() * TAU)
	var brass := _shiny(Color(0.82, 0.62, 0.28))
	for k in 3:
		var leg := _cylinder(0.4, 12.0, Vector3(cos(k * TAU / 3.0) * 2.5, 5.5, sin(k * TAU / 3.0) * 2.5), _mat(Color(0.35, 0.22, 0.12), 0.6), scope)
		leg.rotation = Vector3(sin(k * TAU / 3.0) * 0.25, 0, -cos(k * TAU / 3.0) * 0.25)
	var tube := _cylinder(1.4, 14.0, Vector3(0, 13.0, 0), brass, scope, 1.0)
	tube.rotation.x = -1.0


## A bare bulb hanging on a wire, swaying a little.
func _bulb() -> void:
	var pivot := Node3D.new()
	pivot.position = center() + Vector3(0, WALL_HEIGHT - 4.0, 0)
	add_child(pivot)
	_box(Vector3(0.3, 20.0, 0.3), Vector3(0, -10.0, 0), _mat(Color(0.1, 0.1, 0.1), 0.5), false, pivot, 0.0)
	_sphere(1.8, Vector3(0, -21.0, 0), _glow(Color(1.0, 0.85, 0.5), 3.0), Vector3(1, 1.2, 1), pivot)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.5)
	light.light_energy = 1.2
	light.omni_range = 90.0
	light.position = Vector3(0, -22.0, 0)
	pivot.add_child(light)
	animate(func(t: float, _d: float): pivot.rotation.z = sin(t * 0.9) * 0.05)
