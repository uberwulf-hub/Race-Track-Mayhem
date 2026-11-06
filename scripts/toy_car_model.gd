class_name ToyCarModel
extends Node3D
## Builds a chunky toy car out of simple shapes. Front of the car faces -Z,
## the bottom of the wheels sits at y = 0.

var car: Dictionary
var _wheels: Array[Node3D] = []        # spin pivots
var _front_pivots: Array[Node3D] = []  # steering pivots
var _wheel_radius := 0.3
var _spin := 0.0
var body_root: Node3D                  # tilts a little for squash & stretch
var shadow: MeshInstance3D             # soft blob shadow on the ground
var _look: Dictionary = {}             # paint / sticker / wheels picked in the garage
var _wheel_style := "wheels_classic"
var _side := {"hw": 0.57, "y": 0.45, "len": 2.0, "h": 0.36}   # where stickers go
var _roll := 0.0
var _pitch := 0.0
var _squash_amt := 0.0
var _squash_t := 10.0
var _headlight: SpotLight3D


## look = {"paint": id, "sticker": id, "wheels": id} (see Unlocks); empty = original.
func setup(car_def: Dictionary, with_shadow := true, look: Dictionary = {}) -> ToyCarModel:
	car = car_def.duplicate()
	_look = look
	var paint := Unlocks.get_item(String(look.get("paint", "paint_original")))
	if paint.has("color"):
		car["body"] = paint["color"]
	_wheel_style = String(look.get("wheels", "wheels_classic"))
	if with_shadow:
		shadow = MeshKit.shadow_quad(1.9, 2.9, 0.6)
		shadow.position.y = 0.03
		add_child(shadow)
	body_root = Node3D.new()
	body_root.name = "Body"
	add_child(body_root)
	match String(car.get("style", "sport")):
		"monster":
			_build_monster()
		"buggy":
			_build_buggy()
		"van":
			_build_van()
		"rocket":
			_build_rocket()
		_:
			_build_sport()
	if paint.get("metal", false):
		_make_metallic(body_root, car["body"])
	_add_sticker(String(look.get("sticker", "sticker_none")))
	return self


## Shiny metal paint: every part painted the body colour gets a mirror finish.
func _make_metallic(n: Node, color: Color) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			var m := (c as MeshInstance3D).material_override as StandardMaterial3D
			if m and m.albedo_color.is_equal_approx(color):
				m.metallic = 0.85
				m.roughness = 0.12
		_make_metallic(c, color)


## Leans into turns, nods when speeding up/braking, squashes on landings.
func set_motion(accel: float, side_force: float, delta: float) -> void:
	_roll = lerpf(_roll, clampf(-side_force * 0.015, -0.12, 0.12), minf(1.0, delta * 6.0))
	_pitch = lerpf(_pitch, clampf(accel * 0.0025, -0.08, 0.08), minf(1.0, delta * 6.0))


func squash(amount: float) -> void:
	_squash_amt = amount
	_squash_t = 0.0


func set_headlights(on: bool) -> void:
	if on and _headlight == null:
		_headlight = SpotLight3D.new()
		_headlight.position = Vector3(0, 0.55, -1.2)
		_headlight.spot_range = 16.0
		_headlight.spot_angle = 32.0
		_headlight.light_energy = 4.0
		_headlight.light_color = Color(1.0, 0.95, 0.75)
		body_root.add_child(_headlight)
	if _headlight:
		_headlight.visible = on


## Spins the wheels for the given speed and turns the front wheels.
func animate(speed: float, steer: float, delta: float) -> void:
	_squash_t += delta
	var sq := _squash_amt * exp(-6.0 * _squash_t) * cos(18.0 * _squash_t)
	body_root.scale = Vector3(1.0 + sq * 0.5, 1.0 - sq, 1.0 + sq * 0.5)
	body_root.rotation = Vector3(_pitch, 0.0, _roll)
	_spin -= speed / _wheel_radius * delta
	for w in _wheels:
		w.rotation.x = _spin
	for p in _front_pivots:
		p.rotation.y = lerpf(p.rotation.y, -steer * 0.45, minf(1.0, delta * 12.0))


# ---------------------------------------------------------------------------
# Materials & shape helpers
# ---------------------------------------------------------------------------

static func plastic(color: Color, gloss: float = 0.22) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = gloss
	m.metallic_specular = 0.8
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	return m


static func glass() -> StandardMaterial3D:
	var m := plastic(Color(0.45, 0.8, 1.0), 0.04)
	m.metallic = 0.35
	m.metallic_specular = 1.0
	return m


static func glowing(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var m := plastic(color, 0.3)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO, round_amt := 0.3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var smallest := minf(size.x, minf(size.y, size.z))
	if smallest < 0.08:
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
	else:
		mi.mesh = MeshKit.rounded_box(size, smallest * round_amt, 3)
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _capsule(parent: Node3D, radius: float, length: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length, radius * 2.0)
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material, scale_v := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_v
	parent.add_child(mi)
	return mi


func _bar(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	var dir := (b - a).normalized()
	var up_hint := Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := dir.cross(up_hint).normalized()
	var z := x.cross(dir).normalized()
	mi.transform = Transform3D(Basis(x, dir, z), (a + b) * 0.5)


func _wheel(pos: Vector3, radius: float, width: float, front: bool, hub_color: Color) -> void:
	var hub_mat := plastic(hub_color, 0.15)
	match _wheel_style:
		"wheels_gold":
			hub_mat = plastic(Color(1.0, 0.78, 0.25), 0.12)
			hub_mat.metallic = 0.9
		"wheels_slicks":
			width *= 1.4
			radius *= 1.06
			pos.y *= 1.06
		"wheels_glow":
			hub_mat = glowing(Color(0.3, 1.0, 1.0), 2.5)
	var steer_pivot := Node3D.new()
	steer_pivot.position = pos
	add_child(steer_pivot)
	var spin := Node3D.new()
	steer_pivot.add_child(spin)

	var tire := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = width
	cyl.radial_segments = 18
	tire.mesh = cyl
	tire.rotation.z = PI * 0.5
	tire.material_override = plastic(Color(0.08, 0.08, 0.09), 0.7)
	spin.add_child(tire)

	var hub := MeshInstance3D.new()
	var hc := CylinderMesh.new()
	hc.top_radius = radius * 0.55
	hc.bottom_radius = radius * 0.55
	hc.height = width + 0.04
	hc.radial_segments = 12
	hub.mesh = hc
	hub.rotation.z = PI * 0.5
	hub.material_override = hub_mat
	spin.add_child(hub)

	# A stripe on the tyre so you can see it spinning.
	var mark := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(width + 0.06, radius * 0.25, radius * 1.1)
	mark.mesh = mb
	mark.material_override = plastic(Color(0.95, 0.95, 0.95), 0.4)
	spin.add_child(mark)

	_wheels.append(spin)
	if front:
		_front_pivots.append(steer_pivot)


func _number_decals(y: float, half_width: float, z: float, roof_y: float) -> void:
	var num := str(car.get("number", 1))
	for side: float in [-1.0, 1.0]:
		var lbl := Label3D.new()
		lbl.text = num
		lbl.font_size = 64
		lbl.pixel_size = 0.006
		lbl.outline_size = 14
		lbl.modulate = Color.WHITE
		lbl.outline_modulate = Color(0.05, 0.05, 0.1)
		lbl.position = Vector3(side * (half_width + 0.01), y, z)
		lbl.rotation.y = PI * 0.5 * side
		body_root.add_child(lbl)
	var roof := Label3D.new()
	roof.text = num
	roof.font_size = 64
	roof.pixel_size = 0.006
	roof.outline_size = 14
	roof.position = Vector3(0.0, roof_y + 0.01, z)
	roof.rotation.x = -PI * 0.5
	body_root.add_child(roof)


func _lights(front_z: float, back_z: float, y: float, spread: float) -> void:
	var head := glowing(Color(1.0, 0.97, 0.7), 2.0)
	var tail := glowing(Color(1.0, 0.1, 0.1), 1.5)
	for side: float in [-1.0, 1.0]:
		_sphere(body_root, 0.1, Vector3(side * spread, y, front_z), head, Vector3(1.0, 1.0, 0.5))
		_box(body_root, Vector3(0.22, 0.1, 0.05), Vector3(side * spread, y, back_z), tail)


# ---------------------------------------------------------------------------
# Car styles
# ---------------------------------------------------------------------------

func _build_sport() -> void:
	var body := plastic(car["body"])
	var accent := plastic(car["accent"])
	var gl := glass()
	_wheel_radius = 0.3
	_box(body_root, Vector3(1.12, 0.36, 2.05), Vector3(0, 0.45, 0.0), body)
	_box(body_root, Vector3(1.04, 0.2, 0.6), Vector3(0, 0.36, -1.1), body, Vector3(-0.25, 0, 0))   # nose
	_box(body_root, Vector3(0.9, 0.34, 0.95), Vector3(0, 0.78, 0.15), gl)                        # cabin
	_box(body_root, Vector3(0.86, 0.06, 0.8), Vector3(0, 0.96, 0.18), body)                         # roof
	_box(body_root, Vector3(1.16, 0.07, 1.9), Vector3(0, 0.56, 0.0), accent)                        # racing stripe band
	_box(body_root, Vector3(1.2, 0.06, 0.32), Vector3(0, 0.95, 0.98), accent)                       # spoiler
	for side: float in [-1.0, 1.0]:
		_box(body_root, Vector3(0.06, 0.3, 0.06), Vector3(side * 0.42, 0.78, 0.98), accent)
	_box(body_root, Vector3(1.15, 0.18, 0.2), Vector3(0, 0.3, 1.02), plastic(Color(0.15, 0.15, 0.15), 0.6))
	_lights(-1.32, 1.04, 0.45, 0.38)
	_number_decals(0.45, 0.57, 0.0, 0.99)
	_side = {"hw": 0.57, "y": 0.42, "len": 2.0, "h": 0.3}
	for x: float in [-0.62, 0.62]:
		_wheel(Vector3(x, 0.3, -0.68), 0.3, 0.24, true, Color(0.85, 0.85, 0.9))
		_wheel(Vector3(x, 0.3, 0.68), 0.32, 0.28, false, Color(0.85, 0.85, 0.9))


func _build_monster() -> void:
	var body := plastic(car["body"])
	var dark := plastic(car["accent"], 0.5)
	var gl := glass()
	_wheel_radius = 0.56
	_box(body_root, Vector3(0.9, 0.2, 1.7), Vector3(0, 0.62, 0), dark)                             # chassis
	_box(body_root, Vector3(1.15, 0.45, 2.0), Vector3(0, 1.05, 0.0), body)
	_box(body_root, Vector3(0.95, 0.42, 0.85), Vector3(0, 1.48, 0.15), gl)
	_box(body_root, Vector3(1.0, 0.08, 0.9), Vector3(0, 1.72, 0.15), body)
	_box(body_root, Vector3(1.2, 0.12, 0.25), Vector3(0, 0.85, -1.05), dark)                       # bumper
	_box(body_root, Vector3(1.2, 0.12, 0.25), Vector3(0, 0.85, 1.05), dark)
	for side: float in [-1.0, 1.0]:
		_bar(body_root, Vector3(side * 0.25, 0.65, -0.6), Vector3(side * 0.62, 0.56, -0.62), 0.06, dark)
		_bar(body_root, Vector3(side * 0.25, 0.65, 0.6), Vector3(side * 0.62, 0.56, 0.62), 0.06, dark)
	# flame stickers
	var flame := plastic(Color(1.0, 0.6, 0.0))
	for side: float in [-1.0, 1.0]:
		_box(body_root, Vector3(0.02, 0.14, 0.7), Vector3(side * 0.58, 1.0, -0.55), flame)
	_lights(-1.01, 1.01, 1.12, 0.4)
	_number_decals(1.05, 0.58, 0.2, 1.77)
	_side = {"hw": 0.58, "y": 1.05, "len": 2.0, "h": 0.4}
	for x: float in [-0.78, 0.78]:
		_wheel(Vector3(x, 0.56, -0.68), 0.56, 0.42, true, Color(0.95, 0.75, 0.1))
		_wheel(Vector3(x, 0.56, 0.68), 0.56, 0.42, false, Color(0.95, 0.75, 0.1))


func _build_buggy() -> void:
	var body := plastic(car["body"])
	var accent := plastic(car["accent"])
	var bar := plastic(Color(0.15, 0.15, 0.18), 0.35)
	_wheel_radius = 0.36
	_box(body_root, Vector3(1.0, 0.25, 1.9), Vector3(0, 0.42, 0), body)
	_box(body_root, Vector3(0.9, 0.22, 0.6), Vector3(0, 0.55, -0.85), body, Vector3(0.3, 0, 0))  # nose
	_box(body_root, Vector3(0.6, 0.35, 0.4), Vector3(0, 0.72, 0.75), accent)                     # engine
	for side: float in [-1.0, 1.0]:
		_bar(body_root, Vector3(side * 0.42, 0.55, 0.45), Vector3(side * 0.36, 1.35, 0.25), 0.05, bar)
		_bar(body_root, Vector3(side * 0.42, 0.55, -0.25), Vector3(side * 0.36, 1.35, 0.05), 0.05, bar)
		_bar(body_root, Vector3(side * 0.36, 1.35, 0.25), Vector3(side * 0.36, 1.35, 0.05), 0.05, bar)
		_capsule(body_root, 0.08, 0.35, Vector3(side * 0.85, 0.58, 0.95), bar, Vector3(PI * 0.5, 0, 0)) # exhaust pipes
	_bar(body_root, Vector3(-0.36, 1.35, 0.15), Vector3(0.36, 1.35, 0.15), 0.05, bar)
	# A smiley little driver with a helmet.
	_box(body_root, Vector3(0.45, 0.35, 0.4), Vector3(0, 0.75, 0.2), accent)
	_sphere(body_root, 0.2, Vector3(0, 1.08, 0.15), plastic(Color(1.0, 0.85, 0.7), 0.5))
	_sphere(body_root, 0.22, Vector3(0, 1.14, 0.18), plastic(car["accent"]), Vector3(1.0, 0.85, 1.0))
	_box(body_root, Vector3(0.3, 0.08, 0.02), Vector3(0, 1.08, -0.05), plastic(Color(0.2, 0.2, 0.3), 0.05))
	_lights(-1.08, 0.96, 0.5, 0.3)
	_number_decals(0.42, 0.51, -0.3, 0.68)
	_side = {"hw": 0.5, "y": 0.42, "len": 1.9, "h": 0.22}
	for x: float in [-0.66, 0.66]:
		_wheel(Vector3(x, 0.32, -0.7), 0.32, 0.26, true, car["accent"])
		_wheel(Vector3(x, 0.38, 0.7), 0.38, 0.4, false, car["accent"])


func _build_van() -> void:
	var body := plastic(car["body"])
	var accent := plastic(car["accent"])
	var gl := glass()
	_wheel_radius = 0.3
	_box(body_root, Vector3(1.18, 0.95, 2.1), Vector3(0, 0.8, 0.05), body)
	_box(body_root, Vector3(1.12, 0.45, 0.4), Vector3(0, 0.55, -1.12), body)                     # bonnet
	_box(body_root, Vector3(1.0, 0.35, 0.05), Vector3(0, 1.0, -1.0), gl, Vector3(-0.35, 0, 0))   # windscreen
	for side: float in [-1.0, 1.0]:
		_box(body_root, Vector3(0.02, 0.3, 1.5), Vector3(side * 0.6, 1.02, 0.15), gl)
		_box(body_root, Vector3(0.02, 0.14, 1.9), Vector3(side * 0.6, 0.6, 0.05), accent)            # stripe
	_box(body_root, Vector3(1.0, 0.06, 1.7), Vector3(0, 1.3, 0.15), accent)                       # roof rack
	# Polka dots, because bubblegum.
	for i in 3:
		_sphere(body_root, 0.12, Vector3(0.58, 0.75, -0.5 + i * 0.5), plastic(Color.WHITE), Vector3(0.2, 1.0, 1.0))
		_sphere(body_root, 0.12, Vector3(-0.58, 0.75, -0.5 + i * 0.5), plastic(Color.WHITE), Vector3(0.2, 1.0, 1.0))
	_lights(-1.33, 1.11, 0.62, 0.4)
	_number_decals(1.0, 0.6, 1.0, 1.33)
	_side = {"hw": 0.59, "y": 0.75, "len": 2.1, "h": 0.5}
	for x: float in [-0.6, 0.6]:
		_wheel(Vector3(x, 0.3, -0.72), 0.3, 0.24, true, Color(0.95, 0.95, 0.95))
		_wheel(Vector3(x, 0.3, 0.72), 0.3, 0.24, false, Color(0.95, 0.95, 0.95))


## The secret car: a little rocket on wheels.
func _build_rocket() -> void:
	var body := plastic(car["body"])
	var accent := plastic(car["accent"])
	_wheel_radius = 0.3
	var hull := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 2.3
	hull.mesh = cap
	hull.material_override = body
	hull.rotation.x = PI * 0.5
	hull.position = Vector3(0, 0.62, 0.05)
	body_root.add_child(hull)
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.42
	cone.height = 0.7
	nose.mesh = cone
	nose.material_override = accent
	nose.rotation.x = -PI * 0.5
	nose.position = Vector3(0, 0.62, -1.25)
	body_root.add_child(nose)
	# Cockpit bubble
	var bubble := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.64
	bubble.mesh = sm
	bubble.material_override = glass()
	bubble.scale = Vector3(1.0, 0.8, 1.5)
	bubble.position = Vector3(0, 1.0, -0.2)
	body_root.add_child(bubble)
	# Fins
	for i in 3:
		var a := i * TAU / 3.0 + PI
		var fin := _box(body_root, Vector3(0.06, 0.5, 0.6), Vector3(sin(a) * 0.5, 0.62 + cos(a) * 0.5, 0.95), accent)
		fin.rotation.z = -a
	# Exhaust glow
	var flame := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.25
	fs.height = 0.5
	flame.mesh = fs
	flame.material_override = glowing(Color(1.0, 0.55, 0.15), 3.0)
	flame.scale = Vector3(1.0, 1.0, 1.6)
	flame.position = Vector3(0, 0.62, 1.3)
	body_root.add_child(flame)
	# Side boosters
	for side: float in [-1.0, 1.0]:
		var boost := MeshInstance3D.new()
		var bc := CapsuleMesh.new()
		bc.radius = 0.16
		bc.height = 1.0
		boost.mesh = bc
		boost.material_override = accent
		boost.rotation.x = PI * 0.5
		boost.position = Vector3(side * 0.62, 0.5, 0.4)
		body_root.add_child(boost)
	_number_decals(0.62, 0.51, 0.25, 1.13)
	_side = {"hw": 0.5, "y": 0.62, "len": 1.8, "h": 0.25}
	for x: float in [-0.55, 0.55]:
		_wheel(Vector3(x, 0.28, -0.7), 0.28, 0.22, true, Color(0.9, 0.9, 0.95))
		_wheel(Vector3(x, 0.3, 0.75), 0.3, 0.26, false, Color(0.9, 0.9, 0.95))


# ---------------------------------------------------------------------------
# Stickers
# ---------------------------------------------------------------------------

func _add_sticker(id: String) -> void:
	if id == "sticker_none" or id == "":
		return
	var hw: float = _side["hw"]
	var y: float = _side["y"]
	var len: float = _side["len"]
	var h: float = _side["h"]
	var white := plastic(Color(1, 1, 1), 0.3)
	var accent := plastic(car["accent"], 0.3)
	for side: float in [-1.0, 1.0]:
		var x := side * (hw + 0.015)
		match id:
			"sticker_stripes":
				for k: float in [-0.25, 0.25]:
					_box(body_root, Vector3(0.02, h * 0.16, len * 0.9), Vector3(x, y + k * h, 0), white, Vector3.ZERO, 0.0)
			"sticker_flames":
				var cols := [Color(1.0, 0.85, 0.1), Color(1.0, 0.5, 0.05), Color(0.95, 0.15, 0.05)]
				for k in 4:
					var fl := _box(body_root, Vector3(0.02, h * 0.18, len * (0.42 - k * 0.06)), Vector3(x, y - h * 0.3 + k * h * 0.2, -len * 0.18 - k * 0.04), plastic(cols[k % 3], 0.3), Vector3(0.18 - k * 0.04, 0, 0), 0.0)
					fl.name = "Flame%d" % k
			"sticker_stars":
				for k in 3:
					_star(Vector3(x, y + (0.15 if k == 1 else -0.05) * h, -len * 0.3 + k * len * 0.12), side, h * 0.32, plastic(Color(1.0, 0.9, 0.2), 0.3))
			"sticker_lightning":
				var bolt := plastic(Color(1.0, 0.95, 0.2), 0.3)
				var pts := [Vector3(0, h * 0.35, -len * 0.38), Vector3(0, -h * 0.05, -len * 0.22), Vector3(0, h * 0.1, -len * 0.12), Vector3(0, -h * 0.4, len * 0.08)]
				for k in pts.size() - 1:
					var a: Vector3 = pts[k]
					var b: Vector3 = pts[k + 1]
					var mid := (a + b) * 0.5
					var seg := _box(body_root, Vector3(0.02, h * 0.12, a.distance_to(b) + 0.05), Vector3(x, y + mid.y, mid.z), bolt, Vector3.ZERO, 0.0)
					seg.rotation.x = atan2(b.y - a.y, -(b.z - a.z))
			"sticker_checkers":
				var sq := h * 0.22
				var n := int(len * 0.8 / sq)
				for i in n:
					for row in 2:
						var mat := white if (i + row) % 2 == 0 else plastic(Color(0.08, 0.08, 0.08), 0.3)
						_box(body_root, Vector3(0.02, sq, sq), Vector3(x, y - h * 0.38 + row * sq, -len * 0.4 + i * sq), mat, Vector3.ZERO, 0.0)
	# A matching roof/bonnet touch for some stickers
	if id == "sticker_stripes":
		_box(body_root, Vector3(0.18, 0.02, len * 0.7), Vector3(0, y + h * 0.55 + 0.02, -len * 0.05), accent, Vector3.ZERO, 0.0)


## A six-pointed star made of two flat triangles, stuck on the side of the car.
func _star(pos: Vector3, side: float, size: float, mat: Material) -> void:
	for k in 2:
		var tri := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = size
		cm.bottom_radius = size
		cm.height = 0.02
		cm.radial_segments = 3
		cm.rings = 1
		tri.mesh = cm
		tri.material_override = mat
		tri.position = pos
		tri.rotation = Vector3(0, 0, PI * 0.5)
		tri.rotate_object_local(Vector3.UP, PI * k / 3.0 + PI / 6.0)
		body_root.add_child(tri)
