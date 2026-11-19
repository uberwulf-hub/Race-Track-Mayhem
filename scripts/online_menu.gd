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
var _feed: Label
var _feed_lines: Array = []
var _friends_button: Button
var _friends_panel: Control
var _friends_list: VBoxContainer
var _friend_code_edit: LineEdit
var _friend_msg: Label
var _invite_note := ""   # "Invited Noah..." while waiting for a friend to join
var _preview_spin: Node3D    # turntable for the 3D preview of your car
var _preview_car := -1


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
	_build_friends()
	var back := _button(self, "< Back", _go_back)
	back.add_theme_font_size_override("font_size", 24)
	RaceHud.pin(back, Vector2(0, 0), Vector2(16, 16), Vector2(140, 56))
	Net.friends_changed.connect(_refresh_friends)
	Net.check_friends_soon()
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
	# Joining a friend's race from a "Race me!" invite.
	if Game.pending_join != "":
		_code.text = Game.pending_join
		Game.pending_join = ""
		_join_code()


func _exit_tree() -> void:
	Net.stop_looking()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Sfx.play("back")
		if _friends_panel.visible:
			_friends_panel.visible = false
		elif _lobby.visible:
			Net.leave("")
			_show_browse()
		else:
			Game.goto_menu()


## Back: out of the lobby to the race list, or from the list to the menu.
func _go_back() -> void:
	if _friends_panel.visible:
		_friends_panel.visible = false
	elif _lobby.visible:
		Net.leave("")
		_show_browse()
	else:
		Game.goto_menu()


## Shrinks the race list or lobby when the window is too short for it, so
## nothing (like START RACE!) ends up off the bottom.
func _process(delta: float) -> void:
	if _preview_spin:
		_preview_spin.rotation.y += delta * 0.8
	var screen := get_viewport().get_visible_rect().size
	for c: Control in [_browse, _lobby]:
		if c == null or not c.visible:
			continue
		var top := c.position.y
		var need := maxf(c.size.y, c.get_combined_minimum_size().y)
		var room := screen.y - top - 100.0   # leave room for the message line
		var k := clampf(room / maxf(1.0, need), 0.55, 1.0)
		c.pivot_offset = Vector2(c.size.x * 0.5, 0.0)
		c.scale = Vector2(k, k)


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
	# Races in this house, through the race server (these always work).
	for r in Net.home_races:
		if not r is Dictionary:
			continue
		var room := String(r.get("room", ""))
		var hname := String(r.get("name", "?")).substr(0, Game.NAME_LENGTH)
		var same := int(r.get("v", 0)) == Net.PROTOCOL
		var text := "%s%s's race   (%d racing)" % ["★ " if _is_friend_name(hname) else "", hname, int(r.get("players", 1))]
		if not same:
			text += "  - different version"
		elif not r.get("open", true):
			text += "  - racing now"
		var hb := _button(_games_box, text, func():
			_say("Joining...")
			Net.join_internet(room)
			_show_lobby())
		hb.disabled = not same or not r.get("open", true)
		hb.add_theme_font_size_override("font_size", 26)
	if Net.found.is_empty() and Net.home_races.is_empty():
		var hint := "Looking for races...  (the other computer taps \"Host at Home\")"
		if OS.get_name() == "Windows":
			hint += "\nNot showing up? Make sure both computers have the newest version, or use Host on the Internet."
		var l := RaceHud.make_label(hint, 20, Color(1, 1, 1, 0.7), 4)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_games_box.add_child(l)
		return
	var ips := Net.found.keys()
	# The same race can show up both ways; the race-server one is listed already.
	var listed: Array = Net.home_races.map(func(r): return String(r.get("name", "")) if r is Dictionary else "")
	ips = ips.filter(func(ip) -> bool: return not listed.has(String(Net.found[ip]["name"])))
	ips.sort_custom(func(a, b) -> bool: return _is_friend_name(Net.found[a]["name"]) and not _is_friend_name(Net.found[b]["name"]))
	for ip in ips:
		var g: Dictionary = Net.found[ip]
		var text := "%s%s's race   (%d racing)" % ["★ " if _is_friend_name(g["name"]) else "", g["name"], g["players"]]
		if not g["same_version"]:
			text += "  - different version"
		elif not g["open"]:
			text += "  - racing now"
		var b := _button(_games_box, text, func(): _join(ip))
		b.disabled = not g["same_version"] or not g["open"]
		b.add_theme_font_size_override("font_size", 26)


func _is_friend_name(n: String) -> bool:
	return Game.friends.any(func(f: Dictionary) -> bool: return String(f["name"]).to_lower() == n.to_lower())


func _host() -> void:
	_say("")
	Net.host_home()
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
	_arrow(car_row, "<", func(): _change_car(-1))
	_car_label = RaceHud.make_label("", 24, Color(1.0, 0.9, 0.4), 8)
	_car_label.custom_minimum_size = Vector2(190, 0)
	_car_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	car_row.add_child(_car_label)
	_arrow(car_row, ">", func(): _change_car(1))
	# A little spinning 3D picture of the car you've picked.
	var view_box := SubViewportContainer.new()
	view_box.stretch = true
	view_box.custom_minimum_size = Vector2(460, 150)
	view_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lbox.add_child(view_box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	view_box.add_child(vp)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.2
	vp.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.85, 1.0)
	env.environment.ambient_light_energy = 0.6
	vp.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.position = Vector3(0, 1.9, 5.2)
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0.5, 0), Vector3.UP)
	_preview_spin = Node3D.new()
	vp.add_child(_preview_spin)
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

	# Emote buttons and the latest messages.
	var emotes := HBoxContainer.new()
	emotes.alignment = BoxContainer.ALIGNMENT_CENTER
	emotes.add_theme_constant_override("separation", 8)
	_lobby.add_child(emotes)
	for i in Net.EMOTES.size():
		var idx := i
		var e := _button(emotes, Net.EMOTES[i], func(): Net.send_emote(idx))
		e.add_theme_font_size_override("font_size", 20)
		e.add_theme_color_override("font_color", Net.EMOTE_COLORS[i])
	_feed = RaceHud.make_label("", 22, Color.WHITE, 6)
	_feed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby.add_child(_feed)
	Net.emote_received.connect(_on_emote)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	_lobby.add_child(bottom)
	var leave := _button(bottom, "Leave", func():
		Net.leave("")
		_show_browse())
	# Fixed size and roomy, so no font (Comic Sans on Windows) can cut letters off.
	leave.add_theme_font_size_override("font_size", 32)
	leave.custom_minimum_size = Vector2(190, 0)
	_start_button = _button(bottom, "START RACE!", func(): Net.start_race())
	_start_button.add_theme_font_size_override("font_size", 40)
	_wait_label = RaceHud.make_label("Waiting for the host to start...", 26, Color(0.7, 0.9, 1.0), 8)
	bottom.add_child(_wait_label)


func _on_emote(peer_id: int, text: String) -> void:
	if not is_inside_tree():
		return
	var who := "You" if peer_id == Net.my_id() else Net.player_name_of(peer_id)
	_feed_lines.append("%s: %s" % [who, text])
	while _feed_lines.size() > 2:
		_feed_lines.pop_front()
	_feed.text = "    ".join(_feed_lines)
	Sfx.play("click", 1.4)


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
	if Net.internet and Net.is_host and Net.at_home:
		_address_label.text = ("Others in your house will see your race in their list.   (Or type the code:  %s)" % Net.room_code) if Net.room_code != "" \
			else "Opening your race..."
		_address_label.add_theme_font_size_override("font_size", 24)
		_address_label.add_theme_color_override("font_color", Color(0.6, 1.0, 1.0))
	elif Net.internet and Net.is_host:
		_address_label.text = ("Race code:  %s     Tell your cousins to type it in Race Online!" % Net.room_code) if Net.room_code != "" \
			else "Getting a race code..."
		if Net.players.size() > 1:
			_invite_note = ""
		if _invite_note != "":
			_address_label.text += "\nInvited %s! Waiting for them to join..." % _invite_note
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
		var car_name: String = CarData.nickname(p.get("look", {}))
		if car_name == "":
			car_name = CarData.get_car(int(p["car"]))["name"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_players_box.add_child(row)
		var fid := String(p.get("fid", ""))
		var star := "★ " if fid != "" and Game.is_friend(fid) else ""
		var l := RaceHud.make_label("%s%s  -  %s%s%s" % [star, p["name"], car_name, tag, "   < you" if me else ""],
			24, Color(1.0, 0.9, 0.4) if me else Color.WHITE, 6)
		row.add_child(l)
		if not me and fid != "" and not Game.is_friend(fid) and fid != Game.my_friend_code():
			var pname := String(p["name"])
			var add := _button(row, "+ Friend", func():
				Game.add_friend(fid, pname)
				Net.check_friends_soon()
				_refresh_lobby())
			add.add_theme_font_size_override("font_size", 18)
	var my_car := CarData.get_car(_my_car())
	var my_nick := CarData.nickname(Game.custom_for(my_car["id"]))
	_car_label.text = my_nick if my_nick != "" else String(my_car["name"])
	_show_preview(_my_car())
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
		# Long track names get smaller text so they fit instead of being cut off.
		b.add_theme_font_size_override("font_size", 24 if value.length() <= 14 else (20 if value.length() <= 18 else 17))
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


## A < or > button with room to spare around the arrow.
func _arrow(parent: Node, text: String, cb: Callable) -> Button:
	var b := _button(parent, text, cb)
	b.add_theme_font_size_override("font_size", 30)
	b.custom_minimum_size = Vector2(76, 56)
	return b


## Soft polka dots so the background isn't plain.
class TrackSelectDots extends Control:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		for i in 40:
			var c := Color.from_hsv(rng.randf(), 0.5, 1.0, 0.15)
			draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(20.0, 70.0), c)


# ---------------------------------------------------------------------------
# Friends: your friend code, adding friends, and "Race me!"
# ---------------------------------------------------------------------------

func _build_friends() -> void:
	_friends_button = _button(self, "Friends", func():
		_friends_panel.visible = not _friends_panel.visible
		if _friends_panel.visible:
			_refresh_friends()
			Net.check_friends_soon())
	_friends_button.add_theme_font_size_override("font_size", 24)
	_friends_button.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	RaceHud.pin(_friends_button, Vector2(1, 0), Vector2(-330, 16), Vector2(310, 56))

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	add_child(dim)
	_friends_panel = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(760, 0)
	panel.add_child(box)
	var title := RaceHud.make_label("Friends", 44, Color(0.6, 1.0, 0.7), 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var mine := HBoxContainer.new()
	mine.alignment = BoxContainer.ALIGNMENT_CENTER
	mine.add_theme_constant_override("separation", 12)
	box.add_child(mine)
	mine.add_child(RaceHud.make_label("Your friend code:", 24, Color.WHITE, 6))
	var code := Game.my_friend_code()
	mine.add_child(RaceHud.make_label(code, 34, Color(1.0, 0.9, 0.3), 8))
	_button(mine, "Copy", func():
		DisplayServer.clipboard_set(code)
		_friend_msg.text = "Copied! Send it to your friend.")
	var tip := RaceHud.make_label("Swap codes with your friends, or tap + Friend next to someone in a race lobby.", 18, Color(0.8, 0.9, 1.0), 4)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)

	var add_row := HBoxContainer.new()
	add_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_row.add_theme_constant_override("separation", 10)
	box.add_child(add_row)
	add_row.add_child(RaceHud.make_label("Add a friend:", 24))
	_friend_code_edit = LineEdit.new()
	_friend_code_edit.placeholder_text = "THEIR CODE"
	_friend_code_edit.max_length = 8
	_friend_code_edit.custom_minimum_size = Vector2(240, 54)
	_friend_code_edit.add_theme_font_size_override("font_size", 28)
	_friend_code_edit.text_changed.connect(func(t: String):
		var up := t.to_upper()
		if up != t:
			var caret := _friend_code_edit.caret_column
			_friend_code_edit.text = up
			_friend_code_edit.caret_column = caret)
	_friend_code_edit.text_submitted.connect(func(_t: String): _add_friend_code())
	add_row.add_child(_friend_code_edit)
	_button(add_row, "Add", _add_friend_code)
	_friend_msg = RaceHud.make_label("", 20, Color(1.0, 0.85, 0.5), 6)
	_friend_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_friend_msg)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(0, 220)
	box.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)
	_friends_list = VBoxContainer.new()
	_friends_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friends_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_friends_list)
	var close := _button(box, "Close", func(): _friends_panel.visible = false)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_refresh_friends()


func _add_friend_code() -> void:
	var err := Game.add_friend(_friend_code_edit.text)
	if err != "":
		_friend_msg.text = err
		Sfx.play("back")
		return
	_friend_code_edit.text = ""
	_friend_msg.text = "Friend added! Their name shows up once they're playing."
	Net.check_friends_soon()
	_refresh_friends()


## The friends list (playing now first) and the Friends button's count.
func _refresh_friends() -> void:
	if _friends_list == null:
		return
	var playing := Game.friends.filter(func(f: Dictionary) -> bool: return Net.is_online(f["id"]))
	_friends_button.text = ("Friends (%d playing!)" % playing.size()) if not playing.is_empty() else "Friends"
	for c in _friends_list.get_children():
		_friends_list.remove_child(c)
		c.queue_free()
	if Game.friends.is_empty():
		var l := RaceHud.make_label("No friends yet. Add one with their code!", 22, Color(1, 1, 1, 0.7), 4)
		_friends_list.add_child(l)
		return
	var sorted := Game.friends.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Net.is_online(a["id"]) and not Net.is_online(b["id"]))
	for f: Dictionary in sorted:
		var on := Net.is_online(f["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_friends_list.add_child(row)
		var dot := RaceHud.make_label("●", 26, Color(0.35, 1.0, 0.45) if on else Color(0.5, 0.5, 0.58), 4)
		row.add_child(dot)
		var n := RaceHud.make_label(String(f["name"]), 26, Color.WHITE if on else Color(0.75, 0.75, 0.82), 6)
		n.custom_minimum_size = Vector2(230, 0)
		row.add_child(n)
		var status := RaceHud.make_label("playing now!" if on else "not playing", 20, Color(0.6, 1.0, 0.65) if on else Color(0.6, 0.6, 0.68), 4)
		status.custom_minimum_size = Vector2(150, 0)
		row.add_child(status)
		var fid := String(f["id"])
		var fname := String(f["name"])
		var race := _button(row, "Race me!", func():
			_friends_panel.visible = false
			_invite_note = fname
			Net.race_friend(fid)
			_show_lobby())
		race.disabled = not on
		race.add_theme_font_size_override("font_size", 22)
		var remove := _button(row, "x", func():
			Game.remove_friend(fid)
			_refresh_friends())
		remove.tooltip_text = "Remove this friend"
		remove.add_theme_font_size_override("font_size", 18)


## Puts the chosen car on the little spinning turntable.
func _show_preview(index: int) -> void:
	if _preview_spin == null or index == _preview_car:
		return
	_preview_car = index
	for c in _preview_spin.get_children():
		c.queue_free()
	var car := CarData.get_car(index)
	var model := ToyCarModel.new().setup(car, false, Game.custom_for(car["id"]))
	_preview_spin.add_child(model)
