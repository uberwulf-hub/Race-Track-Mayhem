class_name Bedroom
extends Node3D
## A giant kid's bedroom built around the toy track: wooden floor, rug, bed,
## teddy bear, toy blocks, crayons, a beach ball, a window with sunshine...
## 1 unit is roughly 5 cm, so the room is huge compared to the cars.

const WALL_HEIGHT := 70.0

var room_rect: Rect2          # floor area (x, z)
var track: Track
var _rng := RandomNumberGenerator.new()


func build(p_track: Track) -> Bedroom:
	track = p_track
	_rng.seed = 12345
	var r := track.get_aabb_xz()
	room_rect = Rect2(r.position - Vector2(42.0, 34.0), r.size + Vector2(42.0 + 52.0, 34.0 + 40.0))
	_build_environment()
	_build_floor()
	_build_walls()
	_build_window()
	_build_bed()
	_build_dresser()
	_build_teddy()
	_build_toys()
	return self


func center() -> Vector3:
	var c := room_rect.get_center()
	return Vector3(c.x, 0.0, c.y)


## A nice high corner view that shows the whole room (used for the intro zoom).
func overview_position() -> Vector3:
	return Vector3(room_rect.position.x + 14.0, WALL_HEIGHT - 6.0, room_rect.end.y - 12.0)


# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.75, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.93, 0.85)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(sun)

	var lamp := OmniLight3D.new()
	lamp.position = center() + Vector3(0.0, WALL_HEIGHT - 8.0, 0.0)
	lamp.omni_range = 260.0
	lamp.omni_attenuation = 0.6
	lamp.light_energy = 0.25
	lamp.light_color = Color(1.0, 0.9, 0.75)
	add_child(lamp)


func _mat(color: Color, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, shadow := true, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


func _sphere(radius: float, pos: Vector3, mat: Material, scale_v := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_v
	(parent if parent else self).add_child(mi)
	return mi


func _cylinder(radius: float, height: float, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


## True if a spot on the floor is far enough from the track to put stuff there.
func _clear_of_track(p: Vector3, radius: float) -> bool:
	var min_d := Track.HALF_WIDTH + radius + 2.0
	for k in range(0, track.count, 2):
		var q := track.points[k]
		if Vector2(q.x - p.x, q.z - p.z).length() < min_d:
			return false
	return true


# ---------------------------------------------------------------------------
# Floor, walls, window
# ---------------------------------------------------------------------------

func _build_floor() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var planks := 4
	for x in 256:
		var plank := x * planks / 256
		var shade := 0.9 + 0.1 * sin(plank * 12.9898)
		for y in 256:
			var grain := 0.06 * sin(y * 0.11 + sin(x * 0.3 + plank) * 2.0) + 0.03 * sin(y * 0.53 + x * 0.07)
			var c := Color(0.62, 0.42, 0.25) * (shade + grain)
			if x % (256 / planks) < 2:
				c = Color(0.38, 0.24, 0.13)
			var seam := (y + plank * 97) % 256
			if seam < 2:
				c = Color(0.42, 0.27, 0.15)
			c.a = 1.0
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.45
	m.uv1_scale = Vector3(room_rect.size.x / 24.0, room_rect.size.y / 24.0, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Floor"
	var pm := PlaneMesh.new()
	pm.size = room_rect.size
	floor_mi.mesh = pm
	floor_mi.material_override = m
	floor_mi.position = center()
	add_child(floor_mi)

	# A big round rug under the middle of the track.
	var rug_mat := _mat(Color(0.35, 0.55, 0.95), 1.0)
	var rug := _cylinder(1.0, 0.12, Vector3.ZERO, rug_mat)
	var tr := track.get_aabb_xz()
	rug.position = Vector3(tr.get_center().x, 0.06, tr.get_center().y)
	rug.scale = Vector3(tr.size.x * 0.42, 1.0, tr.size.y * 0.42)
	var rug2 := _cylinder(1.0, 0.14, rug.position, _mat(Color(0.98, 0.85, 0.35), 1.0))
	rug2.scale = rug.scale * Vector3(0.8, 1.0, 0.8)
	var rug3 := _cylinder(1.0, 0.16, rug.position, _mat(Color(0.95, 0.45, 0.5), 1.0))
	rug3.scale = rug.scale * Vector3(0.55, 1.0, 0.55)


func _build_walls() -> void:
	var wall_mat := _mat(Color(0.62, 0.82, 0.95), 0.95)
	var trim := _mat(Color(0.98, 0.98, 0.95), 0.6)
	var r := room_rect
	var h := WALL_HEIGHT
	var c := center()
	# Walls don't cast shadows so the sun can shine in.
	_box(Vector3(r.size.x, h, 2.0), Vector3(c.x, h * 0.5, r.position.y - 1.0), wall_mat, false)
	_box(Vector3(r.size.x, h, 2.0), Vector3(c.x, h * 0.5, r.end.y + 1.0), wall_mat, false)
	_box(Vector3(2.0, h, r.size.y), Vector3(r.position.x - 1.0, h * 0.5, c.z), wall_mat, false)
	_box(Vector3(2.0, h, r.size.y), Vector3(r.end.x + 1.0, h * 0.5, c.z), wall_mat, false)
	# Skirting boards
	_box(Vector3(r.size.x, 3.0, 0.6), Vector3(c.x, 1.5, r.position.y + 0.3), trim)
	_box(Vector3(r.size.x, 3.0, 0.6), Vector3(c.x, 1.5, r.end.y - 0.3), trim)
	_box(Vector3(0.6, 3.0, r.size.y), Vector3(r.position.x + 0.3, 1.5, c.z), trim)
	_box(Vector3(0.6, 3.0, r.size.y), Vector3(r.end.x - 0.3, 1.5, c.z), trim)
	# Ceiling
	_box(Vector3(r.size.x + 4.0, 1.0, r.size.y + 4.0), Vector3(c.x, h + 0.5, c.z), _mat(Color(0.97, 0.97, 0.95)), false)
	# Painted stars on the walls
	var star_mat := _mat(Color(1.0, 0.9, 0.3), 0.5)
	for i in 14:
		var along := _rng.randf_range(0.05, 0.95)
		var y := _rng.randf_range(25.0, h - 8.0)
		var sz := _rng.randf_range(1.5, 3.0)
		var pos := Vector3(r.position.x + r.size.x * along, y, r.position.y + 0.05)
		var star := _box(Vector3(sz, sz, 0.2), pos, star_mat, false)
		star.rotation.z = PI * 0.25
	# A door on the near wall
	_box(Vector3(18.0, 42.0, 0.8), Vector3(r.end.x - 30.0, 21.0, r.end.y - 0.2), _mat(Color(0.98, 0.95, 0.9), 0.5), false)
	_sphere(1.0, Vector3(r.end.x - 37.0, 20.0, r.end.y - 1.0), _mat(Color(0.9, 0.75, 0.2), 0.2))


func _build_window() -> void:
	var r := room_rect
	var cx := r.position.x + r.size.x * 0.62
	var z := r.position.y + 0.2
	var frame_mat := _mat(Color(0.98, 0.98, 0.98), 0.5)
	var sky := StandardMaterial3D.new()
	sky.albedo_color = Color(0.6, 0.85, 1.0)
	sky.emission_enabled = true
	sky.emission = Color(0.65, 0.88, 1.0)
	sky.emission_energy_multiplier = 1.4
	_box(Vector3(44.0, 32.0, 0.3), Vector3(cx, 38.0, z + 0.2), sky, false)
	_box(Vector3(48.0, 2.0, 1.2), Vector3(cx, 54.0, z + 0.4), frame_mat, false)
	_box(Vector3(48.0, 2.0, 2.4), Vector3(cx, 22.0, z + 1.0), frame_mat, false)
	_box(Vector3(2.0, 32.0, 1.2), Vector3(cx - 23.0, 38.0, z + 0.4), frame_mat, false)
	_box(Vector3(2.0, 32.0, 1.2), Vector3(cx + 23.0, 38.0, z + 0.4), frame_mat, false)
	_box(Vector3(1.0, 32.0, 1.0), Vector3(cx, 38.0, z + 0.4), frame_mat, false)
	_box(Vector3(46.0, 1.0, 1.0), Vector3(cx, 38.0, z + 0.4), frame_mat, false)
	# A little sun and a cloud outside
	var sun_mat := StandardMaterial3D.new()
	sun_mat.albedo_color = Color(1.0, 0.9, 0.3)
	sun_mat.emission_enabled = true
	sun_mat.emission = Color(1.0, 0.85, 0.2)
	sun_mat.emission_energy_multiplier = 2.0
	var sun := _cylinder(4.0, 0.2, Vector3(cx + 12.0, 47.0, z + 0.45), sun_mat)
	sun.rotation.x = PI * 0.5
	var cloud := _mat(Color.WHITE, 1.0)
	for i in 3:
		var c := _sphere(3.0, Vector3(cx - 12.0 + i * 3.5, 44.0 + (1.0 if i == 1 else 0.0), z + 0.4), cloud, Vector3(1.0, 0.8, 0.1))
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Curtains
	var curtain := _mat(Color(0.95, 0.45, 0.55), 1.0)
	for side: float in [-1.0, 1.0]:
		var cur := _box(Vector3(9.0, 40.0, 1.5), Vector3(cx + side * 28.0, 36.0, z + 1.6), curtain, false)
		cur.rotation.y = 0.0
	var rod := _cylinder(0.6, 70.0, Vector3(cx, 57.0, z + 2.0), frame_mat)
	rod.rotation.z = PI * 0.5


# ---------------------------------------------------------------------------
# Furniture
# ---------------------------------------------------------------------------

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
