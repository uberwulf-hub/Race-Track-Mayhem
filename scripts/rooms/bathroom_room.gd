class_name BathroomRoom
extends Room
## Bubble Bath Bash's room: blue and white tiles, a bubbly bathtub, a GIANT
## rubber duck, toilet, sink and mirror, towels, shampoo bottles and soap
## bubbles floating around.


func _configure() -> void:
	background_color = Color(0.8, 0.92, 1.0)
	ambient_color = Color(0.92, 0.97, 1.0)
	ambient_energy = 0.3
	sun_color = Color(0.95, 0.98, 1.0)
	lamp_color = Color(0.95, 0.98, 1.0)
	curtain_color = Color(0.5, 0.8, 0.95)
	door_color = Color(0.9, 0.95, 1.0)
	trim_color = Color(0.3, 0.55, 0.85)
	floor_tile_size = 12.0
	floor_roughness = 0.2
	wall_tile_size = 10.0
	exposure = 0.78          # less washed out
	saturation = 1.25


func _floor_image() -> Image:
	return Room.checker_image(Color(0.95, 0.97, 1.0), Color(0.4, 0.66, 0.95), 4, Color(0.75, 0.82, 0.9))


func _wall_image() -> Image:
	return Room.tiles_image(Color(0.7, 0.88, 0.96), Color(0.92, 0.97, 1.0), 4, Color(0.4, 0.7, 0.95))


func _build_props() -> void:
	_bath_mat()
	_bathtub()
	_giant_duck()
	_toilet()
	_sink()
	_towels()
	_bottles()
	_bubbles()


func _bath_mat() -> void:
	var tr := track.get_aabb_xz()
	var mat := _box(Vector3(tr.size.x * 0.5, 0.3, tr.size.y * 0.4), Vector3(tr.get_center().x, 0.15, tr.get_center().y), _mat(Color(0.98, 0.6, 0.75), 1.0), false, null, 0.4)
	mat.name = "BathMat"


func _bathtub() -> void:
	var r := room_rect
	var tub := _node("Bathtub", Vector3(r.position.x + 18.0, 0.0, r.position.y + 50.0))
	var white := _shiny(Color(0.98, 0.98, 1.0))
	_box(Vector3(30.0, 18.0, 64.0), Vector3(0, 11.0, 0), white, true, tub, 0.3)
	var water := _mat(Color(0.45, 0.75, 0.95), 0.05)
	water.metallic_specular = 1.0
	_box(Vector3(25.0, 0.4, 59.0), Vector3(0, 19.0, 0), water, false, tub, 0.0)
	for x: float in [-11.0, 11.0]:      # claw feet
		for z: float in [-27.0, 27.0]:
			_sphere(2.2, Vector3(x, 2.0, z), _shiny(Color(0.9, 0.75, 0.3)), Vector3.ONE, tub)
	# Bubbles piled up in the tub
	var foam := _mat(Color(1, 1, 1), 0.9)
	for i in 28:
		_sphere(_rng.randf_range(2.0, 4.0), Vector3(_rng.randf_range(-10, 10), 19.5 + _rng.randf_range(0, 2.5), _rng.randf_range(-26, 26)), foam, Vector3(1, 0.8, 1), tub)
	# Taps
	var gold := _shiny(Color(0.9, 0.75, 0.3))
	_cylinder(0.9, 7.0, Vector3(0, 23.0, -30.0), gold, tub)
	var spout := _cylinder(0.7, 5.0, Vector3(0, 26.0, -28.0), gold, tub)
	spout.rotation.x = PI * 0.5
	# A little duck floating in the tub
	_duck(tub, Vector3(4.0, 21.5, 10.0), 1.0)


func _duck(parent: Node3D, pos: Vector3, s: float) -> void:
	var yellow := _shiny(Color(1.0, 0.85, 0.1))
	var d := Node3D.new()
	d.position = pos
	d.scale = Vector3.ONE * s
	d.rotation.y = 0.6
	parent.add_child(d)
	_sphere(3.0, Vector3(0, 0, 0), yellow, Vector3(1.0, 0.75, 1.3), d)
	_sphere(2.0, Vector3(0, 2.6, -2.0), yellow, Vector3.ONE, d)
	_sphere(1.0, Vector3(0, 2.2, -3.8), _shiny(Color(1.0, 0.45, 0.05)), Vector3(1.0, 0.45, 1.2), d)
	for side: float in [-1.0, 1.0]:
		_sphere(0.35, Vector3(side * 0.9, 3.2, -3.5), _mat(Color(0.05, 0.05, 0.05), 0.2), Vector3.ONE, d)
	_sphere(1.4, Vector3(0, 1.2, 3.4), yellow, Vector3(1.0, 1.0, 0.6), d)


func _giant_duck() -> void:
	var spots := _free_spots(1, 13.0, _inner_area(18.0))
	if spots.is_empty():
		return
	var holder := _node("GiantDuck", spots[0], _rng.randf() * TAU)
	_duck(holder, Vector3(0, 7.5, 0), 3.2)
	var base_rot := holder.rotation.y
	animate(func(t: float, _d: float):
		holder.rotation.z = sin(t * 1.4) * 0.06
		holder.rotation.y = base_rot + sin(t * 0.5) * 0.15)


func _toilet() -> void:
	var r := room_rect
	var t := _node("Toilet", Vector3(r.end.x - 14.0, 0.0, r.position.y + 26.0), -PI * 0.5)
	var white := _shiny(Color(0.98, 0.98, 1.0))
	_cylinder(5.0, 12.0, Vector3(0, 6.0, 0), white, t, 6.0)
	_cylinder(7.5, 3.0, Vector3(0, 13.5, 1.5), white, t)
	_cylinder(7.0, 0.8, Vector3(0, 15.4, 1.5), _mat(Color(0.55, 0.78, 0.95), 0.3), t)
	_box(Vector3(14.0, 14.0, 6.0), Vector3(0, 20.0, 10.0), white, true, t)
	_sphere(1.0, Vector3(5.0, 25.0, 9.0), _shiny(Color(0.85, 0.85, 0.9)), Vector3.ONE, t)
	# Toilet paper on the wall
	var roll := _cylinder(2.6, 4.0, Vector3(r.end.x - 0.5 - 3.0, 14.0, r.position.y + 42.0), _mat(Color(1, 1, 1), 1.0))
	roll.rotation.x = PI * 0.5


func _sink() -> void:
	var r := room_rect
	var cx := r.position.x + r.size.x * 0.3
	var z := r.position.y + 9.0
	var white := _shiny(Color(0.98, 0.98, 1.0))
	_cylinder(2.5, 26.0, Vector3(cx, 13.0, z), white, null, 2.0)
	_box(Vector3(18.0, 5.0, 13.0), Vector3(cx, 27.5, z), white, true, null, 0.4)
	_cylinder(0.6, 5.0, Vector3(cx, 32.0, z - 5.0), _shiny(Color(0.85, 0.85, 0.9)))
	# Mirror
	var mirror := _mat(Color(0.8, 0.9, 0.95), 0.02)
	mirror.metallic = 0.9
	_box(Vector3(20.0, 24.0, 0.5), Vector3(cx, 46.0, r.position.y + 0.4), mirror, false, null, 0.0)
	_box(Vector3(22.0, 26.0, 0.3), Vector3(cx, 46.0, r.position.y + 0.2), _mat(Color(0.3, 0.55, 0.85)), false, null, 0.0)
	# Toothbrush cup
	_cylinder(1.6, 4.0, Vector3(cx + 6.0, 32.0, z), _mat(Color(0.95, 0.5, 0.6), 0.3))
	for i in 2:
		var brush := _cylinder(0.25, 7.0, Vector3(cx + 5.5 + i, 35.0, z), _mat([Color(0.3, 0.6, 0.95), Color(0.3, 0.85, 0.4)][i], 0.3))
		brush.rotation.z = (i - 0.5) * 0.4


func _towels() -> void:
	var r := room_rect
	var x := r.end.x - 0.6
	var cols := [Color(0.95, 0.55, 0.65), Color(0.55, 0.85, 0.75), Color(1.0, 0.85, 0.4)]
	_upright(_cylinder(0.5, 60.0, Vector3(x - 2.0, 40.0, r.position.y + 90.0), _shiny(Color(0.85, 0.85, 0.9))))
	for i in 3:
		_box(Vector3(1.2, 26.0, 16.0), Vector3(x - 2.5, 28.0, r.position.y + 70.0 + i * 19.0), _mat(cols[i], 1.0), true, null, 0.3)


func _bottles() -> void:
	var cols := [Color(0.95, 0.4, 0.6), Color(0.4, 0.7, 0.95), Color(0.5, 0.9, 0.5), Color(1.0, 0.75, 0.3)]
	var spots := _free_spots(5, 3.0, _inner_area(10.0))
	for i in spots.size():
		var p := spots[i]
		var h := _rng.randf_range(7.0, 11.0)
		_box(Vector3(4.0, h, 2.6), p + Vector3(0, h * 0.5, 0), _shiny(cols[i % cols.size()]), true, null, 0.35)
		_cylinder(1.0, 2.0, p + Vector3(0, h + 1.0, 0), _mat(Color(0.95, 0.95, 0.95), 0.3))
		_label("SHAMPOO" if i % 2 == 0 else "BUBBLES", p + Vector3(0, h * 0.5, 1.35), 40, 0.02, Color.WHITE)


func _bubbles() -> void:
	var bubble := StandardMaterial3D.new()
	bubble.albedo_color = Color(0.85, 0.95, 1.0, 0.25)
	bubble.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble.roughness = 0.0
	bubble.metallic_specular = 1.0
	bubble.rim_enabled = true
	bubble.rim = 1.0
	var area := _inner_area(10.0)
	for i in 24:
		var p := Vector3(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(14.0, 45.0), _rng.randf_range(area.position.y, area.end.y))
		var b := _sphere(_rng.randf_range(1.5, 4.0), p, bubble)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var speed := _rng.randf_range(1.0, 2.5)
		var ph := _rng.randf() * TAU
		var x0 := p.x
		animate(func(t: float, d: float):
			b.position.y += speed * d
			b.position.x = x0 + sin(t * 0.7 + ph) * 2.0
			if b.position.y > 60.0:
				b.position.y = 12.0)
