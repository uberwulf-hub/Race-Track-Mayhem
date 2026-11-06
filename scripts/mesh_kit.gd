class_name MeshKit
extends RefCounted
## Little helpers that make soft, rounded "toy" shapes instead of sharp boxes,
## plus a soft blob shadow texture. Meshes are cached so many cars/blocks of the
## same size share one mesh.

static var _cache: Dictionary = {}
static var _shadow_tex: Texture2D


## A box with rounded edges and corners (a box "inflated" by a sphere).
## `radius` is clamped so it always fits.
static func rounded_box(size: Vector3, radius: float, segments: int = 3) -> ArrayMesh:
	var key := "rb_%s_%.3f_%d" % [size, radius, segments]
	if _cache.has(key):
		return _cache[key]
	var h := size * 0.5
	var r := minf(radius, minf(h.x, minf(h.y, h.z)) * 0.98)
	var inner := h - Vector3(r, r, r)
	# Each face is a cube-sphere patch, split down the middle so the flat part
	# of the face stretches between the two halves.
	var steps: Array = []   # [side, t]
	for i in segments + 1:
		steps.append([-1.0, -1.0 + float(i) / segments])
	for i in segments + 1:
		steps.append([1.0, float(i) / segments])
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
		[Vector3.LEFT, Vector3.UP, Vector3.BACK],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.RIGHT, Vector3.UP],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var grid: Array = []
		for sa: Array in steps:
			var row: Array = []
			for sb: Array in steps:
				var dir := (n + u * tan(float(sa[1]) * PI * 0.25) + v * tan(float(sb[1]) * PI * 0.25)).normalized()
				var core := n * absf(inner.dot(n)) + u * float(sa[0]) * absf(inner.dot(u)) + v * float(sb[0]) * absf(inner.dot(v))
				row.append([core + dir * r, dir])
			grid.append(row)
		for a in steps.size() - 1:
			for b in steps.size() - 1:
				_tri(st, grid[a][b], grid[a + 1][b], grid[a + 1][b + 1])
				_tri(st, grid[a][b], grid[a + 1][b + 1], grid[a][b + 1])
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	var avg: Vector3 = (a[1] + b[1] + c[1])
	var cr := (pb - pa).cross(pc - pa)
	if cr.length_squared() < 1e-12:
		return
	# Godot front faces are clockwise.
	if cr.dot(avg) > 0.0:
		var tmp := b
		b = c
		c = tmp
	for p: Array in [a, b, c]:
		st.set_normal(p[1])
		st.add_vertex(p[0])


## A soft round dark texture for fake shadows under cars.
static func shadow_texture() -> Texture2D:
	if _shadow_tex:
		return _shadow_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for x in size:
		for y in size:
			var d := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length() / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(0, 0, 0, a))
	_shadow_tex = ImageTexture.create_from_image(img)
	return _shadow_tex


## A flat quad with the blob shadow on it, lying in the XZ plane.
static func shadow_quad(width: float, length: float, strength: float = 0.55) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, length)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = shadow_texture()
	m.albedo_color = Color(1, 1, 1, strength)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.render_priority = -1
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
