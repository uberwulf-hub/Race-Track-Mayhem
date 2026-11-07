extends StaticBody3D
## A locker against a wall. Hide inside with E. Look out through the slats.
## Once the Listener learns that you hide, it starts checking lockers -
## hold your breath (Space) while it listens.

var sector: Node
var facing := Vector3.FORWARD   # the direction the locker door faces (into the room)
var _door: MeshInstance3D


func setup(s: Node, wall_normal: Vector3) -> void:
	sector = s
	facing = wall_normal
	collision_layer = 3
	collision_mask = 0
	rotation.y = atan2(facing.x, facing.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.3, 0.28)
	mat.metallic = 0.5
	mat.roughness = 0.55
	# Body: open at the front.
	for part in [[Vector3(0.9, 2.1, 0.05), Vector3(0, 1.05, -0.3)],
			[Vector3(0.05, 2.1, 0.6), Vector3(-0.45, 1.05, 0)],
			[Vector3(0.05, 2.1, 0.6), Vector3(0.45, 1.05, 0)],
			[Vector3(0.9, 0.05, 0.6), Vector3(0, 2.1, 0)],
			[Vector3(0.9, 0.05, 0.6), Vector3(0, 0.02, 0)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		mi.mesh = bm
		mi.material_override = mat
		mi.position = part[1]
		add_child(mi)
	# Door with dark slats you can see through.
	_door = MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(0.86, 2.05, 0.04)
	_door.mesh = door_mesh
	_door.material_override = mat
	_door.position = Vector3(0, 1.05, 0.3)
	add_child(_door)
	var slat_mat := StandardMaterial3D.new()
	slat_mat.albedo_color = Color(0.02, 0.02, 0.02)
	for i in 5:
		var slat := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.6, 0.03, 0.05)
		slat.mesh = sm
		slat.material_override = slat_mat
		slat.position = Vector3(0, 0.45 + i * 0.07, 0.0)
		_door.add_child(slat)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 2.1, 0.62)
	shape.shape = box
	shape.position.y = 1.05
	add_child(shape)


func prompt() -> String:
	return "Hide in locker"


func interact(player: Node) -> void:
	player.enter_locker(self)


func inside_pos() -> Vector3:
	return global_position


func front_pos() -> Vector3:
	return global_position + facing * 0.95


func rattle() -> void:
	var t := create_tween()
	t.tween_property(_door, "rotation:y", 0.06, 0.06)
	t.tween_property(_door, "rotation:y", -0.04, 0.08)
	t.tween_property(_door, "rotation:y", 0.0, 0.06)
	Sound.play_at("locker", global_position, -6.0)


## Hide the door while you're inside so you can see out (the screen shows slats instead).
func set_occupied(on: bool) -> void:
	_door.visible = not on
