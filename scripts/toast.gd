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
