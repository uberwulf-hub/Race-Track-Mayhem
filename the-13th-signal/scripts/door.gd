extends StaticBody3D
## A sliding facility door. The player opens it with E (which makes noise);
## monsters open doors just by walking up to them. Doors close by themselves.
## kind: "door", "keycard" (needs the keycard) or "exit" (needs power + the code).

const S := 3.0
const H := 3.2

var sector: Node
var cell := Vector2i.ZERO
var kind := "door"
var is_open := false
var unlocked := false   # keycard/exit doors, once you've got past them
var stay_open := false
var panel: MeshInstance3D
var shape: CollisionShape3D
var display: Label3D    # the exit door's code-order screen
var _close_t := 0.0
var _tween: Tween


func setup(s: Node, c: Vector2i, along_x: bool, k: String) -> void:
	sector = s
	cell = c
	kind = k
	collision_layer = 3
	collision_mask = 0
	if not along_x:
		rotation.y = PI / 2.0
	var colors := {"door": Color(0.22, 0.26, 0.3), "keycard": Color(0.35, 0.22, 0.12), "exit": Color(0.32, 0.3, 0.12)}
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colors[kind]
	mat.metallic = 0.6
	mat.roughness = 0.45
	panel = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(S, H, 0.3)
	panel.mesh = bm
	panel.material_override = mat
	panel.position.y = H / 2.0
	add_child(panel)
	# A glowing stripe so doors are easy to spot in the dark.
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(S * 0.9, 0.08, 0.34)
	stripe.mesh = sm
	var smat := StandardMaterial3D.new()
	var glow := {"door": Color(0.3, 0.7, 1.0), "keycard": Color(1.0, 0.55, 0.1), "exit": Color(1.0, 0.9, 0.2)}
	smat.albedo_color = glow[kind]
	smat.emission_enabled = true
	smat.emission = glow[kind]
	smat.emission_energy_multiplier = 1.5
	stripe.material_override = smat
	stripe.position.y = 0.4
	panel.add_child(stripe)
	if kind != "door":
		var door_sign := Label3D.new()
		door_sign.text = "SECURITY\nKEYCARD ONLY" if kind == "keycard" else "SERVICE ELEVATOR"
		door_sign.font_size = 48
		door_sign.pixel_size = 0.004
		door_sign.modulate = glow[kind]
		door_sign.position = Vector3(0, 0.75, 0.17)
		panel.add_child(door_sign)
		var back := door_sign.duplicate()
		back.position.z = -0.17
		back.rotation.y = PI
		panel.add_child(back)
	if kind == "exit":
		display = Label3D.new()
		display.font_size = 56
		display.pixel_size = 0.0045
		display.position = Vector3(0, -0.45, 0.17)
		display.modulate = Color(0.4, 0.4, 0.4)
		display.text = "- NO POWER -"
		panel.add_child(display)
		var display_back: Label3D = display.duplicate()
		display_back.position.z = -0.17
		display_back.rotation.y = PI
		panel.add_child(display_back)
		display.set_meta("twin", display_back)
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(S, H, 0.3)
	shape.shape = box
	shape.position.y = H / 2.0
	add_child(shape)


func set_display(text: String, color: Color) -> void:
	if display == null:
		return
	display.text = text
	display.modulate = color
	var twin: Label3D = display.get_meta("twin")
	twin.text = text
	twin.modulate = color


func prompt() -> String:
	if is_open:
		return ""
	match kind:
		"keycard":
			return "Open security door" if (unlocked or sector.has_keycard) else "Locked: security keycard needed"
		"exit":
			if unlocked:
				return "Open elevator"
			return "Elevator keypad" if sector.power_on else "Elevator: no power"
	return "Open door"


func interact(_player: Node) -> void:
	if is_open:
		return
	match kind:
		"keycard":
			if not unlocked:
				if not sector.has_keycard:
					Sound.play_at("locked", global_position, -2.0)
					sector.hud.toast("You need a security keycard.")
					return
				unlocked = true
				sector.unlock_cell(cell)
				Sound.play("pickup", -10.0)
		"exit":
			if not unlocked:
				if not sector.power_on:
					Sound.play_at("locked", global_position, -2.0)
					sector.hud.toast("The elevator has no power.")
					return
				sector.open_keypad()
				return
	open(true)


func open(noisy: bool) -> void:
	_close_t = 5.0
	if is_open:
		return
	is_open = true
	Sound.play_at("door", global_position, -4.0)
	if noisy:
		sector.emit_noise(global_position, 7.0, true)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(panel, "position:y", H * 1.45, 0.6).set_trans(Tween.TRANS_SINE)
	shape.set_deferred("disabled", true)


func close() -> void:
	if not is_open or stay_open:
		return
	is_open = false
	Sound.play_at("door", global_position, -8.0, 0.9)
	shape.set_deferred("disabled", false)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(panel, "position:y", H / 2.0, 0.6).set_trans(Tween.TRANS_SINE)


## Monsters open doors just by being next to them.
func monster_near() -> void:
	if kind == "door" or unlocked:
		open(false)


func _process(delta: float) -> void:
	if not is_open or stay_open:
		return
	_close_t -= delta
	if _close_t <= 0.0:
		if sector.anyone_near(global_position, 2.2):
			_close_t = 1.0
		else:
			close()
