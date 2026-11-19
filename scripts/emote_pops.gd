class_name EmotePops
extends Control
## Online emotes pop up as bubbles down the left side of the screen: a funny
## face (or a word like "Nice!") and who sent it. They slide in, wobble, and
## fade away after a few seconds. Add it to a full-screen Control or layer.

const SHOW_FOR := 3.2
const MAX_BUBBLES := 5

var _list: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("separation", 8)
	_list.alignment = BoxContainer.ALIGNMENT_END
	# Left edge, from a third of the way down to near the bottom.
	_list.anchor_left = 0.0
	_list.anchor_right = 0.0
	_list.anchor_top = 0.3
	_list.anchor_bottom = 0.85
	_list.offset_left = 14
	_list.offset_right = 300
	add_child(_list)


func pop(who: String, emote: String) -> void:
	while _list.get_child_count() >= MAX_BUBBLES:
		var old := _list.get_child(0)
		_list.remove_child(old)
		old.queue_free()
	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.3, 0.88)
	sb.border_color = Color(1.0, 0.85, 0.3)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 10
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	bubble.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	bubble.add_child(row)
	if EmoteFaces.is_face(emote):
		var face := TextureRect.new()
		face.texture = EmoteFaces.texture(emote)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(64, 64)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(face)
	else:
		var word := RaceHud.make_label(emote, 30, Net.emote_color(emote), 8)
		row.add_child(word)
	var name_l := RaceHud.make_label(who, 22, Color.WHITE, 6)
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_l)
	_list.add_child(bubble)
	# Slide in from the left with a little bounce, then fade out.
	bubble.modulate.a = 0.0
	bubble.pivot_offset = Vector2(0, 36)
	bubble.scale = Vector2(0.6, 0.6)
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(bubble, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bubble, "rotation", 0.06, 0.12)
	tw.tween_property(bubble, "rotation", -0.04, 0.12)
	tw.tween_property(bubble, "rotation", 0.0, 0.1)
	tw.tween_interval(SHOW_FOR)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.5)
	tw.tween_callback(bubble.queue_free)
