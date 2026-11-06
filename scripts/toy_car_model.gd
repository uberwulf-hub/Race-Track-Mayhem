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


func setup(car_def: Dictionary, with_shadow := true) -> ToyCarModel:
	car = car_def
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
		_:
			_build_sport()
	return self


## Spins the wheels for the given speed and turns the front wheels.
func animate(speed: float, steer: float, delta: float) -> void:
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
	hub.material_override = plastic(hub_color, 0.15)
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
	for x: float in [-0.6, 0.6]:
		_wheel(Vector3(x, 0.3, -0.72), 0.3, 0.24, true, Color(0.95, 0.95, 0.95))
		_wheel(Vector3(x, 0.3, 0.72), 0.3, 0.24, false, Color(0.95, 0.95, 0.95))
