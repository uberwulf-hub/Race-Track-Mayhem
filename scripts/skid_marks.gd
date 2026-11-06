class_name SkidMarks
extends MultiMeshInstance3D
## Dark rubber streaks left on the track when cars skid, brake hard or scrape.
## A ring buffer of small quads drawn with one MultiMesh, so it stays cheap.

const MAX_MARKS := 900

var _next := 0


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.55)
	quad.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.06, 0.03, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.render_priority = -1
	quad.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = MAX_MARKS
	mm.visible_instance_count = 0
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Adds one streak at a world position, lying on a surface with this basis.
func add_mark(pos: Vector3, basis: Basis, strength: float) -> void:
	var b := basis.orthonormalized()
	multimesh.set_instance_transform(_next, Transform3D(b, pos + b.y * 0.02))
	multimesh.set_instance_color(_next, Color(1, 1, 1, clampf(strength, 0.2, 1.0)))
	_next = (_next + 1) % MAX_MARKS
	multimesh.visible_instance_count = maxi(multimesh.visible_instance_count, _next if _next > 0 else MAX_MARKS)
