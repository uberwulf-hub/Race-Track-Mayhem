class_name Toast
extends CanvasLayer
## Pop-ups that slide in at the top of the screen, like "BADGE EARNED!".
## Lives above every scene (added by Game) so badges earned in menus show too.

var _queue: Array = []
var _busy := false


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.badge_earned.connect(func(id: String): show_badge(id))
	Net.invite_received.connect(show_invite)


func show_badge(badge_id: String) -> void:
	_queue.append(badge_id)
	if not _busy:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var b := Badges.get_badge(_queue.pop_front())
	if b.is_empty():
		_next()
		return
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.08, 0.25, 0.94)
	sb.border_color = b["color"]
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 16
	sb.content_margin_right = 24
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	row.add_child(BadgeMedal.make(b, true, 70))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(RaceHud.make_label("BADGE EARNED!", 20, Color(1.0, 0.9, 0.35), 6))
	col.add_child(RaceHud.make_label(b["name"], 30, Color.WHITE, 8))
	col.add_child(RaceHud.make_label(b["desc"], 18, Color(0.85, 0.85, 1.0), 5))
	add_child(panel)
	await get_tree().process_frame
	var w := get_viewport().get_visible_rect().size.x
	panel.position = Vector2((w - panel.size.x) * 0.5, -panel.size.y - 10)
	Sfx.play("voice_unlock")
	Sfx.play("pickup")
	var tw := panel.create_tween()
	tw.tween_property(panel, "position:y", 16.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.8)
	tw.tween_property(panel, "position:y", -panel.size.y - 10, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		panel.queue_free()
		_next())


## "Noah wants to race you!" with Join and Not Now. Stays up for 20 seconds.
func show_invite(from_name: String, room: String) -> void:
	if room == "":
		return
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.18, 0.35, 0.96)
	sb.border_color = Color(0.5, 1.0, 0.6)
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.theme = Game.ui_theme
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := RaceHud.make_label("%s wants to race you!" % from_name, 34, Color(0.6, 1.0, 0.7), 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var join := Button.new()
	join.text = "Join!"
	join.add_theme_font_size_override("font_size", 34)
	row.add_child(join)
	var no := Button.new()
	no.text = "Not Now"
	no.add_theme_font_size_override("font_size", 24)
	row.add_child(no)
	add_child(panel)
	join.pressed.connect(func():
		Sfx.play("go")
		panel.queue_free()
		_join_friend(room))
	no.pressed.connect(func():
		Sfx.play("back")
		panel.queue_free())
	await get_tree().process_frame
	var vs := get_viewport().get_visible_rect().size
	panel.position = Vector2((vs.x - panel.size.x) * 0.5, vs.y * 0.3)
	join.grab_focus()
	Sfx.play("voice_unlock")
	Sfx.play("pickup")
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.4, 0.4)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(20.0).timeout.connect(func():
		if is_instance_valid(panel):
			panel.queue_free())


func _join_friend(room: String) -> void:
	if Net.active:
		Net.leave("")
	Game.end_grand_prix()
	Game.pending_join = room
	Game.goto("res://scenes/online.tscn")
