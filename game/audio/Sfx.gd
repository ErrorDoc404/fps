extends Node
## Procedural audio (no audio assets were supplied). Generates short PCM clips at startup and plays them
## 2D (UI / local weapon) or positionally (remote weapons, impacts) with distance attenuation.

const RATE := 22050
var _clips := {}
var world_host: Node   # client mission World; 3D sounds are parented there

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return  # dedicated server: no audio
	_clips["shot_rifle"] = _gunshot(0.32, 900.0, 0.9)
	_clips["shot_rifle_heavy"] = _gunshot(0.4, 650.0, 1.0)
	_clips["shot_smg"] = _gunshot(0.22, 1300.0, 0.75)
	_clips["shot_dmr"] = _gunshot(0.55, 500.0, 1.0)
	_clips["shot_pistol"] = _gunshot(0.22, 1500.0, 0.7)
	_clips["shot_enemy"] = _gunshot(0.3, 800.0, 0.85)
	_clips["dry"] = _click(0.04, 3000.0)
	_clips["reload"] = _click(0.08, 1800.0)
	_clips["hit"] = _tone(0.05, 1800.0, 0.5)
	_clips["hit_kill"] = _tone(0.12, 1100.0, 0.6)
	_clips["hurt"] = _gunshot(0.18, 250.0, 0.5)
	_clips["impact"] = _click(0.05, 2400.0)
	_clips["step"] = _gunshot(0.07, 300.0, 0.25)
	_clips["radio"] = _tone(0.09, 1400.0, 0.35)
	_clips["ui"] = _tone(0.04, 900.0, 0.3)
	_clips["bang"] = _gunshot(0.9, 400.0, 1.0)
	_clips["smoke"] = _noise_hiss(1.4)
	_clips["whiz"] = _noise_hiss(0.12)
	_clips["heli"] = _heli_loop()

func _make(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w

func _gunshot(dur: float, cutoff: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 14.0 / dur) * (1.0 if t > 0.002 else t / 0.002)
		lp += a * (randf_range(-1, 1) - lp)
		s[i] = (lp * 2.2 + sin(t * TAU * 70.0) * exp(-t * 30.0) * 0.8) * env * gain
	return _make(s)

func _click(dur: float, freq: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(t * TAU * freq) * exp(-t * 80.0) * 0.6 + randf_range(-0.2, 0.2) * exp(-t * 120.0)
	return _make(s)

func _tone(dur: float, freq: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(t * TAU * freq) * gain * min(1.0, (dur - t) * 60.0) * min(1.0, t * 400.0)
	return _make(s)

func _noise_hiss(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = randf_range(-1, 1) * 0.35 * sin(PI * t / dur)
	return _make(s)

func _heli_loop() -> AudioStreamWAV:
	var n := RATE  # 1 second loop
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += 0.05 * (randf_range(-1, 1) - lp)
		s[i] = lp * 3.0 * (0.55 + 0.45 * sin(t * TAU * 6.0))
	return _make(s, true)

func play_2d(name: String, db := 0.0) -> void:
	if not _clips.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _clips[name]
	p.volume_db = db
	p.pitch_scale = randf_range(0.95, 1.05)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func play_3d(name: String, pos: Vector3, db := 0.0) -> void:
	if not _clips.has(name):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _clips[name]
	p.volume_db = db
	p.unit_size = 8.0
	p.max_distance = 180.0
	p.pitch_scale = randf_range(0.93, 1.07)
	(world_host if is_instance_valid(world_host) else self).add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)

func loop_3d(name: String, parent: Node3D) -> void:
	if not _clips.has(name):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _clips[name]
	p.unit_size = 20.0
	p.max_distance = 250.0
	parent.add_child(p)
	p.play()
