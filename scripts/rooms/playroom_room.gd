class_name PlayroomRoom
extends Room
## Toy Box Twister's room: a bright playroom with a foam puzzle-mat floor,
## a rainbow on the wall, toy chest, block towers, ball pit, xylophone,
## toy train, bean bags and kids' drawings.

const BRIGHT := [Color(0.95, 0.25, 0.25), Color(0.25, 0.55, 0.95), Color(0.98, 0.8, 0.15), Color(0.3, 0.8, 0.35), Color(0.75, 0.4, 0.9), Color(1.0, 0.55, 0.15)]


func _configure() -> void:
	background_color = Color(0.7, 0.85, 1.0)
	curtain_color = Color(0.3, 0.75, 0.45)
	door_color = Color(0.55, 0.8, 1.0)
	floor_tile_size = 20.0
	floor_roughness = 0.85
	wall_tile_size = 10.0
	saturation = 1.2


func _floor_image() -> Image:
	return Room.foam_mat_image([Color(0.95, 0.35, 0.35), Color(0.35, 0.6, 0.95), Color(0.98, 0.85, 0.3), Color(0.4, 0.8, 0.45)])


func _wall_image() -> Image:
	return Room.dots_image(Color(1.0, 0.93, 0.6), Color(1.0, 1.0, 0.92))


func _build_props() -> void:
	_rainbow()
	_drawings()
	_toy_chest()
	_ball_pit()
	_block_towers()
	_xylophone()
	_train()
	_bean_bags()
	_toy_blocks(14, "ABC123XYZ", BRIGHT)


func _rainbow() -> void:
	var r := room_rect
	var cx := r.position.x + r.size.x * 0.28
	var bands := [Color(0.95, 0.25, 0.25), Color(1.0, 0.6, 0.15), Color(1.0, 0.9, 0.2), Color(0.35, 0.8, 0.35), Color(0.3, 0.55, 0.95), Color(0.6, 0.35, 0.85)]
	for i in bands.size():
		var outer := 30.0 - i * 2.4
		var arc := _torus(outer - 2.4, outer, Vector3(cx, 8.0, r.position.y + 0.3), _mat(bands[i], 0.7))
		arc.rotation.x = PI * 0.5
		arc.scale = Vector3(1.0, 0.15, 1.0)
		arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side: float in [-1.0, 1.0]:   # fluffy clouds at the ends
		for k in 3:
			_sphere(3.2, Vector3(cx + side * 26.0 + (k - 1) * 3.5, 9.0 + (1.5 if k == 1 else 0.0), r.position.y + 0.6), _mat(Color.WHITE, 1.0), Vector3(1.0, 0.85, 0.2))


func _drawings() -> void:
	var r := room_rect
	for i in 4:
		var paper := _node("Drawing%d" % i, Vector3(r.position.x + 0.4, 34.0 + (i % 2) * 6.0, r.position.y + 50.0 + i * 22.0), PI * 0.5)
		_box(Vector3(14.0, 11.0, 0.2), Vector3.ZERO, _mat(Color(1, 1, 1), 1.0), false, paper, 0.0)
		match i % 4:
			0:  # sunshine
				_upright(_cylinder(2.2, 0.2, Vector3(-3.0, 2.0, 0.2), _mat(Color(1.0, 0.85, 0.1)), paper))
				_box(Vector3(12.0, 2.0, 0.1), Vector3(0, -4.0, 0.15), _mat(Color(0.3, 0.8, 0.3)), false, paper, 0.0)
			1:  # a house
				_box(Vector3(6.0, 5.0, 0.1), Vector3(0, -1.5, 0.15), _mat(Color(0.95, 0.4, 0.3)), false, paper, 0.0)
				var roof := _box(Vector3(4.6, 4.6, 0.1), Vector3(0, 2.0, 0.16), _mat(Color(0.5, 0.3, 0.2)), false, paper, 0.0)
				roof.rotation.z = PI * 0.25
			2:  # a car, of course
				_box(Vector3(9.0, 2.5, 0.1), Vector3(0, -1.0, 0.15), _mat(Color(0.2, 0.5, 0.95)), false, paper, 0.0)
				for x: float in [-2.8, 2.8]:
					_upright(_cylinder(1.2, 0.1, Vector3(x, -2.6, 0.2), _mat(Color(0.1, 0.1, 0.1)), paper))
			3:  # a flower
				_box(Vector3(0.5, 6.0, 0.1), Vector3(0, -2.0, 0.15), _mat(Color(0.3, 0.75, 0.3)), false, paper, 0.0)
				_upright(_cylinder(2.0, 0.1, Vector3(0, 1.5, 0.2), _mat(Color(0.95, 0.4, 0.7)), paper))


func _toy_chest() -> void:
	var r := room_rect
	var chest := _node("ToyChest", Vector3(r.end.x - 20.0, 0.0, r.position.y + 22.0), -0.3)
	var wood := _mat(Color(0.3, 0.55, 0.95), 0.5)
	_box(Vector3(30.0, 16.0, 18.0), Vector3(0, 8.0, 0), wood, true, chest)
	_box(Vector3(31.0, 2.0, 19.0), Vector3(0, 1.0, 0), _mat(Color(1.0, 0.85, 0.2), 0.5), true, chest)
	var lid := _box(Vector3(30.0, 1.6, 18.0), Vector3(0, 23.0, 9.5), wood, true, chest)
	lid.rotation.x = -1.2
	_label("TOYS", Vector3(0, 9.0, 9.05), 200, 0.03, Color(1.0, 0.9, 0.3), chest, 24)
	# Toys poking out of the top
	_sphere(4.0, Vector3(-7.0, 17.0, 0), _mat(BRIGHT[0], 0.3), Vector3.ONE, chest)
	_box(Vector3(5.0, 5.0, 5.0), Vector3(4.0, 17.0, -2.0), _mat(BRIGHT[2], 0.4), true, chest)
	var bat := _cylinder(0.8, 14.0, Vector3(10.0, 19.0, 3.0), _mat(BRIGHT[3], 0.4), chest)
	bat.rotation.z = 0.5


func _ball_pit() -> void:
	var spots := _free_spots(1, 16.0, _inner_area(20.0))
	if spots.is_empty():
		return
	var p := spots[0]
	_torus(13.0, 16.0, p + Vector3(0, 1.5, 0), _mat(Color(0.95, 0.3, 0.6), 0.6))
	_cylinder(13.5, 0.4, p + Vector3(0, 0.2, 0), _mat(Color(0.3, 0.6, 0.95), 0.8))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mm.mesh = sm
	mm.instance_count = 110
	for i in mm.instance_count:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * 12.0
		var h := 1.0 + _rng.randf() * 1.6
		mm.set_instance_transform(i, Transform3D(Basis(), p + Vector3(cos(a) * d, h, sin(a) * d)))
		mm.set_instance_color(i, BRIGHT[i % BRIGHT.size()])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := _mat(Color.WHITE, 0.3)
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	add_child(mmi)


func _block_towers() -> void:
	for p in _free_spots(3, 5.0, _inner_area(12.0)):
		var h := _rng.randi_range(4, 7)
		for k in h:
			var blk := _box(Vector3(4.0, 4.0, 4.0), p + Vector3(_rng.randf_range(-0.4, 0.4), 2.0 + k * 4.0, _rng.randf_range(-0.4, 0.4)), _mat(BRIGHT[(k + h) % BRIGHT.size()], 0.4))
			blk.rotation.y = _rng.randf_range(-0.3, 0.3)


func _xylophone() -> void:
	var spots := _free_spots(1, 10.0, _inner_area(14.0))
	if spots.is_empty():
		return
	var x := _node("Xylophone", spots[0], _rng.randf() * TAU)
	_box(Vector3(18.0, 2.0, 2.0), Vector3(0, 1.0, -4.0), _mat(Color(0.6, 0.4, 0.25), 0.6), true, x)
	_box(Vector3(18.0, 2.0, 2.0), Vector3(0, 1.0, 4.0), _mat(Color(0.6, 0.4, 0.25), 0.6), true, x)
	for i in 8:
		var len := 11.0 - i * 0.7
		_box(Vector3(1.8, 0.8, len), Vector3(-7.0 + i * 2.0, 2.4, 0), _shiny(BRIGHT[i % BRIGHT.size()]), true, x)
	for side: float in [-1.0, 1.0]:
		var stick := _cylinder(0.3, 10.0, Vector3(side * 4.0, 0.4, 8.0), _mat(Color(0.85, 0.7, 0.5)), x)
		stick.rotation.x = PI * 0.5
		_sphere(1.0, Vector3(side * 4.0, 0.6, 3.2), _mat(Color(0.95, 0.25, 0.3), 0.3), Vector3.ONE, x)


func _train() -> void:
	var r := room_rect
	var train := _node("Train", Vector3(r.position.x + 30.0, 0.0, r.end.y - 10.0))
	var cols := [Color(0.9, 0.2, 0.2), Color(0.25, 0.5, 0.95), Color(1.0, 0.8, 0.15)]
	for car in 3:
		var x := car * 13.0
		_box(Vector3(11.0, 6.0, 6.0), Vector3(x, 4.5, 0), _mat(cols[car], 0.35), true, train)
		if car == 0:
			_box(Vector3(5.0, 5.0, 6.0), Vector3(x - 2.5, 9.5, 0), _mat(cols[car], 0.35), true, train)
			_cylinder(1.2, 4.0, Vector3(x + 3.5, 9.0, 0), _mat(Color(0.15, 0.15, 0.15), 0.4), train)
		for wx: float in [-3.5, 3.5]:
			for wz: float in [-3.2, 3.2]:
				var w := _cylinder(1.6, 0.6, Vector3(x + wx, 1.6, wz), _mat(Color(0.12, 0.12, 0.12), 0.6), train)
				w.rotation.x = PI * 0.5
	for k in 2:
		var link := _box(Vector3(2.5, 0.6, 0.6), Vector3(6.5 + k * 13.0, 3.0, 0), _mat(Color(0.2, 0.2, 0.2)), true, train)
		link.name = "Link%d" % k


func _bean_bags() -> void:
	var r := room_rect
	var spots := [Vector3(r.position.x + 18.0, 0, r.position.y + 18.0), Vector3(r.end.x - 18.0, 0, r.end.y - 30.0)]
	for i in spots.size():
		var p: Vector3 = spots[i]
		if not _clear_of_track(p, 10.0):
			continue
		_sphere(10.0, p + Vector3(0, 5.0, 0), _mat(BRIGHT[i * 3 + 1], 1.0), Vector3(1.0, 0.55, 1.0))
		_sphere(6.0, p + Vector3(0, 9.0, 4.0), _mat(BRIGHT[i * 3 + 1].lightened(0.15), 1.0), Vector3(1.2, 0.8, 0.6))
