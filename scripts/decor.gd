class_name Decor
extends RefCounted
## Decorations you can put round your own track in Build Anywhere: cones,
## toy blocks, flags, trees, a balloon arch and a teddy. They're just for
## looks (cars drive straight through them).

const ITEMS: Array[Dictionary] = [
	{"id": "cone", "name": "Cone", "color": Color(1.0, 0.5, 0.1)},
	{"id": "blocks", "name": "Toy Blocks", "color": Color(0.35, 0.6, 1.0)},
	{"id": "flag", "name": "Flag", "color": Color(0.9, 0.25, 0.3)},
	{"id": "tree", "name": "Tree", "color": Color(0.3, 0.75, 0.35)},
	{"id": "balloons", "name": "Balloons", "color": Color(1.0, 0.45, 0.75)},
	{"id": "teddy", "name": "Teddy", "color": Color(0.7, 0.48, 0.28)},
]
const MAX := 40


static func info(id: String) -> Dictionary:
	for it in ITEMS:
		if it["id"] == id:
			return it
	return {}


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.45
	return m


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col)
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


static func _cyl(bottom: float, top: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = bottom
	c.top_radius = top
	c.height = h
	return c


## Builds a decoration standing on the floor at the origin.
static func make(id: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Decor_" + id
	match id:
		"cone":
			_add(n, _box(Vector3(3.2, 0.4, 3.2)), Vector3(0, 0.2, 0), Color(1.0, 0.45, 0.05))
			_add(n, _cyl(1.3, 0.25, 4.2), Vector3(0, 2.3, 0), Color(1.0, 0.45, 0.05))
			_add(n, _cyl(0.95, 0.75, 0.7), Vector3(0, 2.3, 0), Color(0.97, 0.97, 0.97))
		"blocks":
			var cols := [Color(0.9, 0.25, 0.25), Color(0.3, 0.55, 1.0), Color(1.0, 0.82, 0.2), Color(0.35, 0.8, 0.4)]
			var at := [Vector3(-1.3, 1.2, 0), Vector3(1.3, 1.2, 0.3), Vector3(0, 3.6, 0.1)]
			for k in at.size():
				var b := _add(n, _box(Vector3(2.4, 2.4, 2.4)), at[k], cols[k % cols.size()])
				b.rotation.y = k * 0.4
				var l := Label3D.new()
				l.text = ["A", "B", "C"][k]
				l.font_size = 96
				l.pixel_size = 0.02
				l.outline_size = 10
				l.position = Vector3(0, 0, 1.22)
				b.add_child(l)
		"flag":
			_add(n, _cyl(0.15, 0.15, 9.0), Vector3(0, 4.5, 0), Color(0.85, 0.85, 0.88))
			var cloth := _add(n, _box(Vector3(3.4, 2.2, 0.1)), Vector3(1.8, 7.8, 0), Color(0.9, 0.25, 0.3))
			cloth.name = "Cloth"
			_add(n, _ball(0.35), Vector3(0, 9.1, 0), Color(1.0, 0.85, 0.2))
		"tree":
			_add(n, _cyl(0.9, 0.7, 5.0), Vector3(0, 2.5, 0), Color(0.5, 0.33, 0.18))
			_add(n, _ball(3.0), Vector3(0, 6.5, 0), Color(0.3, 0.72, 0.32))
			_add(n, _ball(2.2), Vector3(1.8, 5.4, 0.8), Color(0.35, 0.78, 0.36))
			_add(n, _ball(2.0), Vector3(-1.6, 5.6, -0.6), Color(0.28, 0.68, 0.3))
		"balloons":
			var bcols := [Color(1.0, 0.35, 0.4), Color(0.35, 0.6, 1.0), Color(1.0, 0.85, 0.25), Color(0.5, 0.9, 0.45), Color(0.85, 0.45, 1.0)]
			for k in 11:   # an arch of balloons over the road
				var a := PI * k / 10.0
				_add(n, _ball(0.95), Vector3(cos(a) * 5.4, 0.8 + sin(a) * 6.5, 0), bcols[k % bcols.size()], Vector3(1, 1.15, 1))
		"teddy":
			var fur := Color(0.72, 0.5, 0.3)
			_add(n, _ball(1.9), Vector3(0, 1.9, 0), fur, Vector3(1, 1.1, 0.9))
			_add(n, _ball(1.4), Vector3(0, 4.6, 0), fur)
			for side: float in [-1.0, 1.0]:
				_add(n, _ball(0.55), Vector3(side * 1.0, 5.8, 0), fur)
				_add(n, _ball(0.6), Vector3(side * 1.8, 2.6, -0.3), fur)
				_add(n, _ball(0.18), Vector3(side * 0.45, 4.9, -1.25), Color(0.05, 0.05, 0.05))
			_add(n, _ball(0.55), Vector3(0, 4.3, -1.2), Color(0.95, 0.85, 0.7), Vector3(1, 0.8, 0.6))
			_add(n, _ball(0.2), Vector3(0, 4.45, -1.6), Color(0.1, 0.06, 0.05))
	n.scale = Vector3.ONE * 1.8   # toy-sized next to the track
	return n


## Decorations saved with a track, as nodes placed on the floor.
static func spawn_all(parent: Node3D, list: Array) -> void:
	for e in list:
		if not e is Dictionary or info(String(e.get("id", ""))).is_empty():
			continue
		var d := make(String(e["id"]))
		d.position = Vector3(float(e.get("x", 0)), Track.BASE_HEIGHT - 0.35, float(e.get("z", 0)))
		d.rotation.y = float(e.get("yaw", 0))
		parent.add_child(d)
