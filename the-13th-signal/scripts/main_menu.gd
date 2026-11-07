extends Control
## Title screen: start the game, pick a mode (scary modes need the Parent PIN),
## options, and Parent Settings.

const PinPad := preload("res://scripts/pin_pad.gd")

var _title: Label
var _mode_button: Button
var _mode_blurb: Label
var _main_box: VBoxContainer
var _options_box: VBoxContainer
var _parent_box: VBoxContainer
var _parent_status: Label
var _pad: Control
var _flicker := 0.0
var _new_pin := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = Game.theme
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Sound.start_ambient(-14.0)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.025)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var noise := ColorRect.new()
	noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	noise.material = Game.static_material(0.05)
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(noise)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	_title = Label.new()
	_title.text = "THE 13TH SIGNAL"
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	col.add_child(_title)
	var tag := Label.new()
	tag.text = "You were never supposed to hear it."
	tag.add_theme_color_override("font_color", Color(0.45, 0.7, 0.85))
	col.add_child(tag)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	col.add_child(spacer)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 10)
	col.add_child(_main_box)
	_add_button(_main_box, "START  -  SECTOR 1: INTAKE", _start)
	_mode_button = _add_button(_main_box, "", _cycle_mode)
	_mode_blurb = Label.new()
	_mode_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_blurb.custom_minimum_size = Vector2(560, 56)
	_mode_blurb.add_theme_font_size_override("font_size", 16)
	_main_box.add_child(_mode_blurb)
	_add_button(_main_box, "OPTIONS", _show_options)
	_add_button(_main_box, "PARENT SETTINGS", _open_parent)
	_add_button(_main_box, "QUIT", func(): get_tree().quit())

	_build_options(col)
	_build_parent(col)

	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(push)
	var advisory := Label.new()
	advisory.text = "No blood or gore. Scares come from sound, darkness and surprise.   Controls: WASD move  |  Shift run  |  Ctrl crouch  |  E use  |  F flashlight  |  Space hold breath  |  Tab journal"
	advisory.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advisory.add_theme_font_size_override("font_size", 14)
	advisory.add_theme_color_override("font_color", Color(0.4, 0.55, 0.65))
	col.add_child(advisory)

	_refresh_mode()
	_main_box.get_child(0).grab_focus()


func _add_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		Sound.play("click", -6.0)
		cb.call())
	parent.add_child(b)
	return b


func _process(delta: float) -> void:
	# The title flickers like a bad signal now and then.
	_flicker -= delta
	if _flicker <= 0.0:
		_flicker = randf_range(0.05, 3.5)
		_title.modulate.a = 1.0 if randf() > 0.25 else randf_range(0.2, 0.7)


# ------------------------------------------------------------------- modes

func _refresh_mode() -> void:
	var m := Game.mode_data()
	var lock := ""
	if Game.mode == Game.Mode.EXPLORER and not Game.scary_unlocked:
		lock = "   (Survivor & Nightmare: Parent Lock)"
	_mode_button.text = "MODE:  %s%s" % [m["name"], lock]
	_mode_button.add_theme_color_override("font_color", m["color"])
	_mode_blurb.text = m["blurb"]


func _cycle_mode() -> void:
	var next := (Game.mode + 1) % Game.MODES.size()
	if Game.mode_allowed(next):
		Game.mode = next
		_refresh_mode()
		return
	if not Game.has_pin():
		_mode_blurb.text = "Survivor and Nightmare are locked. A parent can create a PIN in PARENT SETTINGS to unlock them."
		return
	_ask_pin("PARENT LOCK\nEnter the Parent PIN to unlock Survivor and Nightmare for this session.", func(pin: String):
		if Game.check_pin(pin):
			Game.scary_unlocked = true
			Game.mode = next
			_close_pad()
			_refresh_mode()
		else:
			_pad.show_message("That's not the PIN.")
			_pad.clear_entry())


func _start() -> void:
	Sound.stop_ambient()
	get_tree().change_scene_to_file("res://scenes/sector.tscn")


# ----------------------------------------------------------------- options

func _build_options(col: VBoxContainer) -> void:
	_options_box = VBoxContainer.new()
	_options_box.visible = false
	_options_box.add_theme_constant_override("separation", 10)
	col.add_child(_options_box)
	_slider(_options_box, "Mouse sensitivity", 0.05, 0.8, Game.mouse_sensitivity, func(v): Game.mouse_sensitivity = v)
	_slider(_options_box, "Volume", 0.0, 1.0, Game.volume, func(v):
		Game.volume = v
		Game.apply_volume())
	_slider(_options_box, "Brightness", 0.6, 1.8, Game.brightness, func(v): Game.brightness = v)
	var inv := CheckBox.new()
	inv.text = "Invert look up/down"
	inv.button_pressed = Game.invert_y
	inv.toggled.connect(func(on): Game.invert_y = on)
	_options_box.add_child(inv)
	_add_button(_options_box, "BACK", func():
		Game.save_settings()
		_options_box.visible = false
		_main_box.visible = true)


func _slider(parent: Control, label: String, lo: float, hi: float, value: float, cb: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 240
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(300, 32)
	s.value_changed.connect(cb)
	h.add_child(s)
	parent.add_child(h)


func _show_options() -> void:
	_main_box.visible = false
	_options_box.visible = true


# ---------------------------------------------------------- parent settings

func _build_parent(col: VBoxContainer) -> void:
	_parent_box = VBoxContainer.new()
	_parent_box.visible = false
	_parent_box.add_theme_constant_override("separation", 10)
	col.add_child(_parent_box)
	_parent_status = Label.new()
	_parent_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_parent_status.custom_minimum_size.x = 640
	_parent_box.add_child(_parent_status)
	_add_button(_parent_box, "CHANGE PARENT PIN", func(): _create_pin_flow())
	_add_button(_parent_box, "LOCK SCARY MODES NOW", func():
		Game.lock_scary_modes()
		_refresh_mode()
		_refresh_parent())
	_add_button(_parent_box, "REMOVE PIN  (scary modes stay locked)", func():
		Game.remove_pin()
		_refresh_mode()
		_close_parent())
	_add_button(_parent_box, "BACK", _close_parent)


func _refresh_parent() -> void:
	var state := "UNLOCKED for this session" if Game.scary_unlocked else "LOCKED"
	_parent_status.text = ("PARENT SETTINGS\n\nThe game always starts in EXPLORER mode. Survivor and Nightmare "
		+ "need this PIN once each time the game is opened.\n\nScary modes right now: %s") % state


func _open_parent() -> void:
	if not Game.has_pin():
		_create_pin_flow()
		return
	_ask_pin("PARENT SETTINGS\nEnter the Parent PIN.", func(pin: String):
		if Game.check_pin(pin):
			_close_pad()
			_main_box.visible = false
			_parent_box.visible = true
			_refresh_parent()
		else:
			_pad.show_message("That's not the PIN.")
			_pad.clear_entry())


func _close_parent() -> void:
	_parent_box.visible = false
	_main_box.visible = true


func _create_pin_flow() -> void:
	_new_pin = ""
	_ask_pin("CREATE A PARENT PIN\nChoose 4 digits your younger player won't guess.", func(pin: String):
		if _new_pin == "":
			_new_pin = pin
			_pad.setup("CONFIRM THE PARENT PIN\nType the same 4 digits again.", true)
		elif pin == _new_pin:
			Game.set_pin(pin)
			_close_pad()
			_main_box.visible = false
			_parent_box.visible = true
			_refresh_parent()
		else:
			_new_pin = ""
			_pad.setup("CREATE A PARENT PIN\nThose didn't match. Choose 4 digits.", true))


func _ask_pin(title: String, on_submit: Callable) -> void:
	_close_pad()
	_pad = PinPad.new()
	add_child(_pad)
	_pad.setup(title, true)
	_pad.submitted.connect(on_submit)
	_pad.cancelled.connect(_close_pad)


func _close_pad() -> void:
	if _pad and is_instance_valid(_pad):
		_pad.queue_free()
	_pad = null
