extends Control
## A number pad. Used for the Parent PIN and for the elevator's exit code.
## Digits also work from the keyboard (Backspace deletes, Enter confirms, Esc cancels).

signal submitted(code: String)
signal cancelled

var length := 4
var masked := true
var _entry := ""
var _title: Label
var _display: Label
var _msg: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Game.theme
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.custom_minimum_size.x = 340
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_display = Label.new()
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display.add_theme_font_size_override("font_size", 44)
	_display.add_theme_color_override("font_color", Color(0.5, 1.0, 0.75))
	v.add_child(_display)
	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size.x = 340
	v.add_child(_msg)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for label in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "<", "0", "OK"]:
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(104, 58)
		b.add_theme_font_size_override("font_size", 26)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_press.bind(label))
		grid.add_child(b)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(_cancel)
	v.add_child(cancel)
	_refresh()


func setup(title: String, masked_entry := true, digits := 4) -> void:
	if _title == null:
		await ready
	_title.text = title
	masked = masked_entry
	length = digits
	_entry = ""
	_msg.text = ""
	_refresh()


func show_message(text: String, color := Color(1, 0.5, 0.45)) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", color)


func clear_entry() -> void:
	_entry = ""
	_refresh()


func _press(label: String) -> void:
	match label:
		"<":
			_entry = _entry.substr(0, maxi(_entry.length() - 1, 0))
		"OK":
			if _entry.length() == length:
				submitted.emit(_entry)
			else:
				show_message("Enter %d digits." % length)
		_:
			if _entry.length() < length:
				_entry += label
				Sound.play("key_beep", -8.0)
	_refresh()


func _cancel() -> void:
	cancelled.emit()


func _refresh() -> void:
	if _display == null:
		return
	var shown := ""
	for i in length:
		if i < _entry.length():
			shown += ("*" if masked else _entry[i]) + " "
		else:
			shown += "_ "
	_display.text = shown.strip_edges()


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if k >= KEY_0 and k <= KEY_9:
		_press(str(k - KEY_0))
	elif k >= KEY_KP_0 and k <= KEY_KP_9:
		_press(str(k - KEY_KP_0))
	elif k == KEY_BACKSPACE:
		_press("<")
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		_press("OK")
	elif k == KEY_ESCAPE:
		_cancel()
	else:
		return
	get_viewport().set_input_as_handled()
