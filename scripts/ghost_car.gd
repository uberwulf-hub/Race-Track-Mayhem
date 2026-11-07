class_name GhostCar
extends Node3D
## Race against your own best lap! While you drive, every lap is recorded
## (position + rotation, 20 times a second). If a clean lap beats your best,
## it's saved, and from then on a see-through "ghost" car drives that lap
## alongside you, starting each time you cross the line.

const RATE := 20.0
const DIR := "user://ghosts/"

var track_id := ""
var racer: Racer
var _model: ToyCarModel
var _best: PackedFloat32Array = PackedFloat32Array()   # [t, x, y, z, qx, qy, qz, qw] * n
var _best_time := -1.0
var _rec := PackedFloat32Array()
var _rec_clock := 0.0
var _rec_spoiled := false
var _rec_lap_start := 0.0
var _pending: PackedFloat32Array = PackedFloat32Array()
var _pending_time := -1.0


func setup(p_track: Track, p_track_id: String, p_racer: Racer) -> void:
	track_id = p_track_id
	racer = p_racer
	_load()
	_model = ToyCarModel.new().setup(racer.car, false, Game.custom_for(racer.car["id"]))
	add_child(_model)
	_make_see_through(_model)
	_model.visible = false


func _make_see_through(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.6, 0.85, 1.0, 0.32)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.rim_enabled = true
			(c as MeshInstance3D).material_override = m
			(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif c is Label3D or c is Light3D:
			c.visible = false
		_make_see_through(c)


## Called every frame with the time since the player's current lap started.
func follow(lap_t: float, racing: bool) -> void:
	# --- record ---
	if racing and racer.lap >= 0:
		if lap_t < _rec_clock - 0.5:
			pass  # a new lap started; lap_finished() resets the buffer
		if lap_t >= _rec_clock:
			var t := racer.global_transform
			var q := t.basis.get_rotation_quaternion()
			_rec.append_array(PackedFloat32Array([lap_t, t.origin.x, t.origin.y, t.origin.z, q.x, q.y, q.z, q.w]))
			_rec_clock = lap_t + 1.0 / RATE
	# --- play back ---
	var show := racing and _best.size() >= 16 and lap_t <= _best_time
	_model.visible = show
	if not show:
		return
	var n := _best.size() / 8
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _best[mid * 8] <= lap_t:
			lo = mid
		else:
			hi = mid
	var a := lo * 8
	var b := hi * 8
	var span := maxf(0.0001, _best[b] - _best[a])
	var k := clampf((lap_t - _best[a]) / span, 0.0, 1.0)
	var pa := Vector3(_best[a + 1], _best[a + 2], _best[a + 3])
	var pb := Vector3(_best[b + 1], _best[b + 2], _best[b + 3])
	var qa := Quaternion(_best[a + 4], _best[a + 5], _best[a + 6], _best[a + 7]).normalized()
	var qb := Quaternion(_best[b + 4], _best[b + 5], _best[b + 6], _best[b + 7]).normalized()
	_model.global_transform = Transform3D(Basis(qa.slerp(qb, k)), pa.lerp(pb, k))


## The player crossed the line: keep the lap if it's the best clean one.
func lap_finished(lap_time: float) -> void:
	if not _rec_spoiled and _rec.size() > 16 and lap_time > 2.0:
		var best_so_far := _pending_time if _pending_time > 0.0 else _best_time
		if best_so_far < 0.0 or lap_time < best_so_far:
			_pending = _rec.duplicate()
			_pending_time = lap_time
	_rec = PackedFloat32Array()
	_rec_clock = 0.0
	_rec_spoiled = false


## Falling off or resetting doesn't count as a clean lap.
func lap_spoiled() -> void:
	_rec_spoiled = true


## Saves the best new lap (called when the race ends).
func save_if_better() -> void:
	if _pending_time <= 0.0 or (_best_time > 0.0 and _pending_time >= _best_time):
		return
	DirAccess.make_dir_recursive_absolute(_dir())
	var cfg := ConfigFile.new()
	cfg.set_value("ghost", "lap_time", _pending_time)
	cfg.set_value("ghost", "data", _pending)
	cfg.save(_dir() + track_id + ".cfg")
	_best = _pending
	_best_time = _pending_time


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_dir() + track_id + ".cfg") != OK:
		return
	_best_time = float(cfg.get_value("ghost", "lap_time", -1.0))
	_best = cfg.get_value("ghost", "data", PackedFloat32Array())


## Each player races their own ghost (the first player keeps the old folder).
static func _dir() -> String:
	var slot: int = Engine.get_main_loop().root.get_node("Game").player_slot
	return DIR if slot <= 0 else "%sp%d/" % [DIR, slot]
