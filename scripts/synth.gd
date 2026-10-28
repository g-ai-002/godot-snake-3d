class_name Synth
extends RefCounted

## 运行时合成音效与循环 BGM，全部由 GDScript 生成 PCM，不依赖任何音频素材。

const RATE := 22050


static func _buffer(duration: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(duration * RATE))
	return buf


static func _to_wav(buf: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var sample := int(clampf(buf[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buf.size()
	return stream


static func _tone(
	buf: PackedFloat32Array,
	start: float,
	duration: float,
	freq: float,
	volume := 0.25,
	wave := "square",
	slide := 0.0
) -> void:
	var begin := int(start * RATE)
	var count := int(duration * RATE)
	if count <= 0:
		return
	var attack := maxf(1.0, 0.004 * RATE)
	for i in count:
		var index := begin + i
		if index < 0 or index >= buf.size():
			continue
		var progress := float(i) / float(count)
		var current := freq * pow(2.0, slide * progress)
		var phase := fposmod(float(i) / RATE * current, 1.0)
		var value := 0.0
		match wave:
			"square":
				value = 1.0 if phase < 0.5 else -1.0
			"saw":
				value = phase * 2.0 - 1.0
			"triangle":
				value = 4.0 * absf(phase - 0.5) - 1.0
			_:
				value = sin(phase * TAU)
		var envelope := minf(1.0, float(i) / attack) * pow(1.0 - progress, 1.7)
		buf[index] += value * envelope * volume


static func _noise(
	buf: PackedFloat32Array,
	start: float,
	duration: float,
	volume := 0.2,
	smooth := 0.2
) -> void:
	var begin := int(start * RATE)
	var count := int(duration * RATE)
	var value := 0.0
	for i in count:
		var index := begin + i
		if index < 0 or index >= buf.size():
			continue
		value = lerpf(value, randf_range(-1.0, 1.0), smooth)
		var progress := float(i) / float(count)
		buf[index] += value * pow(1.0 - progress, 1.6) * volume


static func eat() -> AudioStreamWAV:
	var buf := _buffer(0.24)
	_tone(buf, 0.0, 0.08, 740.0, 0.32, "square", 0.45)
	_tone(buf, 0.06, 0.14, 1120.0, 0.24, "triangle", 0.2)
	return _to_wav(buf)


static func powerup() -> AudioStreamWAV:
	var buf := _buffer(0.5)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		_tone(buf, i * 0.07, 0.22, notes[i], 0.2, "triangle", 0.05)
		_tone(buf, i * 0.07, 0.1, notes[i] * 2.0, 0.06, "sine")
	return _to_wav(buf)


static func death() -> AudioStreamWAV:
	var buf := _buffer(0.9)
	_tone(buf, 0.0, 0.7, 420.0, 0.28, "saw", -2.4)
	_tone(buf, 0.0, 0.5, 210.0, 0.12, "square", -1.6)
	_noise(buf, 0.02, 0.55, 0.22, 0.12)
	return _to_wav(buf)


static func shield_break() -> AudioStreamWAV:
	var buf := _buffer(0.4)
	_tone(buf, 0.0, 0.3, 1800.0, 0.22, "sine", -0.6)
	_tone(buf, 0.02, 0.2, 2600.0, 0.12, "triangle", -0.4)
	_noise(buf, 0.0, 0.12, 0.1, 0.5)
	return _to_wav(buf)


static func countdown() -> AudioStreamWAV:
	var buf := _buffer(0.16)
	_tone(buf, 0.0, 0.12, 520.0, 0.22, "square")
	return _to_wav(buf)


static func go() -> AudioStreamWAV:
	var buf := _buffer(0.5)
	_tone(buf, 0.0, 0.22, 780.0, 0.24, "square", 0.35)
	_tone(buf, 0.12, 0.3, 1040.0, 0.2, "triangle", 0.2)
	return _to_wav(buf)


static func music() -> AudioStreamWAV:
	var length := 6.4
	var buf := _buffer(length)
	var step := 0.1
	var root := 110.0
	var chords := [0, 5, 3, 7]
	var degrees := [0, 3, 7, 10, 12, 10, 7, 3]
	for i in 64:
		var t := i * step
		var chord: int = chords[int(i / 16.0) % chords.size()]
		if i % 8 == 0:
			var bass := root * pow(2.0, chord / 12.0) * 0.5
			_tone(buf, t, 0.32, bass, 0.17, "triangle")
		if i % 4 == 2:
			_tone(buf, t, 0.14, root * 4.0 * pow(2.0, chord / 12.0), 0.045, "sine")
		if i % 2 == 0:
			var degree: int = degrees[int(i / 2.0) % degrees.size()]
			_tone(buf, t, 0.16, root * 2.0 * pow(2.0, degree / 12.0), 0.04, "square")
	return _to_wav(buf, true)
