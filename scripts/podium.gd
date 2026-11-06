extends Node3D
## The Grand Prix trophy ceremony: the top three cars on a podium, confetti,
## a trophy, the final points table, and stars and unlocks for the players.

var _cam: Camera3D
var _angle := 0.0
var _cars: Array[ToyCarModel] = []
var _t := 0.0


func _ready() -> void:
	var standings := Game.gp_standings()
	_build_stage(standings)
	_build_ui(standings)
	Sfx.play_music("results", -6.0)
	Game.end_grand_prix()


func _process(delta: float) -> void:
	_t += delta
	_angle += delta * 0.25
	_cam.position = Vector3(3.0 + sin(_angle) * 4.0, 12.0 + sin(_t * 0.5), 30.0 + cos(_angle) * 3.0)
	_cam.look_at(Vector3(3.0, 1.5, 0), Vector3.UP)
	for i in _cars.size():
		_cars[i].animate(0.0, 0.0, delta)
		_cars[i].rotation.y = sin(_t * 1.2 + i) * 0.25


func _build_stage(standings: Array) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.1, 0.32)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 1.0)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.light_energy = 1.0
	add_child(sun)
	Game.apply_quality(env, sun)
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
	for x: float in [-8.0, 0.0, 8.0]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(x, 22, 8)
		spot.look_at_from_position(spot.position, Vector3(x * 0.6, 3, 0), Vector3.UP)
		spot.spot_range = 40.0
		spot.spot_angle = 18.0
		spot.light_energy = 6.0
		spot.light_color = Color.from_hsv(randf(), 0.3, 1.0)
		add_child(spot)

	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(140, 140)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = ImageTexture.create_from_image(Room.checker_image(Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.12), 2))
	fm.uv1_scale = Vector3(14, 14, 1)
	fm.roughness = 0.3
	floor_mi.material_override = fm
	add_child(floor_mi)

	# Podium blocks: 2nd on the left, 1st in the middle, 3rd on the right.
	var heights := [4.0, 2.8, 2.0]
	var xs := [0.0, -7.0, 7.0]
	var cols := [Color(1.0, 0.8, 0.2), Color(0.8, 0.82, 0.88), Color(0.85, 0.52, 0.28)]
	for place in 3:
		var block := MeshInstance3D.new()
		block.mesh = MeshKit.rounded_box(Vector3(6.4, heights[place], 6.0), 0.4, 3)
		block.material_override = ToyCarModel.plastic(cols[place], 0.3)
		block.position = Vector3(xs[place], heights[place] * 0.5, 0)
		add_child(block)
		var num := Label3D.new()
		num.text = str(place + 1)
		num.font_size = 160
		num.pixel_size = 0.02
		num.outline_size = 24
		num.position = Vector3(xs[place], heights[place] * 0.5, 3.05)
		add_child(num)
		if place < standings.size():
			var row: Dictionary = standings[place]
			var car_def := CarData.get_car(int(row["car"]))
			var look := Game.custom_for(car_def["id"]) if int(row["player"]) > 0 else {}
			var model := ToyCarModel.new().setup(car_def, false, look)
			model.scale = Vector3.ONE * 2.2
			model.position = Vector3(xs[place], heights[place], 0)
			add_child(model)
			_cars.append(model)
			var name_l := Label3D.new()
			name_l.text = row["name"]
			name_l.font_size = 64
			name_l.pixel_size = 0.025
			name_l.outline_size = 14
			name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			name_l.modulate = Color(1.0, 0.95, 0.5) if int(row["player"]) > 0 else Color.WHITE
			name_l.position = Vector3(xs[place], heights[place] + 5.0, 0)
			add_child(name_l)
	var cup := Trophy.make(1)
	cup.scale = Vector3.ONE * 0.9
	cup.position = Vector3(0, 4.0, -3.5)
	add_child(cup)

	var confetti := CPUParticles3D.new()
	confetti.amount = 400
	confetti.lifetime = 6.0
	confetti.position = Vector3(0, 26, 0)
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	confetti.emission_box_extents = Vector3(20, 1, 10)
	confetti.direction = Vector3.DOWN
	confetti.initial_velocity_min = 1.0
	confetti.initial_velocity_max = 3.0
	confetti.gravity = Vector3(0, -3, 0)
	confetti.angular_velocity_min = -300.0
	confetti.angular_velocity_max = 300.0
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.3)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.vertex_color_use_as_albedo = true
	qm.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = qm
	confetti.mesh = q
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	grad.colors = PackedColorArray([Color.RED, Color.YELLOW, Color(0.2, 1, 0.3), Color(0.2, 0.6, 1), Color.MAGENTA])
	confetti.color_initial_ramp = grad
	add_child(confetti)

	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true


func _build_ui(standings: Array) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.ui_theme
	layer.add_child(root)

	# Best place of a human player decides the trophy.
	var best := 99
	for i in standings.size():
		if int(standings[i]["player"]) > 0:
			best = mini(best, i + 1)
	var headline := "GRAND PRIX COMPLETE!"
	var col := Color(1.0, 0.85, 0.2)
	if best == 1:
		headline = "GRAND PRIX CHAMPION!"
		Sfx.play("win")
		get_tree().create_timer(1.0).timeout.connect(func(): Sfx.play("voice_congrats"))
	elif best <= 3:
		headline = "%s TROPHY!" % Trophy.NAMES[best - 1].to_upper()
		Sfx.play("finish")
		get_tree().create_timer(1.0).timeout.connect(func(): Sfx.play("voice_congrats"))
	else:
		Sfx.play("finish")
		col = Color(0.7, 0.9, 1.0)
	var title := RaceHud.make_label(headline, 64, col, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RaceHud.pin(title, Vector2(0.5, 0), Vector2(-600, 12), Vector2(1200, 80))
	root.add_child(title)

	var panel := PanelContainer.new()
	RaceHud.pin(panel, Vector2(0, 1), Vector2(16, -250), Vector2(380, 234))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	box.add_child(RaceHud.make_label("Final points  (%s)" % Game.DIFFICULTY_NAMES[Game.difficulty], 20, Color(1.0, 0.9, 0.5), 8))
	for i in standings.size():
		var row: Dictionary = standings[i]
		var l := RaceHud.make_label("%s   %s   %d pts" % [Game.ordinal(i + 1), row["name"], int(row["points"])], 20, Color(1.0, 0.95, 0.5) if int(row["player"]) > 0 else Color.WHITE, 6)
		box.add_child(l)

	# Rewards: a trophy for the shelf plus bonus stars.
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 8)
	RaceHud.pin(right, Vector2(1, 1), Vector2(-560, -330), Vector2(540, 314))
	root.add_child(right)
	var fresh: Array = []
	if best <= 3:
		fresh.append_array(Game.award_trophy(best))
		var bonus: int = [5, 3, 2][best - 1]
		fresh.append_array(Game.award_stars(bonus))
		var t := RaceHud.make_label("+%d ★ bonus!  Your %s trophy is on the bedroom shelf." % [bonus, Trophy.NAMES[best - 1]], 22, Color(1.0, 0.9, 0.3), 8)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(t)
	for id in fresh:
		var it := Unlocks.get_item(id)
		var l := RaceHud.make_label("NEW!  %s unlocked!" % it.get("name", id), 26, Color(1.0, 0.6, 0.95), 8)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(l)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	right.add_child(buttons)
	var again := Button.new()
	again.text = "New Grand Prix"
	again.pressed.connect(func():
		Sfx.play("select")
		Game.start_grand_prix()
		Game.goto_garage())
	buttons.add_child(again)
	var menu := Button.new()
	menu.text = "Menu"
	menu.pressed.connect(func():
		Sfx.play("select")
		Game.goto_menu())
	buttons.add_child(menu)
	menu.grab_focus.call_deferred()
