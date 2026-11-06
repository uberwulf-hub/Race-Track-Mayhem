extends Control
## Pick which track (and room) to race in. Flip through the tracks with the
## arrows; each card shows a mini map (brighter = higher up), the track's
## special features and your best time.

var _index := 0
var _card: PanelContainer
var _card_style: StyleBoxFlat
var _room_label: Label
var _name_label: Label
var _stars_label: Label
var _map: TrackMap
var _features_label: Label
var _blurb_label: Label
var _best_label: Label
var _laps_label: Label
var _dots: HBoxContainer
var _race_button: Button
var _maps: Array = []          # cached [points, heights, max_h, rect] per track


func _ready() -> void:
	Sfx.play_music("garage")
	theme = Game.ui_theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_index = clampi(Game.selected_track, 0, Track.TRACKS.size() - 1)
	for i in Track.TRACKS.size():
		_maps.append(TrackMap.compute(i))

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.2, 0.15, 0.4)
	add_child(bg)
	var dots_bg := DotsBackground.new()
	dots_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dots_bg)

	var header := RaceHud.make_label("PICK A TRACK!", 60, Color(1.0, 0.85, 0.2), 16)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RaceHud.pin(header, Vector2(0.5, 0), Vector2(-500, 10), Vector2(1000, 76))
	add_child(header)

	# The big card in the middle
	_card = PanelContainer.new()
	_card_style = StyleBoxFlat.new()
	_card_style.set_corner_radius_all(28)
	_card_style.set_border_width_all(8)
	_card_style.border_color = Color(1.0, 0.85, 0.2)
	_card_style.set_content_margin_all(20)
	_card.add_theme_stylebox_override("panel", _card_style)
	RaceHud.pin(_card, Vector2(0.5, 0.5), Vector2(-400, -262), Vector2(800, 448))
	add_child(_card)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	_card.add_child(cols)
	_map = TrackMap.new()
	_map.custom_minimum_size = Vector2(380, 380)
	cols.add_child(_map)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(340, 0)
	info.add_theme_constant_override("separation", 8)
	cols.add_child(info)
	_room_label = RaceHud.make_label("", 24, Color(1, 1, 1, 0.9), 8)
	info.add_child(_room_label)
	_name_label = RaceHud.make_label("", 44, Color.WHITE, 14)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_name_label)
	_stars_label = RaceHud.make_label("", 28, Color(1.0, 0.95, 0.4), 8)
	info.add_child(_stars_label)
	_features_label = RaceHud.make_label("", 22, Color(0.9, 1.0, 1.0), 6)
	info.add_child(_features_label)
	_blurb_label = RaceHud.make_label("", 21, Color.WHITE, 6)
	_blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb_label.custom_minimum_size = Vector2(330, 0)
	info.add_child(_blurb_label)
	_best_label = RaceHud.make_label("", 22, Color(0.7, 1.0, 0.75), 6)
	info.add_child(_best_label)

	# Arrows on either side
	var left := _button(self, "<", func(): _change(-1))
	left.add_theme_font_size_override("font_size", 52)
	RaceHud.pin(left, Vector2(0.5, 0.5), Vector2(-530, -90), Vector2(100, 110))
	var right := _button(self, ">", func(): _change(1))
	right.add_theme_font_size_override("font_size", 52)
	RaceHud.pin(right, Vector2(0.5, 0.5), Vector2(430, -90), Vector2(100, 110))
	for b: Button in [left, right]:
		b.focus_mode = Control.FOCUS_NONE

	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 12)
	RaceHud.pin(_dots, Vector2(0.5, 1), Vector2(-200, -132), Vector2(400, 30))
	add_child(_dots)
	for i in Track.TRACKS.size():
		var d := Panel.new()
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(d)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	RaceHud.pin(bottom, Vector2(0.5, 1), Vector2(-500, -92), Vector2(1000, 80))
	add_child(bottom)
	_button(bottom, "Back", _go_back)
	bottom.add_child(RaceHud.make_label("   Laps:", 30))
	var minus := _button(bottom, "-", func(): _change_laps(-1))
	_laps_label = RaceHud.make_label(str(Game.laps), 40, Color(1.0, 0.9, 0.3))
	_laps_label.custom_minimum_size = Vector2(50, 0)
	_laps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_laps_label)
	var plus := _button(bottom, "+", func(): _change_laps(1))
	for b: Button in [minus, plus]:
		b.focus_mode = Control.FOCUS_NONE
	bottom.add_child(Control.new())
	_race_button = _button(bottom, "RACE!", _choose)
	_race_button.add_theme_font_size_override("font_size", 44)
	_race_button.grab_focus.call_deferred()
	_show()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("steer_left"):
		_change(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("steer_right"):
		_change(1)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _go_back() -> void:
	Sfx.play("back")
	Game.goto_garage()


func _change(d: int) -> void:
	_index = wrapi(_index + d, 0, Track.TRACKS.size())
	Sfx.play("click", 1.0 + d * 0.1)
	_show()
	# A little bounce so it feels like flipping a card
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.92, 0.92)
	create_tween().tween_property(_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show() -> void:
	var info: Dictionary = Track.TRACKS[_index]
	var col: Color = info["color"]
	_card_style.bg_color = col.darkened(0.15)
	_room_label.text = "%d / %d   -   %s" % [_index + 1, Track.TRACKS.size(), info["room_name"]]
	_name_label.text = info["name"]
	var stars := int(info["stars"])
	_stars_label.text = "Trickiness  " + "★".repeat(stars) + "☆".repeat(3 - stars)
	var lines := PackedStringArray()
	for f: String in info["features"]:
		lines.append("*  " + f)
	_features_label.text = "\n".join(lines)
	_blurb_label.text = info["blurb"]
	_update_best()
	_map.set_data(_maps[_index])
	for i in _dots.get_child_count():
		var dot := _dots.get_child(i) as Panel
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		sb.bg_color = Track.TRACKS[i]["color"]
		sb.set_border_width_all(4 if i == _index else 0)
		sb.border_color = Color.WHITE
		dot.add_theme_stylebox_override("panel", sb)
		dot.custom_minimum_size = Vector2(30, 30) if i == _index else Vector2(18, 18)


func _update_best() -> void:
	var t := Game.best_time_for(_index)
	_best_label.text = ("Best (%d laps): %s" % [Game.laps, Game.format_time(t)]) if t > 0.0 else "No record yet - set one!"


func _change_laps(d: int) -> void:
	Game.laps = clampi(Game.laps + d, 1, 9)
	_laps_label.text = str(Game.laps)
	Game.save_settings()
	_update_best()


func _choose() -> void:
	Game.selected_track = _index
	Game.save_settings()
	Sfx.play("go")
	Game.goto_race()


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	parent.add_child(b)
	return b


## Top-down drawing of a track, coloured by height (bridges and spirals show on top).
class TrackMap extends Control:
	var pts := PackedVector2Array()
	var heights := PackedFloat32Array()
	var max_h := 1.0
	var rect := Rect2()

	static func compute(index: int) -> Array:
		var t := Track.new()
		t.layout_id = index
		t._build_closed_layout()
		t._resample()
		var p := PackedVector2Array()
		var h := PackedFloat32Array()
		var mh := 1.0
		for k in range(0, t.count, 2):
			p.append(Vector2(t.points[k].x, t.points[k].z))
			h.append(t.points[k].y)
			mh = maxf(mh, t.points[k].y)
		var r := t.get_aabb_xz()
		t.free()
		return [p, h, mh, r]

	func set_data(d: Array) -> void:
		pts = d[0]
		heights = d[1]
		max_h = d[2]
		rect = d[3]
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25), true)
		if pts.is_empty():
			return
		var sc := minf(size.x / rect.size.x, size.y / rect.size.y) * 0.88
		var off := size * 0.5 - rect.get_center() * sc
		var order: Array = range(pts.size())
		order.sort_custom(func(a: int, b: int) -> bool: return heights[a] < heights[b])
		for i: int in order:
			var j := (i + 1) % pts.size()
			var a := pts[i] * sc + off
			var b := pts[j] * sc + off
			var h := heights[i] / max_h
			draw_line(a, b, Color(0.1, 0.05, 0.0, 0.9), 12.0, true)
			draw_line(a, b, Color(1.0, 0.45, 0.05).lerp(Color(1.0, 0.95, 0.55), h), 7.0, true)
		var s := pts[0] * sc + off
		draw_circle(s, 9.0, Color.BLACK)
		draw_circle(s, 6.0, Color.WHITE)


## Soft polka dots so the background isn't plain.
class DotsBackground extends Control:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 40:
			var c := Color.from_hsv(rng.randf(), 0.5, 1.0, 0.18)
			draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(20.0, 70.0), c)
