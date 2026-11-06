extends Node
## Sound effects and music (autoloaded as `Sfx`).
##
## Real recordings live in assets/audio (see assets/audio/CREDITS.md):
##   assets/audio/sfx/<name>.ogg  (or <name>_1.ogg, <name>_2.ogg ... for variations)
##   assets/audio/music/<name>.ogg
## If a file is missing, a little synthesized sound is used instead, so the
## game always works even with no audio files at all.

const RATE := 22050
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const EXTS := ["ogg", "wav", "mp3"]

var _sounds: Dictionary = {}       # name -> Array[AudioStream] (variations)
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		add_child(m)
	_sounds["beep"] = _tone([[523.25, 0.16]], 0.35, "square")
	_sounds["go"] = _tone([[1046.5, 0.55]], 0.35, "square")
	_sounds["click"] = _tone([[880.0, 0.04]], 0.25, "square")
	_sounds["select"] = _tone([[660.0, 0.06], [990.0, 0.08]], 0.25, "square")
	_sounds["lap"] = _tone([[784.0, 0.1], [1046.5, 0.18]], 0.3, "triangle")
	_sounds["final_lap"] = _tone([[784.0, 0.1], [988.0, 0.1], [1175.0, 0.1], [1568.0, 0.25]], 0.3, "square")
	_sounds["win"] = _tone([[523.25, 0.12], [659.25, 0.12], [783.99, 0.12], [1046.5, 0.12], [783.99, 0.1], [1046.5, 0.45]], 0.3, "square")
	_sounds["finish"] = _tone([[659.25, 0.15], [523.25, 0.15], [659.25, 0.35]], 0.3, "triangle")
	_sounds["boost"] = _sweep(220.0, 900.0, 0.55, 0.35, 0.5)
	_sounds["crash"] = _noise(0.6, 0.5, 6.0)
	_sounds["bump"] = _sweep(160.0, 60.0, 0.14, 0.5, 0.2)
	_sounds["jump"] = _sweep(300.0, 700.0, 0.25, 0.3, 0.0)
	_sounds["land"] = _noise(0.15, 0.35, 25.0)
	_sounds["skid"] = _noise(0.3, 0.2, 3.0)
	_sounds["back"] = _tone([[660.0, 0.05], [440.0, 0.08]], 0.25, "square")
	# Wrap the synthesized ones in arrays, then replace with real files where present.
	for key in _sounds.keys():
		_sounds[key] = [_sounds[key]]
	for key in _sounds.keys():
		var files := _find_files(SFX_DIR, key)
		if not files.is_empty():
			_sounds[key] = files


## Finds <dir>/<name>.ogg and variations <name>_1.ogg, <name>_2.ogg, ...
func _find_files(dir: String, sound_name: String) -> Array:
	var out: Array = []
	for ext in EXTS:
		var single := "%s%s.%s" % [dir, sound_name, ext]
		if ResourceLoader.exists(single):
			out.append(load(single))
		for i in range(1, 9):
			var v := "%s%s_%d.%s" % [dir, sound_name, i, ext]
			if ResourceLoader.exists(v):
				out.append(load(v))
	return out


## A looping stream for something continuous (like the engine), or null.
func loop_stream(sound_name: String) -> AudioStream:
	var files := _find_files(SFX_DIR, sound_name)
	if files.is_empty():
		return null
	var st: AudioStream = files[0]
	_set_loop(st)
	return st


func _set_loop(st: AudioStream) -> void:
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	elif st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_end = int(w.get_length() * w.mix_rate)


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

## Plays a music track by name ("menu", "race", ...), cross-fading from the
## current one. Several files like race_1.ogg, race_2.ogg = pick one at random.
func play_music(track_name: String, volume_db: float = -6.0) -> void:
	if track_name == _music_name and (_music_a.playing or _music_b.playing):
		return
	var files := _find_files(MUSIC_DIR, track_name)
	_music_name = track_name
	if files.is_empty():
		stop_music()
		return
	var st: AudioStream = files[randi() % files.size()]
	_set_loop(st)
	var old := _music_a if _music_a.playing else _music_b
	var fresh := _music_b if old == _music_a else _music_a
	fresh.stream = st
	fresh.volume_db = -40.0
	fresh.play()
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(fresh, "volume_db", volume_db, 1.0)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", -40.0, 1.0)
		_music_tween.chain().tween_callback(old.stop)


func stop_music(fade: float = 0.8) -> void:
	_music_name = ""
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	for m in [_music_a, _music_b]:
		if m.playing:
			_music_tween.tween_property(m, "volume_db", -40.0, fade)
	_music_tween.chain().tween_callback(func():
		_music_a.stop()
		_music_b.stop())


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _sounds.has(sound):
		# Sounds with no synthesized fallback (like voices) are looked up once.
		_sounds[sound] = _find_files(SFX_DIR, sound)
	if (_sounds[sound] as Array).is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	var options: Array = _sounds[sound]
	p.stream = options[randi() % options.size()]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


# --------------------------------------------------------------------------
# Synthesis helpers
# --------------------------------------------------------------------------

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _osc(shape: String, phase: float) -> float:
	var f := fmod(phase, 1.0)
	match shape:
		"square":
			return 1.0 if f < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(f - 0.5) - 1.0
		"saw":
			return 2.0 * f - 1.0
	return sin(phase * TAU)


## notes: [[freq, seconds], ...] played one after another.
func _tone(notes: Array, vol: float, shape: String) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for n in notes:
		var freq: float = n[0]
		var count := int(float(n[1]) * RATE)
		var phase := 0.0
		for i in count:
			var t := float(i) / float(count)
			var env := minf(1.0, t * 40.0) * (1.0 - t) * (1.0 - t * 0.3)
			phase += freq / RATE
			out.append(_osc(shape, phase) * vol * env)
	return _make_wav(out)


func _sweep(f0: float, f1: float, seconds: float, vol: float, noise_amt: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var count := int(seconds * RATE)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(count)
		var freq := lerpf(f0, f1, t)
		phase += freq / RATE
		var env := minf(1.0, t * 30.0) * (1.0 - t)
		var v := _osc("triangle", phase) * (1.0 - noise_amt) + randf_range(-1.0, 1.0) * noise_amt
		out.append(v * vol * env)
	return _make_wav(out)


func _noise(seconds: float, vol: float, decay: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var count := int(seconds * RATE)
	var last := 0.0
	for i in count:
		var t := float(i) / float(count)
		# simple low-pass so it sounds more like a crunch than hiss
		last = lerpf(last, randf_range(-1.0, 1.0), 0.35)
		out.append(last * vol * exp(-t * decay) * 1.6)
	return _make_wav(out)
