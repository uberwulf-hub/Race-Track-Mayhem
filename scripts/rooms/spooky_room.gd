class_name SpookyRoom
extends GardenRoom
## Pumpkin Patch Panic, the Halloween track's room: the back garden at night
## under a big full moon. Glowing jack-o'-lanterns, friendly toy tombstones,
## a floating ghost, bats, spider webs, candy and a haunted (toy) house.
## Spooky, but never scary: everything smiles.

const CANDY_COLORS := [Color(1.0, 0.55, 0.1), Color(0.6, 0.25, 0.85), Color(0.3, 0.85, 0.35), Color(1.0, 0.9, 0.25)]


func _configure() -> void:
	super._configure()
	background_color = Color(0.12, 0.1, 0.25)
	sky_top = Color(0.05, 0.04, 0.16)
	sky_horizon = Color(0.35, 0.2, 0.45)      # a purple glow on the horizon
	sky_ground = Color(0.1, 0.12, 0.1)
	ambient_color = Color(0.55, 0.5, 0.85)
	ambient_energy = 0.55
	sun_color = Color(0.7, 0.75, 1.0)          # moonlight
	sun_energy = 0.55
	sun_rotation = Vector3(-40.0, 140.0, 0.0)
	fog_color = Color(0.3, 0.25, 0.45)
	floor_roughness = 0.9
	evening = true
	saturation = 1.2


## Dark night-time grass with fallen orange leaves.
func _floor_image() -> Image:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for x in 128:
		for y in 128:
			var n := 0.05 * sin(x * 0.4 + y * 0.13) * sin(y * 0.37 - x * 0.08) + rng.randf_range(-0.04, 0.04)
			var c := Color(0.16, 0.26, 0.15) * (1.0 + n)
			c.a = 1.0
			img.set_pixel(x, y, c)
	for i in 70:   # leaves
		var p := Vector2i(rng.randi() % 128, rng.randi() % 128)
		var col: Color = [Color(0.85, 0.4, 0.1), Color(0.7, 0.25, 0.08), Color(0.9, 0.65, 0.15)][rng.randi() % 3]
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if absi(dx) + absi(dy) < 2:
					img.set_pixel((p.x + dx) % 128, (p.y + dy) % 128, col)
	return img


func _build_props() -> void:
	_far_field()
	_moon()
	_house()
	_fence()
	_pumpkins()
	_tombstones()
	_ghost()
	_bats()
	_spider_webs()
	_candy()
	_lanterns()


func _far_field() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = room_rect.size + Vector2(900, 900)
	mi.mesh = pm
	mi.material_override = _mat(Color(0.1, 0.16, 0.1), 1.0)
	mi.position = center() + Vector3(0, -0.05, 0)
	add_child(mi)


## A huge glowing full moon low in the sky, with a couple of craters.
func _moon() -> void:
	var c := center()
	var pos := c + Vector3(-room_rect.size.x * 0.9, 160.0, -room_rect.size.y * 1.6)
	var moon := _sphere(38.0, pos, _glow(Color(1.0, 0.96, 0.8), 1.6))
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 3:
		var cr := _sphere(6.0 + k * 2.0, pos + Vector3(-12.0 + k * 11.0, 8.0 - k * 9.0, 33.0), _glow(Color(0.9, 0.85, 0.7), 1.2), Vector3(1, 1, 0.3))
		cr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Jack-o'-lanterns: orange pumpkins with glowing smiley faces.
func _pumpkins() -> void:
	var orange := _mat(Color(1.0, 0.5, 0.08), 0.6)
	var stem := _mat(Color(0.3, 0.45, 0.15), 0.8)
	var face := _glow(Color(1.0, 0.75, 0.2), 3.0)
	var lit: Array[MeshInstance3D] = []
	for p in _free_spots(12, 6.0):
		var s := _rng.randf_range(0.7, 1.5)
		var pk := _node("Pumpkin", p, _rng.randf_range(-0.6, 0.6) + _face_track_angle(p))
		for k in 5:   # ribbed: a ring of squashed spheres
			var a := k * TAU / 5.0
			_sphere(3.0 * s, Vector3(cos(a) * 1.3 * s, 3.0 * s, sin(a) * 1.3 * s), orange, Vector3(0.8, 0.85, 0.8), pk)
		_sphere(3.3 * s, Vector3(0, 3.0 * s, 0), orange, Vector3(1.0, 0.85, 1.0), pk)
		_cylinder(0.5 * s, 2.0 * s, Vector3(0, 6.2 * s, 0), stem, pk)
		# Face on the side looking at the track (-Z of the node).
		for side: float in [-1.0, 1.0]:
			var eye := _box(Vector3(1.1, 1.1, 0.4) * s, Vector3(side * 1.3 * s, 3.9 * s, -3.15 * s), face, false, pk, 0.05)
			eye.rotation.z = PI * 0.25
			lit.append(eye)
		var mouth := _box(Vector3(3.0, 0.7, 0.4) * s, Vector3(0, 2.2 * s, -3.0 * s), face, false, pk, 0.2)
		lit.append(mouth)
	# Flicker like candles.
	animate(func(t: float, _d: float):
		face.emission_energy_multiplier = 2.6 + 0.6 * sin(t * 11.0) * sin(t * 7.3))


## Friendly toy tombstones that say BOO and HI.
func _tombstones() -> void:
	var stone := _mat(Color(0.55, 0.55, 0.62), 0.9)
	var words := ["BOO!", "HI!", "R.I.P.\nTEDDY", "BOO!", "EEK!", "HA HA"]
	var i := 0
	for p in _free_spots(6, 5.0, _inner_area(6.0)):
		var g := _node("Tombstone", p, _face_track_angle(p) + _rng.randf_range(-0.3, 0.3))
		_box(Vector3(6.0, 8.0, 1.6), Vector3(0, 4.0, 0), stone, true, g, 0.4)
		_cylinder(3.0, 1.6, Vector3(0, 8.0, 0), stone, g).rotation.x = PI * 0.5
		_label(words[i % words.size()], Vector3(0, 5.5, -0.85), 90, 0.03, Color(0.25, 0.25, 0.3), g)
		_box(Vector3(7.0, 0.6, 3.0), Vector3(0, 0.3, -1.5), _mat(Color(0.3, 0.22, 0.12), 0.95), false, g)   # dug-up dirt
		g.rotation.z = _rng.randf_range(-0.12, 0.12)
		i += 1


## A friendly ghost that floats round the garden, bobbing and waving.
func _ghost() -> void:
	var ghost := Node3D.new()
	ghost.name = "Ghost"
	add_child(ghost)
	var sheet := StandardMaterial3D.new()
	sheet.albedo_color = Color(0.95, 0.97, 1.0, 0.85)
	sheet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sheet.emission_enabled = true
	sheet.emission = Color(0.6, 0.7, 1.0)
	sheet.emission_energy_multiplier = 0.4
	_sphere(4.5, Vector3(0, 9.0, 0), sheet, Vector3(1, 1.1, 1), ghost)
	_cylinder(4.5, 6.0, Vector3(0, 5.0, 0), sheet, ghost, 4.5)
	for k in 5:   # wavy bottom
		var a := k * TAU / 5.0
		_sphere(1.4, Vector3(cos(a) * 3.6, 2.0, sin(a) * 3.6), sheet, Vector3.ONE, ghost)
	var black := _mat(Color(0.05, 0.05, 0.08), 0.4)
	for side: float in [-1.0, 1.0]:
		_sphere(0.8, Vector3(side * 1.5, 10.0, -4.0), black, Vector3(1, 1.4, 0.6), ghost)
		var arm := _sphere(1.3, Vector3(side * 5.0, 6.5, 0), sheet, Vector3(1.6, 0.8, 0.8), ghost)
		arm.name = "Arm%d" % int(side)
	_sphere(1.0, Vector3(0, 7.6, -4.1), black, Vector3(1.2, 0.8, 0.5), ghost)   # "ooo" mouth
	var c := center()
	var rx := room_rect.size.x * 0.32
	var rz := room_rect.size.y * 0.32
	animate(func(t: float, _d: float):
		var a := t * 0.18
		ghost.position = c + Vector3(cos(a) * rx, 22.0 + sin(t * 1.6) * 3.0, sin(a) * rz)
		ghost.rotation.y = -a + PI
		ghost.rotation.z = sin(t * 1.1) * 0.15)


## Little bats flapping in circles under the moon.
func _bats() -> void:
	var black := _mat(Color(0.1, 0.06, 0.14), 0.6)
	var eye := _glow(Color(1.0, 0.9, 0.3), 2.0)
	var c := center()
	for k in 7:
		var bat := Node3D.new()
		add_child(bat)
		_sphere(1.2, Vector3.ZERO, black, Vector3(1, 1, 1.3), bat)
		for side: float in [-1.0, 1.0]:
			_sphere(0.25, Vector3(side * 0.45, 0.35, -1.1), eye, Vector3.ONE, bat)
			var wing := _box(Vector3(3.5, 0.2, 1.8), Vector3(side * 2.3, 0, 0), black, false, bat, 0.0)
			wing.name = "Wing"
		var radius := _rng.randf_range(30.0, 80.0)
		var height := _rng.randf_range(35.0, 70.0)
		var speed := _rng.randf_range(0.35, 0.7) * (1.0 if k % 2 == 0 else -1.0)
		var phase := _rng.randf() * TAU
		animate(func(t: float, _d: float):
			var a := phase + t * speed
			bat.position = c + Vector3(cos(a) * radius, height + sin(t * 2.0 + phase) * 4.0, sin(a) * radius)
			bat.rotation.y = -a + (0.0 if speed > 0.0 else PI)
			var flap := sin(t * 14.0 + phase) * 0.7
			for w in bat.get_children():
				if w.name.begins_with("Wing"):
					w.rotation.z = flap * signf(w.position.x))


## Spider webs strung between little posts, each with a smiley spider.
func _spider_webs() -> void:
	var silk := _mat(Color(0.92, 0.92, 0.95), 0.5)
	var post := _mat(Color(0.35, 0.25, 0.15), 0.9)
	for p in _free_spots(3, 8.0):
		var web := _node("Web", p, _face_track_angle(p))
		for side: float in [-1.0, 1.0]:
			_cylinder(0.6, 18.0, Vector3(side * 7.0, 9.0, 0), post, web)
		var mid := Vector3(0, 10.0, 0)
		for k in 8:   # spokes
			var a := k * TAU / 8.0
			var spoke := _box(Vector3(0.15, 7.0, 0.15), mid + Vector3(cos(a), sin(a), 0) * 3.5, silk, false, web, 0.0)
			spoke.rotation.z = a - PI * 0.5
		for ring in 3:   # rings
			var r := 2.0 + ring * 2.0
			for k in 8:
				var a := (k + 0.5) * TAU / 8.0
				var seg := _box(Vector3(r * 0.78, 0.12, 0.12), mid + Vector3(cos(a), sin(a), 0) * r * 0.93, silk, false, web, 0.0)
				seg.rotation.z = a + PI * 0.5
		var spider := Node3D.new()
		web.add_child(spider)
		_sphere(1.0, Vector3.ZERO, _mat(Color(0.1, 0.08, 0.12), 0.4), Vector3.ONE, spider)
		for side: float in [-1.0, 1.0]:
			_sphere(0.28, Vector3(side * 0.35, 0.3, -0.85), _mat(Color.WHITE, 0.3), Vector3.ONE, spider)
			for leg in 3:
				var l := _box(Vector3(1.6, 0.15, 0.15), Vector3(side * 1.2, -0.2 + leg * 0.2, -0.4 + leg * 0.4), _mat(Color(0.1, 0.08, 0.12), 0.4), false, spider, 0.0)
				l.rotation.z = side * -0.4
		animate(func(t: float, _d: float):
			spider.position = mid + Vector3(0, sin(t * 0.8 + p.x) * 3.0, -0.3))


## Wrapped sweets scattered about.
func _candy() -> void:
	for p in _free_spots(16, 2.5):
		var col: Color = CANDY_COLORS[_rng.randi() % CANDY_COLORS.size()]
		var c := _node("Candy", p, _rng.randf() * TAU)
		_sphere(1.0, Vector3(0, 0.8, 0), _shiny(col), Vector3(1.4, 0.9, 0.9), c)
		for side: float in [-1.0, 1.0]:
			_cylinder(0.1, 0.9, Vector3(side * 1.6, 0.8, 0), _shiny(col.lightened(0.3)), c, 0.6).rotation.z = side * PI * 0.5


## Paper lanterns on poles so the track glows orange and purple.
func _lanterns() -> void:
	var pole := _mat(Color(0.2, 0.15, 0.1), 0.8)
	var cols := [Color(1.0, 0.55, 0.15), Color(0.7, 0.35, 1.0)]
	var i := 0
	for p in _free_spots(6, 4.0):
		_cylinder(0.35, 14.0, p + Vector3(0, 7.0, 0), pole)
		var col: Color = cols[i % 2]
		_sphere(1.8, p + Vector3(0, 14.5, 0), _glow(col, 2.2), Vector3(1, 1.3, 1))
		var light := OmniLight3D.new()
		light.light_color = col
		light.light_energy = 1.4
		light.omni_range = 26.0
		light.position = p + Vector3(0, 14.0, 0)
		add_child(light)
		i += 1
