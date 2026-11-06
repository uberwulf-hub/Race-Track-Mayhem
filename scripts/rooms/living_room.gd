class_name LivingRoom
extends Room
## Sofa Slalom's room: a cosy living room at sunset with a fluffy carpet,
## sofa, TV showing cartoons, coffee table, bookcase, potted plant, floor
## lamp and a sleeping cat.


func _configure() -> void:
	background_color = Color(0.95, 0.7, 0.55)
	ambient_color = Color(1.0, 0.85, 0.7)
	ambient_energy = 0.38
	sun_color = Color(1.0, 0.75, 0.5)
	sun_energy = 0.85
	sun_rotation = Vector3(-35.0, -60.0, 0.0)
	lamp_color = Color(1.0, 0.8, 0.55)
	lamp_energy = 0.35
	fog_color = Color(1.0, 0.85, 0.75)
	window_sky = Color(1.0, 0.6, 0.45)
	curtain_color = Color(0.55, 0.3, 0.6)
	door_color = Color(0.75, 0.55, 0.38)
	trim_color = Color(0.8, 0.6, 0.42)
	floor_tile_size = 14.0
	floor_roughness = 1.0
	wall_tile_size = 14.0


func _floor_image() -> Image:
	return Room.carpet_image(Color(0.82, 0.72, 0.58), Color(0.7, 0.6, 0.48))


func _wall_image() -> Image:
	return Room.plaid_image(Color(0.95, 0.88, 0.75), Color(0.85, 0.55, 0.45), Color(0.45, 0.6, 0.5))


func _build_props() -> void:
	_rug()
	_sofa()
	_tv()
	_coffee_table()
	_bookcase()
	_plant()
	_floor_lamp()
	_cat()
	_cushions()


func _rug() -> void:
	var tr := track.get_aabb_xz()
	var rug := _box(Vector3(tr.size.x * 0.75, 0.25, tr.size.y * 0.6), Vector3(tr.get_center().x, 0.12, tr.get_center().y), _mat(Color(0.6, 0.25, 0.3), 1.0), false, null, 0.3)
	rug.name = "Rug"
	_box(Vector3(tr.size.x * 0.68, 0.3, tr.size.y * 0.52), rug.position + Vector3(0, 0.02, 0), _mat(Color(0.9, 0.75, 0.45), 1.0), false, null, 0.3)
	_box(Vector3(tr.size.x * 0.6, 0.35, tr.size.y * 0.44), rug.position + Vector3(0, 0.04, 0), _mat(Color(0.6, 0.25, 0.3), 1.0), false, null, 0.3)


func _sofa() -> void:
	var r := room_rect
	var sofa := _node("Sofa", Vector3(r.position.x + r.size.x * 0.45, 0.0, r.end.y - 16.0), PI)
	var fabric := _mat(Color(0.3, 0.5, 0.75), 1.0)
	var w := 70.0
	_box(Vector3(w, 12.0, 26.0), Vector3(0, 8.0, 0), fabric, true, sofa, 0.3)
	_box(Vector3(w, 24.0, 8.0), Vector3(0, 20.0, 11.0), fabric, true, sofa, 0.4)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(8.0, 18.0, 26.0), Vector3(side * (w * 0.5 - 3.0), 13.0, 0), fabric, true, sofa, 0.45)
	for i in 3:
		_box(Vector3(w / 3.0 - 3.0, 5.0, 20.0), Vector3(-w / 3.0 + i * w / 3.0, 16.0, -1.0), _mat(Color(0.35, 0.56, 0.8), 1.0), true, sofa, 0.45)
	var pillow_cols := [Color(1.0, 0.75, 0.3), Color(0.95, 0.45, 0.45)]
	for i in 2:
		var pil := _box(Vector3(10.0, 10.0, 3.5), Vector3(-22.0 + i * 44.0, 24.0, 5.0), _mat(pillow_cols[i], 1.0), true, sofa, 0.45)
		pil.rotation.z = (i - 0.5) * 0.5
	for x: float in [-30.0, 30.0]:
		for z: float in [-10.0, 10.0]:
			_cylinder(1.0, 2.0, Vector3(x, 1.0, z), _mat(Color(0.35, 0.22, 0.12)), sofa)


func _tv() -> void:
	var r := room_rect
	var cx := r.position.x + r.size.x * 0.3
	var z := r.position.y + 8.0
	var wood := _mat(Color(0.5, 0.33, 0.2), 0.6)
	_box(Vector3(46.0, 12.0, 14.0), Vector3(cx, 6.0, z), wood)
	for i in 2:
		_box(Vector3(20.0, 8.0, 0.4), Vector3(cx - 11.0 + i * 22.0, 6.0, z + 7.1), _mat(Color(0.58, 0.4, 0.25), 0.6), false)
	_box(Vector3(44.0, 26.0, 2.0), Vector3(cx, 27.0, z - 1.0), _mat(Color(0.08, 0.08, 0.1), 0.3))
	# Cartoon on the screen: sky, grass, sun and a smiling car
	_box(Vector3(41.0, 23.0, 0.2), Vector3(cx, 27.0, z + 0.1), _glow(Color(0.45, 0.75, 1.0), 0.9), false, null, 0.0)
	_box(Vector3(41.0, 6.0, 0.2), Vector3(cx, 18.5, z + 0.2), _glow(Color(0.35, 0.85, 0.35), 0.9), false, null, 0.0)
	_upright(_cylinder(3.0, 0.2, Vector3(cx + 13.0, 33.0, z + 0.3), _glow(Color(1.0, 0.85, 0.2), 1.2)))
	_box(Vector3(12.0, 4.0, 0.2), Vector3(cx - 4.0, 23.0, z + 0.3), _glow(Color(0.95, 0.25, 0.2), 1.0), false, null, 0.0)
	_box(Vector3(6.0, 3.0, 0.2), Vector3(cx - 4.0, 26.0, z + 0.3), _glow(Color(0.95, 0.25, 0.2), 1.0), false, null, 0.0)
	for wx: float in [-8.0, 0.0]:
		_upright(_cylinder(1.4, 0.2, Vector3(cx + wx, 21.0, z + 0.4), _glow(Color(0.1, 0.1, 0.1), 0.2)))
	_label("CARTOONS!", Vector3(cx, 36.0, z + 0.3), 64, 0.04, Color(1, 1, 1))
	# A remote control on the floor
	var remote_pos := Vector3(cx + 30.0, 0.6, z + 18.0)
	if _clear_of_track(remote_pos, 3.0):
		_box(Vector3(3.0, 1.2, 8.0), remote_pos, _mat(Color(0.15, 0.15, 0.15), 0.5))
		_sphere(0.6, remote_pos + Vector3(0, 0.6, -2.5), _glow(Color(1.0, 0.2, 0.2), 1.0))


## The track can run under the table, so only the legs need room.
func _coffee_table() -> void:
	var area := _inner_area(25.0)
	for attempt in 80:
		var c := Vector3(_rng.randf_range(area.position.x, area.end.x), 0.0, _rng.randf_range(area.position.y, area.end.y))
		var legs: Array[Vector3] = []
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				legs.append(c + Vector3(sx * 15.0, 0.0, sz * 9.0))
		var ok := true
		for l in legs:
			if not _clear_of_track(l, 1.5):
				ok = false
		# Low table: make sure the track under it isn't raised.
		for k in range(0, track.count, 3):
			var q := track.points[k]
			if absf(q.x - c.x) < 19.0 and absf(q.z - c.z) < 13.0 and q.y > 4.0:
				ok = false
		if not ok:
			continue
		var wood := _mat(Color(0.55, 0.35, 0.2), 0.4)
		_box(Vector3(36.0, 1.6, 22.0), c + Vector3(0, 13.0, 0), wood)
		for l in legs:
			_cylinder(1.0, 12.5, l + Vector3(0, 6.25, 0), wood)
		_box(Vector3(14.0, 1.8, 10.0), c + Vector3(-6.0, 14.7, 0), _mat(Color(0.3, 0.6, 0.4), 0.7))
		var game_lbl := _label("GAME NIGHT", c + Vector3(-6.0, 15.65, 0), 48, 0.03, Color.WHITE)
		game_lbl.rotation.x = -PI * 0.5
		_cylinder(2.0, 4.0, c + Vector3(9.0, 15.8, 2.0), _mat(Color(0.95, 0.95, 0.9), 0.3))
		return


func _bookcase() -> void:
	var r := room_rect
	var bc := _node("Bookcase", Vector3(r.position.x + 7.0, 0.0, r.position.y + 40.0), PI * 0.5)
	var wood := _mat(Color(0.55, 0.36, 0.22), 0.6)
	_box(Vector3(34.0, 52.0, 12.0), Vector3(0, 26.0, 0), wood, true, bc, 0.05)
	for shelf in 4:
		var y := 6.0 + shelf * 12.0
		_box(Vector3(32.0, 1.0, 11.0), Vector3(0, y - 1.0, 0.8), _mat(Color(0.45, 0.28, 0.17), 0.6), true, bc, 0.0)
		var x := -14.0
		while x < 13.0:
			var bw := _rng.randf_range(1.2, 2.6)
			var bh := _rng.randf_range(7.0, 10.0)
			_box(Vector3(bw, bh, 8.0), Vector3(x + bw * 0.5, y + bh * 0.5 - 0.5, 1.5), _mat(Color.from_hsv(_rng.randf(), 0.6, 0.85), 0.7), true, bc, 0.05)
			x += bw + 0.2


func _plant() -> void:
	var r := room_rect
	var p := Vector3(r.end.x - 14.0, 0.0, r.position.y + 14.0)
	_cylinder(7.0, 14.0, p + Vector3(0, 7.0, 0), _mat(Color(0.85, 0.45, 0.3), 0.7), null, 8.0)
	var leaf := _mat(Color(0.25, 0.65, 0.3), 0.8)
	for i in 9:
		var a := i * TAU / 9.0
		var l := _sphere(4.0, p + Vector3(cos(a) * 5.0, 22.0 + (i % 3) * 4.0, sin(a) * 5.0), leaf, Vector3(0.6, 2.0, 0.6))
		l.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)


func _floor_lamp() -> void:
	var r := room_rect
	var p := Vector3(r.end.x - 14.0, 0.0, r.end.y - 14.0)
	var metal := _shiny(Color(0.3, 0.3, 0.32))
	_cylinder(5.0, 1.0, p + Vector3(0, 0.5, 0), metal)
	_cylinder(0.6, 50.0, p + Vector3(0, 25.0, 0), metal)
	_cylinder(9.0, 9.0, p + Vector3(0, 52.0, 0), _glow(Color(1.0, 0.85, 0.55), 0.8), null, 5.0)
	var light := OmniLight3D.new()
	light.position = p + Vector3(0, 48.0, 0)
	light.omni_range = 90.0
	light.light_energy = 1.2
	light.light_color = Color(1.0, 0.8, 0.5)
	add_child(light)


func _cat() -> void:
	var spots := _free_spots(1, 9.0, _inner_area(14.0))
	if spots.is_empty():
		return
	var cat := _node("SleepingCat", spots[0], _rng.randf() * TAU)
	_cylinder(9.0, 2.5, Vector3(0, 1.25, 0), _mat(Color(0.7, 0.35, 0.55), 1.0), cat)   # cushion bed
	var fur := _mat(Color(0.95, 0.6, 0.25), 1.0)
	_sphere(5.0, Vector3(0, 5.0, 0), fur, Vector3(1.3, 0.7, 1.0), cat)
	_sphere(3.0, Vector3(-5.0, 4.8, -2.0), fur, Vector3.ONE, cat)
	for side: float in [-1.0, 1.0]:
		var ear := _cylinder(1.2, 2.0, Vector3(-5.5, 7.8, -2.0 + side * 1.6), fur, cat, 0.05)
		ear.rotation.x = side * 0.3
		_box(Vector3(0.2, 0.25, 1.0), Vector3(-7.6, 5.4, -2.0 + side * 1.1), _mat(Color(0.2, 0.1, 0.05)), false, cat, 0.0)  # closed eyes
	_sphere(0.4, Vector3(-7.9, 4.5, -2.0), _mat(Color(1.0, 0.55, 0.6)), Vector3.ONE, cat)
	var tail := _cylinder(1.0, 9.0, Vector3(3.0, 3.0, 4.5), fur, cat)
	tail.rotation = Vector3(PI * 0.5, 0.6, 0)
	for i in 3:   # stripes
		_box(Vector3(1.0, 0.3, 7.0), Vector3(-1.0 + i * 2.5, 8.4, 0), _mat(Color(0.8, 0.4, 0.1)), false, cat, 0.0)
	var zzz := _label("z z Z", Vector3(-6.0, 12.0, -2.0), 64, 0.04, Color(1, 1, 1, 0.9), cat, 8)
	zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func _cushions() -> void:
	var cols := [Color(1.0, 0.75, 0.3), Color(0.95, 0.45, 0.45), Color(0.45, 0.75, 0.6)]
	var spots := _free_spots(3, 6.0, _inner_area(12.0))
	for i in spots.size():
		var c := _box(Vector3(10.0, 3.5, 10.0), spots[i] + Vector3(0, 1.75, 0), _mat(cols[i % cols.size()], 1.0), true, null, 0.45)
		c.rotation.y = _rng.randf() * TAU
