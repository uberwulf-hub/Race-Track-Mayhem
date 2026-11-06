class_name KitchenRoom
extends Room
## Kitchen Kerfuffle's room: checkerboard floor, tiled walls, counters with a
## sink, a fridge covered in magnets, an oven, a big table the track can pass
## under, giant fruit, a cereal box with spilled cereal and a pet bowl.


func _configure() -> void:
	background_color = Color(0.75, 0.9, 1.0)
	ambient_color = Color(1.0, 0.97, 0.92)
	ambient_energy = 0.3
	sun_energy = 0.85
	curtain_color = Color(0.95, 0.85, 0.3)
	door_color = Color(0.95, 0.95, 0.9)
	floor_tile_size = 16.0
	floor_roughness = 0.25
	wall_tile_size = 8.0


func _floor_image() -> Image:
	return Room.checker_image(Color(0.96, 0.95, 0.9), Color(0.35, 0.6, 0.85), 2, Color(0.8, 0.8, 0.78))


func _wall_image() -> Image:
	return Room.tiles_image(Color(0.98, 0.95, 0.85), Color(0.85, 0.82, 0.75), 4, Color(0.55, 0.8, 0.75))


func _build_props() -> void:
	_counters()
	_fridge()
	_table()
	_fruit()
	_cereal()
	_pet_bowl()


func _counters() -> void:
	var r := room_rect
	var cab := _mat(Color(0.55, 0.8, 0.7), 0.5)
	var top := _shiny(Color(0.95, 0.95, 0.95))
	var knob := _shiny(Color(0.85, 0.7, 0.3))
	var length := r.size.x * 0.7
	var x0 := r.position.x + r.size.x * 0.12
	var z := r.position.y + 9.0
	_box(Vector3(length, 18.0, 16.0), Vector3(x0 + length * 0.5, 9.0, z), cab)
	_box(Vector3(length + 2.0, 1.6, 18.0), Vector3(x0 + length * 0.5, 18.8, z + 0.5), top)
	var doors := int(length / 12.0)
	for i in doors:
		var dx := x0 + 6.0 + i * 12.0
		_box(Vector3(10.0, 14.0, 0.5), Vector3(dx, 9.0, z + 8.1), _mat(Color(0.62, 0.86, 0.76), 0.5), false)
		_sphere(0.7, Vector3(dx + 3.5, 12.0, z + 8.6), knob)
	# Upper cabinets beside the window
	for side: float in [-1.0, 1.0]:
		var ux := r.position.x + r.size.x * 0.62 + side * 46.0
		_box(Vector3(30.0, 18.0, 10.0), Vector3(ux, 48.0, r.position.y + 5.0), cab)
	# Sink under the window
	var sx := r.position.x + r.size.x * 0.62
	_box(Vector3(18.0, 0.4, 10.0), Vector3(sx, 19.7, z), _mat(Color(0.6, 0.62, 0.66), 0.2), false)
	var tap := _cylinder(0.8, 8.0, Vector3(sx, 23.5, z - 5.0), knob)
	tap.name = "Tap"
	var spout := _cylinder(0.6, 6.0, Vector3(sx, 27.0, z - 2.5), knob)
	spout.rotation.x = PI * 0.5
	# Toaster and cookie jar
	_box(Vector3(8.0, 6.0, 5.0), Vector3(x0 + 10.0, 22.6, z), _shiny(Color(0.9, 0.3, 0.3)))
	_cylinder(3.5, 7.0, Vector3(x0 + 26.0, 23.0, z), _mat(Color(0.95, 0.85, 0.6), 0.4))
	_label("COOKIES", Vector3(x0 + 26.0, 23.0, z + 3.6), 64, 0.03, Color(0.5, 0.3, 0.15))
	# Oven at the end of the counter
	var ox := x0 + length + 10.0
	_box(Vector3(18.0, 20.0, 16.0), Vector3(ox, 10.0, z), _shiny(Color(0.95, 0.95, 0.95)))
	_box(Vector3(12.0, 8.0, 0.4), Vector3(ox, 9.0, z + 8.1), _glow(Color(1.0, 0.45, 0.1), 0.4), false)
	# A pot of soup bubbling away
	_cylinder(4.0, 5.0, Vector3(ox - 4.0, 23.0, z - 3.5), _shiny(Color(0.85, 0.25, 0.2)))
	var steam := CPUParticles3D.new()
	steam.position = Vector3(ox - 4.0, 26.0, z - 3.5)
	steam.amount = 24
	steam.lifetime = 3.0
	steam.direction = Vector3.UP
	steam.spread = 15.0
	steam.initial_velocity_min = 2.0
	steam.initial_velocity_max = 4.0
	steam.gravity = Vector3(0, 0.5, 0)
	steam.scale_amount_min = 1.0
	steam.scale_amount_max = 2.5
	var puff := SphereMesh.new()
	puff.radius = 0.6
	puff.height = 1.2
	puff.radial_segments = 8
	puff.rings = 4
	var steam_mat := StandardMaterial3D.new()
	steam_mat.albedo_color = Color(1, 1, 1, 0.25)
	steam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = steam_mat
	steam.mesh = puff
	add_child(steam)
	for i in 4:
		_sphere(0.9, Vector3(ox - 6.0 + i * 4.0, 17.0, z + 8.4), _mat(Color(0.2, 0.2, 0.2), 0.4))
		var burner := _cylinder(2.6, 0.3, Vector3(ox + (-4.0 if i % 2 == 0 else 4.0), 20.2, z + (-3.5 if i < 2 else 3.5)), _mat(Color(0.15, 0.15, 0.15), 0.5))
		burner.name = "Burner%d" % i


func _fridge() -> void:
	var r := room_rect
	var f := _node("Fridge", Vector3(r.position.x + 13.0, 0.0, r.position.y + 50.0), PI * 0.5)
	var body := _shiny(Color(0.92, 0.95, 0.98))
	_box(Vector3(22.0, 50.0, 20.0), Vector3(0, 25.0, 0), body, true, f)
	_box(Vector3(22.2, 0.6, 20.2), Vector3(0, 34.0, 0), _mat(Color(0.7, 0.72, 0.75), 0.4), false, f, 0.0)
	for y: float in [42.0, 18.0]:
		_box(Vector3(1.0, 9.0, 1.2), Vector3(8.5, y, 10.6), _shiny(Color(0.75, 0.75, 0.8)), true, f)
	var cols := [Color(0.95, 0.25, 0.3), Color(0.25, 0.55, 0.95), Color(1.0, 0.8, 0.15), Color(0.3, 0.8, 0.35)]
	for i in 8:
		_sphere(1.0, Vector3(_rng.randf_range(-8.0, 6.0), _rng.randf_range(12.0, 46.0), 10.3), _mat(cols[i % cols.size()], 0.3), Vector3(1.0, 1.0, 0.4), f)
	# A drawing stuck on the fridge
	_box(Vector3(8.0, 10.0, 0.1), Vector3(-2.0, 24.0, 10.2), _mat(Color.WHITE, 1.0), false, f, 0.0)
	_box(Vector3(5.0, 1.6, 0.1), Vector3(-2.0, 22.0, 10.3), _mat(Color(0.9, 0.2, 0.2), 0.8), false, f, 0.0)
	_label("VROOM!", Vector3(-2.0, 26.5, 10.3), 48, 0.03, Color(0.2, 0.3, 0.9), f)


## A big table. The track is allowed to run underneath it, so only the legs
## need to be clear of the track.
func _table() -> void:
	var size := Vector2(46.0, 30.0)
	var area := _inner_area(30.0)
	for attempt in 80:
		var c := Vector3(_rng.randf_range(area.position.x, area.end.x), 0.0, _rng.randf_range(area.position.y, area.end.y))
		var legs: Array[Vector3] = []
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				legs.append(c + Vector3(sx * (size.x * 0.5 - 2.0), 0.0, sz * (size.y * 0.5 - 2.0)))
		var ok := true
		for l in legs:
			if not _clear_of_track(l, 1.5):
				ok = false
				break
		if not ok:
			continue
		var wood := _mat(Color(0.85, 0.6, 0.38), 0.5)
		_box(Vector3(size.x, 1.6, size.y), c + Vector3(0, 30.0, 0), wood)
		for l in legs:
			_cylinder(1.2, 30.0, l + Vector3(0, 15.0, 0), wood)
		# Table cloth edge and some plates on top
		_box(Vector3(size.x + 1.0, 2.5, size.y + 1.0), c + Vector3(0, 29.5, 0), _mat(Color(0.95, 0.4, 0.4), 0.9), true, null, 0.05)
		for i in 3:
			_cylinder(4.0, 0.4, c + Vector3(-12.0 + i * 12.0, 31.2, 0), _shiny(Color.WHITE))
		return


func _fruit() -> void:
	var spots := _free_spots(5, 5.5, _inner_area(10.0))
	for i in spots.size():
		var p := spots[i]
		match i % 4:
			0:  # apple
				_sphere(4.5, p + Vector3(0, 4.3, 0), _shiny(Color(0.85, 0.1, 0.12)), Vector3(1.0, 0.95, 1.0))
				_cylinder(0.3, 2.0, p + Vector3(0, 9.0, 0), _mat(Color(0.4, 0.25, 0.1)))
				var leaf := _sphere(1.2, p + Vector3(1.0, 9.2, 0), _mat(Color(0.3, 0.75, 0.25)), Vector3(1.5, 0.3, 0.8))
				leaf.rotation.z = 0.4
			1:  # orange
				_sphere(4.2, p + Vector3(0, 4.2, 0), _mat(Color(1.0, 0.55, 0.05), 0.6))
				_sphere(0.6, p + Vector3(0, 8.3, 0), _mat(Color(0.3, 0.6, 0.2)))
			2:  # banana: a curve of squashed spheres
				for k in 7:
					var a := (k - 3) * 0.22
					_sphere(1.7 - absf(k - 3) * 0.15, p + Vector3(sin(a) * 8.0, 1.6, cos(a) * 8.0 - 8.0), _mat(Color(1.0, 0.85, 0.2), 0.5))
			3:  # pear
				_sphere(4.0, p + Vector3(0, 4.0, 0), _mat(Color(0.65, 0.85, 0.3), 0.5))
				_sphere(2.6, p + Vector3(0, 8.2, 0), _mat(Color(0.65, 0.85, 0.3), 0.5))


func _cereal() -> void:
	var spots := _free_spots(1, 10.0, _inner_area(12.0))
	if spots.is_empty():
		return
	var p := spots[0]
	var box := _node("CerealBox", p, _rng.randf_range(0.0, TAU))
	_box(Vector3(12.0, 18.0, 4.5), Vector3(0, 9.0, 0), _mat(Color(0.95, 0.3, 0.2), 0.6), true, box, 0.05)
	_label("CRUNCHY", Vector3(0, 13.0, 2.3), 72, 0.035, Color(1.0, 0.95, 0.4), box, 16)
	_label("O's", Vector3(0, 8.0, 2.3), 128, 0.04, Color.WHITE, box, 16)
	var bowl := _cylinder(3.0, 1.2, Vector3(0, 3.0, 2.31), _mat(Color(0.95, 0.85, 0.5)), box)
	bowl.rotation.x = PI * 0.5
	# Spilled cereal hoops all around
	for i in 26:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(7.0, 14.0)
		var q := p + Vector3(cos(a) * d, 0.3, sin(a) * d)
		if not _clear_of_track(q, 0.5):
			continue
		var o := _torus(0.35, 0.8, q, _mat(Color(0.95, 0.75, 0.35), 0.7))
		o.rotation = Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, 0)


func _pet_bowl() -> void:
	var r := room_rect
	var p := Vector3(r.end.x - 20.0, 0.0, r.end.y - 16.0)
	if not _clear_of_track(p, 6.0):
		return
	_cylinder(5.0, 3.0, p + Vector3(0, 1.5, 0), _mat(Color(0.3, 0.5, 0.95), 0.3), null, 6.0)
	_cylinder(4.6, 0.3, p + Vector3(0, 2.6, 0), _mat(Color(0.55, 0.35, 0.2), 0.9))
	_label("DOG", Vector3(0, 1.6, 5.6) + p, 64, 0.03, Color.WHITE)
	# A chew bone next to it
	var bone := _cylinder(0.8, 6.0, p + Vector3(9.0, 0.8, 0), _mat(Color(0.98, 0.95, 0.88)))
	bone.rotation.z = PI * 0.5
	for e: float in [-3.0, 3.0]:
		for o: float in [-0.7, 0.7]:
			_sphere(1.0, p + Vector3(9.0 + e, 0.9, o), _mat(Color(0.98, 0.95, 0.88)))
