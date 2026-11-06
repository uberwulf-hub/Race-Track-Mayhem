class_name Spectators
extends RefCounted
## A crowd of toys watching the race from beside the track: teddy bears,
## bunnies, robots, dinosaurs and rubber ducks. They bounce and wave, and
## cheer harder when the cars zoom past.

const KINDS := ["bear", "bunny", "robot", "dino", "duck"]


static func build(room: Room, track: Track, count: int = 16) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777 + track.layout_id
	var crowd := Node3D.new()
	crowd.name = "Spectators"
	room.add_child(crowd)
	var placed: Array[Vector3] = []
	# Most of the crowd gathers near the start line, the rest around the track.
	var candidates: Array[float] = []
	for k in 10:
		candidates.append(-12.0 + k * 3.0)
	var step := track.length / 24.0
	for k in 24:
		candidates.append(k * step + rng.randf() * step * 0.5)
	for s in candidates:
		if placed.size() >= count:
			break
		var t := track.sample(s)
		if t.basis.y.y < 0.85:
			continue   # skip loops, corkscrews and banked bits
		for side: float in [-1.0, 1.0]:
			var out := Vector3(t.basis.x.x, 0.0, t.basis.x.z).normalized() * side
			var p := Vector3(t.origin.x, 0.0, t.origin.z) + out * rng.randf_range(8.0, 11.0)
			if not room._clear_of_track(p, 2.5) or not room.room_rect.grow(-6.0).has_point(Vector2(p.x, p.z)):
				continue
			var too_close := false
			for q in placed:
				if q.distance_to(p) < 5.5:
					too_close = true
					break
			if too_close:
				continue
			placed.append(p)
			var fig := _make(room, KINDS[rng.randi() % KINDS.size()], rng)
			crowd.add_child(fig)
			fig.position = p
			fig.look_at_from_position(p, Vector3(t.origin.x, 0.0, t.origin.z), Vector3.UP)
			fig.rotate_y(PI)   # models face +Z; look_at points -Z at the track
			_animate(room, track, fig, rng.randf() * TAU)
			if placed.size() >= count:
				break


static func _animate(room: Room, track: Track, fig: Node3D, phase: float) -> void:
	var body: Node3D = fig.get_child(0)
	var arms: Array = fig.get_meta("arms", [])
	var base_y := body.position.y
	room.animate(func(t: float, _d: float):
		# Find the nearest car to get excited about.
		var excite := 0.25
		var parent := room.get_parent()
		if parent and parent.get("racers") != null:
			for r in parent.racers:
				var dist := (r as Node3D).global_position.distance_to(fig.global_position)
				excite = maxf(excite, clampf(1.0 - (dist - 6.0) / 14.0, 0.0, 1.0))
		var bounce := absf(sin(t * (4.0 + excite * 6.0) + phase)) * (0.15 + excite * 0.9)
		body.position.y = base_y + bounce
		for i in arms.size():
			var arm: Node3D = arms[i]
			var side := -1.0 if i == 0 else 1.0
			arm.rotation.z = side * (0.4 + excite * (1.2 + sin(t * 9.0 + phase + i) * 0.6)))


static func _mat(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _ball(parent: Node3D, r: float, pos: Vector3, mat: Material, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi


static func _block(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.rounded_box(size, minf(size.x, minf(size.y, size.z)) * 0.25, 2)
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## An arm that pivots at the shoulder so it can wave.
static func _arm(body: Node3D, side: float, at: Vector3, length: float, mat: Material, thick: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at + Vector3(side * 0.1, 0, 0)
	body.add_child(pivot)
	_ball(pivot, thick, Vector3(side * length * 0.5, 0, 0), mat, Vector3(length / (thick * 2.0), 1.0, 1.0))
	return pivot


static func _make(room: Room, kind: String, rng: RandomNumberGenerator) -> Node3D:
	var fig := Node3D.new()
	var body := Node3D.new()
	fig.add_child(body)
	var eye := _mat(Color(0.05, 0.05, 0.08), 0.2)
	var arms: Array = []
	var s := rng.randf_range(0.85, 1.15)
	match kind:
		"bear":
			var fur := _mat(Color.from_hsv(rng.randf_range(0.05, 0.1), 0.55, rng.randf_range(0.5, 0.75)), 1.0)
			_ball(body, 1.6, Vector3(0, 1.7, 0), fur, Vector3(1, 1.1, 0.9))
			_ball(body, 1.3, Vector3(0, 3.8, 0), fur)
			for side: float in [-1.0, 1.0]:
				_ball(body, 0.5, Vector3(side * 0.9, 4.9, 0), fur)
				_ball(body, 0.17, Vector3(side * 0.45, 4.0, 1.15), eye)
				arms.append(_arm(body, side, Vector3(side * 1.3, 2.3, 0), 1.4, fur, 0.45))
			_ball(body, 0.55, Vector3(0, 3.6, 1.1), _mat(Color(0.9, 0.78, 0.6), 1.0), Vector3(1, 0.8, 0.6))
		"bunny":
			var fur := _mat(Color(0.97, 0.95, 0.97), 1.0)
			_ball(body, 1.4, Vector3(0, 1.5, 0), fur, Vector3(1, 1.15, 0.95))
			_ball(body, 1.15, Vector3(0, 3.4, 0), fur)
			for side: float in [-1.0, 1.0]:
				var ear := _ball(body, 0.4, Vector3(side * 0.45, 5.1, 0), fur, Vector3(0.8, 3.0, 0.6))
				ear.rotation.z = -side * 0.15
				_ball(body, 0.15, Vector3(side * 0.4, 3.6, 1.0), eye)
				arms.append(_arm(body, side, Vector3(side * 1.1, 2.0, 0), 1.2, fur, 0.38))
			_ball(body, 0.22, Vector3(0, 3.25, 1.12), _mat(Color(1.0, 0.55, 0.65)))
		"robot":
			var metal := _mat(Color.from_hsv(rng.randf(), 0.5, 0.85), 0.3)
			_block(body, Vector3(2.4, 2.4, 1.6), Vector3(0, 1.8, 0), metal)
			_block(body, Vector3(1.8, 1.5, 1.4), Vector3(0, 3.9, 0), metal)
			var glow := _mat(Color(0.3, 1.0, 1.0))
			glow.emission_enabled = true
			glow.emission = Color(0.3, 1.0, 1.0)
			for side: float in [-1.0, 1.0]:
				_ball(body, 0.22, Vector3(side * 0.45, 4.0, 0.72), glow)
				arms.append(_arm(body, side, Vector3(side * 1.25, 2.6, 0), 1.3, metal, 0.32))
			var ant := _ball(body, 0.25, Vector3(0, 5.2, 0), _mat(Color(1.0, 0.3, 0.3), 0.3))
			ant.name = "Antenna"
		"dino":
			var skin := _mat(Color.from_hsv(rng.randf_range(0.25, 0.4), 0.6, 0.7), 0.7)
			_ball(body, 1.5, Vector3(0, 1.6, 0), skin, Vector3(1, 1.2, 1.1))
			_ball(body, 1.0, Vector3(0, 3.5, 0.6), skin, Vector3(1, 0.9, 1.3))
			var tail := _ball(body, 0.6, Vector3(0, 1.0, -1.8), skin, Vector3(0.8, 0.8, 2.2))
			tail.rotation.x = 0.3
			for k in 4:
				_ball(body, 0.3, Vector3(0, 3.0 - k * 0.7, -0.6 - k * 0.3), _mat(Color(1.0, 0.6, 0.2)))
			for side: float in [-1.0, 1.0]:
				_ball(body, 0.15, Vector3(side * 0.45, 3.8, 1.5), eye)
				arms.append(_arm(body, side, Vector3(side * 1.2, 2.3, 0.5), 0.8, skin, 0.25))
		_:  # duck
			var yellow := _mat(Color(1.0, 0.85, 0.1), 0.2)
			_ball(body, 1.6, Vector3(0, 1.4, 0), yellow, Vector3(1, 0.8, 1.2))
			_ball(body, 1.0, Vector3(0, 3.0, 0.6), yellow)
			_ball(body, 0.5, Vector3(0, 2.8, 1.6), _mat(Color(1.0, 0.45, 0.05), 0.3), Vector3(1, 0.5, 1.3))
			for side: float in [-1.0, 1.0]:
				_ball(body, 0.15, Vector3(side * 0.45, 3.3, 1.4), eye)
				arms.append(_arm(body, side, Vector3(side * 1.5, 1.6, 0), 1.0, yellow, 0.3))
	fig.scale = Vector3.ONE * s
	fig.set_meta("arms", arms)
	# A little sign some of them hold up.
	if rng.randf() < 0.35:
		var sign := Label3D.new()
		sign.text = ["GO GO GO!", "VROOM!", "WOOHOO!", "FAST!", "YAY!"][rng.randi() % 5]
		sign.font_size = 64
		sign.pixel_size = 0.03
		sign.outline_size = 12
		sign.modulate = Color(1.0, 0.9, 0.3)
		sign.position = Vector3(0, 7.0, 0.3)
		body.add_child(sign)
	return fig
