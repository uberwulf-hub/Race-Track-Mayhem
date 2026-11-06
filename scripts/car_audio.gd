class_name CarAudio
extends Node
## The engine, high-rev layer and brake squeal for one human player's car.
## Uses recorded loops when they exist, otherwise a synthesized toy motor.

var racer: Racer
var _engine: AudioStreamPlayer
var _high: AudioStreamPlayer
var _brake: AudioStreamPlayer
var _gen: AudioStreamGeneratorPlayback
var _phase := 0.0
var _phase2 := 0.0
var _freq := 60.0
var _was_pressing := false
var _offset_db := 0.0


func setup(p_racer: Racer, offset_db: float = 0.0) -> void:
	racer = p_racer
	_offset_db = offset_db
	process_mode = Node.PROCESS_MODE_ALWAYS
	_brake = _loop("brake")
	_engine = _loop("engine")
	if _engine:
		_high = _loop("engine_high")
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.15
	var p := AudioStreamPlayer.new()
	p.stream = gen
	p.bus = "SFX"
	p.volume_db = -16.0 + offset_db
	add_child(p)
	p.play()
	_gen = p.get_stream_playback()


func _loop(sound_name: String) -> AudioStreamPlayer:
	var st := Sfx.loop_stream(sound_name)
	if st == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = "SFX"
	p.volume_db = -60.0
	add_child(p)
	p.play()
	return p


func update(quiet: bool, racing: bool) -> void:
	quiet = quiet or racer.mode == Racer.Mode.FALLING
	# Brakes squeal while braking hard.
	if _brake:
		var want := -9.0 + _offset_db if racer.braking and not quiet else -60.0
		_brake.volume_db = lerpf(_brake.volume_db, want, 0.25)
		_brake.pitch_scale = 1.25 + clampf(racer.speed / 60.0, 0.0, 0.4)
	# A quick rev when you hit the gas from (nearly) stopped.
	var pressing := racer.throttle_input > 0.5
	if pressing and not _was_pressing and absf(racer.speed) < 8.0 and racing:
		Sfx.play("rev")
	_was_pressing = pressing
	var rev := absf(racer.speed) / 45.0 + racer.throttle_input * 0.2
	if racer.turbo_on or racer.boost_timer > 0.0:
		rev += 0.3
	if racer.in_air:
		rev += 0.35        # wheels spin free in the air
	rev = clampf(rev, 0.0, 1.6)
	if _engine:
		_engine.pitch_scale = lerpf(_engine.pitch_scale, 0.75 + rev * 0.8, 0.15)
		_engine.volume_db = lerpf(_engine.volume_db, -60.0 if quiet else -7.0 + minf(rev, 1.0) * 3.0 + _offset_db, 0.1)
		if _high:
			# The screamy high layer fades in as you go faster.
			var high := clampf((rev - 0.55) / 0.6, 0.0, 1.0)
			_high.pitch_scale = lerpf(_high.pitch_scale, 0.8 + rev * 0.5, 0.15)
			_high.volume_db = lerpf(_high.volume_db, -60.0 if quiet or high <= 0.01 else linear_to_db(high) - 9.0 + _offset_db, 0.1)
		return
	if _gen == null:
		return
	var target := 0.0 if quiet else 55.0 + rev * 140.0
	for i in _gen.get_frames_available():
		_freq = lerpf(_freq, target, 0.0008)
		if _freq < 5.0:
			_gen.push_frame(Vector2.ZERO)
			continue
		_phase = fmod(_phase + _freq / 22050.0, 1.0)
		_phase2 = fmod(_phase2 + _freq * 0.503 / 22050.0, 1.0)
		var v := (_phase * 2.0 - 1.0) * 0.35 + (0.25 if _phase2 < 0.5 else -0.25)
		_gen.push_frame(Vector2(v, v) * 0.5)
