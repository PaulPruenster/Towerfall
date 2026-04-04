class_name GameSfx
extends RefCounted


const SAMPLE_RATE: int = 22_050

static var _cache: Dictionary = {}

static func play(anchor: Node, event_name: StringName, global_position: Vector2 = Vector2.ZERO, pitch_scale: float = 1.0) -> void:
	if anchor == null:
		return

	var tree := anchor.get_tree()
	if tree == null or tree.current_scene == null:
		return

	var player := AudioStreamPlayer2D.new()
	player.stream = _get_stream(event_name)
	player.global_position = global_position
	player.pitch_scale = pitch_scale
	player.volume_db = _get_volume_db(event_name)
	player.finished.connect(player.queue_free)
	tree.current_scene.add_child(player)
	player.play()

static func _get_stream(event_name: StringName) -> AudioStreamWAV:
	if _cache.has(event_name):
		return _cache[event_name]

	var stream := _build_stream(event_name)
	_cache[event_name] = stream
	return stream

static func _build_stream(event_name: StringName) -> AudioStreamWAV:
	var frequency: float = 440.0
	var duration: float = 0.1
	var amplitude: float = 0.45
	var waveform: int = 0

	match event_name:
		&"arrow_shot":
			frequency = 720.0
			duration = 0.05
			amplitude = 0.28
		&"arrow_hit":
			frequency = 210.0
			duration = 0.08
			amplitude = 0.4
			waveform = 1
		&"ricochet":
			frequency = 920.0
			duration = 0.06
			amplitude = 0.22
		&"explosion":
			frequency = 120.0
			duration = 0.18
			amplitude = 0.58
			waveform = 2
		&"hurt":
			frequency = 150.0
			duration = 0.12
			amplitude = 0.48
			waveform = 1
		&"armor":
			frequency = 560.0
			duration = 0.08
			amplitude = 0.22
		&"death":
			frequency = 96.0
			duration = 0.24
			amplitude = 0.6
			waveform = 2
		&"chest_open":
			frequency = 660.0
			duration = 0.09
			amplitude = 0.28
		&"chest_ready":
			frequency = 980.0
			duration = 0.12
			amplitude = 0.18
		&"gate_open":
			frequency = 420.0
			duration = 0.09
			amplitude = 0.22
		&"gate_teleport":
			frequency = 520.0
			duration = 0.1
			amplitude = 0.24
		&"switch_press":
			frequency = 300.0
			duration = 0.08
			amplitude = 0.24
			waveform = 1
		&"jump_pad":
			frequency = 760.0
			duration = 0.1
			amplitude = 0.3
		&"dash_ready":
			frequency = 1040.0
			duration = 0.07
			amplitude = 0.18
		&"hazard":
			frequency = 180.0
			duration = 0.09
			amplitude = 0.34
			waveform = 1

	var sample_count := maxi(int(SAMPLE_RATE * duration), 1)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for index in range(sample_count):
		var time := float(index) / SAMPLE_RATE
		var progress := float(index) / sample_count
		var envelope := sin(progress * PI)
		var sample := _wave(waveform, frequency, time) * amplitude * envelope
		var value := int(clamp(sample * 32767.0, -32768.0, 32767.0))
		data[index * 2] = value & 0xFF
		data[index * 2 + 1] = (value >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream

static func _wave(waveform: int, frequency: float, time: float) -> float:
	var phase := fmod(frequency * time, 1.0)
	match waveform:
		1:
			if sin(TAU * phase) >= 0.0:
				return 1.0
			return -1.0
		2:
			return 1.0 - abs(phase * 2.0 - 1.0) * 2.0
		_:
			return sin(TAU * phase)

static func _get_volume_db(event_name: StringName) -> float:
	match event_name:
		&"death", &"explosion":
			return -7.0
		&"arrow_hit", &"hurt", &"hazard":
			return -9.0
		_:
			return -12.0
