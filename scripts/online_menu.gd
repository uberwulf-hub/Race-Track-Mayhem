extends Control
## Race Online: host a race or join one on your home network, then wait in
## the lobby. The host picks the track and settings; everyone picks a car.

var _browse: VBoxContainer
var _lobby: VBoxContainer
var _games_box: VBoxContainer
var _address: LineEdit
var _message: Label
var _players_box: VBoxContainer
var _settings_box: GridContainer
var _lobby_title: Label
var _address_label: Label
var _car_label: Label
var _start_button: Button
var _wait_label: Label
var _lobby_cols: Control
var _code: LineEdit


func _ready() -> void:
	Sfx.play_music("menu")
	theme = Game.ui_theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.13, 0.2, 0.42)
	add_child(bg)
	var dots := TrackSelectDots.new()
	dots.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dots)

	var header := RaceHud.make_label("RACE ONLINE!", 60, Color(0.55, 1.0, 1.0), 16)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RaceHud.pin(header, Vector2(0.5, 0), Vector2(-500, 10), Vector2(1000, 76))
	add_child(header)

	_message = RaceHud.make_label("", 19, Color(1.0, 0.75, 0.5), 8)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	RaceHud.pin(_message, Vector2(0.5, 1), Vector2(-560, -96), Vector2(1120, 90))
	add_child(_message)

	_build_browse()
	_build_lobby()
	Net.lobby_changed.connect(_refresh_lobby)
	Net.games_found_changed.connect(_refresh_games)
	Net.join_failed.connect(func(reason: String):
		_show_browse()
		_say(reason))
	Net.session_ended.connect(func(reason: String):
		if is_inside_tree():
			_show_browse()
			_say(reason))

	if Net.active:
		_show_lobby()   # back from a race
	else:
		_show_browse()


func _exit_tree() -> void:
	Net.stop_looking()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Sfx.play("back")
		if _lobby.visible:
			Net.leave("")
			_show_browse()
		else:
			Game.goto_menu()


func _say(text: String) -> void:
	_message.text = text


# ---------------------------------------------------------------------------
# Finding a race
# ---------------------------------------------------------------------------

func _build_browse() -> void:
	_browse = VBoxContainer.new()
	_browse.add_theme_constant_override("separation", 14)
	RaceHud.pin(_browse, Vector2(0.5, 0), Vector2(-380, 100), Vector2(760, 520))
	add_child(_browse)
	var hosts := HBoxContainer.new()
	hosts.add_theme_constant_override("separation", 12)
	_browse.add_child(hosts)
	var host := _button(hosts, "Host at Home", _host)
	host.tooltip_text = "Race people on the same Wi-Fi"
	var host_net := _button(hosts, "Host on the Internet", _host_internet)
	host_net.tooltip_text = "Race people in other houses: you get a code to give them"
	host_net.add_theme_color_override("font_color", Color(0.75, 1.0, 1.0))
	for b: Button in [host, host_net]:
		b.add_theme_font_size_override("font_size", 30)
		b.custom_minimum_size = Vector2(0, 76)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 10)
	_browse.add_child(code_row)
	code_row.add_child(RaceHud.make_label("Got a race code?", 26, Color(0.75, 1.0, 1.0), 8))
	_code = LineEdit.new()
	_code.placeholder_text = "ABCD"
	_code.max_length = 4
	_code.custom_minimum_size = Vector2(150, 56)
	_code.add_theme_font_size_override("font_size", 32)
	_code.text_changed.connect(func(t: String):
		var up := t.to_upper()
		if up != t:
			var caret := _code.caret_column
			_code.text = up
			_code.caret_column = caret)
	_code.text_submitted.connect(func(_t: String): _join_code())
	code_row.add_child(_code)
	var join_code := _button(code_row, "Join Internet Race", _join_code)
	join_code.add_theme_font_size_override("font_size", 24)
	var wifi_row := HBoxContainer.new()
	wifi_row.add_theme_constant_override("separation", 12)
	_browse.add_child(wifi_row)
	var wifi_label := RaceHud.make_label("Races on your Wi-Fi:", 26, Color(1.0, 0.9, 0.5), 8)
	wifi_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wifi_row.add_child(wifi_label)
	if OS.get_name() == "Windows":
		# Windows Firewall often blocks home races (especially after "Cancel" on its prompt).
		var fw := _button(wifi_row, "Fix Firewall", _fix_firewall)
		fw.tooltip_text = "Let Race Track Mayhem through Windows Firewall (do this on BOTH computers)"
		fw.add_theme_font_size_override("font_size", 20)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 130)
	_browse.add_child(panel)
	_games_box = VBoxContainer.new()
	_games_box.add_theme_constant_override("separation", 8)
	panel.add_child(_games_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_browse.add_child(row)
	row.add_child(RaceHud.make_label("Or join at home by address:", 22))
	_address = LineEdit.new()
	_address.placeholder_text = "like 192.168.1.20"
	_address.custom_minimum_size = Vector2(260, 52)
	_address.add_theme_font_size_override("font_size", 24)
	_address.text_submitted.connect(func(_t: String): _join(_address.text))
	row.add_child(_address)
	_button(row, "Join", func(): _join(_address.text))
	_button(_browse, "Back", func(): Game.goto_menu())


func _show_browse() -> void:
	_browse.visible = true
	_lobby.visible = false
	Net.start_looking()
	_refresh_games()
	(_browse.get_child(0).get_child(0) as Button).grab_focus.call_deferred()


func _refresh_games() -> void:
	if _games_box == null:
		return
	for c in _games_box.get_children():
		_games_box.remove_child(c)
		c.queue_free()
	if Net.found.is_empty():
		var hint := "Looking for races...  (the other computer taps \"Host at Home\")"
		if OS.get_name() == "Windows":
			hint += "\nNot showing up? Tap Fix Firewall on both computers, or use Host on the Internet."
		var l := RaceHud.make_label(hint, 20, Color(1, 1, 1, 0.7), 4)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_games_box.add_child(l)
		return
	for ip in Net.found:
		var g: Dictionary = Net.found[ip]
		var text := "%s's race   (%d racing)" % [g["name"], g["players"]]
		if not g["same_version"]:
			text += "  - different version"
		elif not g["open"]:
			text += "  - racing now"
		var b := _button(_games_box, text, func(): _join(ip))
		b.disabled = not g["same_version"] or not g["open"]
		b.add_theme_font_size_override("font_size", 26)


func _host() -> void:
	var err := Net.host()
	if err != "":
		_say(err)
		return
	_say("")
	_show_lobby()


func _fix_firewall() -> void:
	if Net.fix_firewall():
		_say("Windows will ask \"Allow this app to make changes?\" - choose Yes. Do this on BOTH computers, then host or look for races again.")
	else:
		_say("Couldn't open the Windows firewall settings. Try Host on the Internet instead - it needs no firewall changes.")


func _host_internet() -> void:
	_say("")
	Net.host_internet()
	_show_lobby()


func _join_code() -> void:
	_say("Joining...")
	Net.join_internet(_code.text)
	_show_lobby()


func _join(address: String) -> void:
	_say("Joining...")
	Net.join(address)
	_show_lobby()


# ---------------------------------------------------------------------------
# The lobby
# ---------------------------------------------------------------------------

func _build_lobby() -> void:
	_lobby = VBoxContainer.new()
	_lobby.add_theme_constant_override("separation", 10)
	RaceHud.pin(_lobby, Vector2(0.5, 0), Vector2(-560, 90), Vector2(1120, 560))
	add_child(_lobby)
	_lobby_title = RaceHud.make_label("", 34, Color(1.0, 0.9, 0.4), 10)
	_lobby_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby.add_child(_lobby_title)
	_address_label = RaceHud.make_label("", 20, Color(0.8, 0.9, 1.0), 6)
	_address_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby.add_child(_address_label)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	_lobby.add_child(cols)
	_lobby_cols = cols
	# Left: who's here and my car
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(500, 330)
	cols.add_child(left)
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", 6)
	left.add_child(lbox)
	lbox.add_child(RaceHud.make_label("Racers", 28, Color(0.55, 1.0, 1.0), 8))
	_players_box = VBoxContainer.new()
	lbox.add_child(_players_box)
	var car_row := HBoxContainer.new()
	car_row.add_theme_constant_override("separation", 8)
	lbox.add_child(car_row)
	car_row.add_child(RaceHud.make_label("Your car:", 24))
	_button(car_row, "<", func(): _change_car(-1))
	_car_label = RaceHud.make_label("", 24, Color(1.0, 0.9, 0.4), 8)
	_car_label.custom_minimum_size = Vector2(190, 0)
	_car_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	car_row.add_child(_car_label)
	_button(car_row, ">", func(): _change_car(1))
	# Right: race settings (the host can change them)
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(580, 330)
	cols.add_child(right)
	var rbox := VBoxContainer.new()
	right.add_child(rbox)
	rbox.add_child(RaceHud.make_label("The Race", 28, Color(0.55, 1.0, 1.0), 8))
	_settings_box = GridContainer.new()
	_settings_box.columns = 2
	_settings_box.add_theme_constant_override("h_separation", 16)
	_settings_box.add_theme_constant_override("v_separation", 6)
	rbox.add_child(_settings_box)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	_lobby.add_child(bottom)
	_button(bottom, "Leave", func():
		Net.leave("")
		_show_browse())
	_start_button = _button(bottom, "START RACE!", func(): Net.start_race())
	_start_button.add_theme_font_size_override("font_size", 40)
	_wait_label = RaceHud.make_label("Waiting for the host to start...", 26, Color(0.7, 0.9, 1.0), 8)
	bottom.add_child(_wait_label)


func _show_lobby() -> void:
	Net.stop_looking()
	_browse.visible = false
	_lobby.visible = true
	_refresh_lobby()


func _refresh_lobby() -> void:
	if not _lobby.visible:
		return
	if not Net.active:
		return
	var joining := Net.players.is_empty()
	_lobby_cols.visible = not joining   # nothing to show until the host answers
	_wait_label.text = "Connecting to the race..." if joining else "Waiting for the host to start..."
	if joining:
		_lobby_title.text = "Joining..."
	else:
		_lobby_title.text = "%s's race" % String(Net.players.get(1, {}).get("name", "?"))
		_say("")
	if Net.internet and Net.is_host:
		_address_label.text = ("Race code:  %s     Tell your cousins to type it in Race Online!" % Net.room_code) if Net.room_code != "" \
			else "Getting a race code..."
		_address_label.add_theme_font_size_override("font_size", 28)
		_address_label.add_theme_color_override("font_color", Color(0.6, 1.0, 1.0))
	elif Net.is_host:
		_address_label.text = "Others on your Wi-Fi can find you automatically, or join at:  %s" % Net.local_address()
	else:
		_address_label.text = ("Internet race  %s" % Net.room_code) if Net.internet else ""
	for c in _players_box.get_children():
		_players_box.remove_child(c)
		c.queue_free()
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = Net.players[id]
		var tag := "  (host)" if int(id) == 1 else ""
		var me := int(id) == Net.my_id()
		var l := RaceHud.make_label("%s  -  %s%s%s" % [p["name"], CarData.get_car(int(p["car"]))["name"], tag, "   < you" if me else ""],
			24, Color(1.0, 0.9, 0.4) if me else Color.WHITE, 6)
		_players_box.add_child(l)
	_car_label.text = CarData.get_car(_my_car())["name"]
	_fill_settings()
	_start_button.visible = Net.is_host
	_wait_label.visible = not Net.is_host


func _my_car() -> int:
	var car: int = Game.selected_car
	return car if CarData.is_available(car) else 0


func _change_car(d: int) -> void:
	var car := _my_car()
	for i in CarData.count():
		car = wrapi(car + d, 0, CarData.count())
		if CarData.is_available(car):
			break
	Net.set_my_car(car)
	_refresh_lobby()


func _fill_settings() -> void:
	for c in _settings_box.get_children():
		_settings_box.remove_child(c)
		c.queue_free()
	var st := Net.settings
	var track_name: String = Game.track_info(int(st["track"]))["name"] if not Game.is_custom_track(int(st["track"])) or Net.is_host \
		else String(Net.custom_track.get("name", "Host's track"))
	_setting("Track:", track_name, func():
		Net.set_setting("track", wrapi(int(st["track"]) + 1, 0, Game.track_count())))
	_setting("Laps:", str(st["laps"]), func():
		Net.set_setting("laps", int(st["laps"]) % 9 + 1))
	_setting("Computer cars:", "On" if st["ai"] else "Off", func(): Net.set_setting("ai", not st["ai"]))
	_setting("Computer drivers:", Game.DIFFICULTY_NAMES[int(st["difficulty"])], func():
		Net.set_setting("difficulty", (int(st["difficulty"]) + 1) % 3))
	_setting("Power-ups:", "On" if st["powerups"] else "Off", func(): Net.set_setting("powerups", not st["powerups"]))


## A setting row: the host gets a button to change it, everyone else just sees it.
func _setting(label: String, value: String, change: Callable) -> void:
	_settings_box.add_child(RaceHud.make_label(label, 24))
	if Net.is_host:
		var b := _button(_settings_box, value, change)
		b.custom_minimum_size = Vector2(300, 0)
		b.add_theme_font_size_override("font_size", 24)
		b.clip_text = true
	else:
		_settings_box.add_child(RaceHud.make_label(value, 24, Color(1.0, 0.9, 0.4), 6))


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	parent.add_child(b)
	return b


## Soft polka dots so the background isn't plain.
class TrackSelectDots extends Control:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		for i in 40:
			var c := Color.from_hsv(rng.randf(), 0.5, 1.0, 0.15)
			draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(20.0, 70.0), c)
