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
var _hint_hidden := false
var _minimap: Minimap
var _root: Control
var _message_tween: Tween
var _center_tween: Tween
var _speed_lines: SpeedLines
var _fade: ColorRect
var _fade_tween: Tween
var speed_effect := 0.0     # 0..1, set by the race camera
var player_tag := "":        # "P1" / "P2" in split screen
	set(v):
		player_tag = v
		if _tag_label:
			_tag_label.text = v
			_tag_label.visible = v != ""
var _tag_label: Label
var _wrong_way: Label
var _incoming: Label
var _incoming_on := false
var _behind: BehindArrows
var _item_panel: PanelContainer
var _item_style: StyleBoxFlat
var _item_name: Label
var _item_hint: Label
var _speed_box: Control
var _turbo_box: Control
var touch := false:             # on-screen buttons: show "tap" hints instead of keys
	set(v):
		touch = v
		if v:
			hide_hint()
			if _item_hint:
				_item_hint.text = "tap ITEM"
			_make_room_for_buttons()
var _item_kind := ""


static func make_label(text: String, size: int, color: Color = Color.WHITE, outline: int = 10) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.15))
	return l


## Pins a control to an anchor point of its parent with a fixed offset and size.
## With on-screen buttons the bottom corners belong to your thumbs: move the
## speed, turbo meter and mini map up out of the way.
func _make_room_for_buttons() -> void:
	if _speed_box:
		pin(_speed_box, Vector2(1, 0), Vector2(-300, 108), Vector2(280, 90))
		_speed_label.add_theme_font_size_override("font_size", 30)
	if _turbo_box:
		pin(_turbo_box, Vector2(0, 0), Vector2(20, 236), Vector2(240, 70))
		_turbo_label.text = "TURBO"
		_turbo_label.add_theme_font_size_override("font_size", 22)
	if _minimap:
		_minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_minimap.position = Vector2(20, 316)
		_minimap.size = Vector2(170, 150)


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
	_speed_box = br
	RaceHud.pin(br, Vector2(1, 1), Vector2(-300, -120), Vector2(280, 100))
	_root.add_child(br)
	_speed_label = make_label("0 mph", 40)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_speed_label)
	_speed_bar = _make_bar(Color(0.3, 1.0, 0.4))
	br.add_child(_speed_bar)

	# --- bottom left: turbo ---
	var bl := VBoxContainer.new()
	_turbo_box = bl
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

	# --- power-up slot ---
	_item_panel = PanelContainer.new()
	_item_style = StyleBoxFlat.new()
	_item_style.set_corner_radius_all(16)
	_item_style.set_border_width_all(5)
	_item_style.border_color = Color.WHITE
	_item_style.set_content_margin_all(8)
	_item_panel.add_theme_stylebox_override("panel", _item_style)
	pin(_item_panel, Vector2(0, 0), Vector2(20, 150), Vector2(230, 80))
	_item_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ib := VBoxContainer.new()
	ib.add_theme_constant_override("separation", 0)
	_item_panel.add_child(ib)
	_item_name = make_label("", 26, Color.WHITE, 8)
	_item_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ib.add_child(_item_name)
	var key := "E / Y button"
	if player and player.input_prefix == "p2_":
		key = "/ key / Y button"
	_item_hint = make_label("press " + key, 18, Color(1, 1, 1, 0.9), 6)
	_item_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ib.add_child(_item_hint)
	_item_panel.visible = false
	_root.add_child(_item_panel)

	# --- "cars right behind you" arrows ---
	_behind = BehindArrows.new()
	_behind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin(_behind, Vector2(0.5, 1), Vector2(-260, -110), Vector2(520, 60))
	_root.add_child(_behind)

	# --- wrong way warning ---
	_wrong_way = make_label("WRONG WAY!", 72, Color(1.0, 0.3, 0.25), 16)
	_wrong_way.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin(_wrong_way, Vector2(0.5, 0.5), Vector2(-400, 40), Vector2(800, 100))
	_wrong_way.visible = false
	_root.add_child(_wrong_way)
	# "Incoming!" when a power-up is about to hit you from behind.
	_incoming = make_label("", 40, Color(1.0, 0.85, 0.2), 14)
	_incoming.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin(_incoming, Vector2(0.5, 1), Vector2(-300, -250), Vector2(600, 60))
	_incoming.visible = false
	_root.add_child(_incoming)

	# --- player tag (split screen) ---
	_tag_label = make_label(player_tag, 40, Color(0.5, 0.9, 1.0), 12)
	pin(_tag_label, Vector2(0.5, 0), Vector2(-60, 8), Vector2(120, 50))
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_label.visible = player_tag != ""
	_root.add_child(_tag_label)

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
		if c == _hint_label and _hint_hidden:
			continue
		if c == _item_panel:
			c.visible = v and _item_kind != ""
			continue
		if c == _center_label or c == _message_label or c == _title_box or c == _speed_lines or c == _fade or c == _wrong_way or c == _tag_label or c == _incoming:
			continue
		c.visible = v


func hide_hint() -> void:
	_hint_hidden = true
	if _hint_label:
		_hint_label.visible = false
		_hint_label.modulate.a = 0.0


## Warns about a shot coming from behind: {"kind", "dist", "side"} or {} for none.
## Blinks faster the closer it gets; the arrow shows which side it's on.
func set_incoming(threat: Dictionary) -> void:
	if _incoming == null:
		return
	var on := not threat.is_empty()
	if on != _incoming_on:
		_incoming_on = on
		if on:
			Sfx.play("beep", 1.6, -6.0)
	_incoming.visible = on
	if not on:
		return
	var d: float = threat["dist"]
	var side: float = threat["side"]
	var arrow := "<<  " if side < -0.25 else ""
	var arrow_r := "  >>" if side > 0.25 else ""
	_incoming.text = "%s! INCOMING %s !%s" % [arrow, "BUBBLE" if threat["kind"] == "bubble" else "BALL", arrow_r]
	var rate := lerpf(16.0, 5.0, clampf(d / 32.0, 0.0, 1.0))
	var blink := sin(Time.get_ticks_msec() * 0.001 * rate) > -0.2
	_incoming.modulate.a = 1.0 if blink else 0.35
	var k := 1.0 + clampf(1.0 - d / 32.0, 0.0, 1.0) * 0.25
	_incoming.pivot_offset = Vector2(300, 30)
	_incoming.scale = Vector2(k, k)


func set_wrong_way(on: bool) -> void:
	if _wrong_way == null or _wrong_way.visible == on:
		return
	_wrong_way.visible = on
	if on:
		_wrong_way.scale = Vector2(0.5, 0.5)
		_wrong_way.pivot_offset = Vector2(400, 50)
		create_tween().tween_property(_wrong_way, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## [[side -1..1, closeness 0..1, colour], ...] for cars just behind.
## Shows the power-up being held ("" = none). Pops when a new one arrives.
func set_item(kind: String, shielded: bool) -> void:
	if _item_panel == null:
		return
	if kind == _item_kind:
		return
	_item_kind = kind
	_item_panel.visible = kind != "" and _lap_label.visible
	if kind == "":
		return
	var col: Color = PowerUps.COLORS[kind]
	_item_style.bg_color = col.darkened(0.25)
	_item_name.text = PowerUps.NAMES[kind]
	_item_panel.pivot_offset = Vector2(115, 40)
	_item_panel.scale = Vector2(1.4, 1.4)
	create_tween().tween_property(_item_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_nearby(cars: Array) -> void:
	if _behind:
		_behind.cars = cars
		_behind.queue_redraw()


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


## Little coloured arrows at the bottom of the screen when a car is right
## behind you: left, middle or right depending on where it is.
class BehindArrows extends Control:
	var cars: Array = []

	func _draw() -> void:
		for c in cars:
			var side: float = c[0]
			var close: float = c[1]
			var col: Color = c[2]
			var x := size.x * 0.5 + side * size.x * 0.42
			var h := 18.0 + close * 22.0
			var y := size.y - 6.0
			var pts := PackedVector2Array([Vector2(x, y - h), Vector2(x - h * 0.8, y), Vector2(x + h * 0.8, y)])
			var a := 0.45 + close * 0.55
			draw_colored_polygon(pts, Color(0, 0, 0, a))
			var inner := PackedVector2Array([Vector2(x, y - h + 6), Vector2(x - h * 0.8 + 7, y - 3), Vector2(x + h * 0.8 - 7, y - 3)])
			draw_colored_polygon(inner, Color(col.r, col.g, col.b, a))
