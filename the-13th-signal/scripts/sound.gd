extends Node
## Sounds (autoloaded as `Sound`). Every sound is synthesized when the game
## starts, so there are no audio files to license or download.
## Harsh "sting" sounds are only ever played outside Explorer mode.

const RATE := 22050

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _ambient: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_ambient = AudioStreamPlayer.new()
	add_child(_ambient)
	_generate()


func stream(sound_name: String) -> AudioStream:
	return _streams.get(sound_name)


func play(sound_name: String, vol_db := 0.0, pitch := 1.0) -> void:
	var s: AudioStream = _streams.get(sound_name)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


## A sound that comes from a place in the world (it gets quieter far away).
func play_at(sound_name: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	var s: AudioStream = _streams.get(sound_name)
	var scene := get_tree().current_scene
	if s == null or scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.unit_size = 5.0
	p.max_distance = 45.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func start_ambient(vol_db := -10.0) -> void:
	if _ambient.playing:
		_ambient.volume_db = vol_db
		return
	_ambient.stream = _streams["drone"]
	_ambient.volume_db = vol_db
	_ambient.play()


func stop_ambient() -> void:
	_ambient.stop()


# ------------------------------------------------------------- synthesis

func _buf(dur: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(dur * RATE))
	return a


func _wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


## Filtered noise with a decay. lp: 0..1 (smaller = darker/muffled).
func _noise(dur: float, lp: float, decay: float, gain := 0.8, attack := 0.004) -> PackedFloat32Array:
	var a := _buf(dur)
	var y := 0.0
	for i in a.size():
		var t := float(i) / RATE
		y += lp * (randf_range(-1.0, 1.0) - y)
		var env := minf(t / attack, 1.0) * exp(-t * decay)
		a[i] = y * env * gain
	return a


func _tone(notes: Array, gain := 0.3, wave := "sine", decay := 6.0) -> PackedFloat32Array:
	var total := 0.0
	for n in notes:
		total += float(n[1])
	var a := _buf(total)
	var i := 0
	for n in notes:
		var f: float = n[0]
		var count := int(float(n[1]) * RATE)
		for j in count:
			if i >= a.size():
				break
			var t := float(j) / RATE
			var ph := fmod(t * f, 1.0)
			var v := 0.0
			match wave:
				"square": v = 1.0 if ph < 0.5 else -1.0
				"triangle": v = 4.0 * absf(ph - 0.5) - 1.0
				_: v = sin(TAU * ph)
			if f <= 1.0:
				v = 0.0  # a rest between notes
			var env := minf(t / 0.005, 1.0) * exp(-t * decay)
			a[i] = v * env * gain
			i += 1
	return a


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset := 0) -> PackedFloat32Array:
	var out := a.duplicate()
	if out.size() < b.size() + offset:
		out.resize(b.size() + offset)
	for i in b.size():
		out[i + offset] += b[i]
	return out


func _generate() -> void:
	# Footsteps: soft concrete, and loud clangy metal grates.
	_streams["step"] = _wav(_noise(0.09, 0.25, 45.0, 0.6))
	var grate := _noise(0.25, 0.6, 18.0, 0.5)
	grate = _mix(grate, _tone([[523.0, 0.25]], 0.12, "square", 16.0))
	grate = _mix(grate, _tone([[797.0, 0.25]], 0.08, "square", 20.0))
	_streams["step_grate"] = _wav(grate)

	# Doors.
	var door := _noise(0.7, 0.08, 4.0, 0.9, 0.05)
	door = _mix(door, _noise(0.5, 0.5, 8.0, 0.25), 2000)
	_streams["door"] = _wav(door)
	_streams["locked"] = _wav(_tone([[110.0, 0.12], [1.0, 0.05], [104.0, 0.18]], 0.35, "square", 5.0))
	_streams["locker"] = _wav(_mix(_noise(0.3, 0.4, 14.0, 0.6), _tone([[180.0, 0.3]], 0.15, "triangle", 10.0)))

	# Intercom and UI.
	_streams["chime"] = _wav(_tone([[880.0, 0.22], [659.25, 0.45]], 0.22, "sine", 3.5))
	_streams["blip"] = _wav(_tone([[1320.0, 0.025]], 0.08, "square", 30.0))
	_streams["echo_blip"] = _wav(_tone([[1250.0, 0.02], [610.0, 0.02]], 0.08, "square", 25.0))
	_streams["click"] = _wav(_tone([[900.0, 0.05]], 0.15, "sine", 40.0))
	_streams["pickup"] = _wav(_tone([[523.25, 0.08], [659.25, 0.08], [987.77, 0.25]], 0.22, "triangle", 5.0))
	_streams["key_beep"] = _wav(_tone([[1046.5, 0.07]], 0.2, "sine", 25.0))
	_streams["key_ok"] = _wav(_tone([[784.0, 0.1], [1046.5, 0.1], [1568.0, 0.3]], 0.25, "sine", 4.0))
	_streams["key_bad"] = _wav(_tone([[220.0, 0.15], [1.0, 0.04], [196.0, 0.3]], 0.3, "square", 3.0))
	_streams["checkpoint"] = _wav(_tone([[659.25, 0.1], [987.77, 0.3]], 0.15, "sine", 6.0))

	# Breakers and power.
	var thunk := _tone([[70.0, 0.35]], 0.7, "sine", 9.0)
	thunk = _mix(thunk, _noise(0.05, 0.9, 80.0, 0.6))
	_streams["breaker"] = _wav(thunk)
	var hum := _buf(2.0)
	for i in hum.size():
		var t := float(i) / RATE
		var f := 40.0 + 80.0 * minf(t / 1.6, 1.0)
		hum[i] = (sin(TAU * f * t) * 0.4 + sin(TAU * f * 2.0 * t) * 0.15) * minf(t * 3.0, 1.0) * minf((2.0 - t) * 4.0, 1.0)
	_streams["power_on"] = _wav(hum)
	var alarm := _buf(1.6)
	for i in alarm.size():
		var t := float(i) / RATE
		var f := 660.0 if fmod(t, 0.4) < 0.2 else 520.0
		alarm[i] = (1.0 if fmod(t * f, 1.0) < 0.5 else -1.0) * 0.18 * minf((1.6 - t) * 6.0, 1.0)
	_streams["alarm"] = _wav(alarm)

	# The Listener: echolocation clicks and a low breath.
	var click := _noise(0.03, 0.95, 160.0, 0.9, 0.001)
	click = _mix(click, _noise(0.03, 0.95, 160.0, 0.7, 0.001), int(0.06 * RATE))
	_streams["listener_click"] = _wav(click)
	var breath := _buf(1.4)
	var y := 0.0
	for i in breath.size():
		var t := float(i) / RATE
		y += 0.05 * (randf_range(-1.0, 1.0) - y)
		breath[i] = y * sin(PI * t / 1.4) * 2.2
	_streams["listener_breath"] = _wav(breath)

	# The Replacement: creaking plastic.
	var creak := _buf(0.5)
	var phase := 0.0
	for i in creak.size():
		var t := float(i) / RATE
		phase += (90.0 + 40.0 * sin(t * 23.0)) / RATE
		var pulse := 1.0 if fmod(phase, 1.0) < 0.08 else 0.0
		creak[i] = (pulse * 0.5 + randf_range(-0.05, 0.05)) * sin(PI * t / 0.5)
	_streams["creak"] = _wav(creak)

	# Tripwire chimes (the Listener's traps).
	var chimes := _tone([[1568.0, 0.6]], 0.18, "sine", 4.0)
	chimes = _mix(chimes, _tone([[1864.0, 0.6]], 0.15, "sine", 4.0), 1500)
	chimes = _mix(chimes, _tone([[2093.0, 0.6]], 0.15, "sine", 4.0), 3200)
	_streams["trap"] = _wav(chimes)

	# You, holding your breath too long.
	_streams["gasp"] = _wav(_noise(0.45, 0.35, 6.0, 0.7, 0.02))
	var beat := _tone([[55.0, 0.18]], 0.8, "sine", 14.0)
	beat = _mix(beat, _tone([[52.0, 0.18]], 0.6, "sine", 14.0), int(0.26 * RATE))
	_streams["heartbeat"] = _wav(beat)

	# Distant facility noises.
	_streams["bang"] = _wav(_mix(_noise(1.2, 0.05, 3.0, 1.0), _tone([[62.0, 1.0]], 0.5, "sine", 3.0)))
	_streams["drip"] = _wav(_tone([[1800.0, 0.04], [1300.0, 0.08]], 0.1, "sine", 30.0))

	# Caught: TV static. (Never a scream, never anything graphic.)
	_streams["static"] = _wav(_noise(1.8, 0.9, 1.2, 0.35, 0.01))

	# Jump-scare sting (Survivor and Nightmare only).
	var sting := _noise(1.3, 0.7, 2.5, 0.35, 0.002)
	for f in [233.0, 247.0, 370.0, 523.0]:
		sting = _mix(sting, _tone([[f, 1.3]], 0.12, "square", 2.2))
	_streams["sting"] = _wav(sting)

	# A looping low drone for the facility, made from tones that repeat
	# exactly every 6 seconds so the loop is seamless.
	var drone := _buf(6.0)
	for i in drone.size():
		var t := float(i) / RATE
		var swell := 0.75 + 0.25 * sin(TAU * t / 6.0)
		drone[i] = (sin(TAU * 55.0 * t) * 0.22 + sin(TAU * (331.0 / 6.0) * t) * 0.18
			+ sin(TAU * 110.0 * t) * 0.05 + sin(TAU * (497.0 / 6.0) * t) * 0.07) * swell
	_streams["drone"] = _wav(drone, true)
