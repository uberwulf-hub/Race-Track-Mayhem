class_name Trophy
extends RefCounted
## Builds a shiny trophy cup (gold, silver or bronze). Used on the podium and
## on the bedroom shelf where your Grand Prix trophies are kept.

const COLORS := [Color(1.0, 0.78, 0.2), Color(0.85, 0.87, 0.92), Color(0.82, 0.5, 0.25)]
const NAMES := ["Gold", "Silver", "Bronze"]


static func metal(place: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = COLORS[clampi(place - 1, 0, 2)]
	m.metallic = 0.9
	m.roughness = 0.18
	return m


## A cup about 6 units tall at scale 1. `label` is engraved on the base.
static func make(place: int, label: String = "") -> Node3D:
	var root := Node3D.new()
	var m := metal(place)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.18, 0.12, 0.08)
	dark.roughness = 0.4
	_mesh(root, MeshKit.rounded_box(Vector3(3.0, 1.2, 3.0), 0.25, 2), Vector3(0, 0.6, 0), dark)
	_mesh(root, _cyl(0.35, 0.5, 2.0), Vector3(0, 2.2, 0), m)
	_mesh(root, _cyl(0.9, 0.35, 0.5), Vector3(0, 1.45, 0), m)
	_mesh(root, _cyl(1.7, 0.55, 2.6), Vector3(0, 4.4, 0), m)
	var rim := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 1.55
	t.outer_radius = 1.8
	rim.mesh = t
	rim.material_override = m
	rim.position = Vector3(0, 5.7, 0)
	root.add_child(rim)
	for side: float in [-1.0, 1.0]:
		var handle := MeshInstance3D.new()
		var ht := TorusMesh.new()
		ht.inner_radius = 0.45
		ht.outer_radius = 0.7
		handle.mesh = ht
		handle.material_override = m
		handle.position = Vector3(side * 1.75, 4.6, 0)
		handle.rotation = Vector3(PI * 0.5, 0, 0)
		root.add_child(handle)
	var star := Label3D.new()
	star.text = str(place)
	star.font_size = 96
	star.pixel_size = 0.012
	star.outline_size = 16
	star.modulate = Color(1, 1, 1)
	star.outline_modulate = Color(0.3, 0.2, 0.05)
	star.position = Vector3(0, 4.4, 1.75)
	root.add_child(star)
	if label != "":
		var l := Label3D.new()
		l.text = label
		l.font_size = 48
		l.pixel_size = 0.012
		l.outline_size = 10
		l.modulate = Color(1.0, 0.92, 0.6)
		l.position = Vector3(0, 0.6, 1.53)
		root.add_child(l)
	return root


static func _cyl(bottom: float, top: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = bottom
	c.top_radius = top
	c.height = h
	c.radial_segments = 24
	return c


static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
