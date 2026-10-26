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
var _step_players: Array[AudioStreamPlayer] = []
var _step_i := 0
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
var _dog_t := 18.0
var _bell_t := 35.0


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
	player = p_player
	screams = p_screams
	_rng.randomize()
	ensure_buses()
	for i in 4:
		_steps.append(Synth.step(i))
	for i in 2:
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
	_dog = _player3d(Synth.dog(), "Ambiente", -8.0, 30.0)
	_bell = _player3d(Synth.bell(), "Ambiente", -2.0, 60.0)
	_creak = _player3d(Synth.creak(), "Efeitos", -4.0, 12.0)
	_whisper = _player3d(Synth.whisper(), "Efeitos", -6.0, 8.0)
	player.footstep.connect(_on_step)
	Config.apply(get_parent())


func get_bpm() -> float:
	return 60.0 * (_heart.pitch_scale if _heart else 1.0)


func bump_fear(amount: float) -> void:
	fear_boost = minf(1.0, fear_boost + amount)


func _on_step(loudness: float) -> void:
	var p := _step_players[_step_i]
	_step_i = (_step_i + 1) % _step_players.size()
	p.stream = _steps[_rng.randi() % _steps.size()]
	p.volume_db = lerpf(-26.0, -5.0, loudness)
	p.pitch_scale = _rng.randf_range(0.92, 1.08) * (0.9 if loudness < 0.3 else 1.0)
	p.play()


## Rangido de madeira vindo de uma posição (porta, janela...).
func play_creak(pos: Vector3) -> void:
	_creak.global_position = pos
	_creak.pitch_scale = _rng.randf_range(0.85, 1.15)
	_creak.play()


## Sussurro bem perto do jogador (o Bradador está por perto).
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

	_dog_t -= delta
	if _dog_t <= 0.0:
		_dog_t = _rng.randf_range(25.0, 60.0)
		var a := _rng.randf() * TAU
		_dog.global_position = player.global_position + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(70.0, 130.0) + Vector3(0, 3, 0)
		_dog.pitch_scale = _rng.randf_range(0.85, 1.2)
		_dog.play()
	_bell_t -= delta
	if _bell_t <= 0.0:
		_bell_t = _rng.randf_range(50.0, 90.0)
		_bell.global_position = Route.pos(Route.CHURCH_S) + Vector3(0, 26, 0)
		_bell.play()
