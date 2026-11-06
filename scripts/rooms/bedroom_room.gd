class_name BedroomRoom
extends Room
## Bedroom Speedway's room: wooden floor, rainbow rug, bed, dresser,
## teddy bear, toy blocks, crayons, beach ball, poster and trophy shelf.


func _configure() -> void:
	curtain_color = Color(0.95, 0.45, 0.55)


func _floor_image() -> Image:
	return Room.wood_image(Color(0.62, 0.42, 0.25))


func _wall_image() -> Image:
	return Room.stripes_image(Color(0.62, 0.8, 0.95), Color(0.68, 0.85, 0.98), Color(1.0, 0.95, 0.6))


func _build_props() -> void:
	_build_rug()
	_build_wall_stars()
	_build_bed()
	_build_dresser()
	_build_teddy()
	_build_toys()
	_build_poster()
	_build_shelf()


func _build_rug() -> void:
	var tr := track.get_aabb_xz()
	var rug := _cylinder(1.0, 0.12, Vector3(tr.get_center().x, 0.06, tr.get_center().y), _mat(Color(0.35, 0.55, 0.95), 1.0))
	rug.scale = Vector3(tr.size.x * 0.42, 1.0, tr.size.y * 0.42)
	var rug2 := _cylinder(1.0, 0.14, rug.position, _mat(Color(0.98, 0.85, 0.35), 1.0))
	rug2.scale = rug.scale * Vector3(0.8, 1.0, 0.8)
	var rug3 := _cylinder(1.0, 0.16, rug.position, _mat(Color(0.95, 0.45, 0.5), 1.0))
	rug3.scale = rug.scale * Vector3(0.55, 1.0, 0.55)


func _build_wall_stars() -> void:
	var r := room_rect
	var star_mat := _mat(Color(1.0, 0.9, 0.3), 0.5)
	for i in 14:
		var pos := Vector3(r.position.x + r.size.x * _rng.randf_range(0.05, 0.95), _rng.randf_range(25.0, WALL_HEIGHT - 8.0), r.position.y + 0.05)
		var sz := _rng.randf_range(1.5, 3.0)
		var star := _box(Vector3(sz, sz, 0.2), pos, star_mat, false)
		star.rotation.z = PI * 0.25


func _build_bed() -> void:
	var r := room_rect
	var bed := Node3D.new()
	bed.name = "Bed"
	add_child(bed)
	var w := 30.0
	var l := 52.0
	bed.position = Vector3(r.end.x - w * 0.5 - 1.0, 0.0, r.position.y + l * 0.5 + 6.0)
	var wood := _mat(Color(0.85, 0.6, 0.35), 0.6)
	_box(Vector3(w, 8.0, l), Vector3(0, 6.0, 0), wood, true, bed)                          # frame
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			_box(Vector3(2.5, 4.0, 2.5), Vector3(x * (w * 0.5 - 1.5), 2.0, z * (l * 0.5 - 1.5)), wood, true, bed)
	_box(Vector3(w - 1.0, 5.0, l - 1.0), Vector3(0, 12.5, 0), _mat(Color(0.97, 0.97, 1.0), 1.0), true, bed)   # mattress
	_box(Vector3(w + 1.0, 2.0, l * 0.62), Vector3(0, 15.6, l * 0.18), _mat(Color(0.3, 0.75, 0.45), 1.0), true, bed)  # blanket
	_box(Vector3(w + 1.2, 10.0, l * 0.62), Vector3(0, 10.0, l * 0.18), _mat(Color(0.3, 0.75, 0.45), 1.0), true, bed)
	_box(Vector3(w, 26.0, 2.5), Vector3(0, 13.0, -l * 0.5 - 1.2), wood, true, bed)          # headboard
	var pillow := _sphere(5.0, Vector3(0, 16.5, -l * 0.5 + 7.0), _mat(Color(1.0, 0.95, 0.75), 1.0), Vector3(2.2, 0.6, 1.0), bed)
	pillow.name = "Pillow"
	# Blanket polka dots
	var dot := _mat(Color(1.0, 0.95, 0.4), 1.0)
	for i in 8:
		_cylinder(1.6, 0.2, Vector3(_rng.randf_range(-w * 0.4, w * 0.4), 16.65, _rng.randf_range(-l * 0.05, l * 0.45)), dot, bed)


func _build_dresser() -> void:
	var r := room_rect
	var d := Node3D.new()
	d.name = "Dresser"
	add_child(d)
	d.position = Vector3(r.position.x + 9.0, 0.0, r.position.y + 38.0)
	var body := _mat(Color(0.98, 0.9, 0.95), 0.6)
	_box(Vector3(16.0, 30.0, 34.0), Vector3(0, 15.0, 0), body, true, d)
	var colors := [Color(1.0, 0.55, 0.6), Color(0.55, 0.85, 1.0), Color(0.7, 0.95, 0.55)]
	for i in 3:
		_box(Vector3(0.6, 8.0, 30.0), Vector3(8.2, 6.0 + i * 9.0, 0), _mat(colors[i], 0.5), true, d)
		_sphere(1.0, Vector3(8.8, 6.0 + i * 9.0, 0), _mat(Color(1, 1, 1), 0.3), Vector3.ONE, d)
	# Lamp on top
	_cylinder(2.5, 1.0, Vector3(0, 30.5, -8.0), _mat(Color(0.3, 0.3, 0.35), 0.4), d)
	_cylinder(0.5, 10.0, Vector3(0, 36.0, -8.0), _mat(Color(0.3, 0.3, 0.35), 0.4), d)
	var shade := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 2.5
	cone.bottom_radius = 5.0
	cone.height = 6.0
	shade.mesh = cone
	var shade_mat := _mat(Color(1.0, 0.9, 0.5), 0.8)
	shade_mat.emission_enabled = true
	shade_mat.emission = Color(1.0, 0.85, 0.4)
	shade_mat.emission_energy_multiplier = 0.6
	shade.material_override = shade_mat
	shade.position = Vector3(0, 42.0, -8.0)
	d.add_child(shade)
	# Picture books
	for i in 4:
		var bk := _box(Vector3(6.0, 1.2, 8.0), Vector3(0, 30.6 + i * 1.2, 8.0), _mat(Color.from_hsv(_rng.randf(), 0.7, 0.95), 0.6), true, d)
		bk.rotation.y = _rng.randf_range(-0.3, 0.3)


func _build_teddy() -> void:
	var r := room_rect
	var bear := Node3D.new()
	bear.name = "TeddyBear"
	add_child(bear)
	bear.position = Vector3(r.position.x + 16.0, 0.0, r.end.y - 18.0)
	bear.rotation.y = deg_to_rad(-135.0)
	var fur := _mat(Color(0.65, 0.42, 0.25), 1.0)
	var light := _mat(Color(0.92, 0.78, 0.6), 1.0)
	var dark := _mat(Color(0.08, 0.05, 0.05), 0.2)
	_sphere(8.0, Vector3(0, 8.0, 0), fur, Vector3(1.0, 1.1, 0.9), bear)          # body
	_sphere(5.0, Vector3(0, 8.0, -5.5), light, Vector3(1.0, 1.1, 0.5), bear)     # tummy
	_sphere(6.0, Vector3(0, 19.5, 0), fur, Vector3.ONE, bear)                     # head
	_sphere(2.5, Vector3(0, 18.5, -5.2), light, Vector3(1.0, 0.8, 0.8), bear)    # muzzle
	_sphere(0.9, Vector3(0, 19.2, -7.0), dark, Vector3.ONE, bear)                 # nose
	for side: float in [-1.0, 1.0]:
		_sphere(2.4, Vector3(side * 4.5, 24.5, 0), fur, Vector3(1.0, 1.0, 0.6), bear)      # ears
		_sphere(1.3, Vector3(side * 4.5, 24.5, -0.8), light, Vector3(1.0, 1.0, 0.5), bear)
		_sphere(0.8, Vector3(side * 2.2, 21.5, -5.3), dark, Vector3.ONE, bear)            # eyes
		_sphere(3.0, Vector3(side * 7.5, 10.0, -2.0), fur, Vector3(0.8, 1.5, 0.8), bear)   # arms
		_sphere(3.5, Vector3(side * 4.5, 2.5, -6.0), fur, Vector3(1.0, 0.8, 1.5), bear)    # legs
		_sphere(2.0, Vector3(side * 4.5, 2.6, -10.5), light, Vector3(1.0, 1.0, 0.3), bear) # paw pads
	# A bow tie
	var bow := _mat(Color(0.9, 0.15, 0.2), 0.5)
	_sphere(1.6, Vector3(-1.5, 14.6, -4.6), bow, Vector3(1.3, 0.9, 0.5), bear)
	_sphere(1.6, Vector3(1.5, 14.6, -4.6), bow, Vector3(1.3, 0.9, 0.5), bear)


func _build_toys() -> void:
	var tr := track.get_aabb_xz()
	var letters := "ABCRACEMAYHEM123"
	var block_cols := [Color(0.95, 0.25, 0.25), Color(0.25, 0.55, 0.95), Color(0.98, 0.8, 0.15), Color(0.3, 0.8, 0.35), Color(0.75, 0.4, 0.9)]
	var placed := 0
	var tries := 0
	while placed < 22 and tries < 600:
		tries += 1
		var p := Vector3(
			_rng.randf_range(room_rect.position.x + 8.0, room_rect.end.x - 40.0),
			0.0,
			_rng.randf_range(room_rect.position.y + 8.0, room_rect.end.y - 8.0))
		var size := _rng.randf_range(2.6, 4.0)
		if not _clear_of_track(p, size):
			continue
		var stack := 1 if _rng.randf() < 0.7 else 2
		for k in stack:
			var col: Color = block_cols[_rng.randi() % block_cols.size()]
			var blk := _box(Vector3(size, size, size), p + Vector3(0, size * 0.5 + k * size, 0), _mat(col, 0.45))
			blk.rotation.y = _rng.randf_range(0.0, TAU)
			for face in 4:
				var lbl := Label3D.new()
				lbl.text = letters[_rng.randi() % letters.length()]
				lbl.font_size = 128
				lbl.pixel_size = size * 0.0045
				lbl.outline_size = 0
				lbl.modulate = Color.WHITE
				var ang := face * PI * 0.5
				lbl.position = Vector3(sin(ang), 0.0, cos(ang)) * (size * 0.5 + 0.02)
				lbl.rotation.y = ang
				blk.add_child(lbl)
		placed += 1

	# A big striped beach ball
	var ball_pos := Vector3(tr.get_center().x + 6.0, 6.0, tr.get_center().y + 10.0)
	for i in 40:
		if _clear_of_track(ball_pos, 6.0):
			break
		ball_pos = Vector3(_rng.randf_range(tr.position.x, tr.end.x), 6.0, _rng.randf_range(tr.position.y, tr.end.y))
	var ball := Node3D.new()
	ball.position = ball_pos
	ball.rotation = Vector3(0.4, 0.3, 0.2)
	add_child(ball)
	var ball_cols := [Color(0.95, 0.2, 0.2), Color.WHITE, Color(0.2, 0.5, 0.95), Color.WHITE, Color(0.98, 0.85, 0.15), Color.WHITE]
	for i in ball_cols.size():
		var wedge := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 6.0
		sm.height = 12.0
		wedge.mesh = sm
		wedge.material_override = _mat(ball_cols[i], 0.3)
		wedge.scale = Vector3(0.18, 1.0, 1.0)
		wedge.rotation.y = i * PI / ball_cols.size()
		ball.add_child(wedge)
	_sphere(5.9, Vector3.ZERO, _mat(Color.WHITE, 0.3), Vector3.ONE, ball)

	# Crayons lying on the floor
	var crayon_cols := [Color(0.9, 0.15, 0.15), Color(0.15, 0.45, 0.9), Color(0.2, 0.75, 0.3), Color(0.95, 0.75, 0.1), Color(0.6, 0.3, 0.85)]
	var c_placed := 0
	tries = 0
	while c_placed < 9 and tries < 400:
		tries += 1
		var p := Vector3(_rng.randf_range(tr.position.x - 20.0, tr.end.x + 20.0), 0.55, _rng.randf_range(tr.position.y - 20.0, tr.end.y + 20.0))
		if not _clear_of_track(p, 5.0) or not room_rect.grow(-6.0).has_point(Vector2(p.x, p.z)):
			continue
		var crayon := Node3D.new()
		crayon.position = p
		crayon.rotation.y = _rng.randf_range(0.0, TAU)
		add_child(crayon)
		var col: Color = crayon_cols[c_placed % crayon_cols.size()]
		var body := _cylinder(0.55, 8.0, Vector3.ZERO, _mat(col, 0.7), crayon)
		body.rotation.z = PI * 0.5
		var tip := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 0.55
		cone.height = 1.4
		tip.mesh = cone
		tip.material_override = _mat(col, 0.7)
		tip.position = Vector3(4.7, 0, 0)
		tip.rotation.z = -PI * 0.5
		crayon.add_child(tip)
		var wrap := _cylinder(0.58, 5.0, Vector3(-0.5, 0, 0), _mat(col.lightened(0.5), 0.9), crayon)
		wrap.rotation.z = PI * 0.5
		c_placed += 1


func _build_poster() -> void:
	var r := room_rect
	var poster := Node3D.new()
	poster.name = "Poster"
	add_child(poster)
	poster.position = Vector3(r.position.x + 0.3, 38.0, r.position.y + r.size.y * 0.62)
	poster.rotation.y = PI * 0.5
	_box(Vector3(34.0, 24.0, 0.4), Vector3.ZERO, _mat(Color(1.0, 0.97, 0.85), 0.8), false, poster, 0.0)
	_box(Vector3(36.0, 26.0, 0.2), Vector3(0, 0, -0.15), _mat(Color(0.95, 0.3, 0.3), 0.6), false, poster, 0.0)
	# A cartoon car drawing
	var red := _mat(Color(0.9, 0.15, 0.12), 0.5)
	_box(Vector3(16.0, 4.0, 0.3), Vector3(0, -3.0, 0.35), red, false, poster)
	_box(Vector3(8.0, 3.5, 0.3), Vector3(-1.0, 0.5, 0.35), red, false, poster)
	_box(Vector3(6.0, 2.4, 0.2), Vector3(-1.0, 0.6, 0.5), _mat(Color(0.5, 0.8, 1.0), 0.2), false, poster)
	for x: float in [-5.0, 5.0]:
		var wheel := _cylinder(2.0, 0.4, Vector3(x, -5.2, 0.5), _mat(Color(0.1, 0.1, 0.1), 0.6), poster)
		wheel.rotation.x = PI * 0.5
		var hub := _cylinder(0.9, 0.5, Vector3(x, -5.2, 0.55), _mat(Color(0.9, 0.9, 0.9), 0.3), poster)
		hub.rotation.x = PI * 0.5
	for i in 3:
		_box(Vector3(3.0 - i * 0.6, 0.5, 0.2), Vector3(-11.0 - i * 0.4, -2.0 + i * 1.3, 0.4), _mat(Color(0.3, 0.3, 0.3), 0.8), false, poster)
	var title := Label3D.new()
	title.text = "RACE DAY!"
	title.font_size = 200
	title.pixel_size = 0.03
	title.outline_size = 30
	title.modulate = Color(1.0, 0.55, 0.1)
	title.outline_modulate = Color(0.25, 0.1, 0.3)
	title.position = Vector3(0, 7.5, 0.4)
	poster.add_child(title)


func _build_shelf() -> void:
	# A shelf above the bed holding the Grand Prix trophies you've won.
	var r := room_rect
	var shelf := Node3D.new()
	shelf.name = "TrophyShelf"
	add_child(shelf)
	shelf.position = Vector3(r.end.x - 3.5, 36.0, r.position.y + 72.0)
	shelf.rotation.y = -PI * 0.5
	_box(Vector3(32.0, 0.8, 6.0), Vector3.ZERO, _mat(Color(0.85, 0.6, 0.35), 0.6), true, shelf)
	var title := _label("TROPHIES", Vector3(0, 12.5, 0.3), 96, 0.03, Color(1.0, 0.85, 0.3), shelf, 16)
	title.name = "ShelfTitle"
	for d in 3:
		var x := (d - 1) * 10.0
		if Game.trophies.has(d):
			var cup := Trophy.make(int(Game.trophies[d]), Game.DIFFICULTY_NAMES[d])
			cup.scale = Vector3.ONE * 1.1
			cup.position = Vector3(x, 0.4, 0)
			shelf.add_child(cup)
		else:
			_box(Vector3(5.0, 6.0, 0.4), Vector3(x, 3.4, 0), _mat(Color(1, 1, 1, 1), 0.9), true, shelf)
			_label("?", Vector3(x, 4.2, 0.25), 128, 0.03, Color(0.6, 0.6, 0.7), shelf, 0)
			_label("%s Cup" % Game.DIFFICULTY_NAMES[d], Vector3(x, 1.4, 0.25), 48, 0.025, Color(0.4, 0.4, 0.5), shelf, 0)
