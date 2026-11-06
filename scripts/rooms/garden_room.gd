class_name GardenRoom
extends Room
## Backyard Blast's garden: an outdoor lawn under a big blue sky, with the
## back of the house, a picket fence, a big tree with a swing, flower beds,
## sunflowers, a garden gnome, mushrooms, a pond (right under the big jump!)
## with lily pads and a frog, and butterflies fluttering about.

const FLOWER_COLORS := [Color(0.95, 0.25, 0.35), Color(1.0, 0.85, 0.2), Color(0.65, 0.4, 0.95), Color(1.0, 0.55, 0.15), Color(0.95, 0.5, 0.75), Color(0.3, 0.6, 1.0)]


func _configure() -> void:
	outdoor = true
	background_color = Color(0.55, 0.78, 1.0)
	ambient_color = Color(0.85, 0.92, 1.0)
	ambient_energy = 0.45
	sun_color = Color(1.0, 0.96, 0.85)
	sun_energy = 1.15
	sun_rotation = Vector3(-50.0, -30.0, 0.0)
	lamp_energy = 0.0
	fog_color = Color(0.75, 0.86, 1.0)
	floor_tile_size = 30.0
	floor_roughness = 0.95
	saturation = 1.2


## Freshly mowed lawn: light and dark stripes with little flecks.
func _floor_image() -> Image:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for x in 128:
		for y in 128:
			var c := Color(0.36, 0.66, 0.26) if (x / 64) % 2 == 0 else Color(0.3, 0.58, 0.22)
			c = c * rng.randf_range(0.9, 1.08)
			if rng.randf() < 0.02:
				c = Color(0.5, 0.78, 0.35)
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


func _build_props() -> void:
	_far_lawn()
	_house()
	_fence()
	_tree_and_swing()
	_pond()
	_flower_beds()
	_sunflowers()
	_gnome()
	_mushrooms()
	_bushes()
	_watering_can()
	_stepping_stones()
	_butterflies()
	_clouds()


## More grass beyond the fence so the world doesn't end at the edge.
func _far_lawn() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = room_rect.size + Vector2(900, 900)
	mi.mesh = pm
	mi.material_override = _mat(Color(0.32, 0.58, 0.24), 1.0)
	mi.position = center() + Vector3(0, -0.05, 0)
	add_child(mi)


## The back of the house along one side, with a door and windows.
func _house() -> void:
	var r := room_rect
	var z := r.position.y - 2.0
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for x in 64:
		for y in 64:
			var row := y / 8
			var bx := (x + (4 if row % 2 == 0 else 0)) % 16
			var c := Color(0.78, 0.42, 0.32) * (0.92 + 0.08 * sin(float(row * 7 + x / 16)))
			if y % 8 == 0 or bx == 0:
				c = Color(0.88, 0.85, 0.8)
			c.a = 1.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var brick := StandardMaterial3D.new()
	brick.albedo_texture = ImageTexture.create_from_image(img)
	brick.uv1_triplanar = true
	brick.uv1_world_triplanar = true
	brick.uv1_scale = Vector3.ONE / 10.0
	brick.roughness = 0.9
	_box(Vector3(r.size.x + 80.0, 90.0, 4.0), Vector3(r.get_center().x, 45.0, z - 2.0), brick, false, null, 0.0)
	# Back door with steps
	var dx := r.position.x + r.size.x * 0.35
	_box(Vector3(20.0, 44.0, 1.0), Vector3(dx, 24.0, z), _mat(Color(0.2, 0.45, 0.75), 0.5))
	_sphere(1.0, Vector3(dx + 7.0, 22.0, z + 0.8), _shiny(Color(0.9, 0.75, 0.3)))
	for i in 2:
		_box(Vector3(28.0 - i * 4.0, 2.0, 8.0 - i * 3.0), Vector3(dx, 1.0 + i * 2.0, z + 4.0 - i * 1.5), _mat(Color(0.7, 0.7, 0.72), 0.9))
	# Windows with flower boxes
	for k in 2:
		var wx := r.position.x + r.size.x * (0.62 + k * 0.2)
		_box(Vector3(26.0, 22.0, 0.6), Vector3(wx, 48.0, z), _glow(Color(0.65, 0.85, 1.0), 0.4), false, null, 0.0)
		_box(Vector3(28.0, 2.0, 1.4), Vector3(wx, 59.5, z + 0.4), _mat(Color.WHITE), false)
		_box(Vector3(28.0, 4.0, 4.0), Vector3(wx, 35.5, z + 2.0), _mat(Color(0.55, 0.32, 0.18)), false)
		for f in 6:
			_flower(Vector3(wx - 11.0 + f * 4.4, 37.5, z + 2.0), 0.6, FLOWER_COLORS[(f + k) % FLOWER_COLORS.size()])
	# A drainpipe
	_cylinder(1.0, 90.0, Vector3(r.end.x - 10.0, 45.0, z + 1.5), _mat(Color(0.85, 0.85, 0.85), 0.5))


## White picket fence around the other three sides.
func _fence() -> void:
	var r := room_rect
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = MeshKit.rounded_box(Vector3(2.0, 14.0, 0.7), 0.3, 2)
	var xf: Array[Transform3D] = []
	var gap := 3.2
	var edges := [
		[Vector3(r.position.x, 0, r.end.y), Vector3(r.end.x, 0, r.end.y)],
		[Vector3(r.position.x, 0, r.position.y), Vector3(r.position.x, 0, r.end.y)],
		[Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y)],
	]
	for e in edges:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var n := int(a.distance_to(b) / gap)
		var dir := (b - a).normalized()
		var fb := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
		for i in n + 1:
			var p := a + dir * i * gap
			xf.append(Transform3D(fb, p + Vector3(0, 7.0, 0)))
		for h: float in [4.0, 10.5]:
			var rail := _box(Vector3(a.distance_to(b), 1.2, 0.5), (a + b) * 0.5 + Vector3(0, h, 0), _mat(Color(0.96, 0.96, 0.94), 0.6), true, null, 0.0)
			rail.basis = fb
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(Color(0.97, 0.97, 0.95), 0.6)
	add_child(mmi)


func _tree_and_swing() -> void:
	var r := room_rect
	var base := Vector3(r.end.x - 28.0, 0, r.end.y - 28.0)
	if not _clear_of_track(base, 10.0):
		base = Vector3(r.position.x + 28.0, 0, r.end.y - 28.0)
	var bark := _mat(Color(0.45, 0.3, 0.18), 0.95)
	_cylinder(5.0, 60.0, base + Vector3(0, 30.0, 0), bark, null, 3.5)
	var branch := _cylinder(1.8, 30.0, base + Vector3(-12.0, 48.0, 0), bark)
	branch.rotation.z = PI * 0.5
	var leaves := [Color(0.25, 0.55, 0.2), Color(0.3, 0.62, 0.22), Color(0.22, 0.5, 0.18)]
	for i in 9:
		var a := i * TAU / 9.0
		_sphere(_rng.randf_range(12.0, 17.0), base + Vector3(cos(a) * 14.0 - 6.0, 66.0 + sin(a * 2.0) * 6.0, sin(a) * 12.0), _mat(leaves[i % 3], 0.9))
	_sphere(18.0, base + Vector3(-6.0, 76.0, 0), _mat(leaves[0], 0.9))
	# A swing hanging from the branch, gently swinging.
	var pivot := Node3D.new()
	pivot.position = base + Vector3(-18.0, 47.0, 0)
	add_child(pivot)
	var rope := _mat(Color(0.85, 0.75, 0.55), 0.9)
	for side: float in [-1.0, 1.0]:
		_cylinder(0.25, 34.0, Vector3(0, -17.0, side * 4.0), rope, pivot)
	_box(Vector3(5.0, 0.8, 10.0), Vector3(0, -34.0, 0), _mat(Color(0.8, 0.2, 0.2), 0.5), true, pivot)
	animate(func(t: float, _d: float): pivot.rotation.z = sin(t * 1.1) * 0.22)


## A pond right under the big jump, so missing it means a splash!
func _pond() -> void:
	if track.gaps.is_empty():
		return
	var g: Array = track.gaps[0]
	var a := track.sample(g[0]).origin
	var b := track.sample(g[1]).origin
	var mid := Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5)
	var along := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var pond := Node3D.new()
	pond.name = "Pond"
	pond.position = mid
	pond.basis = Basis(along.cross(Vector3.UP), Vector3.UP, -along)
	add_child(pond)
	var rim := _cylinder(1.0, 0.6, Vector3(0, 0.3, 0), _mat(Color(0.55, 0.52, 0.48), 0.9), pond)
	rim.scale = Vector3(14.0, 1.0, 22.0)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.2, 0.5, 0.75)
	water.roughness = 0.05
	water.metallic = 0.3
	water.metallic_specular = 1.0
	var surface := _cylinder(1.0, 0.2, Vector3(0, 0.65, 0), water, pond)
	surface.scale = Vector3(12.5, 1.0, 20.5)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Ripples
	animate(func(t: float, _d: float): water.albedo_color = Color(0.2, 0.5 + sin(t * 1.5) * 0.03, 0.75))
	# Lily pads and a frog
	var pad := _mat(Color(0.3, 0.65, 0.25), 0.6)
	for i in 6:
		var p := Vector3(_rng.randf_range(-8.0, 8.0), 0.8, _rng.randf_range(-15.0, 15.0))
		var lp := _cylinder(2.0, 0.15, p, pad, pond)
		lp.name = "LilyPad%d" % i
		if i % 2 == 0:
			_flower(p + Vector3(0.6, 0.1, 0.3), 0.5, Color(1.0, 0.75, 0.85), pond, 0.4)
	var frog := Node3D.new()
	frog.position = Vector3(3.0, 1.0, -6.0)
	pond.add_child(frog)
	_cylinder(2.2, 0.15, Vector3(0, -0.15, 0), pad, frog)
	var skin := _mat(Color(0.35, 0.75, 0.25), 0.4)
	_sphere(1.4, Vector3(0, 1.0, 0), skin, Vector3(1.0, 0.75, 1.1), frog)
	for side: float in [-1.0, 1.0]:
		_sphere(0.5, Vector3(side * 0.6, 1.9, -0.6), skin, Vector3.ONE, frog)
		_sphere(0.25, Vector3(side * 0.6, 2.05, -0.95), _mat(Color(0.05, 0.05, 0.05), 0.2), Vector3.ONE, frog)
	animate(func(t: float, _d: float):
		var hop := maxf(0.0, sin(t * 0.9))
		frog.position.y = 1.0 + pow(hop, 8.0) * 2.5)


func _flower(pos: Vector3, s: float, petal_color: Color, parent: Node3D = null, stem := 1.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * s
	(parent if parent else self).add_child(root)
	if stem > 0.5:
		_cylinder(0.25, 6.0 * stem, Vector3(0, 3.0 * stem, 0), _mat(Color(0.25, 0.6, 0.2)), root)
	var top := Vector3(0, 6.0 * stem, 0)
	var petal := _mat(petal_color, 0.6)
	for k in 5:
		var a := k * TAU / 5.0
		_sphere(1.0, top + Vector3(cos(a) * 1.1, 0, sin(a) * 1.1), petal, Vector3(1.0, 0.35, 1.0), root)
	_sphere(0.7, top + Vector3(0, 0.25, 0), _mat(Color(1.0, 0.85, 0.2), 0.5), Vector3(1.0, 0.6, 1.0), root)


func _flower_beds() -> void:
	var r := room_rect
	var soil := _mat(Color(0.4, 0.26, 0.15), 1.0)
	# A bed along each fence side, broken up wherever the track comes close.
	var lines := [
		[Vector3(r.position.x + 8.0, 0, r.end.y - 6.0), Vector3(1, 0, 0), r.size.x - 16.0],
		[Vector3(r.position.x + 6.0, 0, r.position.y + 10.0), Vector3(0, 0, 1), r.size.y - 20.0],
		[Vector3(r.end.x - 6.0, 0, r.position.y + 10.0), Vector3(0, 0, 1), r.size.y - 20.0],
	]
	for l in lines:
		var start: Vector3 = l[0]
		var dir: Vector3 = l[1]
		var length: float = l[2]
		var d := 0.0
		while d < length:
			var p := start + dir * d
			if _clear_of_track(p, 4.0):
				var bed := _box(Vector3(6.0, 0.6, 6.0), p + Vector3(0, 0.3, 0), soil, false, null, 0.3)
				bed.name = "Bed"
				for k in 2:
					var fp := p + Vector3(_rng.randf_range(-1.8, 1.8), 0.4, _rng.randf_range(-1.8, 1.8))
					_flower(fp, _rng.randf_range(0.7, 1.1), FLOWER_COLORS[_rng.randi() % FLOWER_COLORS.size()])
			d += 6.5


func _sunflowers() -> void:
	for p in _free_spots(5, 4.0, _inner_area(14.0)):
		var root := Node3D.new()
		root.position = p
		root.rotation.y = _rng.randf() * TAU
		add_child(root)
		var h := _rng.randf_range(22.0, 30.0)
		_cylinder(0.6, h, Vector3(0, h * 0.5, 0), _mat(Color(0.3, 0.6, 0.2)), root)
		for side: float in [-1.0, 1.0]:
			var leaf := _sphere(2.0, Vector3(side * 2.0, h * 0.45, 0), _mat(Color(0.3, 0.62, 0.22)), Vector3(1.6, 0.25, 0.8), root)
			leaf.rotation.z = side * 0.4
		var head := Node3D.new()
		head.position = Vector3(0, h, 0.5)
		head.rotation.x = 0.35
		root.add_child(head)
		for k in 14:
			var a := k * TAU / 14.0
			var pt := _sphere(1.3, Vector3(cos(a) * 3.6, sin(a) * 3.6, 0), _mat(Color(1.0, 0.82, 0.1), 0.6), Vector3(0.7, 1.6, 0.3), head)
			pt.rotation.z = a - PI * 0.5
		_upright(_cylinder(2.8, 0.8, Vector3.ZERO, _mat(Color(0.4, 0.25, 0.1), 0.9), head))
		var ph := _rng.randf() * TAU
		animate(func(t: float, _d: float): root.rotation.z = sin(t * 0.7 + ph) * 0.03)


func _gnome() -> void:
	var spots := _free_spots(1, 5.0, _inner_area(12.0))
	if spots.is_empty():
		return
	var g := _node("Gnome", spots[0], _rng.randf() * TAU)
	_cylinder(2.4, 6.0, Vector3(0, 3.0, 0), _mat(Color(0.2, 0.4, 0.85), 0.5), g, 1.8)
	_sphere(1.8, Vector3(0, 7.2, 0), _mat(Color(1.0, 0.82, 0.7), 0.6), Vector3.ONE, g)
	_sphere(1.9, Vector3(0, 5.8, 0.9), _mat(Color(0.97, 0.97, 0.97), 0.9), Vector3(1.0, 1.3, 0.7), g)
	_sphere(0.5, Vector3(0, 7.2, 1.7), _mat(Color(1.0, 0.6, 0.55), 0.5), Vector3.ONE, g)
	_cylinder(2.0, 5.0, Vector3(0, 10.5, 0), _mat(Color(0.9, 0.15, 0.15), 0.5), g, 0.05)
	for side: float in [-1.0, 1.0]:
		_sphere(0.25, Vector3(side * 0.7, 7.8, 1.55), _mat(Color(0.05, 0.05, 0.1), 0.2), Vector3.ONE, g)


func _mushrooms() -> void:
	for p in _free_spots(6, 3.0, _inner_area(10.0)):
		var s := _rng.randf_range(0.7, 1.4)
		var m := _node("Mushroom", p)
		m.scale = Vector3.ONE * s
		_cylinder(0.9, 3.0, Vector3(0, 1.5, 0), _mat(Color(0.97, 0.94, 0.88), 0.8), m)
		var cap := _sphere(2.6, Vector3(0, 3.0, 0), _mat(Color(0.9, 0.15, 0.15), 0.4), Vector3(1.0, 0.55, 1.0), m)
		cap.name = "Cap"
		for k in 5:
			var a := k * TAU / 5.0
			_sphere(0.35, Vector3(cos(a) * 1.6, 3.9, sin(a) * 1.6), _mat(Color.WHITE, 0.6), Vector3(1, 0.4, 1), m)


func _bushes() -> void:
	for p in _free_spots(8, 6.0, _inner_area(8.0)):
		for k in 4:
			_sphere(_rng.randf_range(3.0, 4.5), p + Vector3(_rng.randf_range(-2.5, 2.5), 3.0 + k * 0.6, _rng.randf_range(-2.5, 2.5)), _mat(Color(0.2, 0.5 + _rng.randf() * 0.15, 0.18), 0.95))


func _watering_can() -> void:
	var spots := _free_spots(1, 5.0, _inner_area(12.0))
	if spots.is_empty():
		return
	var w := _node("WateringCan", spots[0], _rng.randf() * TAU)
	var green := _shiny(Color(0.2, 0.7, 0.45))
	_cylinder(3.0, 6.0, Vector3(0, 3.0, 0), green, w)
	var spout := _cylinder(0.5, 7.0, Vector3(4.5, 4.5, 0), green, w, 0.3)
	spout.rotation.z = -0.9
	var handle := _torus(2.2, 2.7, Vector3(-0.5, 6.0, 0), green, w)
	handle.rotation.x = PI * 0.5


func _stepping_stones() -> void:
	var r := room_rect
	var from := Vector3(r.position.x + r.size.x * 0.35, 0, r.position.y + 8.0)
	for i in 10:
		var p := from + Vector3(_rng.randf_range(-2.0, 2.0), 0.15, i * 7.0)
		if not _clear_of_track(p, 2.5):
			continue
		var stone := _sphere(2.6, p, _mat(Color(0.62, 0.6, 0.58), 0.9), Vector3(1.0, 0.12, 0.8))
		stone.rotation.y = _rng.randf() * TAU


func _butterflies() -> void:
	var area := _inner_area(10.0)
	for i in 7:
		var b := Node3D.new()
		add_child(b)
		var col: Color = FLOWER_COLORS[i % FLOWER_COLORS.size()]
		var wings: Array[Node3D] = []
		for side: float in [-1.0, 1.0]:
			var hinge := Node3D.new()
			b.add_child(hinge)
			var w := _sphere(0.9, Vector3(side * 0.9, 0, 0), _mat(col, 0.5), Vector3(1.0, 0.08, 0.8), hinge)
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			wings.append(hinge)
		_sphere(0.2, Vector3.ZERO, _mat(Color(0.1, 0.1, 0.1)), Vector3(1, 1, 3), b)
		var home := Vector3(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(6.0, 18.0), _rng.randf_range(area.position.y, area.end.y))
		var ph := _rng.randf() * TAU
		var rad := _rng.randf_range(8.0, 16.0)
		animate(func(t: float, _d: float):
			var tt := t * 0.35 + ph
			var p := home + Vector3(sin(tt) * rad, sin(tt * 2.3) * 2.0, sin(tt * 0.7) * cos(tt) * rad)
			var ahead := home + Vector3(sin(tt + 0.05) * rad, 0, sin((tt + 0.05) * 0.7) * cos(tt + 0.05) * rad)
			b.position = p
			if p.distance_to(ahead) > 0.01:
				b.look_at(Vector3(ahead.x, p.y, ahead.z), Vector3.UP)
			var flap := sin(t * 18.0 + ph) * 0.9
			wings[0].rotation.z = -flap
			wings[1].rotation.z = flap)


func _clouds() -> void:
	var c := center()
	var white := _mat(Color(1, 1, 1), 1.0)
	for i in 8:
		var a := i * TAU / 8.0 + _rng.randf() * 0.4
		var p := c + Vector3(cos(a) * 320.0, _rng.randf_range(110.0, 170.0), sin(a) * 320.0)
		for k in 4:
			var puff := _sphere(_rng.randf_range(14.0, 22.0), p + Vector3(k * 16.0 - 24.0, _rng.randf_range(-4.0, 6.0), _rng.randf_range(-6.0, 6.0)), white, Vector3(1.0, 0.6, 0.8))
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
