class_name BeachRoom
extends GardenRoom
## Sandy Shores Splash, the summer track's room: a sunny beach. Warm sand,
## the sea rolling in along one side, striped umbrellas and towels, sand
## castles with flags, palm trees, scuttling crabs, starfish, a bouncing
## beach ball and seagulls overhead.

const STRIPES := [Color(1.0, 0.3, 0.3), Color(0.2, 0.6, 1.0), Color(1.0, 0.8, 0.15), Color(0.3, 0.8, 0.45), Color(1.0, 0.5, 0.75)]

var _sea_z := 0.0       # where the water starts (the far side of the room)


func _configure() -> void:
	super._configure()
	background_color = Color(0.55, 0.8, 1.0)
	sky_top = Color(0.2, 0.55, 1.0)
	sky_horizon = Color(0.75, 0.92, 1.0)
	sky_ground = Color(0.2, 0.55, 0.85)        # the sea all the way out
	ambient_color = Color(1.0, 0.95, 0.85)
	ambient_energy = 0.3
	sun_color = Color(1.0, 0.95, 0.8)
	sun_energy = 0.85
	sun_rotation = Vector3(-60.0, -25.0, 0.0)
	fog_color = Color(0.8, 0.9, 1.0)
	floor_roughness = 0.95
	saturation = 1.2


## Warm sand with ripples and little shells.
func _floor_image() -> Image:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for x in 128:
		for y in 128:
			var ripple := 0.035 * sin(y * 0.45 + sin(x * 0.09) * 2.5)
			var c := Color(0.88, 0.74, 0.5) * (0.97 + ripple + rng.randf_range(-0.03, 0.03))
			c.a = 1.0
			img.set_pixel(x, y, c)
	for i in 25:   # shells and pebbles
		var p := Vector2i(rng.randi() % 128, rng.randi() % 128)
		var col: Color = [Color(1.0, 0.95, 0.9), Color(0.95, 0.7, 0.65), Color(0.75, 0.68, 0.6)][rng.randi() % 3]
		img.set_pixel(p.x, p.y, col)
		img.set_pixel((p.x + 1) % 128, p.y, col)
	return img


func _build_props() -> void:
	_sea_z = room_rect.position.y - 4.0
	_far_sand()
	_sea()
	_umbrellas()
	_sand_castles()
	_palms()
	_crabs()
	_starfish()
	_beach_ball()
	_seagulls()
	_clouds()


func _far_sand() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(room_rect.size.x + 900, room_rect.size.y + 450)
	mi.mesh = pm
	mi.material_override = _mat(Color(0.86, 0.73, 0.5), 1.0)
	mi.position = Vector3(center().x, -0.05, room_rect.end.y + 4.0 - pm.size.y * 0.5 + 200.0)
	add_child(mi)


## The sea along the far side, with waves that roll up the sand and back.
func _sea() -> void:
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.15, 0.6, 0.85, 0.92)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.08
	water.metallic_specular = 1.0
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(room_rect.size.x + 1200, 700)
	sea.mesh = pm
	sea.material_override = water
	sea.position = Vector3(center().x, 0.4, _sea_z - 350.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	# Foamy waves: white strips that slide in and out.
	var foam := _mat(Color(0.97, 0.99, 1.0), 0.6)
	var waves: Array[MeshInstance3D] = []
	for k in 3:
		var w := _box(Vector3(room_rect.size.x + 200, 0.4, 3.0), Vector3(center().x, 0.6, _sea_z - k * 14.0), foam, false, null, 0.2)
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		waves.append(w)
	var base := _sea_z
	animate(func(t: float, _d: float):
		sea.position.z = base - 350.0 + sin(t * 0.6) * 2.0
		for k in waves.size():
			var ph := fmod(t * 0.12 + k / 3.0, 1.0)
			waves[k].position.z = base - 40.0 + ph * 42.0
			waves[k].scale.z = 1.0 + ph * 1.5
			waves[k].position.y = 0.6 - ph * 0.3)


## Striped beach umbrellas with a towel underneath.
func _umbrellas() -> void:
	var pole := _mat(Color(0.95, 0.95, 0.95), 0.4)
	for p in _free_spots(5, 10.0):
		var u := _node("Umbrella", p, _rng.randf() * TAU)
		_cylinder(0.45, 18.0, Vector3(0, 9.0, 0), pole, u)
		for k in 8:
			var col: Color = STRIPES[k % 2 * 2]   # red and yellow
			if k % 2 == 1:
				col = Color(1, 1, 1)
			var seg := _cylinder(0.2, 3.5, Vector3(0, 17.5, 0), _mat(col, 0.6), u, 10.0)
			seg.rotation.y = k * TAU / 8.0
			seg.scale = Vector3(1.0, 1.0, 0.42)
		_sphere(0.8, Vector3(0, 19.4, 0), pole, Vector3.ONE, u)
		var towel_col: Color = STRIPES[_rng.randi() % STRIPES.size()]
		var towel := _box(Vector3(8.0, 0.2, 14.0), Vector3(3.0, 0.1, 2.0), _mat(towel_col, 0.9), false, u, 0.0)
		for s in 3:
			_box(Vector3(8.05, 0.22, 1.2), Vector3(0, 0, -5.0 + s * 5.0), _mat(Color.WHITE, 0.9), false, towel, 0.0)


## Sand castles with towers, a doorway and a little flag.
func _sand_castles() -> void:
	var sand := _mat(Color(0.93, 0.78, 0.5), 0.95)
	var dark := _mat(Color(0.55, 0.42, 0.25), 0.95)
	for p in _free_spots(4, 9.0, _inner_area(10.0)):
		var c := _node("SandCastle", p, _face_track_angle(p))
		_box(Vector3(10.0, 5.0, 10.0), Vector3(0, 2.5, 0), sand, true, c, 0.6)
		for x: float in [-5.0, 5.0]:
			for z: float in [-5.0, 5.0]:
				_cylinder(2.0, 8.0, Vector3(x, 4.0, z), sand, c, 1.7)
				for k in 4:   # battlements
					var a := k * TAU / 4.0
					_box(Vector3(0.9, 1.0, 0.9), Vector3(x + cos(a) * 1.4, 8.4, z + sin(a) * 1.4), sand, false, c, 0.1)
		_cylinder(2.5, 6.0, Vector3(0, 8.0, 0), sand, c, 2.0)   # keep
		_box(Vector3(2.4, 3.0, 0.4), Vector3(0, 1.5, -5.05), dark, false, c, 0.3)   # door
		_cylinder(0.12, 6.0, Vector3(0, 14.0, 0), _mat(Color(0.4, 0.3, 0.2), 0.8), c)
		var flag := _box(Vector3(2.4, 1.4, 0.1), Vector3(1.3, 16.2, 0), _mat(STRIPES[_rng.randi() % STRIPES.size()], 0.6), false, c, 0.0)
		animate(func(t: float, _d: float): flag.rotation.y = sin(t * 4.0 + p.x) * 0.35)


## Palm trees: a curvy trunk of stacked rings and big drooping leaves.
func _palms() -> void:
	var bark := _mat(Color(0.6, 0.42, 0.22), 0.9)
	var leaf := _mat(Color(0.2, 0.65, 0.25), 0.7)
	var coconut := _mat(Color(0.4, 0.26, 0.12), 0.6)
	for p in _free_spots(6, 10.0):
		var tree := _node("Palm", p, _rng.randf() * TAU)
		var lean := _rng.randf_range(0.1, 0.25)
		var top := Vector3.ZERO
		for k in 10:
			var y := k * 3.6
			var off := Vector3(sin(k * 0.12) * lean * k * 3.0, y + 1.8, 0)
			_cylinder(1.6 - k * 0.06, 3.8, off, bark, tree, 1.4 - k * 0.06)
			top = off + Vector3(0, 2.0, 0)
		for k in 7:
			var a := k * TAU / 7.0
			var frond := Node3D.new()
			frond.position = top
			frond.rotation = Vector3(0, a, 0)
			tree.add_child(frond)
			var blade := _box(Vector3(2.6, 0.3, 13.0), Vector3(0, 0, -6.0), leaf, true, frond, 0.4)
			blade.rotation.x = 0.35   # droops down
		for k in 3:
			_sphere(1.1, top + Vector3(cos(k * 2.1) * 1.4, -1.2, sin(k * 2.1) * 1.4), coconut, Vector3.ONE, tree)


## Little red crabs scuttling sideways, back and forth.
func _crabs() -> void:
	var red := _mat(Color(0.95, 0.3, 0.2), 0.5)
	var white := _mat(Color.WHITE, 0.3)
	var black := _mat(Color(0.05, 0.05, 0.05), 0.3)
	for p in _free_spots(5, 4.0):
		var crab := _node("Crab", p, _rng.randf() * TAU)
		var body := Node3D.new()
		crab.add_child(body)
		_sphere(1.5, Vector3(0, 1.3, 0), red, Vector3(1.3, 0.7, 1.0), body)
		for side: float in [-1.0, 1.0]:
			_cylinder(0.12, 1.0, Vector3(side * 0.5, 2.3, -0.6), red, body)
			_sphere(0.35, Vector3(side * 0.5, 2.9, -0.6), white, Vector3.ONE, body)
			_sphere(0.17, Vector3(side * 0.5, 2.95, -0.9), black, Vector3.ONE, body)
			_sphere(0.7, Vector3(side * 2.4, 1.6, -1.3), red, Vector3(1.0, 0.7, 1.3), body)   # claws
			for leg in 3:
				var l := _box(Vector3(1.6, 0.2, 0.2), Vector3(side * 1.8, 0.7, -0.6 + leg * 0.6), red, false, body, 0.0)
				l.rotation.z = side * 0.5
		var start := p
		var phase := _rng.randf() * TAU
		animate(func(t: float, _d: float):
			var x := sin(t * 0.7 + phase) * 6.0
			crab.position = start + crab.basis.x * x
			body.rotation.z = sin(t * 12.0) * 0.06)


func _starfish() -> void:
	for p in _free_spots(8, 2.5):
		var col: Color = [Color(1.0, 0.5, 0.3), Color(1.0, 0.75, 0.25), Color(0.95, 0.4, 0.55)][_rng.randi() % 3]
		var star := _node("Starfish", p, _rng.randf() * TAU)
		for k in 5:
			var a := k * TAU / 5.0
			var arm := _box(Vector3(0.9, 0.4, 2.4), Vector3(sin(a) * 1.1, 0.25, cos(a) * 1.1), _mat(col, 0.7), false, star, 0.3)
			arm.rotation.y = a


## A big striped beach ball bouncing on the sand.
func _beach_ball() -> void:
	var spots := _free_spots(1, 6.0, _inner_area(10.0))
	if spots.is_empty():
		return
	var ball := Node3D.new()
	ball.name = "BeachBall"
	add_child(ball)
	for k in 6:
		var seg := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 4.0
		sm.height = 8.0
		seg.mesh = sm
		seg.material_override = _mat(STRIPES[k % STRIPES.size()] if k % 2 == 0 else Color.WHITE, 0.4)
		seg.scale = Vector3(0.3 + 0.001 * k, 1.0, 1.0)
		seg.rotation.y = k * PI / 6.0
		ball.add_child(seg)
	var base := spots[0]
	animate(func(t: float, _d: float):
		var h := absf(sin(t * 2.2)) * 7.0
		ball.position = base + Vector3(0, 4.0 + h, 0)
		ball.rotation.x = t * 1.5)


## Seagulls gliding in big lazy circles.
func _seagulls() -> void:
	var white := _mat(Color(0.98, 0.98, 0.98), 0.5)
	var grey := _mat(Color(0.6, 0.62, 0.68), 0.5)
	var beak := _mat(Color(1.0, 0.75, 0.15), 0.4)
	var c := center()
	for k in 4:
		var gull := Node3D.new()
		add_child(gull)
		_sphere(1.2, Vector3.ZERO, white, Vector3(0.8, 0.8, 1.6), gull)
		_box(Vector3(0.4, 0.3, 0.9), Vector3(0, 0.1, -2.1), beak, false, gull, 0.05)
		for side: float in [-1.0, 1.0]:
			var wing := _box(Vector3(4.5, 0.2, 1.6), Vector3(side * 2.6, 0.2, 0), grey, false, gull, 0.0)
			wing.name = "Wing"
		var radius := _rng.randf_range(40.0, 90.0)
		var height := _rng.randf_range(45.0, 75.0)
		var phase := _rng.randf() * TAU
		animate(func(t: float, _d: float):
			var a := phase + t * 0.25
			gull.position = c + Vector3(cos(a) * radius, height + sin(t + phase) * 3.0, sin(a) * radius - 40.0)
			gull.rotation.y = -a
			for w in gull.get_children():
				if w.name.begins_with("Wing"):
					w.rotation.z = sin(t * 3.0 + phase) * 0.3 * signf(w.position.x))
