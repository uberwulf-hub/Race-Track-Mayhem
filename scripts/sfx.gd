extends Node
## Tiny procedural sound effects (autoloaded as `Sfx`) so the game needs no audio files.

const RATE := 22050

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
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


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _sounds.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[sound]
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
