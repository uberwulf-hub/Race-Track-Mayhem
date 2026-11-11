extends Node3D
## The Showroom: every car on its own spinning pedestal in a big shiny
## garage, with your Grand Prix trophies and badge medals on the shelves.
## Locked cars are dark mystery shapes that say how to get them. Slide along
## the row, and pick the car you like to race with it.

const SPACING := 9.0

var _index := 0
var _cam: Camera3D
var _cam_x := 0.0
var _turntables: Array[Node3D] = []
var _name_label: Label
var _info_label: Label
var _drive_button: Button
var _time := 0.0


func _ready() -> void:
	Sfx.play_music("garage")
	_index = clampi(Game.selected_car, 0, CarData.count() - 1)
	_build_scene()
	_build_ui()
	_cam_x = _index * SPACING
	_show()


func _process(delta: float) -> void:
	_time += delta
	for i in _turntables.size():
		_turntables[i].rotation.y += delta * (0.9 if i == _index else 0.25)
	_cam_x = lerpf(_cam_x, _index * SPACING, minf(1.0, delta * 4.0))
	_cam.position = Vector3(_cam_x, 5.5, 15.0)
	_cam.look_at(Vector3(_cam_x, 3.0, -2.0), Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("steer_left"):
		_step(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("steer_right"):
		_step(1)
	elif event.is_action_pressed("ui_cancel"):
		Sfx.play("back")
		Game.goto_menu()


func _step(d: int) -> void:
	_index = wrapi(_index + d, 0, CarData.count())
	Sfx.play("click", 1.0 + d * 0.1)
	_show()


func _show() -> void:
	var car := CarData.get_car(_index)
	var have := CarData.is_available(_index)
	var nick := CarData.nickname(Game.custom_for(car["id"]))
	_name_label.text = (nick if nick != "" else String(car["name"])) if have else "? ? ?"
	_name_label.add_theme_color_override("font_color", (car["body"] as Color).lightened(0.3) if have else Color(0.7, 0.7, 0.78))
	if have:
		_info_label.text = String(car["blurb"])
	else:
		_info_label.text = "LOCKED: " + Unlocks.requirement_text(Unlocks.get_item(String(car.get("unlock", ""))))
	_drive_button.disabled = not have
	_drive_button.text = "Your car!" if have and _index == Game.selected_car else "Drive this car"


func _drive() -> void:
	if not CarData.is_available(_index):
		return
	Game.selected_car = _index
	Game.save_settings()
	Sfx.play("go")
	_show()


# ---------------------------------------------------------------------------
# The room
# ---------------------------------------------------------------------------

func _build_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.12, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 1.0)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, 20, 0)
	key.light_energy = 0.8
	key.shadow_enabled = true
	add_child(key)
	Game.apply_quality(env, key)
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false

	var n := CarData.count()
	var length := n * SPACING + 20.0
	var mid := (n - 1) * SPACING * 0.5
	# Shiny chequered showroom floor.
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(length + 40.0, 40.0)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for x in 64:
		for y in 64:
			img.set_pixel(x, y, Color(0.92, 0.92, 0.95) if ((x / 32) + (y / 32)) % 2 == 0 else Color(0.18, 0.18, 0.22))
	fm.albedo_texture = ImageTexture.create_from_image(img)
	fm.uv1_scale = Vector3((length + 40.0) / 8.0, 5.0, 1.0)
	fm.roughness = 0.15
	fm.metallic_specular = 0.8
	floor_mi.material_override = fm
	floor_mi.position = Vector3(mid, 0, 0)
	add_child(floor_mi)
	# Back wall with a big sign.
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(length + 40.0, 16.0, 0.5)
	wall.mesh = wm
	wall.material_override = ToyCarModel.plastic(Color(0.25, 0.3, 0.55), 0.8)
	wall.position = Vector3(mid, 8.0, -6.0)
	add_child(wall)
	# The sign, repeated along the wall so it's always in view.
	var sx := 4.0
	while sx < length - 10.0:
		var sign := Label3D.new()
		sign.text = "%s'S SHOWROOM" % (Game.player_name.to_upper() if Game.player_name != "" else "MY")
		sign.font_size = 120
		sign.pixel_size = 0.012
		sign.outline_size = 24
		sign.modulate = Color(1.0, 0.85, 0.25)
		sign.position = Vector3(sx, 10.6, -5.6)
		add_child(sign)
		sx += 30.0

	# A pedestal and a car for every car in the game.
	for i in n:
		var x := i * SPACING
		var have := CarData.is_available(i)
		var ped := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 3.2
		cm.bottom_radius = 3.5
		cm.height = 0.8
		ped.mesh = cm
		ped.material_override = ToyCarModel.chrome() if have else ToyCarModel.plastic(Color(0.3, 0.3, 0.35), 0.6)
		ped.position = Vector3(x, 0.4, 0)
		add_child(ped)
		var spot := SpotLight3D.new()
		spot.position = Vector3(x, 12.0, 2.0)
		spot.rotation_degrees = Vector3(-80, 0, 0)
		spot.spot_angle = 18.0
		spot.spot_range = 20.0
		spot.light_energy = 3.0 if have else 0.6
		spot.light_color = Color(1.0, 0.95, 0.85)
		add_child(spot)
		var table := Node3D.new()
		table.position = Vector3(x, 0.8, 0)
		add_child(table)
		_turntables.append(table)
		var car := CarData.get_car(i)
		var model := ToyCarModel.new().setup(car, true, Game.custom_for(car["id"]) if have else {})
		model.scale = Vector3.ONE * 1.6
		table.add_child(model)
		if not have:
			_silhouette(model)
			var q := Label3D.new()
			q.text = "?"
			q.font_size = 200
			q.pixel_size = 0.012
			q.outline_size = 24
			q.modulate = Color(1.0, 0.9, 0.4)
			q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			q.position = Vector3(x, 5.0, 0)
			add_child(q)

	_shelves(mid, length)

	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true


## Shelves on the back wall: Grand Prix trophies and badge medals.
func _shelves(mid: float, length: float) -> void:
	var wood := ToyCarModel.plastic(Color(0.6, 0.42, 0.25), 0.6)
	for row in 2:
		var shelf := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(length + 30.0, 0.3, 1.6)
		shelf.mesh = bm
		shelf.material_override = wood
		shelf.position = Vector3(mid, 4.2 + row * 3.4, -5.0)
		add_child(shelf)
	# Trophies on the lower shelf by the first cars, one per difficulty won.
	for d in 3:
		if Game.trophies.has(d):
			var cup := Trophy.make(int(Game.trophies[d]), Game.DIFFICULTY_NAMES[d])
			cup.scale = Vector3.ONE * 0.5
			cup.position = Vector3(-3.0 + d * 3.0, 4.35, -5.0)
			add_child(cup)
	# Every badge you've earned as a medal on the shelves, spread along the wall.
	var earned: Array = Game.badges
	var gap := clampf(length / maxf(1.0, earned.size()), 2.2, 4.0)
	for k in earned.size():
		var b := Badges.get_badge(String(earned[k]))
		if b.is_empty():
			continue
		var medal := Node3D.new()
		medal.position = Vector3(-6.0 + k * gap + (0.0 if k % 2 == 0 else 0.0), 8.3 if k % 2 == 0 else 5.0, -4.9)
		if k % 2 == 1:
			medal.position.x += 6.0   # lower-shelf medals sit past the trophies
		add_child(medal)
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.8
		cm.bottom_radius = 0.8
		cm.height = 0.15
		disc.mesh = cm
		disc.rotation.x = PI * 0.5
		var mm := StandardMaterial3D.new()
		mm.albedo_color = b["color"]
		mm.metallic = 0.6
		mm.roughness = 0.25
		disc.material_override = mm
		medal.add_child(disc)
		var sym := Label3D.new()
		sym.text = String(b["symbol"])
		sym.font_size = 64
		sym.pixel_size = 0.008
		sym.outline_size = 10
		sym.position = Vector3(0, 0, 0.1)
		medal.add_child(sym)
	if earned.is_empty() and Game.trophies.is_empty():
		var hint := Label3D.new()
		hint.text = "Win cups and badges to fill these shelves!"
		hint.font_size = 64
		hint.pixel_size = 0.012
		hint.outline_size = 12
		hint.position = Vector3(6.0, 6.2, -4.8)
		add_child(hint)


func _silhouette(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ToyCarModel.plastic(Color(0.08, 0.06, 0.14), 0.6)
		elif c is Label3D or c is Light3D:
			c.visible = false
		_silhouette(c)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.ui_theme
	layer.add_child(root)
	_name_label = RaceHud.make_label("", 46, Color.WHITE, 14)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RaceHud.pin(_name_label, Vector2(0.5, 1), Vector2(-500, -230), Vector2(1000, 60))
	root.add_child(_name_label)
	_info_label = RaceHud.make_label("", 22, Color(0.9, 0.92, 1.0), 8)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RaceHud.pin(_info_label, Vector2(0.5, 1), Vector2(-450, -170), Vector2(900, 60))
	root.add_child(_info_label)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 18)
	RaceHud.pin(bottom, Vector2(0.5, 1), Vector2(-450, -96), Vector2(900, 80))
	root.add_child(bottom)
	_button(bottom, "Back", func():
		Sfx.play("back")
		Game.goto_menu())
	_button(bottom, "  <  ", func(): _step(-1))
	_drive_button = _button(bottom, "Drive this car", _drive)
	_drive_button.add_theme_font_size_override("font_size", 34)
	_button(bottom, "  >  ", func(): _step(1))
	var count := 0
	for i in CarData.count():
		if CarData.is_available(i):
			count += 1
	var tally := RaceHud.make_label("%d of %d cars   %d badges" % [count, CarData.count(), Game.badges.size()], 24, Color(1.0, 0.9, 0.4), 8)
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	RaceHud.pin(tally, Vector2(0, 0), Vector2(22, 70), Vector2(400, 40))
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(tally)
	var title := RaceHud.make_label("SHOWROOM", 44, Color(1.0, 0.85, 0.25), 14)
	RaceHud.pin(title, Vector2(0, 0), Vector2(20, 10), Vector2(400, 60))
	root.add_child(title)


func _button(parent: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	parent.add_child(b)
	return b
