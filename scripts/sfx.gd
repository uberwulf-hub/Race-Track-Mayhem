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
## Your own private sounds go here and win over the built-in ones
## (this folder is git-ignored; see assets/audio/local/README.md).
const LOCAL_SFX_DIR := "res://assets/audio/local/sfx/"
const LOCAL_MUSIC_DIR := "res://assets/audio/local/music/"

## Default loudness (dB) per sound, so menu clicks stay gentle.
const LEVELS := {
	"click": -16.0, "select": -11.0, "back": -12.0,
	"beep": -6.0, "go": -4.0,
	"voice_ready": -2.0, "voice_set": -2.0, "voice_go": 0.0, "voice_win": 0.0,
	"voice_final": -2.0, "voice_record": 0.0, "voice_unlock": -2.0, "voice_congrats": 0.0,
	"bump": -4.0, "crash": -3.0, "boost": -6.0, "jump": -6.0, "land": -6.0,
	"skid": -8.0, "whoosh": -6.0, "rev": -4.0,
	"pickup": -8.0, "throw": -6.0, "pop": -4.0, "splash": -5.0, "shield": -6.0,
	"lap": -4.0, "final_lap": -4.0, "win": -3.0, "finish": -3.0,
}
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
	# Soft, round start-light beeps (sine with a little warmth, no harsh edges).
	_sounds["beep"] = _bell(587.33, 0.35, 0.45)
	_sounds["go"] = _bell(1174.66, 0.8, 0.45)
	_sounds["click"] = _bell(880.0, 0.06, 0.2)
	_sounds["select"] = _bell(660.0, 0.12, 0.25)
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
	_sounds["back"] = _bell(440.0, 0.12, 0.25)
	_sounds["whoosh"] = _whoosh(0.7, 0.5)
	_sounds["rev"] = _rev(0.9, 0.4)
	_sounds["pickup"] = _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.06, 0.3)
	_sounds["throw"] = _sweep(500.0, 180.0, 0.25, 0.3, 0.6)
	_sounds["pop"] = _pop()
	_sounds["splash"] = _noise(0.5, 0.45, 5.0)
	_sounds["shield"] = _arpeggio([392.0, 587.33, 783.99], 0.09, 0.28)
	# Wrap the synthesized ones in arrays, then replace with real files where present.
	for key in _sounds.keys():
		_sounds[key] = [_sounds[key]]
	var real := 0
	for key in _sounds.keys():
		var files := _find_files(SFX_DIR, key)
		if not files.is_empty():
			_sounds[key] = files
			real += 1
	var music := 0
	for m in ["menu", "garage", "race", "results"]:
		if not _find_files(MUSIC_DIR, m).is_empty():
			music += 1
	print("Race Track Mayhem audio: %d sounds from files (%d synthesized), %d music tracks found." % [real, _sounds.size() - real, music])


## Finds <dir>/<name>.ogg and variations <name>_1.ogg, <name>_2.ogg, ...
## Files in the private local folder win over the built-in ones.
func _find_files(dir: String, sound_name: String) -> Array:
	var local_dir := LOCAL_SFX_DIR if dir == SFX_DIR else (LOCAL_MUSIC_DIR if dir == MUSIC_DIR else "")
	if local_dir != "":
		var mine := _scan(local_dir, sound_name)
		if not mine.is_empty():
			return mine
	return _scan(dir, sound_name)


func _scan(dir: String, sound_name: String) -> Array:
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


func _set_no_loop(st: AudioStream) -> void:
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = false
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = false
	elif st is AudioStreamWAV:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

## Plays a music track by name ("menu", "race", ...), cross-fading from the
## current one. Several files like race_1.ogg, race_2.ogg = pick one at random.
## Tracks that play once instead of looping, then hand over to another track.
const PLAY_ONCE := {"results": "menu"}
## A screen with no song of its own borrows another (the pickers keep the menu
## song going without restarting it).
const FALLBACK := {"garage": "menu"}


func play_music(track_name: String, volume_db: float = -6.0) -> void:
	var files := _find_files(MUSIC_DIR, track_name)
	if files.is_empty() and FALLBACK.has(track_name):
		track_name = FALLBACK[track_name]
		files = _find_files(MUSIC_DIR, track_name)
	if track_name == _music_name and (_music_a.playing or _music_b.playing):
		return
	_music_name = track_name
	if files.is_empty():
		stop_music()
		return
	var st: AudioStream = files[randi() % files.size()]
	if PLAY_ONCE.has(track_name):
		_set_no_loop(st)
	else:
		_set_loop(st)
	var old := _music_a if _music_a.playing else _music_b
	var fresh := _music_b if old == _music_a else _music_a
	fresh.stream = st
	fresh.volume_db = -40.0
	fresh.play()
	if PLAY_ONCE.has(track_name):
		var next_track: String = PLAY_ONCE[track_name]
		var this_stream := st
		fresh.finished.connect(func():
			# Only if nothing else started meanwhile.
			if _music_name == track_name and fresh.stream == this_stream:
				play_music(next_track, volume_db), CONNECT_ONE_SHOT)
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
	p.volume_db = volume_db + float(LEVELS.get(sound, 0.0))
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


## A soft bell-like tone: sine plus a quiet octave, gentle attack, smooth fade.
func _bell(freq: float, seconds: float, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var count := int(seconds * RATE)
	for i in count:
		var t := float(i) / RATE
		var k := float(i) / count
		var env := minf(1.0, t * 200.0) * pow(1.0 - k, 2.0)
		var v := sin(TAU * freq * t) + 0.25 * sin(TAU * freq * 2.0 * t) + 0.08 * sin(TAU * freq * 3.0 * t)
		out.append(v * vol * env * 0.75)
	return _make_wav(out)


## Air rushing past: filtered noise that swells and fades, with a falling pitch.
func _whoosh(seconds: float, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var count := int(seconds * RATE)
	var lp := 0.0
	var lp2 := 0.0
	for i in count:
		var k := float(i) / count
		var cutoff := lerpf(0.35, 0.06, k)       # brighter at first, then duller
		lp = lerpf(lp, randf_range(-1.0, 1.0), cutoff)
		lp2 = lerpf(lp2, lp, cutoff)
		var env := sin(PI * pow(k, 0.7))
		out.append(lp2 * vol * env * 3.0)
	return _make_wav(out)


## A quick toy-motor rev: a buzzy tone sweeping up.
func _rev(seconds: float, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var count := int(seconds * RATE)
	var phase := 0.0
	var phase2 := 0.0
	for i in count:
		var k := float(i) / count
		var freq := lerpf(70.0, 210.0, 1.0 - pow(1.0 - k, 2.0))
		phase = fmod(phase + freq / RATE, 1.0)
		phase2 = fmod(phase2 + freq * 0.5 / RATE, 1.0)
		var v := (phase * 2.0 - 1.0) * 0.5 + (0.3 if phase2 < 0.5 else -0.3)
		var env := minf(1.0, k * 12.0) * (1.0 - pow(k, 3.0))
		out.append(v * vol * env)
	return _make_wav(out)


## A quick run of soft bell notes (power-up pickup, shield).
func _arpeggio(freqs: Array, note_len: float, vol: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for f in freqs:
		var n := int(note_len * RATE)
		for i in n:
			var t := float(i) / RATE
			var k := float(i) / n
			out.append((sin(TAU * float(f) * t) + 0.3 * sin(TAU * float(f) * 2.0 * t)) * vol * minf(1.0, k * 30.0) * (1.0 - k * 0.7))
	return _make_wav(out)


## A bubble popping: a short bright blip that drops in pitch.
func _pop() -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var count := int(0.12 * RATE)
	var phase := 0.0
	for i in count:
		var k := float(i) / count
		phase += lerpf(1400.0, 300.0, k) / RATE
		out.append(sin(TAU * phase) * 0.5 * exp(-k * 6.0) + randf_range(-0.15, 0.15) * (1.0 - k))
	return _make_wav(out)
