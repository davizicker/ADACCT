class_name Synth
extends RefCounted
## Sons gerados por código, para o protótipo rodar sem nenhum asset de áudio.
## São placeholders: o grito final deve vir de atores/foley.

const RATE := 22050


static func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	# normaliza: nenhum som passa de 90% (evita estouro quando várias camadas tocam juntas)
	var peak := 0.0
	for v in samples:
		peak = maxf(peak, absf(v))
	if peak > 0.9:
		var k := 0.9 / peak
		for i in samples.size():
			samples[i] *= k
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


# ================================================================== efeitos do jogo (v2)
# Tudo sintetizado por código (placeholders atmosféricos). Gravações reais devem substituí-los.

static func _noise(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(-1.0, 1.0)


## Passo no calçamento de pedra: estalo seco + batida grave + arrasto. `variant` muda o timbre.
static func step(variant: int) -> AudioStreamWAV:
	var n := int(RATE * 0.30)
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + variant
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var f0 := 62.0 + variant * 7.0
	for i in n:
		var t := float(i) / RATE
		var x := _noise(rng)
		lp += 0.18 * (x - lp)
		var click := x * exp(-t * 110.0) * 0.55
		var thump := sin(TAU * f0 * t) * exp(-t * 26.0) * 0.95
		var scuff := lp * exp(-t * 13.0) * 0.55
		out[i] = (click + thump + scuff) * 0.75
	return _to_wav(out, false)


## Latido de cachorro distante (3 latidos).
static func dog() -> AudioStreamWAV:
	var n := int(RATE * 1.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var out := PackedFloat32Array()
	out.resize(n)
	var starts := [0.05, 0.58, 1.10]
	for st in starts:
		var i0 := int(st * RATE)
		var blen := int(0.30 * RATE)
		var ph := 0.0
		for k in blen:
			if i0 + k >= n:
				break
			var t := float(k) / RATE
			var f := lerpf(520.0, 330.0, t / 0.30)
			ph += TAU * f / RATE
			var env := minf(1.0, t * 60.0) * exp(-t * 7.0)
			var v := (sin(ph) * 0.5 + sin(ph * 2.0) * 0.35 + sin(ph * 3.0) * 0.25 + _noise(rng) * 0.22) * env
			out[i0 + k] += v * 0.7
	return _to_wav(out, false)


## Grilos ao fundo (loop de 8 s).
static func crickets() -> AudioStreamWAV:
	var n := RATE * 8
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var out := PackedFloat32Array()
	out.resize(n)
	for c in 5:
		var f := 4300.0 + c * 310.0
		var period := 0.9 + c * 0.13
		var phase := rng.randf() * period
		for i in n:
			var t := float(i) / RATE + phase
			var tp := fmod(t, period)
			var gate := 0.0
			if tp < 0.22:
				gate = 0.5 + 0.5 * sin(TAU * 38.0 * tp)
			out[i] += sin(TAU * f * float(i) / RATE) * gate * 0.07
	return _to_wav(out, true)


## Batimento cardíaco (loop de 1 s): dois golpes graves.
static func heartbeat() -> AudioStreamWAV:
	var n := RATE
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for hit in [[0.0, 1.0], [0.24, 0.7]]:
			var tt: float = t - hit[0]
			if tt >= 0.0:
				v += sin(TAU * lerpf(70.0, 38.0, minf(tt * 6.0, 1.0)) * tt) * exp(-tt * 14.0) * hit[1]
		out[i] = v * 0.9
	return _to_wav(out, true)


## Respiração ofegante (1,6 s): ruído filtrado com subida e descida.
static func breath() -> AudioStreamWAV:
	var n := int(RATE * 1.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += 0.35 * (_noise(rng) - lp)
		lp2 += 0.08 * (lp - lp2)
		var env := pow(sin(PI * minf(t / 1.5, 1.0)), 2.0)
		out[i] = (lp - lp2) * env * 0.9
	return _to_wav(out, false)


## Rangido de madeira (1,2 s).
static func creak() -> AudioStreamWAV:
	var n := int(RATE * 1.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var f := 150.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		f += _noise(rng) * 3.0
		f = clampf(f, 90.0, 260.0)
		ph += TAU * f / RATE
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		var gate := 0.5 + 0.5 * sin(TAU * 17.0 * t + sin(t * 9.0) * 3.0)
		lp += 0.25 * (saw - lp)
		out[i] = lp * gate * sin(PI * t / 1.2) * 0.8
	return _to_wav(out, false)


## Zumbido grave de tensão (loop de 8 s, sem emenda: frequências múltiplas de 1/8 Hz).
static func drone() -> AudioStreamWAV:
	var n := RATE * 8
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var lfo := 0.5 + 0.5 * sin(TAU * 0.25 * t)
		var v := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 82.5 * t) * 0.28 * lfo + sin(TAU * 110.25 * t) * 0.2 * (1.0 - lfo)
		v += sin(TAU * 58.5 * t) * 0.18     # batimento dissonante com 55 Hz (3,5 Hz)
		out[i] = v * 0.55
	return _to_wav(out, true)


## Riacho (loop de 6 s).
static func water() -> AudioStreamWAV:
	var n := RATE * 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		lp += 0.45 * (_noise(rng) - lp)
		lp2 += 0.05 * (lp - lp2)
		var t := float(i) / RATE
		var mod := 0.65 + 0.35 * sin(TAU * 0.5 * t) * sin(TAU * 1.0 * t + 1.0)
		out[i] = (lp - lp2 * 0.4) * mod * 0.7
	var fade := 3000
	for i in fade:
		out[i] = lerpf(out[n - fade + i], out[i], float(i) / fade)
	return _to_wav(out, true)


## Galope em calçamento de pedra (loop de 2,4 s): cascos secos em ritmo irregular.
static func gallop() -> AudioStreamWAV:
	var period := 0.6
	var n := int(RATE * period * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var out := PackedFloat32Array()
	out.resize(n)
	var beats := [0.0, 0.17, 0.30, 0.44]
	for cycle in 4:
		for b in beats:
			var i0 := int((cycle * period + b) * RATE)
			var amp := 0.8 if b == 0.0 else 0.6
			for k in int(0.22 * RATE):
				if i0 + k >= n:
					break
				var t := float(k) / RATE
				var click := _noise(rng) * exp(-t * 70.0) * 0.7
				var ring := sin(TAU * 720.0 * t) * exp(-t * 55.0) * 0.5
				var thud := sin(TAU * 75.0 * t) * exp(-t * 28.0) * 0.8
				out[i0 + k] += (click + ring + thud) * amp
	return _to_wav(out, true)


## Relincho (1,5 s).
static func neigh() -> AudioStreamWAV:
	var n := int(RATE * 1.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 131
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / 1.5
		var f := 520.0 + 700.0 * sin(PI * minf(u * 1.3, 1.0)) + 40.0 * sin(TAU * 22.0 * t)
		ph += TAU * f / RATE
		var env := minf(1.0, t * 14.0) * pow(1.0 - u, 0.6)
		var v := sin(ph) * 0.5 + sin(ph * 2.0) * 0.3 + sin(ph * 3.0) * 0.2 + _noise(rng) * 0.18 * (0.5 + 0.5 * sin(TAU * 31.0 * t))
		out[i] = v * env * 0.75
	return _to_wav(out, false)


## Fogo crepitando (loop de 3 s).
static func fire() -> AudioStreamWAV:
	var n := RATE * 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 141
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		lp += 0.06 * (_noise(rng) - lp)
		out[i] = lp * 0.9
	for k in 70:
		var i0 := rng.randi_range(0, n - 800)
		for j in 700:
			out[i0 + j] += _noise(rng) * exp(-float(j) / 90.0) * rng.randf_range(0.2, 0.7)
	var fade := 2000
	for i in fade:
		out[i] = lerpf(out[n - fade + i], out[i], float(i) / fade)
	return _to_wav(out, true)


## Sussurro ininteligível (2 s): ruído com formantes em ritmo de sílabas.
static func whisper() -> AudioStreamWAV:
	var n := int(RATE * 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 151
	var out := PackedFloat32Array()
	out.resize(n)
	var b1 := 0.0
	var b2 := 0.0
	var s1 := 0.0
	var s2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := _noise(rng)
		var f1 := 700.0 + 500.0 * sin(TAU * 3.1 * t)
		var f2 := 2200.0 + 800.0 * sin(TAU * 2.3 * t + 1.0)
		var a1 := TAU * f1 / RATE
		var a2 := TAU * f2 / RATE
		s1 += a1 * (x - b1 - 0.35 * s1)
		b1 += a1 * s1
		s2 += a2 * (x - b2 - 0.25 * s2)
		b2 += a2 * s2
		var syll := pow(0.5 + 0.5 * sin(TAU * 4.2 * t), 2.0)
		out[i] = (s1 * 0.6 + s2 * 0.5) * syll * 0.9
	return _to_wav(out, false)


## Acorde dissonante de susto (1,3 s).
static func sting() -> AudioStreamWAV:
	var n := int(RATE * 1.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 161
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t * 80.0) * exp(-t * 2.8)
		var v := 0.0
		for f in [110.0, 116.5, 233.0, 349.0, 466.0, 698.0]:
			v += sin(TAU * f * t + sin(t * 40.0) * 0.8) * 0.18
		v += _noise(rng) * exp(-t * 9.0) * 0.6
		out[i] = v * env
	return _to_wav(out, false)


## Tinido de vidro (pegar um frasco).
static func clink() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := sin(TAU * 2350.0 * t) * 0.5 + sin(TAU * 3720.0 * t) * 0.35 + sin(TAU * 5210.0 * t) * 0.2
		out[i] = v * exp(-t * 11.0) * 0.8
	return _to_wav(out, false)


## Chuvisco de TV sem sinal + zumbido de 60 Hz (loop de 2 s, sem emenda: 120 Hz = 240 ciclos exatos).
static func tv_static() -> AudioStreamWAV:
	var n := RATE * 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 211
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += 0.55 * (_noise(rng) - lp)
		var crackle := _noise(rng) * (0.12 + 0.10 * sin(TAU * 7.0 * t))
		out[i] = lp * 0.20 + crackle * 0.10 + sin(TAU * 60.0 * t) * 0.05 + sin(TAU * 120.0 * t) * 0.03
	var fade := 1500
	for i in fade:
		out[i] = lerpf(out[n - fade + i], out[i], float(i) / fade)
	return _to_wav(out, true)
