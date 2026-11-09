class_name SnowRoom
extends GardenRoom
## Frosty Backyard, the holiday track's room: the garden under fresh snow at
## dusk. Snowy lawn and fence, pine trees with twinkly lights, snowmen,
## presents, a frozen pond under the big jump, a sled and falling snow.

const LIGHT_COLORS := [Color(1.0, 0.2, 0.2), Color(0.2, 0.9, 0.3), Color(1.0, 0.8, 0.2), Color(0.3, 0.5, 1.0)]


func _configure() -> void:
	super._configure()
	background_color = Color(0.62, 0.7, 0.85)
	sky_top = Color(0.35, 0.42, 0.65)
	sky_horizon = Color(0.95, 0.75, 0.7)       # a pink winter sunset
	ambient_color = Color(0.8, 0.85, 1.0)
	ambient_energy = 0.5
	sun_color = Color(1.0, 0.82, 0.65)
	sun_energy = 0.8
	sun_rotation = Vector3(-25.0, -60.0, 0.0)
	fog_color = Color(0.85, 0.88, 0.95)
	floor_roughness = 0.75
	evening = true                             # cars switch their headlights on
	sky_ground = Color(0.85, 0.88, 0.95)       # snowy fields in the distance
	saturation = 1.1


## Fresh snow: white with a blue tint, soft drifts and sparkles.
func _floor_image() -> Image:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for x in 128:
		for y in 128:
			var drift := 0.04 * sin(x * 0.11 + sin(y * 0.07) * 2.0) + 0.03 * sin(y * 0.19)
			var c := Color(0.9, 0.93, 1.0) * (0.95 + drift + rng.randf_range(-0.02, 0.02))
			if rng.randf() < 0.012:
				c = Color(1.0, 1.0, 1.0)   # sparkle
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


func _build_props() -> void:
	_far_snow()
	_house()
	_fence()
	_frozen_pond()
	_pine_trees()
	_snowmen()
	_presents()
	_sled()
	_falling_snow()
	_clouds()


func _far_snow() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = room_rect.size + Vector2(900, 900)
	mi.mesh = pm
	mi.material_override = _mat(Color(0.86, 0.9, 0.98), 1.0)
	mi.position = center() + Vector3(0, -0.05, 0)
	add_child(mi)


## A frozen pond right under the big jump.
func _frozen_pond() -> void:
	if track.gaps.is_empty():
		return
	var g: Array = track.gaps[0]
	var a := track.sample(g[0]).origin
	var b := track.sample(g[1]).origin
	var mid := Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5)
	var along := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var pond := Node3D.new()
	pond.name = "FrozenPond"
	pond.position = mid
	pond.basis = Basis(along.cross(Vector3.UP), Vector3.UP, -along)
	add_child(pond)
	var rim := _cylinder(1.0, 0.6, Vector3(0, 0.3, 0), _mat(Color(0.95, 0.97, 1.0), 0.9), pond)
	rim.scale = Vector3(14.0, 1.0, 22.0)
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.7, 0.85, 0.98)
	ice.roughness = 0.04
	ice.metallic = 0.2
	ice.metallic_specular = 1.0
	var surface := _cylinder(1.0, 0.2, Vector3(0, 0.65, 0), ice, pond)
	surface.scale = Vector3(12.5, 1.0, 20.5)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A penguin skating on it.
	var pg := Node3D.new()
	pond.add_child(pg)
	_sphere(1.6, Vector3(0, 2.0, 0), _mat(Color(0.08, 0.08, 0.12), 0.5), Vector3(1.0, 1.4, 1.0), pg)
	_sphere(1.2, Vector3(0, 1.9, -0.6), _mat(Color.WHITE, 0.6), Vector3(0.9, 1.2, 0.6), pg)
	_sphere(0.35, Vector3(0, 3.2, -1.3), _mat(Color(1.0, 0.6, 0.1), 0.5), Vector3(1, 0.6, 1.4), pg)
	animate(func(t: float, _d: float):
		pg.position = Vector3(sin(t * 0.6) * 7.0, 0.7, cos(t * 0.6) * 14.0)
		pg.rotation.y = -t * 0.6)


## Pine trees with twinkly lights and a star on top.
func _pine_trees() -> void:
	var needles := _mat(Color(0.12, 0.38, 0.22), 0.9)
	var snow := _mat(Color(0.95, 0.97, 1.0), 0.8)
	var bulbs: Array[StandardMaterial3D] = []
	for c in LIGHT_COLORS:
		bulbs.append(_glow(c, 2.0))
	var i := 0
	for p in _free_spots(6, 12.0):
		var s := _rng.randf_range(0.8, 1.25)
		_cylinder(1.6 * s, 8.0 * s, p + Vector3(0, 4.0 * s, 0), _mat(Color(0.4, 0.26, 0.15), 0.9))
		for layer in 3:
			var y := (8.0 + layer * 8.0) * s
			var rad := (11.0 - layer * 3.0) * s
			_cylinder(rad, 11.0 * s, p + Vector3(0, y + 4.0 * s, 0), needles, null, 0.3)
			_cylinder(rad * 0.75, 1.0 * s, p + Vector3(0, y + 0.6 * s, 0), snow, null, rad * 0.55)   # snow on each layer
			for k in 8:
				var a := k * TAU / 8.0 + layer
				var lp := p + Vector3(cos(a) * rad * 0.8, y + 1.5 * s, sin(a) * rad * 0.8)
				_sphere(0.6 * s, lp, bulbs[(i + k) % bulbs.size()])
		_sphere(1.6 * s, p + Vector3(0, 36.0 * s, 0), _glow(Color(1.0, 0.9, 0.3), 3.0))   # star
		i += 1
	# Twinkle: swap the bulbs' brightness.
	animate(func(t: float, _d: float):
		for k in bulbs.size():
			bulbs[k].emission_energy_multiplier = 1.2 + 1.2 * (0.5 + 0.5 * sin(t * 3.0 + k * 1.7)))


func _snowmen() -> void:
	var snow := _mat(Color(0.97, 0.98, 1.0), 0.8)
	for p in _free_spots(4, 7.0, _inner_area(10.0)):
		var man := _node("Snowman", p, _rng.randf() * TAU)
		_sphere(5.0, Vector3(0, 4.5, 0), snow, Vector3.ONE, man)
		_sphere(3.6, Vector3(0, 11.5, 0), snow, Vector3.ONE, man)
		_sphere(2.6, Vector3(0, 16.8, 0), snow, Vector3.ONE, man)
		_cylinder(0.5, 3.0, Vector3(0, 16.8, -3.2), _mat(Color(1.0, 0.5, 0.1), 0.5), man, 0.05).rotation.x = -PI * 0.5   # carrot nose
		for side: float in [-1.0, 1.0]:
			_sphere(0.35, Vector3(side * 0.9, 17.6, -2.3), _mat(Color(0.05, 0.05, 0.05), 0.3), Vector3.ONE, man)
			var arm := _cylinder(0.3, 7.0, Vector3(side * 5.5, 12.5, 0), _mat(Color(0.4, 0.26, 0.15), 0.9), man)
			arm.rotation.z = side * 1.0
		var scarf_col: Color = LIGHT_COLORS[_rng.randi() % LIGHT_COLORS.size()]
		_torus(2.2, 3.2, Vector3(0, 14.4, 0), _mat(scarf_col, 0.7), man)
		_cylinder(2.2, 0.5, Vector3(0, 19.1, 0), _mat(Color(0.1, 0.1, 0.12), 0.5), man)   # hat brim
		_cylinder(1.6, 3.5, Vector3(0, 21.0, 0), _mat(Color(0.1, 0.1, 0.12), 0.5), man)


func _presents() -> void:
	var ribbon := _shiny(Color(1.0, 0.85, 0.2))
	for p in _free_spots(7, 4.0):
		var col: Color = LIGHT_COLORS[_rng.randi() % LIGHT_COLORS.size()]
		var size := _rng.randf_range(3.0, 5.5)
		var box := _box(Vector3(size, size * 0.8, size), p + Vector3(0, size * 0.4, 0), _shiny(col))
		box.rotation.y = _rng.randf() * TAU
		_box(Vector3(size + 0.1, size * 0.8 + 0.1, 0.6), Vector3.ZERO, ribbon, false, box, 0.0)
		_box(Vector3(0.6, size * 0.8 + 0.1, size + 0.1), Vector3.ZERO, ribbon, false, box, 0.0)
		_sphere(0.9, Vector3(0, size * 0.42, 0), ribbon, Vector3(1.4, 0.6, 1.4), box)


func _sled() -> void:
	var spots := _free_spots(1, 8.0, _inner_area(12.0))
	if spots.is_empty():
		return
	var sled := _node("Sled", spots[0], _rng.randf() * TAU)
	_box(Vector3(6.0, 0.8, 14.0), Vector3(0, 2.4, 0), _mat(Color(0.75, 0.25, 0.15), 0.6), true, sled)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.5, 0.5, 15.0), Vector3(side * 2.5, 0.5, 0.0), _shiny(Color(0.8, 0.8, 0.85)), true, sled)
		var curl := _torus(1.2, 1.7, Vector3(side * 2.5, 1.6, -7.4), _shiny(Color(0.8, 0.8, 0.85)), sled)
		curl.rotation.z = PI * 0.5


## Gentle snowfall over the whole yard.
func _falling_snow() -> void:
	var p := CPUParticles3D.new()
	p.amount = 150 if Game.is_mobile() else 350
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(room_rect.size.x * 0.6, 2.0, room_rect.size.y * 0.6)
	p.position = center() + Vector3(0, 90.0, 0)
	p.direction = Vector3(0.2, -1.0, 0.1)
	p.spread = 15.0
	p.gravity = Vector3(0, -4.0, 0)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 10.0
	var flake := SphereMesh.new()
	flake.radius = 0.45
	flake.height = 0.9
	flake.radial_segments = 6
	flake.rings = 3
	p.mesh = flake
	var m := _mat(Color.WHITE, 1.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
