extends Control
## Pick which track to race on. Each card shows a mini map of the track
## (brighter = higher up), its special features and your best time.

var _cards: Array[Button] = []
var _laps_label: Label
var _best_labels: Array[Label] = []


func _ready() -> void:
	Sfx.play_music("menu")
	theme = Game.ui_theme
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.2, 0.15, 0.4)
	add_child(bg)
	var dots := DotsBackground.new()
	dots.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dots)

	var header := RaceHud.make_label("PICK A TRACK!", 64, Color(1.0, 0.85, 0.2), 16)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RaceHud.pin(header, Vector2(0.5, 0), Vector2(-500, 16), Vector2(1000, 80))
	add_child(header)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	RaceHud.pin(row, Vector2(0.5, 0.5), Vector2(-620, -250), Vector2(1240, 440))
	add_child(row)
	for i in Track.TRACKS.size():
		row.add_child(_make_card(i))

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 18)
	RaceHud.pin(bottom, Vector2(0.5, 1), Vector2(-460, -100), Vector2(920, 80))
	add_child(bottom)
	_button(bottom, "Back", func(): Game.goto_garage())
	bottom.add_child(RaceHud.make_label("   Laps:", 32))
	_button(bottom, "-", func(): _change_laps(-1))
	_laps_label = RaceHud.make_label(str(Game.laps), 40, Color(1.0, 0.9, 0.3))
	_laps_label.custom_minimum_size = Vector2(50, 0)
	_laps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_laps_label)
	_button(bottom, "+", func(): _change_laps(1))

	var start := clampi(Game.selected_track, 0, _cards.size() - 1)
	_cards[start].grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Sfx.play("back")
		Game.goto_garage()


func _make_card(index: int) -> Button:
	var info: Dictionary = Track.TRACKS[index]
	var card := Button.new()
	card.custom_minimum_size = Vector2(560, 430)
	card.pressed.connect(func(): _choose(index))
	card.focus_entered.connect(func(): Sfx.play("click", 1.0, -8.0))
	_cards.append(card)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24
	box.offset_right = -24
	box.offset_top = 14
	box.offset_bottom = -18
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var title := RaceHud.make_label(info["name"], 42, Color.WHITE, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var stars := "*".repeat(int(info["stars"])) + "-".repeat(3 - int(info["stars"]))
	var diff := RaceHud.make_label("Trickiness: " + stars.replace("*", "★").replace("-", "☆"), 24, Color(1.0, 0.95, 0.5), 8)
	diff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(diff)

	var map := TrackMap.new()
	map.custom_minimum_size = Vector2(0, 190)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.load_track(index)
	box.add_child(map)

	var feats := RaceHud.make_label("  ".join(PackedStringArray(info["features"])), 20, Color(0.8, 0.95, 1.0), 6)
	feats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(feats)
	var blurb := RaceHud.make_label(info["blurb"], 20, Color.WHITE, 6)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(blurb)
	var best := RaceHud.make_label("", 22, Color(0.6, 1.0, 0.7), 6)
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(best)
	_best_labels.append(best)
	_update_best(index)
	return card


func _update_best(index: int) -> void:
	var t := Game.best_time_for(index)
	_best_labels[index].text = ("Best (%d laps): %s" % [Game.laps, Game.format_time(t)]) if t > 0.0 else "No record yet - set one!"


func _change_laps(d: int) -> void:
	Game.laps = clampi(Game.laps + d, 1, 9)
	_laps_label.text = str(Game.laps)
	Game.save_settings()
	for i in _best_labels.size():
		_update_best(i)


func _choose(index: int) -> void:
	Game.selected_track = index
	Game.save_settings()
	Sfx.play("go")
	Game.goto_race()


func _button(parent: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	parent.add_child(b)
	return b


## Top-down drawing of a track, coloured by height.
class TrackMap extends Control:
	var pts := PackedVector2Array()
	var heights := PackedFloat32Array()
	var max_h := 1.0
	var rect := Rect2()

	func load_track(index: int) -> void:
		var t := Track.new()
		t.layout_id = index
		t._build_closed_layout()
		t._resample()
		for k in range(0, t.count, 2):
			pts.append(Vector2(t.points[k].x, t.points[k].z))
			heights.append(t.points[k].y)
			max_h = maxf(max_h, t.points[k].y)
		rect = t.get_aabb_xz()
		t.free()

	func _draw() -> void:
		if pts.is_empty():
			return
		var sc := minf(size.x / rect.size.x, size.y / rect.size.y) * 0.92
		var off := size * 0.5 - rect.get_center() * sc
		# Draw low parts first so bridges and loops appear on top.
		var order: Array = range(pts.size())
		order.sort_custom(func(a: int, b: int) -> bool: return heights[a] < heights[b])
		for i: int in order:
			var j := (i + 1) % pts.size()
			var a := pts[i] * sc + off
			var b := pts[j] * sc + off
			var h := heights[i] / max_h
			draw_line(a, b, Color(0.1, 0.05, 0.0, 0.9), 11.0, true)
			draw_line(a, b, Color(1.0, 0.45, 0.05).lerp(Color(1.0, 0.95, 0.5), h), 6.0, true)
		draw_circle(pts[0] * sc + off, 7.0, Color.WHITE)


## Soft polka dots so the background isn't plain.
class DotsBackground extends Control:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 40:
			var c := Color.from_hsv(rng.randf(), 0.5, 1.0, 0.18)
			draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(20.0, 70.0), c)
