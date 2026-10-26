class_name Synth
extends RefCounted
## Sons gerados por código, para o protótipo rodar sem nenhum asset de áudio.
## São placeholders: o grito final deve vir de atores/foley.

const RATE := 22050


static func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Grito descendente, trêmulo e rouco (~2,4 s).
static func scream() -> AudioStreamWAV:
	var dur := 2.4
	var n := int(RATE * dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / dur
		var f := lerpf(650.0, 240.0, u) + 90.0 * sin(TAU * 5.5 * t) + 40.0 * sin(TAU * 13.0 * t)
		phase += TAU * f / RATE
		var env := minf(1.0, u * 12.0) * pow(1.0 - u, 1.3)
		var tone := sin(phase) * 0.5 + sin(phase * 2.01) * 0.3 + sin(phase * 3.02) * 0.2
		var rasp := rng.randf_range(-1.0, 1.0) * 0.25 * (0.5 + 0.5 * sin(TAU * 9.0 * t))
		out[i] = (tone * 0.7 + rasp) * env * 0.8
	return _to_wav(out, false)


## Vento grave em loop (ruído marrom).
static func wind() -> AudioStreamWAV:
	var n := RATE * 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var out := PackedFloat32Array()
	out.resize(n)
	var v := 0.0
	for i in n:
		v = v * 0.985 + rng.randf_range(-1.0, 1.0) * 0.06
		var swell := 0.6 + 0.4 * sin(TAU * float(i) / n)
		out[i] = v * swell * 1.6
	# costura o fim no começo para não estalar no loop
	var fade := 2000
	for i in fade:
		var k := float(i) / fade
		out[i] = lerpf(out[n - fade + i], out[i], k)
	return _to_wav(out, true)


## Sino distante (~6 s).
static func bell() -> AudioStreamWAV:
	var n := RATE * 6
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 0.9)
		out[i] = (sin(TAU * 196.0 * t) * 0.5 + sin(TAU * 196.0 * 2.76 * t) * 0.25 + sin(TAU * 196.0 * 5.4 * t) * 0.1) * env * 0.6
	return _to_wav(out, false)
