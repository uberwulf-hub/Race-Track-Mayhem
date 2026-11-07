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
var _custom_row: HBoxContainer
var _delete_button: Button
var _delete_armed := false
var _header: Label
var _badge: PanelContainer
var _badge_label: Label
var _time := 0.0
var _popup: Control             # the "share" / "get a track" box
var _popup_box: VBoxContainer


func _ready() -> void:
	Sfx.play_music("garage")
	theme = Game.ui_theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_index = clampi(Game.selected_track, 0, Game.track_count() - 1)
	for i in Game.track_count():
		_maps.append(TrackMap.compute(i))

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.2, 0.15, 0.4)
	add_child(bg)
	var dots_bg := DotsBackground.new()
	dots_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dots_bg)

	var header := RaceHud.make_label("PICK A TRACK!", 60, Color(1.0, 0.85, 0.2), 16)
	_header = header
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
	# Your own tracks can be changed or thrown away.
	_custom_row = HBoxContainer.new()
	_custom_row.add_theme_constant_override("separation", 10)
	info.add_child(_custom_row)
	var edit := _button(_custom_row, "Edit", func(): Game.goto_editor(_index - Track.TRACKS.size()))
	var share := _button(_custom_row, "Share", _share)
	share.tooltip_text = "Get a code so friends can race this track"
	_delete_button = _button(_custom_row, "Delete", _delete_custom)
	for b: Button in [edit, share, _delete_button]:
		b.add_theme_font_size_override("font_size", 20)

	# A "MY TRACK" ribbon on the corner of your own tracks, so they stand out.
	_badge = PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(1.0, 0.3, 0.55)
	bs.set_corner_radius_all(16)
	bs.set_border_width_all(5)
	bs.border_color = Color.WHITE
	bs.set_content_margin_all(10)
	bs.shadow_color = Color(0, 0, 0, 0.35)
	bs.shadow_size = 8
	_badge.add_theme_stylebox_override("panel", bs)
	_badge_label = RaceHud.make_label("", 26, Color.WHITE, 8)
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.add_child(_badge_label)
	RaceHud.pin(_badge, Vector2(0.5, 0.5), Vector2(300, -282), Vector2(240, 60))
	_badge.rotation = deg_to_rad(8.0)
	add_child(_badge)

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
	for i in Game.track_count():
		if i == Track.TRACKS.size():
			# A little gap and a wrench between the game's tracks and yours.
			var gap := RaceHud.make_label("|", 30, Color(1, 1, 1, 0.5), 4)
			gap.set_meta("divider", true)
			_dots.add_child(gap)
		var d := Panel.new()
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.set_meta("track", i)
		_dots.add_child(d)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	RaceHud.pin(bottom, Vector2(0.5, 1), Vector2(-500, -92), Vector2(1000, 80))
	add_child(bottom)
	_button(bottom, "Back", _go_back)
	var build := _button(bottom, "Build a Track!", func(): Game.goto_editor(-1))
	# Top-left, so the bottom row still fits on small screens.
	var get_track := _button(self, "Get a Track", _open_get)
	get_track.tooltip_text = "Type a friend's track code"
	get_track.add_theme_font_size_override("font_size", 22)
	RaceHud.pin(get_track, Vector2(0, 0), Vector2(16, 16), Vector2(210, 52))
	build.add_theme_font_size_override("font_size", 24)
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
	if _popup and _popup.visible:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("steer_left"):
		_change(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("steer_right"):
		_change(1)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _popup and _popup.visible:
		_close_popup()
		return
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _go_back() -> void:
	Sfx.play("back")
	Game.goto_garage()


func _change(d: int) -> void:
	_index = wrapi(_index + d, 0, Game.track_count())
	Sfx.play("click", 1.0 + d * 0.1)
	_show()
	# A little bounce so it feels like flipping a card
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.92, 0.92)
	create_tween().tween_property(_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _delete_custom() -> void:
	if not _delete_armed:
		_delete_armed = true
		_delete_button.text = "Sure?"
		return
	var slot := _index - Track.TRACKS.size()
	if slot >= 0 and slot < Game.custom_tracks.size():
		Game.custom_tracks.remove_at(slot)
		Game.selected_track = clampi(Game.selected_track, 0, Game.track_count() - 1)
		Game.save_settings()
		Sfx.play("crash", 1.3, -10.0)
		Game.goto_track_select()


func _show() -> void:
	_delete_armed = false
	if _delete_button:
		_delete_button.text = "Delete"
	_custom_row.visible = Game.is_custom_track(_index)
	var info: Dictionary = Game.track_info(_index)
	var col: Color = info["color"]
	var mine := Game.is_custom_track(_index)
	# Your own tracks get a blueprint look and a rainbow border.
	_card_style.bg_color = Color(0.09, 0.27, 0.58) if mine else col.darkened(0.15)
	_card_style.set_border_width_all(10 if mine else 8)
	if not mine:
		_card_style.border_color = Color(1.0, 0.85, 0.2)
	_map.blueprint = mine
	_badge.visible = mine
	var owner: String = info.get("by", "") if info.get("by", "") != "" else Game.player_name
	_badge_label.text = "MY TRACK!" if owner == "" else "%s'S TRACK!" % owner.to_upper()
	_badge.custom_minimum_size = Vector2(0, 0)
	_header.text = "YOUR OWN TRACKS!" if mine else "PICK A TRACK!"
	_header.add_theme_color_override("font_color", Color(0.55, 1.0, 1.0) if mine else Color(1.0, 0.85, 0.2))
	_room_label.text = "%d / %d   -   %s" % [_index + 1, Game.track_count(), info["room_name"]]
	_name_label.text = info["name"]
	var stars := int(info["stars"])
	_stars_label.text = "Trickiness  " + "★".repeat(stars) + "☆".repeat(3 - stars)
	if info.get("custom", false):
		var by: String = info.get("by", "")
		_stars_label.text = "Built by %s!" % (by if by != "" else (Game.player_name if Game.player_name != "" else "YOU"))
	var lines := PackedStringArray()
	for f: String in info["features"]:
		lines.append("*  " + f)
	_features_label.text = "\n".join(lines)
	_blurb_label.text = info["blurb"]
	_update_best()
	_map.set_data(_maps[_index])
	for child in _dots.get_children():
		if not child.has_meta("track"):
			continue
		var i: int = child.get_meta("track")
		var dot := child as Panel
		var custom_dot := Game.is_custom_track(i)
		var sb := StyleBoxFlat.new()
		# The game's tracks are round dots; yours are blue diamonds.
		sb.set_corner_radius_all(3 if custom_dot else 12)
		sb.bg_color = Color(0.35, 0.75, 1.0) if custom_dot else Game.track_info(i)["color"]
		sb.set_border_width_all(4 if i == _index else (2 if custom_dot else 0))
		sb.border_color = Color.WHITE
		dot.add_theme_stylebox_override("panel", sb)
		dot.custom_minimum_size = Vector2(30, 30) if i == _index else Vector2(18, 18)
		dot.pivot_offset = dot.custom_minimum_size * 0.5
		dot.rotation = PI / 4.0 if custom_dot else 0.0


func _process(delta: float) -> void:
	_time += delta
	if Game.is_custom_track(_index):
		_card_style.border_color = Color.from_hsv(fmod(_time * 0.3, 1.0), 0.65, 1.0)
		_badge.pivot_offset = _badge.size * 0.5
		var pulse := 1.0 + sin(_time * 4.0) * 0.05
		_badge.scale = Vector2(pulse, pulse)


# ---------------------------------------------------------------------------
# Sharing tracks with a code
# ---------------------------------------------------------------------------

func _share() -> void:
	var slot := _index - Track.TRACKS.size()
	if slot < 0 or slot >= Game.custom_tracks.size():
		return
	var t: Dictionary = Game.custom_tracks[slot].duplicate()
	if not t.has("by"):
		t["by"] = Game.player_name if Game.player_name != "" else "a friend"
	_show_popup("Share This Track")
	_popup_text("Getting a code...", 26, Color.WHITE)
	var res: Dictionary = await Net.share_track(t)
	if not is_inside_tree():
		return
	_clear_popup()
	if res.has("code"):
		var code := String(res["code"])
		_popup_text("Tell your friends this code:", 24, Color.WHITE)
		_popup_text(code, 72, Color(1.0, 0.9, 0.3))
		_popup_text("They tap Get a Track and type it in.", 20, Color(0.8, 0.9, 1.0))
		var row := _popup_row()
		_button(row, "Copy Code", func():
			DisplayServer.clipboard_set(code)
			Sfx.play("select"))
		_button(row, "Done", _close_popup).grab_focus()
		Sfx.play("voice_unlock")
	else:
		_popup_text(String(res.get("error", "Something went wrong.")), 22, Color(1.0, 0.7, 0.5))
		_button(_popup_row(), "OK", _close_popup).grab_focus()


func _open_get() -> void:
	_show_popup("Get a Track")
	_popup_text("Type your friend's track code:", 24, Color.WHITE)
	var edit := LineEdit.new()
	edit.max_length = 5
	edit.placeholder_text = "ABCDE"
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(300, 70)
	edit.add_theme_font_size_override("font_size", 44)
	edit.text_changed.connect(func(t: String):
		if t.to_upper() != t:
			var c := edit.caret_column
			edit.text = t.to_upper()
			edit.caret_column = c)
	_popup_box.add_child(edit)
	var status := _popup_text("", 20, Color(1.0, 0.75, 0.5))
	var row := _popup_row()
	var get_it := _button(row, "Get It!", func(): _fetch(edit, status))
	edit.text_submitted.connect(func(_t: String): _fetch(edit, status))
	_button(row, "Cancel", _close_popup)
	get_it.add_theme_font_size_override("font_size", 30)
	edit.grab_focus.call_deferred()


func _fetch(edit: LineEdit, status: Label) -> void:
	if Game.custom_tracks.size() >= Game.MAX_CUSTOM_TRACKS:
		status.text = "You have %d tracks already! Delete one first." % Game.MAX_CUSTOM_TRACKS
		return
	status.text = "Getting the track..."
	status.add_theme_color_override("font_color", Color.WHITE)
	var res: Dictionary = await Net.fetch_track(edit.text)
	if not is_inside_tree():
		return
	if not res.has("pieces"):
		status.text = String(res.get("error", "Couldn't get that track."))
		status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5))
		Sfx.play("back")
		return
	var pieces: Array = []
	for p in res["pieces"]:
		if not Track.piece_info(String(p)).is_empty():
			pieces.append(String(p))
	Game.custom_tracks.append({"name": String(res.get("name", "Shared Track")).substr(0, 24),
		"room": String(res.get("room", "bedroom")), "pieces": pieces,
		"by": String(res.get("by", "a friend")).substr(0, Game.NAME_LENGTH)})
	Game.selected_track = Game.track_count() - 1
	Game.save_settings()
	Sfx.play("voice_unlock")
	Game.goto_track_select()   # reload, showing the new track


func _show_popup(title: String) -> void:
	if _popup == null:
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.add_child(center)
		var panel := PanelContainer.new()
		center.add_child(panel)
		_popup_box = VBoxContainer.new()
		_popup_box.add_theme_constant_override("separation", 12)
		_popup_box.custom_minimum_size = Vector2(560, 0)
		panel.add_child(_popup_box)
		_popup = dim
	_clear_popup(true)
	var t := RaceHud.make_label(title, 44, Color(0.55, 1.0, 1.0), 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_box.add_child(t)
	_popup.visible = true


func _clear_popup(all := false) -> void:
	for i in range(_popup_box.get_child_count() - 1, 0 if not all else -1, -1):
		var c := _popup_box.get_child(i)
		_popup_box.remove_child(c)
		c.queue_free()


func _close_popup() -> void:
	_popup.visible = false
	_race_button.grab_focus()


func _popup_text(text: String, size: int, col: Color) -> Label:
	var l := RaceHud.make_label(text, size, col, 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_box.add_child(l)
	return l


func _popup_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_popup_box.add_child(row)
	return row


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
	var blueprint := false:
		set(v):
			blueprint = v
			queue_redraw()

	static func compute(index: int) -> Array:
		var t := Track.for_index(index)
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
		if blueprint:
			# Graph-paper grid, like a plan you drew yourself.
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.18, 0.42), true)
			var step := 24.0
			var x := 0.0
			while x <= size.x:
				draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.55, 0.8, 1.0, 0.18), 1.0)
				x += step
			var y := 0.0
			while y <= size.y:
				draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.55, 0.8, 1.0, 0.18), 1.0)
				y += step
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.9, 1.0, 0.6), false, 3.0)
		else:
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
			if blueprint:
				draw_line(a, b, Color(0.02, 0.1, 0.3, 0.9), 12.0, true)
				draw_line(a, b, Color(0.55, 0.85, 1.0).lerp(Color.WHITE, h), 7.0, true)
			else:
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
