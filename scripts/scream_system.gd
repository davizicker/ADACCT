class_name ScreamSystem
extends Node
## Mecânica central: o Bradador grita de longe, você PARA e RESPONDE gritando.
## Responder certo o afasta; ficar em silêncio, andar durante a janela, ou olhar
## para ele o aproxima. No estágio final ele chega até você.

signal player_died
signal log_line(text: String)

enum State { WAIT, SCREAM, WINDOW, RESULT }

## distância do Bradador por estágio (m). O último estágio é a morte.
const STAGE_DIST: Array[float] = [90.0, 55.0, 32.0, 16.0, 3.0]
const WINDOW_SECONDS := 3.0
const SHOUT_NEEDED := 0.5
const GAZE_SECONDS := 1.6

var enabled := true
var audio: AudioDirector = null
var stage := 0
var state := State.WAIT
var mic_threshold := Config.mic_threshold
var has_mic := false
var mic_level := 0.0
## teste automatizado: resultados forçados em ordem (true = respondeu certo)
var forced_results: Array[bool] = []
var interval_range := Vector2(14.0, 24.0)

var player: Player
var hud: Hud
var bradador: Node3D
var scream_stream := Synth.scream()
var successes := 0
var echo_done := false

var _timer := 8.0
var _scream_left := 0.0
var _window_left := 0.0
var _shout_time := 0.0
var _screams_heard := 0
## +1 = o Bradador fica à frente (rua acima), -1 = atrás (rua abaixo)
var _axis := 1.0
var _echo_t := -1.0
var _gaze_t := 0.0
var _gaze_warned := false
var _capture: AudioEffectCapture
var _scream_player: AudioStreamPlayer3D
var _echo_player: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func setup(p_player: Player, p_hud: Hud, p_bradador: Node3D, use_mic: bool) -> void:
	player = p_player
	hud = p_hud
	_rng.randomize()
	bradador = p_bradador
	bradador.visible = false
	_scream_player = _make_3d_player(6.0)
	_echo_player = _make_3d_player(4.0)
	if use_mic:
		has_mic = _setup_mic()


func _make_3d_player(gain_db: float) -> AudioStreamPlayer3D:
	var ap := AudioStreamPlayer3D.new()
	ap.stream = scream_stream
	ap.unit_size = 30.0
	ap.volume_db = gain_db
	ap.max_distance = 0.0
	add_child(ap)
	return ap


func _setup_mic() -> bool:
	var idx := AudioServer.get_bus_index("Mic")
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Mic")
		_capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(idx, _capture)
		# silencia a saída DEPOIS da captura para o jogador não ouvir a si mesmo
		var amp := AudioEffectAmplify.new()
		amp.volume_db = -80.0
		AudioServer.add_bus_effect(idx, amp)
	else:
		_capture = AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture
	if _capture == null:
		return false
	var mic_player := AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Mic"
	add_child(mic_player)
	mic_player.play()
	return true


func _read_mic(delta: float) -> void:
	if _capture == null:
		return
	var frames := _capture.get_frames_available()
	if frames > 0:
		var buf := _capture.get_buffer(frames)
		var sum := 0.0
		for v in buf:
			sum += v.x * v.x
		var rms := sqrt(sum / maxf(buf.size(), 1))
		mic_level = maxf(rms, mic_level - delta * 0.6)
	else:
		mic_level = maxf(0.0, mic_level - delta * 0.6)


func is_shouting() -> bool:
	return Input.is_action_pressed("shout") or (has_mic and mic_level > mic_threshold)


func _process(delta: float) -> void:
	if not enabled or player == null:
		return
	_read_mic(delta)
	if Input.is_action_just_pressed("threshold_down"):
		mic_threshold = maxf(0.01, mic_threshold - 0.01)
		Config.mic_threshold = mic_threshold
		Config.save_all()
	if Input.is_action_just_pressed("threshold_up"):
		mic_threshold = minf(0.5, mic_threshold + 0.01)
		Config.mic_threshold = mic_threshold
		Config.save_all()
	hud.set_mic(mic_level, mic_threshold, has_mic)

	if _echo_t > 0.0:
		_echo_t -= delta
		if _echo_t <= 0.0:
			_play_echo_behind()

	_update_gaze(delta)

	match state:
		State.WAIT:
			_timer -= delta
			if _timer <= 0.0:
				_begin_scream()
		State.SCREAM:
			_scream_left -= delta
			if _scream_left <= 0.0:
				_begin_window()
		State.WINDOW:
			_window_left -= delta
			if player.move_speed < 0.5 and is_shouting():
				_shout_time += delta
			if forced_results.size() > 0:
				_resolve(forced_results.pop_front())
			elif _shout_time >= SHOUT_NEEDED:
				_resolve(true)
			elif _window_left <= 0.0:
				_resolve(false)
		State.RESULT:
			_timer -= delta
			if _timer <= 0.0:
				_timer = _rng.randf_range(interval_range.x, interval_range.y)
				state = State.WAIT


func _place_bradador() -> void:
	var dist := STAGE_DIST[stage]
	var s_p := Route.nearest_s(player.global_position)
	var s_b := s_p + _axis * dist
	# se a rua acabar antes da distância pedida (começo ou igreja), ele vem pelo outro lado
	if s_b < 0.0 or s_b > Route.length() - 6.0:
		_axis = -_axis
		s_b = s_p + _axis * dist
	s_b = clampf(s_b, 0.0, Route.length() - 6.0)
	var p := Route.pos(s_b)
	bradador.global_position = Vector3(p.x, p.y + 0.03, p.z)
	var look := Vector3(player.global_position.x, bradador.global_position.y, player.global_position.z)
	if look.distance_to(bradador.global_position) > 0.1:
		bradador.look_at(look, Vector3.UP)
	bradador.visible = stage >= 1


func _begin_scream() -> void:
	_screams_heard += 1
	_axis = 1.0 if _rng.randf() < 0.55 else -1.0
	_place_bradador()
	_scream_player.global_position = bradador.global_position + Vector3(0, 1.8, 0)
	_scream_player.play()
	_scream_left = scream_stream.get_length()
	state = State.SCREAM
	if _screams_heard == 1:
		hud.show_prompt("Algo grita na névoa.\nQuando parar: PARE e RESPONDA (grite ou segure R).", 6.0)
	if audio != null and stage >= 2:
		audio.play_whisper()
	log_line.emit("scream #%d stage=%d axis=%d" % [_screams_heard, stage, int(_axis)])


func _begin_window() -> void:
	state = State.WINDOW
	_window_left = WINDOW_SECONDS
	_shout_time = 0.0
	if _screams_heard <= 2:
		hud.show_prompt("PARE E GRITE!", WINDOW_SECONDS)


func _resolve(success: bool) -> void:
	hud.show_prompt("", 0.0)
	if success:
		successes += 1
		stage = maxi(0, stage - 1)
		log_line.emit("RESPONDEU certo -> stage=%d" % stage)
		if successes == 2 and not echo_done:
			echo_done = true
			_echo_t = 1.8
	else:
		stage += 1
		player.shake(0.06, 0.6)
		if audio != null:
			audio.bump_fear(0.25)
		log_line.emit("FALHOU -> stage=%d" % stage)
	if stage >= STAGE_DIST.size() - 1:
		_kill()
		return
	_place_bradador()
	state = State.RESULT
	_timer = 2.5


## Evento viral #1: depois de responder, sua "própria voz" volta de trás de você.
func _play_echo_behind() -> void:
	var back := player.global_transform.basis.z.normalized()
	_echo_player.global_position = player.global_position + back * 2.5 + Vector3(0, 1.6, 0)
	_echo_player.pitch_scale = 0.55
	_echo_player.play()
	player.shake(0.12, 1.2)
	player.blackout(1.4)
	if audio != null:
		audio.play_sting()
	hud.flash(Color(1, 1, 1, 0.55), 0.12)
	log_line.emit("ECHO atrás do jogador")


func _update_gaze(delta: float) -> void:
	if stage < 1 or not bradador.visible:
		_gaze_t = 0.0
		return
	var to := bradador.global_position + Vector3(0, 2.0, 0) - player.cam.global_position
	var looking := to.length() < 45.0 and (-player.cam.global_transform.basis.z).dot(to.normalized()) > 0.96
	if looking:
		_gaze_t += delta
		if not _gaze_warned and _gaze_t > 0.6:
			_gaze_warned = true
			hud.show_prompt("Não olhe para ele.", 3.0)
		if _gaze_t >= GAZE_SECONDS:
			_gaze_t = 0.0
			stage += 1
			log_line.emit("OLHOU -> stage=%d" % stage)
			player.shake(0.08, 0.6)
			if stage >= STAGE_DIST.size() - 1:
				_kill()
			else:
				_place_bradador()
	else:
		_gaze_t = maxf(0.0, _gaze_t - delta * 2.0)


func _kill() -> void:
	enabled = false
	stage = STAGE_DIST.size() - 1
	_place_bradador()
	bradador.visible = true
	player.frozen = true
	player.blackout(60.0)
	_scream_player.pitch_scale = 1.3
	_scream_player.volume_db = 12.0
	_scream_player.play()
	player.shake(0.2, 1.0)
	if audio != null:
		audio.play_sting()
	player_died.emit()
