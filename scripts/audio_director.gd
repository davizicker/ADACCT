class_name AudioDirector
extends Node
## Cuida de TODO o áudio do ambiente: vento, grilos, zumbido de tensão, batimento cardíaco,
## respiração, passos, cachorros e sino distantes, e os "sustos" sonoros.
## O medo (0..1) vem do estágio do Bradador e de eventos; ele sobe o batimento, tira os grilos
## (o silêncio assusta) e faz a imagem escurecer (ver hud.gd).
## Todos os sons são sintetizados por código (scripts/synth.gd): troque por gravações reais.

var player: Player
var screams: ScreamSystem
var fear := 0.0
## eventos (Mula, sustos) somam medo aqui; decai sozinho
var fear_boost := 0.0

var _rng := RandomNumberGenerator.new()
var _steps: Array[AudioStreamWAV] = []
var _steps_soft: Array[AudioStreamWAV] = []
var _steps_wood: Array[AudioStreamWAV] = []
var _step_players: Array[AudioStreamPlayer] = []
var _step_i := 0
var _step_ultimo := -1
var _owl: AudioStreamPlayer3D
var _owl_t := 40.0
var _wind: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _breath: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _dog: AudioStreamPlayer3D
var _bell: AudioStreamPlayer3D
var _creak: AudioStreamPlayer3D
var _whisper: AudioStreamPlayer3D
var _water: AudioStreamPlayer3D
var _clink: AudioStreamPlayer
var _fountain: AudioStreamPlayer3D
var _passo_b: AudioStreamPlayer3D
var _arranha: AudioStreamPlayer3D
var _rosna: AudioStreamPlayer3D
var _papel: AudioStreamPlayer
var _passos_b: Array[AudioStreamWAV] = []
var _t_passo_b := 3.0
var _t_arranha := 15.0
var _t_rosna := 25.0
var _dog_t := 18.0
var _bell_t := 35.0
var interior := false                      # o jogador está dentro de uma casa (passos de madeira, mundo abafado)
var _sinos_restantes := 6                  # as seis badaladas das 18h, logo no começo da noite
var _sino_prox := 4.0
var _cutoff := 20000.0


static func ensure_buses() -> void:
	for spec in [["Musica", 0.0], ["Efeitos", 0.22], ["Ambiente", 0.12]]:
		var bus_name: String = spec[0]
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
		var wet: float = spec[1]
		if wet > 0.0:
			var rev := AudioEffectReverb.new()
			rev.room_size = 0.55      # rua de pedra entre paredes: eco curto
			rev.damping = 0.5
			rev.wet = wet
			rev.dry = 1.0
			AudioServer.add_bus_effect(idx, rev)
		if bus_name == "Ambiente":
			var lp := AudioEffectLowPassFilter.new()          # dentro de casa o mundo lá fora fica abafado (filtro fecha suavemente)
			lp.cutoff_hz = 20000.0
			AudioServer.add_bus_effect(idx, lp)


func _loop_player(stream: AudioStream, bus: String, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	add_child(p)
	p.play()
	return p


func _player3d(stream: AudioStream, bus: String, volume_db: float, unit := 25.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.unit_size = unit
	p.max_distance = 0.0
	add_child(p)
	return p


func setup(p_player: Player, p_screams: ScreamSystem) -> void:
	add_to_group("audio")
	player = p_player
	screams = p_screams
	_rng.randomize()
	ensure_buses()
	for i in 8:
		_steps.append(Synth.step(i))                 # passos leves na pedra (8 variações para nunca soarem iguais)
	for i in 4:
		_steps_soft.append(Synth.step(20 + i, true)) # agachado: mais baixo e abafado
	for i in 6:
		_steps_wood.append(Synth.step_wood(i))       # dentro das casas: assoalho de madeira
	for i in 3:
		var sp := AudioStreamPlayer.new()
		sp.bus = "Efeitos"
		add_child(sp)
		_step_players.append(sp)
	_wind = _loop_player(Synth.wind(), "Ambiente", -14.0)
	_crickets = _loop_player(Synth.crickets(), "Ambiente", -20.0)
	_drone = _loop_player(Synth.drone(), "Musica", -40.0)
	_heart = _loop_player(Synth.heartbeat(), "Efeitos", -60.0)
	_breath = AudioStreamPlayer.new()
	_breath.stream = Synth.breath()
	_breath.bus = "Efeitos"
	_breath.volume_db = -8.0
	add_child(_breath)
	_sting = AudioStreamPlayer.new()
	_sting.stream = Synth.sting()
	_sting.bus = "Efeitos"
	_sting.volume_db = -2.0
	add_child(_sting)
	_owl = _player3d(Synth.owl(), "Ambiente", -9.0, 40.0)
	_dog = _player3d(Synth.dog(), "Ambiente", -8.0, 30.0)
	_bell = _player3d(Synth.bell(), "Ambiente", -2.0, 60.0)
	_bell.max_polyphony = 4                    # as badaladas se sobrepõem, como um sino de verdade
	_creak = _player3d(Synth.creak(), "Efeitos", -4.0, 12.0)
	_whisper = _player3d(Synth.whisper(), "Efeitos", -6.0, 8.0)
	_clink = AudioStreamPlayer.new()
	_clink.stream = Synth.clink()
	_clink.bus = "Efeitos"
	_clink.volume_db = -4.0
	add_child(_clink)
	_water = _player3d(Synth.water(), "Ambiente", -4.0, 14.0)
	_water.global_position = Route.pos(Route.BRIDGE_S) + Vector3(0, -3.0, 0)
	_water.play()
	_fountain = _player3d(Synth.water(), "Ambiente", -2.0, 9.0)
	_fountain.global_position = Route.pos(Route.FOUNTAIN_S) + Route.right(Route.FOUNTAIN_S) * Route.FOUNTAIN_SIDE * (Route.width(Route.FOUNTAIN_S) * 0.5 + 1.5) + Vector3(0, 1.0, 0)
	_fountain.play()
	for k in 4:
		_passos_b.append(Synth.passo_pesado(k))
	_passo_b = _player3d(_passos_b[0], "Efeitos", -3.0, 22.0)
	_arranha = _player3d(Synth.arranhao(), "Efeitos", -5.0, 14.0)
	_rosna = _player3d(Synth.rosnado(), "Efeitos", -4.0, 12.0)
	_papel = AudioStreamPlayer.new()
	_papel.stream = Synth.papel()
	_papel.bus = "Efeitos"
	_papel.volume_db = -9.0
	add_child(_papel)
	player.footstep.connect(_on_step)
	Config.apply(get_parent())


func get_bpm() -> float:
	return 60.0 * (_heart.pitch_scale if _heart else 1.0)


func acalmar(amount: float) -> void:
	fear_boost = maxf(0.0, fear_boost - amount)
	fear = maxf(0.0, fear - amount * 0.5)


func bump_fear(amount: float) -> void:
	fear_boost = minf(1.0, fear_boost + amount)


func _on_step(loudness: float) -> void:
	var p := _step_players[_step_i]
	_step_i = (_step_i + 1) % _step_players.size()
	var lista: Array[AudioStreamWAV] = _steps
	var dentro := interior or player.global_position.x > 1500.0          # dentro de casa: madeira em vez de pedra
	if dentro:
		lista = _steps_wood
	elif loudness < 0.3:
		lista = _steps_soft
	var k := _rng.randi() % lista.size()
	if k == _step_ultimo and lista.size() > 1:                # nunca o mesmo som duas vezes seguidas
		k = (k + 1 + _rng.randi() % (lista.size() - 1)) % lista.size()
	_step_ultimo = k
	p.stream = lista[k]
	p.volume_db = lerpf(-34.0, -13.0, loudness) + _rng.randf_range(-1.5, 1.0)       # passo leve; correr é bem mais audível
	p.pitch_scale = _rng.randf_range(0.93, 1.07) * (0.94 if loudness < 0.3 else 1.0)
	p.play()
	if dentro and loudness > 0.25 and _rng.randf() < 0.10:
		play_creak(player.global_position + Vector3(0, 0.0, 0))     # a tábua range de vez em quando


## Rangido de madeira vindo de uma posição (porta, janela...).
func play_creak(pos: Vector3) -> void:
	_creak.global_position = pos
	_creak.pitch_scale = _rng.randf_range(0.85, 1.15)
	_creak.play()


## Sussurro bem perto do jogador (o Bradador está por perto).
func play_creak_at(pos: Vector3) -> void:
	play_creak(pos)


## Missao avisa quando o jogador entra/sai de uma casa.
func set_interior(v: bool) -> void:
	interior = v


func play_clink() -> void:
	_clink.play()


func play_papel() -> void:
	_papel.pitch_scale = _rng.randf_range(0.92, 1.08)
	_papel.play()


## Presença sonora do Bradador: passos pesados vindos dele, arranhões nas paredes e rosnado quando está perto.
func _presenca_bradador(delta: float) -> void:
	if screams == null or screams.stage < 1 or screams.bradador == null or screams.hold:
		return
	if screams._em_casa():
		return
	var st := screams.stage
	var origem: Vector3 = screams.bradador.global_position
	var dist := origem.distance_to(player.global_position)
	_t_passo_b -= delta
	if _t_passo_b <= 0.0:
		_t_passo_b = _rng.randf_range(2.4, 3.8) / (0.6 + 0.4 * float(st))
		_passo_b.stream = _passos_b[_rng.randi() % _passos_b.size()]
		_passo_b.global_position = origem + Vector3(0, 0.1, 0)
		_passo_b.volume_db = lerpf(-14.0, -1.0, clampf(1.0 - dist / 90.0, 0.0, 1.0))
		_passo_b.pitch_scale = _rng.randf_range(0.9, 1.08)
		_passo_b.play()
	_t_arranha -= delta
	if _t_arranha <= 0.0:
		_t_arranha = _rng.randf_range(11.0, 24.0) / (0.5 + 0.5 * float(st))
		var a := _rng.randf() * TAU
		_arranha.global_position = player.global_position + Vector3(cos(a), 0.6, sin(a)) * _rng.randf_range(5.0, 12.0)
		_arranha.pitch_scale = _rng.randf_range(0.85, 1.15)
		_arranha.play()
	if st >= 3:
		_t_rosna -= delta
		if _t_rosna <= 0.0:
			_t_rosna = _rng.randf_range(18.0, 34.0)
			var d2 := -player.global_transform.basis.z
			_rosna.global_position = player.global_position - d2 * _rng.randf_range(4.0, 8.0) + Vector3(0, 1.2, 0)
			_rosna.pitch_scale = _rng.randf_range(0.9, 1.1)
			_rosna.play()


func play_whisper() -> void:
	var dir := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
	_whisper.global_position = player.global_position + dir * 1.6 + Vector3(0, 1.6, 0)
	_whisper.play()


func play_sting() -> void:
	_sting.play()
	bump_fear(0.35)


func _process(delta: float) -> void:
	if player == null:
		return
	var target := 0.0
	if screams != null:
		target = clampf(float(screams.stage) / 3.0, 0.0, 1.0) * 0.8
		if screams.state == ScreamSystem.State.SCREAM or screams.state == ScreamSystem.State.WINDOW:
			target += 0.25
	target = clampf(target + fear_boost, 0.0, 1.0)
	fear = move_toward(fear, target, delta * (0.5 if target > fear else 0.12))
	fear_boost = maxf(0.0, fear_boost - delta * 0.1)
	player.fear = fear

	_heart.volume_db = lerpf(-60.0, -7.0, smoothstep(0.08, 0.9, fear))
	_heart.pitch_scale = lerpf(0.85, 1.55, fear)
	_drone.volume_db = lerpf(-40.0, -15.0, fear)
	_crickets.volume_db = lerpf(-20.0, -60.0, clampf(fear * 1.3, 0.0, 1.0))   # o silêncio assusta
	_wind.volume_db = lerpf(-14.0, -10.0, fear)
	if (player.exhausted or player.stamina < 22.0) and not _breath.playing:
		_breath.pitch_scale = _rng.randf_range(0.95, 1.1)
		_breath.play()

	# mundo abafado dentro de casa (filtro passa-baixa no barramento "Ambiente")
	var alvo_cut := 1400.0 if interior else 20000.0
	_cutoff = lerpf(_cutoff, alvo_cut, clampf(delta * 3.0, 0.0, 1.0))
	var ib := AudioServer.get_bus_index("Ambiente")
	if ib != -1:
		for ei in AudioServer.get_bus_effect_count(ib):
			var ef := AudioServer.get_bus_effect(ib, ei)
			if ef is AudioEffectLowPassFilter:
				(ef as AudioEffectLowPassFilter).cutoff_hz = _cutoff
	# as seis badaladas das 18h (o sino que a vila inteira conhece)
	if _sinos_restantes > 0:
		_sino_prox -= delta
		if _sino_prox <= 0.0:
			_sinos_restantes -= 1
			_sino_prox = 4.6
			_bell.global_position = Route.pos(Route.CHURCH_S) + Vector3(0, 26, 0)
			_bell.pitch_scale = 1.0
			_bell.volume_db = 3.0 if _sinos_restantes > 0 else 0.0
			_bell.play()
	_presenca_bradador(delta)
	_dog_t -= delta
	if _dog_t <= 0.0:
		_dog_t = _rng.randf_range(25.0, 60.0)
		var a := _rng.randf() * TAU
		_dog.global_position = player.global_position + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(70.0, 130.0) + Vector3(0, 3, 0)
		_dog.pitch_scale = _rng.randf_range(0.85, 1.2)
		_dog.play()
	_owl_t -= delta
	if _owl_t <= 0.0:
		_owl_t = _rng.randf_range(45.0, 110.0)
		var ao := _rng.randf() * TAU
		_owl.global_position = player.global_position + Vector3(cos(ao), 0.0, sin(ao)) * _rng.randf_range(45.0, 90.0) + Vector3(0, 8, 0)
		_owl.pitch_scale = _rng.randf_range(0.9, 1.12)
		_owl.play()
	_bell_t -= delta
	if _bell_t <= 0.0:
		_bell_t = _rng.randf_range(50.0, 90.0)
		_bell.volume_db = -2.0
		_bell.global_position = Route.pos(Route.CHURCH_S) + Vector3(0, 26, 0)
		_bell.play()
