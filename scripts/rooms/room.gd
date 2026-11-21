class_name Room
extends Node3D
## Base class for the giant rooms the toy tracks are set up in.
## 1 unit is roughly 5 cm, so the furniture is huge compared to the cars.
##
## A themed room (BedroomRoom, KitchenRoom, ...) sets its colours in
## `_configure()`, supplies floor/wall textures, and builds its furniture in
## `_build_props()`. This base class does the lighting, floor, walls,
## window and door, plus handy shape helpers.

const WALL_HEIGHT := 70.0

var room_rect: Rect2          # floor area (x, z)
var environment: Environment
var sun_light: DirectionalLight3D
var _animators: Array[Callable] = []   # little things that move (cat tails, bubbles...)
var _anim_time := 0.0
var track: Track
var _rng := RandomNumberGenerator.new()

# --- theme settings (override in _configure) ---
var background_color := Color(0.55, 0.75, 0.95)
var ambient_color := Color(1.0, 0.93, 0.85)
var ambient_energy := 0.35
var sun_color := Color(1.0, 0.95, 0.85)
var sun_energy := 0.9
var sun_rotation := Vector3(-55.0, -35.0, 0.0)
var lamp_color := Color(1.0, 0.9, 0.75)
var lamp_energy := 0.25
var fog_color := Color(0.75, 0.85, 1.0)
var floor_tile_size := 24.0           # world units per floor texture repeat
var floor_roughness := 0.45
var wall_tile_size := 12.0
var trim_color := Color(0.98, 0.98, 0.95)
var ceiling_color := Color(0.97, 0.97, 0.95)
var curtain_color := Color(0.95, 0.45, 0.55)
var door_color := Color(0.98, 0.95, 0.9)
var has_window := true
var outdoor := false                  # garden: sky instead of walls and ceiling
var sky_ground := Color(0.3, 0.55, 0.25)    # the far-away ground under an outdoor sky
var sky_top := Color(0.25, 0.5, 0.95)
var sky_horizon := Color(0.75, 0.88, 1.0)
var evening := false               # cars switch their headlights on
var window_sky := Color(0.6, 0.85, 1.0)

# Weather and time of day for this race (set before build()).
var time_of_day := 0               # 0 day, 1 sunset, 2 night
var rain := false
var exposure := 0.9                # overall brightness (night and rain turn it down)
var saturation := 1.15


## Makes the right room for a theme id (see Track.TRACKS "room").
static func create(theme: String) -> Room:
	match theme:
		"playroom":
			return PlayroomRoom.new()
		"kitchen":
			return KitchenRoom.new()
		"bathroom":
			return BathroomRoom.new()
		"living_room":
			return LivingRoom.new()
		"garden":
			return GardenRoom.new()
		"garage":
			return GarageRoom.new()
		"snowyard":
			return SnowRoom.new()
		"spooky":
			return SpookyRoom.new()
		"attic":
			return AtticRoom.new()
		"beach":
			return BeachRoom.new()
	return BedroomRoom.new()


func build(p_track: Track) -> Room:
	track = p_track
	_rng.seed = 12345
	var r := track.get_aabb_xz()
	room_rect = Rect2(r.position - Vector2(42.0, 34.0), r.size + Vector2(42.0 + 52.0, 34.0 + 40.0))
	_configure()
	_apply_weather()
	_build_environment()
	_build_floor()
	if not outdoor:
		_build_walls()
		if has_window:
			_build_window()
	_build_props()
	if rain:
		_build_rain()
	return self


## Sunset, night and rain change the room's light before it's built.
func _apply_weather() -> void:
	match time_of_day:
		1:   # sunset: warm, low, orange light
			sun_color = Color(1.0, 0.62, 0.38)
			sun_energy *= 0.8
			sun_rotation.x = -18.0
			ambient_color = ambient_color.lerp(Color(1.0, 0.75, 0.6), 0.6)
			ambient_energy *= 0.85
			sky_top = Color(0.35, 0.35, 0.7)
			sky_horizon = Color(1.0, 0.58, 0.38)
			background_color = background_color.lerp(Color(0.95, 0.6, 0.45), 0.6)
			window_sky = Color(1.0, 0.6, 0.4)
			fog_color = Color(1.0, 0.75, 0.6)
			exposure = 0.8
			evening = true
		2:   # night: blue moonlight, lamps on, headlights on
			sun_color = Color(0.55, 0.65, 1.0)
			sun_energy = 0.3
			sun_rotation.x = -50.0
			ambient_color = Color(0.45, 0.5, 0.85)
			ambient_energy = maxf(0.22, ambient_energy * 0.6)
			sky_top = Color(0.02, 0.03, 0.1)
			sky_horizon = Color(0.1, 0.12, 0.3)
			sky_ground = sky_ground.darkened(0.7)
			background_color = Color(0.05, 0.06, 0.15)
			window_sky = Color(0.08, 0.1, 0.28)
			fog_color = Color(0.2, 0.22, 0.4)
			lamp_energy = maxf(lamp_energy, 1.4)
			lamp_color = Color(1.0, 0.8, 0.5)
			exposure = 0.5
			saturation *= 0.85
			evening = true
	if rain:
		sun_energy *= 0.45
		ambient_color = ambient_color.lerp(Color(0.7, 0.72, 0.78), 0.45)
		sky_top = sky_top.lerp(Color(0.4, 0.42, 0.48), 0.7)
		sky_horizon = sky_horizon.lerp(Color(0.6, 0.62, 0.68), 0.7)
		window_sky = window_sky.lerp(Color(0.5, 0.55, 0.62), 0.6)
		background_color = background_color.lerp(Color(0.45, 0.48, 0.55), 0.5)
		saturation *= 0.85
		exposure *= 0.72
		evening = evening or time_of_day > 0


## Rain: falling outside (or running down the window indoors), a soft
## patter, and now and then a flash of lightning.
func _build_rain() -> void:
	var p := CPUParticles3D.new()
	var drop := BoxMesh.new()
	if outdoor:
		p.amount = 300 if Game.is_mobile() else 900
		p.lifetime = 1.6
		p.preprocess = 1.6
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(room_rect.size.x * 0.55, 1.0, room_rect.size.y * 0.55)
		p.position = center() + Vector3(0, 70.0, 0)
		p.direction = Vector3(0.1, -1.0, 0.05)
		p.spread = 3.0
		p.gravity = Vector3(0, -40.0, 0)
		p.initial_velocity_min = 45.0
		p.initial_velocity_max = 55.0
		drop.size = Vector3(0.3, 3.6, 0.3)
	elif has_window:
		# Little drops sliding down the window glass.
		var r := room_rect
		p.amount = 70
		p.lifetime = 4.0
		p.preprocess = 4.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(21.0, 14.0, 0.05)
		p.position = Vector3(r.position.x + r.size.x * 0.62, 38.0, r.position.y + 0.8)
		p.direction = Vector3(0, -1, 0)
		p.spread = 5.0
		p.gravity = Vector3(0, -2.0, 0)
		p.initial_velocity_min = 1.0
		p.initial_velocity_max = 3.0
		drop.size = Vector3(0.25, 0.6, 0.05)
	else:
		p.free()
		p = null
	if p:
		p.mesh = drop
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.8, 0.88, 1.0, 0.75)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p.material_override = m
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
	# The patter of rain: soft looping noise.
	var player := AudioStreamPlayer.new()
	player.stream = _rain_sound()
	player.volume_db = -20.0 if not outdoor else -14.0
	player.autoplay = true
	add_child(player)
	# Lightning: a bright flash now and then.
	var base := ambient_energy
	_lightning(base)


func _lightning(base: float) -> void:
	var timer := Timer.new()
	timer.wait_time = randf_range(8.0, 16.0)
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func():
		timer.wait_time = randf_range(10.0, 22.0)
		if environment == null:
			return
		var tw := create_tween()
		tw.tween_property(environment, "ambient_light_energy", base + 2.5, 0.05)
		tw.tween_property(environment, "ambient_light_energy", base, 0.12)
		tw.tween_property(environment, "ambient_light_energy", base + 1.8, 0.05)
		tw.tween_property(environment, "ambient_light_energy", base, 0.35)
		Sfx.play("bump", 0.4, -8.0))   # a distant rumble


## One second of soft, smoothed noise that loops: sounds like rain.
static func _rain_sound() -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	data.resize(rate * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var smooth := 0.0
	for i in rate:
		smooth = lerpf(smooth, rng.randf_range(-1.0, 1.0), 0.35)
		var v := int(clampf(smooth * 0.5, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = rate
	return w


## Registers something that moves every frame: f(time: float, delta: float).
func animate(f: Callable) -> void:
	_animators.append(f)


func _process(delta: float) -> void:
	_anim_time += delta
	for f in _animators:
		f.call(_anim_time, delta)


func center() -> Vector3:
	var c := room_rect.get_center()
	return Vector3(c.x, 0.0, c.y)


## A nice high corner view that shows the whole room (used for the intro zoom).
func overview_position() -> Vector3:
	return Vector3(room_rect.position.x + 14.0, WALL_HEIGHT - 6.0, room_rect.end.y - 12.0)


# ---------------------------------------------------------------------------
# Things a theme overrides
# ---------------------------------------------------------------------------

func _configure() -> void:
	pass


func _floor_image() -> Image:
	return wood_image(Color(0.62, 0.42, 0.25))


func _wall_image() -> Image:
	return stripes_image(Color(0.62, 0.8, 0.95), Color(0.68, 0.85, 0.98), Color(1.0, 0.95, 0.6))


func _build_props() -> void:
	pass


# ---------------------------------------------------------------------------
# Lighting, floor, walls, window
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background_color
	if outdoor:
		# A real sky that also lights the scene.
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = sky_top
		sky_mat.sky_horizon_color = sky_horizon
		sky_mat.ground_horizon_color = sky_horizon
		sky_mat.ground_bottom_color = sky_ground
		sky_mat.sun_angle_max = 20.0
		var sky := Sky.new()
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = exposure
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = 0.0005
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = saturation
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0   # shorter = sharper, less jagged shadows near the car
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.rotation_degrees = sun_rotation
	add_child(sun)
	Game.apply_quality(env, sun)
	environment = env
	sun_light = sun

	var lamp := OmniLight3D.new()
	lamp.position = center() + Vector3(0.0, WALL_HEIGHT - 8.0, 0.0)
	lamp.omni_range = 280.0
	lamp.omni_attenuation = 0.6
	lamp.light_energy = lamp_energy
	lamp.light_color = lamp_color
	add_child(lamp)


func _build_floor() -> void:
	var img := _floor_image()
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	_add_depth(m, img, 4.0)
	m.roughness = floor_roughness
	m.uv1_scale = Vector3(room_rect.size.x / floor_tile_size, room_rect.size.y / floor_tile_size, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Floor"
	var pm := PlaneMesh.new()
	pm.size = room_rect.size
	floor_mi.mesh = pm
	floor_mi.material_override = m
	floor_mi.position = center()
	add_child(floor_mi)


## Gives a floor or wall texture real depth: grout lines, plank seams and
## carpet weave catch the light (a normal map made from the picture itself).
static func _add_depth(m: StandardMaterial3D, img: Image, strength: float) -> void:
	var bump := img.duplicate() as Image
	if bump.is_compressed():
		return
	bump.clear_mipmaps()
	bump.convert(Image.FORMAT_L8)
	bump.convert(Image.FORMAT_RGBA8)
	bump.bump_map_to_normal_map(strength)
	bump.generate_mipmaps()
	m.normal_enabled = true
	m.normal_texture = ImageTexture.create_from_image(bump)
	m.normal_scale = 0.8


func _wall_material() -> StandardMaterial3D:
	var img := _wall_image()
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	_add_depth(m, img, 3.0)
	m.roughness = 0.9
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / wall_tile_size
	return m


func _build_walls() -> void:
	var wall_mat := _wall_material()
	var trim := _mat(trim_color, 0.6)
	var r := room_rect
	var h := WALL_HEIGHT
	var c := center()
	# Walls don't cast shadows so the sun can shine in.
	_box(Vector3(r.size.x, h, 2.0), Vector3(c.x, h * 0.5, r.position.y - 1.0), wall_mat, false, null, 0.0)
	_box(Vector3(r.size.x, h, 2.0), Vector3(c.x, h * 0.5, r.end.y + 1.0), wall_mat, false, null, 0.0)
	_box(Vector3(2.0, h, r.size.y), Vector3(r.position.x - 1.0, h * 0.5, c.z), wall_mat, false, null, 0.0)
	_box(Vector3(2.0, h, r.size.y), Vector3(r.end.x + 1.0, h * 0.5, c.z), wall_mat, false, null, 0.0)
	_box(Vector3(r.size.x, 3.0, 0.6), Vector3(c.x, 1.5, r.position.y + 0.3), trim)
	_box(Vector3(r.size.x, 3.0, 0.6), Vector3(c.x, 1.5, r.end.y - 0.3), trim)
	_box(Vector3(0.6, 3.0, r.size.y), Vector3(r.position.x + 0.3, 1.5, c.z), trim)
	_box(Vector3(0.6, 3.0, r.size.y), Vector3(r.end.x - 0.3, 1.5, c.z), trim)
	_box(Vector3(r.size.x + 4.0, 1.0, r.size.y + 4.0), Vector3(c.x, h + 0.5, c.z), _mat(ceiling_color), false, null, 0.0)
	# A door on the near wall
	_box(Vector3(18.0, 42.0, 0.8), Vector3(r.end.x - 30.0, 21.0, r.end.y - 0.2), _mat(door_color, 0.5), false)
	_sphere(1.0, Vector3(r.end.x - 37.0, 20.0, r.end.y - 1.0), _mat(Color(0.9, 0.75, 0.2), 0.2))


func _build_window() -> void:
	var r := room_rect
	var cx := r.position.x + r.size.x * 0.62
	var z := r.position.y + 0.2
	var frame_mat := _mat(Color(0.98, 0.98, 0.98), 0.5)
	var sky := _glow(window_sky, 1.4)
	_box(Vector3(44.0, 32.0, 0.3), Vector3(cx, 38.0, z + 0.2), sky, false)
	_box(Vector3(48.0, 2.0, 1.2), Vector3(cx, 54.0, z + 0.4), frame_mat, false)
	_box(Vector3(48.0, 2.0, 2.4), Vector3(cx, 22.0, z + 1.0), frame_mat, false)
	_box(Vector3(2.0, 32.0, 1.2), Vector3(cx - 23.0, 38.0, z + 0.4), frame_mat, false)
	_box(Vector3(2.0, 32.0, 1.2), Vector3(cx + 23.0, 38.0, z + 0.4), frame_mat, false)
	_box(Vector3(1.0, 32.0, 1.0), Vector3(cx, 38.0, z + 0.4), frame_mat, false)
	_box(Vector3(46.0, 1.0, 1.0), Vector3(cx, 38.0, z + 0.4), frame_mat, false)
	# The sun in the window (a moon at night, hidden behind the rain clouds).
	if not rain:
		var sun_col := Color(0.92, 0.94, 1.0) if time_of_day == 2 else (Color(1.0, 0.55, 0.25) if time_of_day == 1 else Color(1.0, 0.85, 0.2))
		var sun := _cylinder(4.0, 0.2, Vector3(cx + 12.0, 47.0 if time_of_day != 1 else 41.0, z + 0.45), _glow(sun_col, 2.0))
		sun.rotation.x = PI * 0.5
	var cloud := _mat(Color(0.6, 0.62, 0.68) if rain else (Color(0.4, 0.42, 0.55) if time_of_day == 2 else Color.WHITE), 1.0)
	for i in 3:
		var c := _sphere(3.0, Vector3(cx - 12.0 + i * 3.5, 44.0 + (1.0 if i == 1 else 0.0), z + 0.4), cloud, Vector3(1.0, 0.8, 0.1))
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var curtain := _mat(curtain_color, 1.0)
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(cx + side * 28.0, 56.0, z + 1.6)
		add_child(pivot)
		_box(Vector3(9.0, 40.0, 1.5), Vector3(0, -20.0, 0), curtain, false, pivot)
		var ph := side
		animate(func(t: float, _d: float): pivot.rotation.x = -0.04 - 0.035 * (1.0 + sin(t * 0.8 + ph)))
	var rod := _cylinder(0.6, 70.0, Vector3(cx, 57.0, z + 2.0), frame_mat)
	rod.rotation.z = PI * 0.5


# ---------------------------------------------------------------------------
# Shape helpers
# ---------------------------------------------------------------------------

func _mat(color: Color, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _glow(color: Color, energy: float = 1.0) -> StandardMaterial3D:
	var m := _mat(color, 0.5)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _shiny(color: Color) -> StandardMaterial3D:
	var m := _mat(color, 0.15)
	m.metallic_specular = 0.9
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, shadow := true, parent: Node3D = null, round_amt := 0.15) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var smallest := minf(size.x, minf(size.y, size.z))
	if round_amt <= 0.0 or smallest < 0.3:
		var mesh := BoxMesh.new()
		mesh.size = size
		mi.mesh = mesh
	else:
		mi.mesh = MeshKit.rounded_box(size, smallest * round_amt, 3)
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


func _cylinder(radius: float, height: float, pos: Vector3, mat: Material, parent: Node3D = null, top_radius := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


func _torus(inner: float, outer: float, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 48
	mesh.ring_segments = 16
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


func _label(text: String, pos: Vector3, size_px: int, pixel: float, color: Color, parent: Node3D = null, outline := 0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size_px
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = outline
	l.position = pos
	(parent if parent else self).add_child(l)
	return l


## Stands a flat disc/cylinder up on its edge (rotates it to face +Z).
func _upright(n: Node3D) -> Node3D:
	n.rotation.x = PI * 0.5
	return n


func _node(node_name: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	n.rotation.y = rot_y
	add_child(n)
	return n


## True if a spot on the floor is far enough from the track to put stuff there.
func _clear_of_track(p: Vector3, radius: float) -> bool:
	var min_d := Track.HALF_WIDTH + radius + 2.0
	for k in range(0, track.count, 2):
		var q := track.points[k]
		if Vector2(q.x - p.x, q.z - p.z).length() < min_d:
			return false
	return true


## Finds up to `count` random free floor spots (inside `area`) for props of `radius`.
func _free_spots(count: int, radius: float, area: Rect2 = Rect2()) -> Array[Vector3]:
	var a := area if area.size != Vector2.ZERO else room_rect.grow(-radius - 6.0)
	var out: Array[Vector3] = []
	var tries := 0
	while out.size() < count and tries < count * 40:
		tries += 1
		var p := Vector3(_rng.randf_range(a.position.x, a.end.x), 0.0, _rng.randf_range(a.position.y, a.end.y))
		if not _clear_of_track(p, radius):
			continue
		var ok := true
		for q in out:
			if q.distance_to(p) < radius * 2.2:
				ok = false
				break
		if ok:
			out.append(p)
	return out


## The area well inside the room but away from the walls (for scattered toys).
## Turns a prop (whose front is -Z) at p to face the nearest bit of track.
func _face_track_angle(p: Vector3) -> float:
	var best := 1e9
	var best_pos := p
	for i in 40:
		var o := track.sample(track.length * i / 40.0).origin
		var d := Vector2(o.x - p.x, o.z - p.z).length()
		if d < best:
			best = d
			best_pos = o
	var dir := best_pos - p
	return atan2(-dir.x, -dir.z)


func _inner_area(margin: float = 8.0) -> Rect2:
	return room_rect.grow(-margin)


## Toy blocks with letters on them.
func _toy_blocks(count: int, letters: String, colors: Array, area: Rect2 = Rect2()) -> void:
	for p in _free_spots(count, 4.0, area):
		var size := _rng.randf_range(2.6, 4.0)
		var stack := 1 if _rng.randf() < 0.7 else 2
		for k in stack:
			var col: Color = colors[_rng.randi() % colors.size()]
			var blk := _box(Vector3(size, size, size), p + Vector3(0, size * 0.5 + k * size, 0), _mat(col, 0.45))
			blk.rotation.y = _rng.randf_range(0.0, TAU)
			for face in 4:
				var ang := face * PI * 0.5
				var lbl := _label(letters[_rng.randi() % letters.length()], Vector3(sin(ang), 0.0, cos(ang)) * (size * 0.5 + 0.02), 128, size * 0.0045, Color.WHITE, blk)
				lbl.rotation.y = ang


# ---------------------------------------------------------------------------
# Texture generators (small images, tiled across the floor/walls)
# ---------------------------------------------------------------------------

static func wood_image(base: Color, planks: int = 4) -> Image:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for x in 256:
		var plank := x * planks / 256
		var shade := 0.9 + 0.1 * sin(plank * 12.9898)
		for y in 256:
			var grain := 0.06 * sin(y * 0.11 + sin(x * 0.3 + plank) * 2.0) + 0.03 * sin(y * 0.53 + x * 0.07)
			var c := base * (shade + grain)
			if x % (256 / planks) < 2:
				c = base * 0.6
			if (y + plank * 97) % 256 < 2:
				c = base * 0.65
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func checker_image(a: Color, b: Color, squares: int = 2, grout := Color(0, 0, 0, 0)) -> Image:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var sq := 128 / squares
	for x in 128:
		for y in 128:
			var c := a if ((x / sq) + (y / sq)) % 2 == 0 else b
			if grout.a > 0.0 and (x % sq < 2 or y % sq < 2):
				c = grout
			img.set_pixel(x, y, c)
	return img


static func tiles_image(tile: Color, grout: Color, tiles: int = 4, accent := Color(0, 0, 0, 0)) -> Image:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var sq := 128 / tiles
	for x in 128:
		for y in 128:
			var c := tile
			if accent.a > 0.0 and ((x / sq) * 3 + (y / sq) * 5) % 7 == 0:
				c = accent
			c = c * (0.97 + 0.03 * sin(x * 0.2) * sin(y * 0.17))
			if x % sq < 3 or y % sq < 3:
				c = grout
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func carpet_image(base: Color, fleck: Color) -> Image:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for x in 128:
		for y in 128:
			var c := base * rng.randf_range(0.92, 1.06)
			if rng.randf() < 0.04:
				c = fleck
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func foam_mat_image(colors: Array) -> Image:
	# Interlocking foam puzzle mat: coloured squares with a jigsaw edge.
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for x in 128:
		for y in 128:
			var tx := x / 64
			var ty := y / 64
			var lx := x % 64
			var ly := y % 64
			# jigsaw tabs poke into the neighbouring tile
			var tab_x := lx > 56 and absi(ly - 32) < 8
			var tab_y := ly > 56 and absi(lx - 32) < 8
			if tab_x:
				tx = (tx + 1) % 2
			if tab_y:
				ty = (ty + 1) % 2
			var c: Color = colors[(tx + ty * 2) % colors.size()]
			c = c * (0.96 + 0.04 * sin(x * 0.9) * sin(y * 0.8))
			c.a = 1.0
			img.set_pixel(x, y, c)
	return img


static func stripes_image(base: Color, stripe: Color, star: Color) -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for x in 64:
		for y in 64:
			var c := stripe if (x / 16) % 2 == 0 else base
			var dx := absi((x % 32) - 8)
			var dy := absi((y % 32) - 16)
			if star.a > 0.0 and (dx + dy <= 2 or (dx == 0 and dy <= 3) or (dy == 0 and dx <= 3)):
				c = star
			img.set_pixel(x, y, c)
	return img


static func dots_image(base: Color, dot: Color) -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for x in 64:
		for y in 64:
			var c := base
			for o: Vector2 in [Vector2(16, 16), Vector2(48, 48)]:
				if Vector2(x, y).distance_to(o) < 6.0:
					c = dot
			img.set_pixel(x, y, c)
	return img


static func plaid_image(base: Color, line_a: Color, line_b: Color) -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for x in 64:
		for y in 64:
			var c := base
			if x % 32 < 4 or y % 32 < 4:
				c = c.lerp(line_a, 0.5)
			if (x + 16) % 32 < 2 or (y + 16) % 32 < 2:
				c = c.lerp(line_b, 0.5)
			img.set_pixel(x, y, c)
	return img
