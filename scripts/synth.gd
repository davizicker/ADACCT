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


## Ressonador de formante (filtro de estado variável de Chamberlin). `st` = [passa-baixa, passa-banda].
static func _formante(x: float, st: Array, freq: float, banda: float) -> float:
	var f: float = 2.0 * sin(PI * minf(freq, RATE * 0.45) / RATE)
	var q1: float = banda / maxf(freq, 1.0)
	var lo: float = st[0]
	var bd: float = st[1]
	lo += f * bd
	var alta: float = x - lo - q1 * bd
	bd += f * alta
	st[0] = lo
	st[1] = bd
	return bd


## Grito do Bradador (~2,6 s): fonte glótica (trem de pulsos com tremor e rouquidão) passando por três formantes que
## deslizam de "a" para "o", duas vozes levemente desafinadas (coro sobrenatural), ar no meio e distorção suave.
static func scream() -> AudioStreamWAV:
	var dur := 2.6
	var n := int(RATE * dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out := PackedFloat32Array()
	out.resize(n)
	var fase := [0.0, 0.0]
	var det := [1.0, 1.0075]
	var st1 := [[0.0, 0.0], [0.0, 0.0]]
	var st2 := [[0.0, 0.0], [0.0, 0.0]]
	var st3 := [[0.0, 0.0], [0.0, 0.0]]
	var jit := 0.0
	var ar := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / dur
		jit = jit * 0.995 + _noise(rng) * 0.004                      # tremor lento e irregular no tom
		# curva do tom: sobe depressa ao agudo, mantém e cai arrastando
		var curva := 0.0
		if u < 0.14:
			curva = lerpf(380.0, 820.0, u / 0.14)
		else:
			curva = lerpf(820.0, 300.0, pow((u - 0.14) / 0.86, 0.8))
		var vib := 1.0 + 0.035 * sin(TAU * (5.2 + 1.5 * u) * t) + jit
		var f0 := curva * vib
		var env := minf(1.0, u * 14.0) * pow(1.0 - u, 0.9)
		var vogal := smoothstep(0.1, 0.8, u)                          # "a" -> "o"
		var f1 := lerpf(820.0, 520.0, vogal) * (1.0 + 0.08 * sin(TAU * 2.0 * t))
		var f2 := lerpf(1400.0, 950.0, vogal)
		var f3 := lerpf(2700.0, 2500.0, vogal)
		ar = ar * 0.6 + _noise(rng) * 0.4
		var mix := 0.0
		for v in 2:
			fase[v] += f0 * det[v] / RATE
			var ph: float = fase[v] - floor(fase[v])
			var pulso := (1.0 - ph) * (1.0 - ph) * 2.0 - 0.66          # onda dente-de-serra curvada (fonte glótica)
			var rouco := 0.75 + 0.25 * sin(TAU * f0 * 0.5 * t)         # subharmônico: aspereza
			var src: float = (pulso * rouco + ar * 0.22) * 0.5
			mix += _formante(src, st1[v], f1, 90.0) * 1.0 + _formante(src, st2[v], f2, 130.0) * 0.75 + _formante(src, st3[v], f3, 190.0) * 0.45
		var vozes := mix * 0.5
		out[i] = tanh(vozes * 2.2) * env * 0.85
	return _to_wav(out, false)


## Vento em loop de 12 s (sem emenda): ruído filtrado com rajadas lentas e um assobio que passa pelos beirais.
static func wind() -> AudioStreamWAV:
	var seg := 12
	var n := RATE * seg
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var out := PackedFloat32Array()
	out.resize(n)
	var v := 0.0
	var b1 := [0.0, 0.0]
	for i in n:
		var t := float(i) / RATE
		var x := _noise(rng)
		v = v * 0.985 + x * 0.06
		# rajadas: frequências que são múltiplos de 1/12 Hz fecham o loop sem estalo
		var rajada := 0.55 + 0.25 * sin(TAU * 1.0 / 12.0 * t + 0.6) + 0.15 * sin(TAU * 3.0 / 12.0 * t + 2.0) + 0.08 * sin(TAU * 7.0 / 12.0 * t)
		var assobio_f := 520.0 + 260.0 * sin(TAU * 2.0 / 12.0 * t) + 90.0 * sin(TAU * 5.0 / 12.0 * t)
		var whistle := _formante(x * 0.5, b1, assobio_f, 55.0) * pow(maxf(rajada - 0.45, 0.0), 1.5) * 1.8
		out[i] = (v * rajada * 1.5 + whistle * 0.05)
	return _to_wav(out, true)


## Chuva constante em telhas e pedra (loop 4 s): ruído filtrado com gotas mais fortes esparsas.
static func rain() -> AudioStreamWAV:
	var n := RATE * 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var w := rng.randf_range(-1.0, 1.0)
		lp = lp * 0.55 + w * 0.45
		lp2 = lp2 * 0.95 + w * 0.05
		var drop := 0.0
		if rng.randf() < 0.0025:
			drop = rng.randf_range(0.3, 0.9)
		out[i] = lp * 0.35 + lp2 * 0.9 + drop * w
	var fade := 2000
	for i in fade:
		var k := float(i) / fade
		out[i] = lerpf(out[n - fade + i], out[i], k)
	return _to_wav(out, true)


## Sino de bronze distante (~8 s): parciais inarmônicos de sino de verdade (hum, prime, terça menor, quinta, nominal...),
## cada um com seu tempo de decaimento, leve batimento entre pares e a pancada do badalo no início.
static func bell() -> AudioStreamWAV:
	var n := RATE * 8
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var out := PackedFloat32Array()
	out.resize(n)
	var f := 174.0
	# [razão, amplitude, decaimento por segundo, desafinação para o batimento]
	var parciais := [[0.5, 0.45, 0.35, 0.0], [1.0, 0.55, 0.55, 0.9], [1.2, 0.42, 0.75, 0.0], [1.5, 0.30, 1.0, 0.0], [2.0, 0.34, 1.2, 1.4], [2.5, 0.18, 1.6, 0.0], [3.0, 0.16, 1.9, 0.0], [4.1, 0.10, 2.6, 0.0], [5.4, 0.07, 3.4, 0.0]]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for pr in parciais:
			var fr: float = f * pr[0] + pr[3]
			v += sin(TAU * fr * t + pr[0] * 0.7) * pr[1] * exp(-t * pr[2])
		var bate := _noise(rng) * exp(-t * 90.0) * 0.5 + sin(TAU * 410.0 * t) * exp(-t * 40.0) * 0.2          # pancada do badalo
		out[i] = (v * minf(1.0, t * 400.0) + bate) * 0.5
	return _to_wav(out, false)


# ================================================================== efeitos do jogo (v2)
# Tudo sintetizado por código (placeholders atmosféricos). Gravações reais devem substituí-los.

static func _noise(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(-1.0, 1.0)


## Passo LEVE no calçamento de pedra: calcanhar (clique seco curto) e, logo depois, a ponta do pé (mais fraca), com um
## toque grave de contato, grãos de areia/cascalho e o roçar da roupa. Cada `variant` muda tempo, brilho e grãos,
## para que dois passos nunca soem iguais. `soft` = passo agachado (mais baixo e abafado).
static func step(variant: int, soft := false) -> AudioStreamWAV:
	var n := int(RATE * 0.26)
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + variant * 17
	var out := PackedFloat32Array()
	out.resize(n)
	var brilho := rng.randf_range(0.20, 0.34)            # coeficiente do filtro: quanto maior, mais agudo o clique
	var toe_t := rng.randf_range(0.055, 0.095)           # a ponta do pé toca um instante depois
	var f0 := rng.randf_range(85.0, 125.0)                # toque grave de contato (sola no chão)
	var gain := 0.55 if soft else 1.0
	var lpa := 0.0
	var lpb := 0.0
	var cloth := 0.0
	var grit_hp := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := _noise(rng)
		lpa += brilho * (x - lpa)
		var hp := x - lpa                                  # tira o grave do ruído
		lpb += 0.55 * (hp - lpb)                          # e o agudo extremo: sobra a faixa do estalo
		var heel := lpb * exp(-t * 150.0) * 0.55
		var thump := sin(TAU * f0 * t) * exp(-t * 52.0) * (0.0 if soft else 0.30)
		var tt := t - toe_t
		var toe := 0.0
		if tt > 0.0:
			toe = lpb * exp(-tt * 190.0) * 0.30 + sin(TAU * (f0 * 1.15) * tt) * exp(-tt * 60.0) * (0.0 if soft else 0.10)
		var grit := 0.0
		if t < 0.09 and rng.randf() < 0.012:
			grit_hp = rng.randf_range(0.15, 0.5) * (1.0 if rng.randf() < 0.5 else -1.0)
		grit_hp *= 0.55
		grit = grit_hp
		cloth += 0.04 * (_noise(rng) - cloth)
		var rustle := cloth * sin(PI * clampf(t / 0.16, 0.0, 1.0)) * 0.55
		out[i] = (heel + thump + toe + grit * 0.5 + rustle) * gain * 0.8
	return _to_wav(out, false)


## Passo em assoalho de madeira (dentro das casas): batida oca, ressonância da tábua e um rangido curtinho às vezes.
static func step_wood(variant: int) -> AudioStreamWAV:
	var n := int(RATE * 0.34)
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + variant * 13
	var out := PackedFloat32Array()
	out.resize(n)
	var f0 := rng.randf_range(115.0, 165.0)
	var f_tab := rng.randf_range(280.0, 420.0)             # a tábua ressoa
	var lp := 0.0
	var cloth := 0.0
	var toe_t := rng.randf_range(0.07, 0.11)
	for i in n:
		var t := float(i) / RATE
		var x := _noise(rng)
		lp += 0.30 * (x - lp)
		var body := sin(TAU * f0 * t) * exp(-t * 30.0) * 0.55
		var ring := sin(TAU * f_tab * t) * exp(-t * 22.0) * 0.22
		var knock := lp * exp(-t * 90.0) * 0.45
		var tt := t - toe_t
		var toe := 0.0
		if tt > 0.0:
			toe = (sin(TAU * f0 * 1.2 * tt) * exp(-tt * 45.0) * 0.18 + lp * exp(-tt * 140.0) * 0.14)
		cloth += 0.04 * (_noise(rng) - cloth)
		out[i] = (body + ring + knock + toe + cloth * sin(PI * clampf(t / 0.2, 0.0, 1.0)) * 0.45) * 0.75
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


## Grilos ao fundo (loop de 10 s): cada grilo canta séries de 3 a 5 pulsos rápidos com intervalo próprio, tom que varia um
## pouco e volume que oscila (distâncias diferentes), como um coro de verdade e não um zumbido regular.
static func crickets() -> AudioStreamWAV:
	var seg := 10
	var n := RATE * seg
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var out := PackedFloat32Array()
	out.resize(n)
	for c in 7:
		var f := 3900.0 + c * 330.0 + rng.randf_range(-60.0, 60.0)
		var periodo := rng.randf_range(0.95, 1.7)
		var fase := rng.randf() * periodo
		var pulsos := rng.randi_range(3, 5)
		var dist := rng.randf_range(0.35, 1.0)
		var vib_f := rng.randf_range(0.05, 0.2)
		for i in n:
			var t := float(i) / RATE
			var tp := fmod(t + fase, periodo)
			var gate := 0.0
			var dur_serie := pulsos * 0.045
			if tp < dur_serie:
				var pp := fmod(tp, 0.045) / 0.045
				gate = sin(PI * pp) * (1.0 - 0.3 * (tp / dur_serie))
			var oscila := 0.6 + 0.4 * sin(TAU * float(c + 1) / seg * t)         # volume oscila (múltiplo de 1/10 Hz: fecha o loop)
			var fm := f * (1.0 + 0.004 * sin(TAU * 90.0 * t))
			out[i] += sin(TAU * fm * t) * gate * 0.06 * dist * oscila
	return _to_wav(out, true)


## Coruja ao longe (~1,6 s): dois "uu" graves e abafados, o segundo mais baixo.
static func owl() -> AudioStreamWAV:
	var n := int(RATE * 1.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 311
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for hoot in [[0.05, 360.0, 0.45], [0.62, 310.0, 0.7]]:
		var i0 := int(hoot[0] * RATE)
		var len := int(hoot[2] * RATE)
		for k in len:
			if i0 + k >= n:
				break
			var t := float(k) / RATE
			var u := t / float(hoot[2])
			var fr: float = hoot[1] * (1.0 - 0.12 * u) * (1.0 + 0.01 * sin(TAU * 6.0 * t))
			ph += TAU * fr / RATE
			var env := sin(PI * minf(u * 1.0, 1.0)) * (1.0 - 0.3 * u)
			out[i0 + k] += (sin(ph) * 0.7 + sin(ph * 2.0) * 0.12 + _noise(rng) * 0.004) * env * 0.7
	return _to_wav(out, false)


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


## Passo PESADO e arrastado (o Bradador): pancada grave, arrasto de bota na pedra e um estalo úmido no fim.
static func passo_pesado(variant: int) -> AudioStreamWAV:
	var n := int(RATE * 0.75)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant * 31
	var out := PackedFloat32Array()
	out.resize(n)
	var f0 := rng.randf_range(48.0, 66.0)
	var drag_t := rng.randf_range(0.10, 0.16)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := _noise(rng)
		lp += 0.08 * (x - lp)
		lp2 += 0.35 * (x - lp2)
		var thud := sin(TAU * f0 * t * (1.0 - 0.25 * t)) * exp(-t * 11.0) * 0.95
		var body := lp * exp(-t * 14.0) * 0.8
		var td := t - drag_t
		var drag := 0.0
		if td > 0.0:
			drag = (lp2 - lp) * sin(PI * clampf(td / 0.42, 0.0, 1.0)) * 0.55 * (0.7 + 0.3 * sin(TAU * 31.0 * td))
		var slap := 0.0
		var ts := t - 0.50
		if ts > 0.0:
			slap = (lp2 - lp) * exp(-ts * 60.0) * 0.5 + sin(TAU * 90.0 * ts) * exp(-ts * 25.0) * 0.35
		out[i] = thud + body + drag + slap
	return _to_wav(out, false)


## Unhas arranhando madeira/pedra: três riscos curtos, cada um com ruído agudo modulado (som de coisa tentando entrar).
static func arranhao() -> AudioStreamWAV:
	var n := int(RATE * 1.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 931
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var starts := [0.05, 0.50, 0.92]
	for i in n:
		var t := float(i) / RATE
		var x := _noise(rng)
		lp += 0.55 * (x - lp)
		var hp := x - lp
		var env := 0.0
		for st in starts:
			var d: float = t - float(st)
			if d > 0.0 and d < 0.38:
				env = maxf(env, sin(PI * d / 0.38) * (0.6 + 0.4 * sin(TAU * 47.0 * d)))
		out[i] = hp * env * 0.55
	return _to_wav(out, false)


## Rosnado grave e úmido, com tremor de garganta (rouquidão) e um fio de respiração.
static func rosnado() -> AudioStreamWAV:
	var n := int(RATE * 2.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 947
	var out := PackedFloat32Array()
	out.resize(n)
	var st1 := [0.0, 0.0]
	var st2 := [0.0, 0.0]
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 68.0 + 14.0 * sin(TAU * 0.9 * t) - 10.0 * t
		ph += TAU * f / RATE
		var saw := fmod(ph / TAU, 1.0) * 2.0 - 1.0
		var trem := 0.55 + 0.45 * sin(TAU * 23.0 * t + 1.7 * sin(TAU * 3.0 * t))
		var src := saw * trem + _noise(rng) * 0.25
		var a := _formante(src, st1, 260.0 + 80.0 * sin(TAU * 1.3 * t), 0.14)
		var b := _formante(src, st2, 720.0, 0.10)
		var env := sin(PI * clampf(t / 2.2, 0.0, 1.0))
		out[i] = (a * 0.85 + b * 0.35) * env * 0.9
	return _to_wav(out, false)


## Papel sendo desdobrado/amassado (ao abrir ou fechar um bilhete).
static func papel() -> AudioStreamWAV:
	var n := int(RATE * 0.55)
	var rng := RandomNumberGenerator.new()
	rng.seed = 971
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var burst := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := _noise(rng)
		lp += 0.30 * (x - lp)
		if rng.randf() < 0.0035:
			burst = rng.randf_range(0.4, 1.0)
		burst *= 0.9985
		var env := sin(PI * clampf(t / 0.55, 0.0, 1.0))
		out[i] = ((x - lp) * 0.25 + (x - lp) * burst * 0.5) * env
	return _to_wav(out, false)
