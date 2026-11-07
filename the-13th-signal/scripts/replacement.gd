extends Node3D
## THE REPLACEMENT. Looks like an ordinary scientist mannequin.
## It only moves when you can't see it. Keep your light on it.
## (In Explorer mode it creeps closer but never catches you.)

const SPEED := 5.0

var sector: Node
var active := false
var path: Array[Vector2i] = []
var _repath_t := 0.0
var _creak_t := 0.0
var _home := Vector3.ZERO


## The mannequin itself. Also used for one scripted scare.
static func build_model() -> Node3D:
	var root := Node3D.new()
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = Color(0.86, 0.83, 0.78)
	plastic.roughness = 0.35
	var coat := StandardMaterial3D.new()
	coat.albedo_color = Color(0.92, 0.93, 0.95)
	coat.roughness = 0.8
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.14)
	var parts := [
		# [mesh, size/params, position, rotation_z, material]
		["capsule", Vector2(0.09, 0.95), Vector3(-0.13, 0.48, 0), 0.0, dark],
		["capsule", Vector2(0.09, 0.95), Vector3(0.13, 0.48, 0), 0.0, dark],
		["box", Vector3(0.52, 0.78, 0.28), Vector3(0, 1.32, 0), 0.0, coat],
		["box", Vector3(0.56, 0.42, 0.3), Vector3(0, 0.85, 0), 0.0, coat],
		["capsule", Vector2(0.065, 0.75), Vector3(-0.33, 1.28, 0), 0.08, coat],
		["capsule", Vector2(0.065, 0.75), Vector3(0.33, 1.28, 0), -0.08, coat],
		["sphere", Vector2(0.05, 0.1), Vector3(-0.36, 0.88, 0), 0.0, plastic],
		["sphere", Vector2(0.05, 0.1), Vector3(0.36, 0.88, 0), 0.0, plastic],
		["capsule", Vector2(0.05, 0.16), Vector3(0, 1.75, 0), 0.0, plastic],
		["sphere", Vector2(0.13, 0.32), Vector3(0, 1.93, 0), 0.0, plastic],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		match p[0]:
			"capsule":
				var c := CapsuleMesh.new()
				c.radius = p[1].x
				c.height = p[1].y
				mi.mesh = c
			"sphere":
				var s := SphereMesh.new()
				s.radius = p[1].x
				s.height = p[1].y
				mi.mesh = s
			_:
				var b := BoxMesh.new()
				b.size = p[1]
				mi.mesh = b
		mi.position = p[2]
		mi.rotation.z = p[3]
		mi.material_override = p[4]
		root.add_child(mi)
	# A visitor badge. No face at all.
	var badge := Label3D.new()
	badge.text = "VISITOR"
	badge.font_size = 24
	badge.pixel_size = 0.003
	badge.modulate = Color(0.2, 0.3, 0.6)
	badge.position = Vector3(0.13, 1.5, 0.15)
	root.add_child(badge)
	return root


func setup(s: Node) -> void:
	sector = s
	add_child(build_model())
	_home = global_position


func reset_to(pos: Vector3) -> void:
	global_position = pos
	path.clear()


func _physics_process(delta: float) -> void:
	if not active or sector == null or sector.paused_world:
		return
	var player: Node = sector.player
	if player.frozen:
		return
	var head := global_position + Vector3(0, 1.6, 0)
	var chest := global_position + Vector3(0, 1.0, 0)
	if player.can_see(head) or player.can_see(chest):
		return   # Frozen while watched.
	var hunts: bool = Game.mode_data()["replacement_hunts"]
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	# Always turn to face you when you're not looking.
	rotation.y = atan2(to_player.x, to_player.z)
	if not hunts and dist < 5.0:
		return   # Explorer: it only creeps closer, it never catches you.
	_repath_t -= delta
	if _repath_t <= 0.0 or path.is_empty():
		_repath_t = 0.6
		path = sector.find_path(global_position, player.global_position)
	if path.is_empty():
		return
	var speed := SPEED * float(Game.mode_data()["listener_speed"])
	var target: Vector3 = sector.cell_to_world(path[0])
	if path.size() == 1:
		target = player.global_position
	var to := target - global_position
	to.y = 0.0
	var step := speed * delta
	if to.length() <= step:
		global_position = Vector3(target.x, global_position.y, target.z)
		path.remove_at(0)
		if not path.is_empty():
			sector.monster_entering(path[0])
	else:
		global_position += to.normalized() * step
	_creak_t -= delta
	if _creak_t <= 0.0 and dist < 16.0:
		_creak_t = randf_range(0.6, 1.2)
		Sound.play_at("creak", global_position + Vector3(0, 1, 0), -2.0, randf_range(0.8, 1.2))
	if hunts and dist < 1.25 and not player.hidden_in:
		sector.on_caught("replacement")
