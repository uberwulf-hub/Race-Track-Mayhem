class_name RaceHud
extends CanvasLayer
## Everything drawn on top of the race: lap counter, place, timer, speedo,
## turbo meter, mini-map, countdown and big pop-up messages.

var track: Track
var racers: Array[Racer] = []
var player: Racer

var _lap_label: Label
var _time_label: Label
var _best_label: Label
var _place_label: Label
var _place_small: Label
var _speed_label: Label
var _speed_bar: ProgressBar
var _turbo_bar: ProgressBar
var _turbo_label: Label
var _center_label: Label
var _message_label: Label
var _title_box: VBoxContainer
var _hint_label: Label
var _minimap: Minimap
var _root: Control
var _message_tween: Tween
var _center_tween: Tween
var _speed_lines: SpeedLines
var _fade: ColorRect
var _fade_tween: Tween
var speed_effect := 0.0     # 0..1, set by the race camera


static func make_label(text: String, size: int, color: Color = Color.WHITE, outline: int = 10) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.15))
	return l


## Pins a control to an anchor point of its parent with a fixed offset and size.
static func pin(c: Control, anchor: Vector2, offset: Vector2, size: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + size.x
	c.offset_bottom = offset.y + size.y


func setup(p_track: Track, p_racers: Array[Racer], p_player: Racer) -> void:
	track = p_track
	racers = p_racers
	player = p_player
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Game.ui_theme
	add_child(_root)

	# --- speed lines (drawn first so they sit under everything) ---
	_speed_lines = SpeedLines.new()
	_speed_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_speed_lines)

	# --- top left: lap + time ---
	var tl := VBoxContainer.new()
	tl.position = Vector2(24, 16)
	_root.add_child(tl)
	_lap_label = make_label("LAP 1/3", 44, Color(1.0, 0.9, 0.3))
	tl.add_child(_lap_label)
	_time_label = make_label("0:00.00", 32)
	tl.add_child(_time_label)
	_best_label = make_label("", 22, Color(0.7, 1.0, 0.8), 8)
	tl.add_child(_best_label)

	# --- top right: place ---
	var tr := HBoxContainer.new()
	RaceHud.pin(tr, Vector2(1, 0), Vector2(-260, 10), Vector2(240, 100))
	tr.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(tr)
	_place_label = make_label("1st", 80, Color(1.0, 0.85, 0.2), 14)
	tr.add_child(_place_label)
	_place_small = make_label("/5", 34)
	_place_small.size_flags_vertical = Control.SIZE_SHRINK_END
	tr.add_child(_place_small)

	# --- bottom right: speed ---
	var br := VBoxContainer.new()
	RaceHud.pin(br, Vector2(1, 1), Vector2(-300, -120), Vector2(280, 100))
	_root.add_child(br)
	_speed_label = make_label("0 mph", 40)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_speed_label)
	_speed_bar = _make_bar(Color(0.3, 1.0, 0.4))
	br.add_child(_speed_bar)

	# --- bottom left: turbo ---
	var bl := VBoxContainer.new()
	RaceHud.pin(bl, Vector2(0, 1), Vector2(24, -110), Vector2(300, 90))
	_root.add_child(bl)
	_turbo_label = make_label("TURBO  [SPACE]", 26, Color(0.5, 0.95, 1.0))
	bl.add_child(_turbo_label)
	_turbo_bar = _make_bar(Color(0.3, 0.85, 1.0))
	bl.add_child(_turbo_bar)

	# --- mini map ---
	_minimap = Minimap.new()
	_minimap.hud = self
	_minimap.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_minimap.anchor_top = 0.5
	_minimap.anchor_bottom = 0.5
	_minimap.offset_left = -210
	_minimap.offset_right = -20
	_minimap.offset_top = -110
	_minimap.offset_bottom = 110
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_minimap)

	# --- centre: countdown / messages ---
	_center_label = make_label("", 190, Color(1.0, 0.9, 0.2), 28)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pin(_center_label, Vector2(0.5, 0.5), Vector2(-450, -200), Vector2(900, 260))
	_center_label.pivot_offset = Vector2(450, 130)
	_root.add_child(_center_label)

	_message_label = make_label("", 64, Color.WHITE, 16)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin(_message_label, Vector2(0.5, 0), Vector2(-500, 140), Vector2(1000, 90))
	_message_label.pivot_offset = Vector2(500, 45)
	_root.add_child(_message_label)

	# --- intro title ---
	_title_box = VBoxContainer.new()
	RaceHud.pin(_title_box, Vector2(0.5, 1), Vector2(-500, -230), Vector2(1000, 200))
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_title_box)
	var t1 := make_label("RACE TRACK MAYHEM", 40, Color(1.0, 0.6, 0.15), 12)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(t1)
	var t2 := make_label(Game.track_name(), 84, Color(1.0, 0.95, 0.4), 18)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(t2)
	var t3 := make_label("%d laps  *  %s" % [Game.laps, Game.DIFFICULTY_NAMES[Game.difficulty]], 32, Color.WHITE, 10)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(t3)
	_title_box.visible = false

	_hint_label = make_label("W / UP = Go    A D / LEFT RIGHT = Steer    SPACE = Turbo    R = Reset    C = Camera    ESC = Pause", 20, Color(1, 1, 1, 0.9), 8)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin(_hint_label, Vector2(0.5, 1), Vector2(-600, -40), Vector2(1200, 30))
	_root.add_child(_hint_label)

	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.02, 0.12, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	_root.move_child(_message_label, -1)   # messages show on top of the fade

	set_race_ui_visible(false)


func _make_bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(260, 26)
	bar.show_percentage = false
	bar.max_value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(13)
	bg.set_border_width_all(3)
	bg.border_color = Color(1, 1, 1, 0.8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(13)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	return bar


func set_race_ui_visible(v: bool) -> void:
	for c in _root.get_children():
		if c == _center_label or c == _message_label or c == _title_box or c == _speed_lines or c == _fade:
			continue
		c.visible = v


## Fades the screen to dark (used when a car falls off the track).
func fade_out(time: float = 0.45) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 1.0, time)


func fade_in(time: float = 0.5) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 0.0, time)


func show_title(v: bool) -> void:
	_title_box.visible = v
	if v:
		_title_box.modulate.a = 0.0
		create_tween().tween_property(_title_box, "modulate:a", 1.0, 0.6)


func hide_title() -> void:
	var tw := create_tween()
	tw.tween_property(_title_box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _title_box.visible = false)


func show_countdown(text: String, color: Color) -> void:
	_center_label.text = text
	_center_label.add_theme_color_override("font_color", color)
	_center_label.scale = Vector2(2.2, 2.2)
	_center_label.modulate.a = 1.0
	if _center_tween:
		_center_tween.kill()
	_center_tween = create_tween()
	_center_tween.tween_property(_center_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_center_tween.tween_interval(0.35)
	_center_tween.tween_property(_center_label, "modulate:a", 0.0, 0.3)


func flash_message(text: String, color: Color = Color.WHITE, hold: float = 1.2) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	_message_label.scale = Vector2(0.3, 0.3)
	_message_label.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(_message_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_message_tween.tween_interval(hold)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.4)


func fade_hint() -> void:
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(_hint_label, "modulate:a", 0.0, 1.0)


func _process(delta: float) -> void:
	if player == null:
		return
	var shown_lap := clampi(player.lap + 1, 1, player.laps_to_win)
	_lap_label.text = "LAP %d/%d" % [shown_lap, player.laps_to_win]
	if player.lap == player.laps_to_win - 1 and not player.has_finished:
		_lap_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	_time_label.text = Game.format_time(player.finish_time if player.has_finished else player.race_time)
	_best_label.text = ("Best lap " + Game.format_time(player.best_lap)) if player.best_lap > 0.0 else ""
	_place_label.text = Game.ordinal(player.place)
	_place_small.text = "/%d" % racers.size()
	var place_col := Color(1.0, 0.85, 0.2) if player.place == 1 else (Color(0.85, 0.9, 1.0) if player.place <= 3 else Color(1.0, 0.6, 0.5))
	_place_label.add_theme_color_override("font_color", place_col)
	var mph := absf(player.speed) * 2.2
	_speed_label.text = "%d mph" % int(mph)
	_speed_bar.value = clampf(absf(player.speed) / 60.0, 0.0, 1.0)
	_turbo_bar.value = player.turbo
	_turbo_label.modulate = Color(1, 1, 1, 1.0 if player.turbo > 0.05 else 0.5)
	_minimap.queue_redraw()
	_speed_lines.amount = lerpf(_speed_lines.amount, speed_effect, minf(1.0, delta * 6.0))
	_speed_lines.queue_redraw()


## Little top-down map of the track with a dot for each car.
class Minimap extends Control:
	var hud: RaceHud
	var _poly := PackedVector2Array()
	var _rect: Rect2

	func _draw() -> void:
		if hud == null or hud.track == null:
			return
		var t := hud.track
		if _poly.is_empty():
			_rect = t.get_aabb_xz()
			for k in range(0, t.count, 3):
				_poly.append(Vector2(t.points[k].x, t.points[k].z))
			_poly.append(_poly[0])
		var sc := minf(size.x / _rect.size.x, size.y / _rect.size.y) * 0.9
		var off := size * 0.5 - _rect.get_center() * sc
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.3), true)
		var pts := PackedVector2Array()
		for p in _poly:
			pts.append(p * sc + off)
		draw_polyline(pts, Color(0.1, 0.05, 0.0, 0.8), 9.0, true)
		draw_polyline(pts, Color(1.0, 0.55, 0.1), 5.0, true)
		var start := Vector2(t.points[0].x, t.points[0].z) * sc + off
		draw_circle(start, 5.0, Color.WHITE)
		for r in hud.racers:
			if r == hud.player:
				continue
			var p := Vector2(r.global_position.x, r.global_position.z) * sc + off
			draw_circle(p, 6.0, Color(0, 0, 0))
			draw_circle(p, 4.5, r.car["body"])
		var pp := Vector2(hud.player.global_position.x, hud.player.global_position.z) * sc + off
		draw_circle(pp, 9.0, Color.WHITE)
		draw_circle(pp, 6.5, hud.player.car["body"])


## White streaks rushing out from the middle of the screen when going really fast.
class SpeedLines extends Control:
	var amount := 0.0
	var _seeds: Array[Vector3] = []

	func _draw() -> void:
		if amount < 0.02:
			return
		if _seeds.is_empty():
			for i in 70:
				_seeds.append(Vector3(randf() * TAU, randf(), randf_range(0.6, 1.4)))
		var c := size * 0.5
		var radius := size.length() * 0.5
		var t := Time.get_ticks_msec() / 1000.0
		for sd in _seeds:
			var phase := fmod(sd.y + t * 2.2 * sd.z, 1.0)
			var dir := Vector2(cos(sd.x), sin(sd.x))
			var r0 := radius * (0.45 + phase * 0.6)
			var r1 := r0 + radius * 0.18 * sd.z
			var a := amount * 0.45 * (1.0 - phase)
			draw_line(c + dir * r0, c + dir * r1, Color(1, 1, 1, a), 3.0 * sd.z, true)
