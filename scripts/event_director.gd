class_name EventDirector
extends Node
## Dirige os eventos que NÃO são o grito do Bradador: a Mula-sem-cabeça, o apagão dos lampiões
## e a janela assombrada (esta última se comporta sozinha, ver janela_assombrada.gd).
## Os tempos são sorteados; os eventos nunca acontecem ao mesmo tempo que a Mula.

var enabled := true
var player: Player
var screams: ScreamSystem
var audio: AudioDirector
var mula: Mula
var hud: Hud
var log_enabled := true

var _rng := RandomNumberGenerator.new()
var _t_mula := 110.0
var _t_blackout := 45.0
var _mula_hint_shown := false
var _refuge_count := 0
var _blackout_running := false


func setup(p_player: Player, p_screams: ScreamSystem, p_audio: AudioDirector, p_mula: Mula, p_hud: Hud) -> void:
	player = p_player
	screams = p_screams
	audio = p_audio
	mula = p_mula
	hud = p_hud
	_rng.randomize()
	mula.finished.connect(_on_mula_finished)
	for area in get_tree().get_nodes_in_group("refugio"):
		var a := area as Area3D
		a.body_entered.connect(func(b: Node3D) -> void:
			if b == player:
				_refuge_count += 1
				mula.refuge_count = _refuge_count)
		a.body_exited.connect(func(b: Node3D) -> void:
			if b == player:
				_refuge_count = maxi(0, _refuge_count - 1)
				mula.refuge_count = _refuge_count)


func _process(delta: float) -> void:
	if not enabled or player == null or not screams.enabled:
		return
	if mula.active or _blackout_running:
		return
	_t_blackout -= delta
	_t_mula -= delta
	var calm := screams.state == ScreamSystem.State.WAIT or screams.state == ScreamSystem.State.RESULT
	if _t_blackout <= 0.0 and calm:
		start_blackout()
	elif _t_mula <= 0.0 and screams.state == ScreamSystem.State.WAIT:
		start_mula()


func start_mula(from_above := true) -> void:
	var s_p := Route.nearest_s(player.global_position)
	var start := s_p + 180.0 if from_above else s_p - 180.0
	var direction := -1.0 if from_above else 1.0
	if start > Route.length() - 10.0 or start < 5.0:
		# sem espaço desse lado: ela vem do outro
		from_above = not from_above
		start = s_p + 180.0 if from_above else s_p - 180.0
		direction = -1.0 if from_above else 1.0
	start = clampf(start, 0.0, Route.length() - 8.0)
	screams.hold = true
	mula.refuge_count = _refuge_count
	mula.start(player, screams, audio, start, direction)
	_t_mula = _rng.randf_range(85.0, 140.0)
	if not _mula_hint_shown:
		_mula_hint_shown = true
		hud.show_prompt("Galope no calçamento!\nApague a lanterna [F] e entre num beco.", 7.0)
	if log_enabled:
		print("[evento] MULA de s=%.0f direcao=%d (jogador s=%.0f)" % [start, int(direction), s_p])


func _on_mula_finished() -> void:
	await get_tree().create_timer(3.0).timeout
	screams.hold = false
	if log_enabled:
		print("[evento] mula terminou")


## Os lampiões à frente do jogador se apagam em onda, como se algo caminhasse pela rua.
func start_blackout() -> void:
	_blackout_running = true
	var s_p := Route.nearest_s(player.global_position)
	var lamps: Array = []
	for l in get_tree().get_nodes_in_group("lampioes"):
		var light := l as Node3D
		var s_l := Route.nearest_s(light.global_position)
		if s_l > s_p - 15.0 and s_l < s_p + 120.0:
			lamps.append([s_l, l])
	lamps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	if log_enabled:
		print("[evento] APAGAO: %d lampioes" % lamps.size())
	for pair in lamps:
		var delay: float = maxf(0.0, (pair[0] - s_p)) / 30.0
		var lamp: Object = pair[1]
		get_tree().create_timer(delay).timeout.connect(func() -> void: lamp.set("ligada", false))
		get_tree().create_timer(delay + 7.0 + _rng.randf_range(0.0, 2.5)).timeout.connect(func() -> void: lamp.set("ligada", true))
	audio.bump_fear(0.2)
	audio.play_creak(player.global_position + Vector3(0, 2, -6))
	_t_blackout = _rng.randf_range(60.0, 100.0) - screams.stage * 8.0
	await get_tree().create_timer(10.0).timeout
	_blackout_running = false
