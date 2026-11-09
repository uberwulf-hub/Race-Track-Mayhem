class_name PowerUps
extends Node3D
## Power-ups! Rainbow "?" boxes sit across the track. Drive through one to get
## a random power-up, then use it (E / Y button):
##   Bubble Blaster - shoots a soap bubble forward; a car it hits floats slowly in a bubble
##   Bouncy Ball    - a ball that zig-zags off the rails and spins out cars it hits
##   Water Balloon  - drops a slippery puddle behind you
##   Rocket Boost   - a big burst of speed
##   Bubble Shield  - blocks the next hit
##   Toy Magnet     - pulls you along to the car ahead
##   Banana Peel    - drops a peel behind you; cars that hit it spin round
##   Toy Parachute  - your jumps float down gently and land safely
## Cars further back get better power-ups, and the computer cars use them too.
## Everything moves along the track (distance + sideways), just like the cars,
## so it works through loops and corkscrews.

signal item_got(racer: Racer, kind: String)
signal item_hit(victim: Racer, kind: String, by: Racer)
signal item_used(racer: Racer, kind: String, side: float)   # for online races

var online := false   # online: hits only count for cars driven on this computer

const KINDS := ["bubble", "ball", "balloon", "rocket", "shield", "magnet", "banana", "parachute"]
const NAMES := {"bubble": "Bubble Blaster", "ball": "Bouncy Ball", "balloon": "Water Balloon", "rocket": "Rocket Boost", "shield": "Bubble Shield",
	"magnet": "Toy Magnet", "banana": "Banana Peel", "parachute": "Toy Parachute"}
const COLORS := {"bubble": Color(0.55, 0.85, 1.0), "ball": Color(1.0, 0.35, 0.3), "balloon": Color(0.3, 0.6, 1.0), "rocket": Color(1.0, 0.6, 0.15), "shield": Color(0.6, 1.0, 0.7),
	"magnet": Color(0.95, 0.25, 0.35), "banana": Color(1.0, 0.88, 0.25), "parachute": Color(0.75, 0.55, 1.0)}
const MAGNET_TIME := 3.5
const PARACHUTE_TIME := 12.0
const BOX_RESPAWN := 4.0
const BOX_LANES := [-2.2, 0.0, 2.2]

var track: Track
var racers: Array[Racer] = []
var _boxes: Array = []        # [{s, lat, node, timer}]
var _shots: Array = []        # [{kind, s, total, lat, lat_vel, speed, life, owner, node}]
var _puddles: Array = []      # [{s, lat, life, node, owner}]
var _ai_wait: Dictionary = {} # racer -> seconds before it uses its item
var _time := 0.0


func setup(p_track: Track, p_racers: Array[Racer]) -> void:
	track = p_track
	racers = p_racers
	for r in racers:
		_ai_wait[r] = 0.0
	_place_boxes()


# ---------------------------------------------------------------------------
# Item boxes
# ---------------------------------------------------------------------------

func _place_boxes() -> void:
	for frac: float in [0.22, 0.5, 0.78]:
		var s := _find_flat_spot(track.length * frac)
		if s < 0.0:
			continue
		for lat in BOX_LANES:
			var node := _make_box()
			add_child(node)
			_boxes.append({"s": s, "lat": lat, "node": node, "timer": 0.0})


## Moves forward from `s` until the track is flat, level and not a stunt.
func _find_flat_spot(s: float) -> float:
	var step := 2.0
	for i in int(track.length / step):
		var t := s + i * step
		var ok := true
		for k in range(-6, 7, 3):
			var f := track.flags_at(t + k)
			if (f & (Track.FLAG_LOOP | Track.FLAG_GAP | Track.FLAG_BOOST | Track.FLAG_START)) != 0 or track.sample(t + k).basis.y.y < 0.92:
				ok = false
				break
		if ok:
			return fposmod(t, track.length)
	return -1.0


func _make_box() -> Node3D:
	var root := Node3D.new()
	var cube := MeshInstance3D.new()
	cube.mesh = MeshKit.rounded_box(Vector3(1.4, 1.4, 1.4), 0.3, 2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.5, 0.2, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 0.8
	mat.roughness = 0.2
	cube.material_override = mat
	root.add_child(cube)
	var q := Label3D.new()
	q.text = "?"
	q.font_size = 128
	q.pixel_size = 0.012
	q.outline_size = 20
	q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	q.no_depth_test = false
	root.add_child(q)
	root.set_meta("mat", mat)
	return root


# ---------------------------------------------------------------------------
# Every physics frame (called by the race)
# ---------------------------------------------------------------------------

func update(delta: float) -> void:
	_time += delta
	_update_boxes(delta)
	_update_shots(delta)
	_update_puddles(delta)
	_update_magnets(delta)
	_ai(delta)


func _update_boxes(delta: float) -> void:
	for b in _boxes:
		var node: Node3D = b["node"]
		var f := track.sample(b["s"])
		if b["timer"] > 0.0:
			b["timer"] -= delta
			node.visible = b["timer"] <= 0.0
			if node.visible:
				node.scale = Vector3.ONE * 0.1
		node.scale = node.scale.lerp(Vector3.ONE, minf(1.0, delta * 6.0))
		var bob := sin(_time * 3.0 + float(b["lat"])) * 0.25
		node.global_transform = Transform3D(f.basis.rotated(f.basis.y.normalized(), _time * 2.0), f.origin + f.basis.x * float(b["lat"]) + f.basis.y * (1.5 + bob))
		var mat: StandardMaterial3D = node.get_meta("mat")
		var col := Color.from_hsv(fmod(_time * 0.3 + float(b["lat"]) * 0.1, 1.0), 0.7, 1.0, 0.85)
		mat.albedo_color = col
		mat.emission = col
		if b["timer"] > 0.0:
			continue
		for r in racers:
			if r.mode != Racer.Mode.DRIVING or r.has_finished:
				continue
			if _track_gap(r.s, b["s"]) < 1.6 and absf(r.lateral - float(b["lat"])) < 1.4:
				b["timer"] = BOX_RESPAWN
				node.visible = false
				if r.item == "" and not r.remote:
					r.item = _roll_item(r)
					_ai_wait[r] = randf_range(1.0, 4.0)
					item_got.emit(r, r.item)
				break


## Better power-ups for cars further back.
func _roll_item(r: Racer) -> String:
	var weights := {"bubble": 3.0, "ball": 3.0, "balloon": 2.0, "rocket": 2.0, "shield": 2.0, "magnet": 1.5, "banana": 2.0, "parachute": 1.0}
	if r.place <= 1:
		weights = {"bubble": 1.0, "ball": 1.5, "balloon": 3.0, "rocket": 0.5, "shield": 4.0, "magnet": 0.0, "banana": 3.0, "parachute": 1.0}
	elif r.place >= 4:
		weights = {"bubble": 4.0, "ball": 3.0, "balloon": 1.0, "rocket": 4.0, "shield": 1.0, "magnet": 4.0, "banana": 0.5, "parachute": 1.0}
	if track.gaps.is_empty():
		weights["parachute"] = 0.0   # no jumps on this track
	var total := 0.0
	for k in weights:
		total += weights[k]
	var pick := randf() * total
	for k in weights:
		pick -= weights[k]
		if pick <= 0.0:
			return k
	return "rocket"


func _track_gap(a: float, b: float) -> float:
	var d := fposmod(a - b, track.length)
	return minf(d, track.length - d)


## Signed distance from a to b along the track (positive = b is ahead).
func _ahead(a: float, b: float) -> float:
	var d := fposmod(b - a, track.length)
	return d if d < track.length * 0.5 else d - track.length


# ---------------------------------------------------------------------------
# Using items
# ---------------------------------------------------------------------------

func use_item(r: Racer) -> void:
	var kind := r.item
	if kind == "" or r.mode != Racer.Mode.DRIVING:
		return
	r.item = ""
	var side := 1.0 if randf() < 0.5 else -1.0
	item_used.emit(r, kind, side)
	_use(r, kind, side)


## A power-up used on another computer (online): show it here too.
func use_remote(r: Racer, kind: String, side: float) -> void:
	_use(r, kind, side)


func _use(r: Racer, kind: String, side: float) -> void:
	match kind:
		"bubble":
			_shoot(r, "bubble", maxf(r.speed, 20.0) + 22.0, 0.0, 6.0)
			Sfx.play("throw", 1.2)
		"ball":
			_shoot(r, "ball", maxf(r.speed, 20.0) + 14.0, side * 9.0, 7.0)
			Sfx.play("throw", 0.9)
		"balloon", "banana":
			var s := fposmod(r.s - 3.0, track.length)
			var node := _make_puddle() if kind == "balloon" else _make_peel()
			add_child(node)
			_puddles.append({"s": s, "lat": r.lateral, "life": 18.0 if kind == "balloon" else 25.0, "node": node, "owner": r, "kind": kind})
			if kind == "balloon":
				Sfx.play("splash", 1.2, -4.0)
			else:
				Sfx.play("throw", 0.7, -4.0)
		"magnet":
			if not r.remote:
				r.magnet_timer = MAGNET_TIME
			Sfx.play("pickup", 0.6)
		"parachute":
			if not r.remote:
				r.parachute_timer = PARACHUTE_TIME
			Sfx.play("shield", 1.3)
		"rocket":
			if not r.remote:
				r.boost_timer = 2.4
				r.speed = maxf(r.speed, float(r.stats["top_speed"]) * 1.35)
			Sfx.play("boost", 0.9)
		"shield":
			if not r.remote:
				r.shield_timer = 10.0
			Sfx.play("shield")


func _shoot(r: Racer, kind: String, speed: float, lat_vel: float, life: float) -> void:
	var node := _make_shot(kind)
	add_child(node)
	_shots.append({"kind": kind, "s": fposmod(r.s + 2.5, track.length), "lat": r.lateral, "lat_vel": lat_vel, "speed": speed, "life": life, "owner": r, "node": node, "age": 0.0})


func _make_shot(kind: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	var mat := StandardMaterial3D.new()
	if kind == "bubble":
		sm.radius = 1.0
		sm.height = 2.0
		mat.albedo_color = Color(0.7, 0.9, 1.0, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.rim_enabled = true
		mat.rim = 1.0
		mat.roughness = 0.0
		mat.metallic_specular = 1.0
	else:
		sm.radius = 0.6
		sm.height = 1.2
		mat.albedo_color = COLORS["ball"]
		mat.roughness = 0.25
		var stripe := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.55
		tm.outer_radius = 0.66
		stripe.mesh = tm
		var sm2 := StandardMaterial3D.new()
		sm2.albedo_color = Color(1.0, 0.9, 0.2)
		stripe.material_override = sm2
		root.add_child(stripe)
	mi.mesh = sm
	mi.material_override = mat
	root.add_child(mi)
	return root


func _make_puddle() -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.6
	cm.bottom_radius = 1.6
	cm.height = 0.08
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.0
	mat.metallic_specular = 1.0
	mi.material_override = mat
	mi.scale = Vector3(1.0, 1.0, 1.4)
	root.add_child(mi)
	# Bits of burst balloon
	for k in 3:
		var bit := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.25
		bm.height = 0.3
		bit.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(1.0, 0.3, 0.5)
		bit.material_override = bmat
		bit.position = Vector3(cos(k * 2.1) * 1.0, 0.1, sin(k * 2.1) * 1.3)
		root.add_child(bit)
	return root


func _update_shots(delta: float) -> void:
	var limit := Track.HALF_WIDTH - 0.7
	for i in range(_shots.size() - 1, -1, -1):
		var p: Dictionary = _shots[i]
		p["life"] -= delta
		p["age"] += delta
		p["s"] = fposmod(float(p["s"]) + float(p["speed"]) * delta, track.length)
		var lat: float = p["lat"] + float(p["lat_vel"]) * delta
		if p["kind"] == "bubble":
			# Bubbles drift towards the nearest car ahead.
			var target := _nearest_ahead(p["owner"], p["s"], 40.0)
			if target:
				lat = move_toward(lat, target.lateral, delta * 4.0)
		elif absf(lat) > limit:
			lat = clampf(lat, -limit, limit)
			p["lat_vel"] = -float(p["lat_vel"])
			if p["age"] > 0.2:
				Sfx.play("bump", 1.6, -16.0)
		p["lat"] = lat
		var f := track.sample(p["s"])
		var hop := absf(sin(float(p["age"]) * 9.0)) * 0.8 if p["kind"] == "ball" else 1.4 + sin(float(p["age"]) * 5.0) * 0.2
		var node: Node3D = p["node"]
		node.global_transform = Transform3D(f.basis, f.origin + f.basis.x * lat + f.basis.y * (0.6 + hop))
		if p["kind"] == "ball":
			node.rotate_object_local(Vector3.RIGHT, float(p["age"]) * 8.0)
		var hit := false
		for r in racers:
			if r.mode != Racer.Mode.DRIVING:
				continue
			if r == p["owner"] and p["age"] < 1.0:
				continue
			if _track_gap(r.s, p["s"]) < 1.7 and absf(r.lateral - lat) < 1.4:
				_hit(r, p["kind"], p["owner"])
				hit = true
				break
		if hit or p["life"] <= 0.0 or (f.basis.y.y < -0.5 and p["kind"] == "ball"):
			if not hit:
				Sfx.play("pop", 1.3, -12.0)
			node.queue_free()
			_shots.remove_at(i)


## A banana peel: a yellow star of floppy bits lying on the track.
func _make_peel() -> Node3D:
	var root := Node3D.new()
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(1.0, 0.86, 0.2)
	yellow.roughness = 0.5
	var brown := StandardMaterial3D.new()
	brown.albedo_color = Color(0.45, 0.3, 0.12)
	for k in 4:
		var flap := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.28
		cm.height = 1.6
		flap.mesh = cm
		flap.material_override = yellow
		var a := k * TAU / 4.0 + 0.4
		flap.position = Vector3(cos(a) * 0.6, 0.18, sin(a) * 0.6)
		flap.rotation = Vector3(0, -a, PI * 0.5 - 0.25)
		flap.scale = Vector3(1.0, 1.0, 0.45)
		root.add_child(flap)
	var middle := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.4
	sm.height = 0.6
	middle.mesh = sm
	middle.material_override = yellow
	middle.position.y = 0.25
	root.add_child(middle)
	var stem := MeshInstance3D.new()
	var st := CylinderMesh.new()
	st.top_radius = 0.1
	st.bottom_radius = 0.12
	st.height = 0.4
	stem.mesh = st
	stem.material_override = brown
	stem.position.y = 0.6
	root.add_child(stem)
	return root


## Magnets: a car with the Toy Magnet is pulled along to the car ahead.
func _update_magnets(delta: float) -> void:
	for r in racers:
		if r.magnet_timer <= 0.0 or r.remote or r.mode != Racer.Mode.DRIVING:
			continue
		var target := _nearest_ahead(r, r.s, 80.0)
		if target == null:
			continue
		var gap := _ahead(r.s, target.s)
		if gap < 3.5:
			r.magnet_timer = minf(r.magnet_timer, 0.3)   # caught them!
			continue
		var top := float(r.stats["top_speed"])
		r.speed = move_toward(r.speed, minf(maxf(target.speed + 10.0, top * 1.1), top * 1.3), delta * 40.0)
		r.lateral = move_toward(r.lateral, target.lateral * 0.6, delta * 2.0)


func _update_puddles(delta: float) -> void:
	for i in range(_puddles.size() - 1, -1, -1):
		var p: Dictionary = _puddles[i]
		p["life"] -= delta
		var f := track.sample(p["s"])
		var node: Node3D = p["node"]
		node.global_transform = Transform3D(f.basis, f.origin + f.basis.x * float(p["lat"]) + f.basis.y * 0.05)
		var kind := String(p.get("kind", "balloon"))
		var gone: bool = float(p["life"]) <= 0.0
		for r in racers:
			if r.mode != Racer.Mode.DRIVING:
				continue
			if r == p["owner"] and p["life"] > (16.5 if kind == "balloon" else 23.5):
				continue
			if _track_gap(r.s, p["s"]) < 1.8 and absf(r.lateral - float(p["lat"])) < 1.8:
				_hit(r, kind, p["owner"])
				gone = true
				break
		if gone:
			node.queue_free()
			_puddles.remove_at(i)


func _hit(r: Racer, kind: String, by: Racer) -> void:
	if r.remote:
		# Its own computer decides what happens; just say "got 'em" here.
		item_hit.emit(r, kind, by)
		return
	if r.shield_timer > 0.0:
		r.shield_timer = 0.0
		Sfx.play("pop", 0.8)
		item_hit.emit(r, "shield", by)
		return
	match kind:
		"bubble":
			r.bubble_timer = 1.8
			Sfx.play("pop", 1.0, -2.0)
		"ball":
			r.spin_vel += (1.0 if randf() < 0.5 else -1.0) * 9.0
			r.speed *= 0.45
			r.knock += randf_range(-4.0, 4.0)
			Sfx.play("bump", 0.8)
		"balloon":
			r.spin_vel += (1.0 if randf() < 0.5 else -1.0) * 7.0
			r.speed *= 0.6
			Sfx.play("splash")
		"banana":
			r.spin_vel += (1.0 if randf() < 0.5 else -1.0) * 12.0   # a full spin
			r.speed *= 0.5
			Sfx.play("skid", 1.2)
	item_hit.emit(r, kind, by)


## The nearest shot coming up behind a car (for the "incoming!" warning):
## {"kind", "dist" (track units behind), "side" (-1 left .. 1 right)} or {}.
func incoming_for(r: Racer, within: float = 32.0) -> Dictionary:
	var best := {}
	var best_d := within
	for p in _shots:
		if p["owner"] == r:
			continue
		var d := _ahead(float(p["s"]), r.s)   # > 0: the car is ahead of the shot
		if d > 0.0 and d < best_d and float(p["speed"]) > absf(r.speed) + 2.0:
			best_d = d
			best = {"kind": p["kind"], "dist": d,
				"side": clampf((float(p["lat"]) - r.lateral) / Track.HALF_WIDTH, -1.0, 1.0)}
	return best


func _nearest_ahead(owner: Racer, from_s: float, within: float) -> Racer:
	var best: Racer = null
	var best_d := within
	for r in racers:
		if r == owner or r.mode != Racer.Mode.DRIVING:
			continue
		var d := _ahead(from_s, r.s)
		if d > 0.0 and d < best_d:
			best_d = d
			best = r
	return best


# ---------------------------------------------------------------------------
# Computer drivers using their items
# ---------------------------------------------------------------------------

func _ai(delta: float) -> void:
	for r in racers:
		if r.is_player or r.remote or r.item == "" or r.mode != Racer.Mode.DRIVING or not r.controls_enabled:
			continue
		_ai_wait[r] = float(_ai_wait.get(r, 0.0)) - delta
		if _ai_wait[r] > 0.0:
			continue
		var use := false
		match r.item:
			"bubble", "ball":
				use = _nearest_ahead(r, r.s, 35.0) != null or _ai_wait[r] < -6.0
			"balloon", "banana":
				for o in racers:
					var d := _ahead(r.s, o.s)
					if o != r and d < -2.0 and d > -18.0:
						use = true
				use = use or _ai_wait[r] < -8.0
			"rocket":
				use = absf(track.curvature_at(r.s + 15.0)) < 0.02
			"shield":
				use = true
			"magnet":
				var ahead := _nearest_ahead(r, r.s, 70.0)
				use = ahead != null and _ahead(r.s, ahead.s) > 15.0
			"parachute":
				for g: Array in track.gaps:
					var d := _ahead(r.s, float(g[0]))
					if d > 5.0 and d < 60.0:
						use = true
				use = use or _ai_wait[r] < -10.0
		if use:
			use_item(r)
