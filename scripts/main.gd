extends Node3D
## Liga as peças da cena principal. Argumentos de teste (depois de "--"):
##   --selftest       simula respostas certas/erradas até a morte
##   --selftest-walk  anda pela rua inteira até a igreja (sem gritos)
##   --selftest-mula=rua|refugio|refugio_aceso  testa a regra da Mula-sem-cabeça
##   --selftest-auto  partida completa automática (eventos ligados) por ~7 min simulados
##   --selftest-escape tenta sair da rua andando para os lados (a vila deve ser fechada)
##   --shot=<arquivo.png> [--shot-s=<m>] [--shot-stage=<n>] [--shot-yaw=<graus>] [--shot-pitch=<graus>] [--shot-lift=<m>]  salva um print e sai

# Os objetos abaixo estão em scenes/main.tscn: mexa neles no editor.
@onready var world: Node3D = $Vila
@onready var player: Player = $Jogador
@onready var hud: Hud = $Interface
@onready var screams: ScreamSystem = $Gritos
@onready var bradador: Node3D = $Bradador
@onready var audio: AudioDirector = $Audio
@onready var mula: Mula = $Mula
@onready var eventos: EventDirector = $Eventos
@onready var church_door: Area3D = $Vila/Adro/Igreja/Porta
var finished := false
var menu: Menu = null
var mode := ""
var _shot_frames := 20
var shot_path := ""
var _t := 0.0
var _frames := 0


func _ready() -> void:
	Config.load_all()
	_setup_input()
	var args := OS.get_cmdline_user_args()
	if "--selftest" in args:
		mode = "selftest"
	elif "--selftest-walk" in args:
		mode = "walk"
	elif "--selftest-escape" in args:
		mode = "escape"
	elif "--selftest-auto" in args:
		mode = "auto"
	var mula_case := ""
	for a in args:
		if a.begins_with("--selftest-mula="):
			mode = "mula"
			mula_case = a.substr(16)
	var shot_s := 2.0
	var shot_stage := 0
	var shot_yaw := 0.0
	var shot_pitch := 0.0
	var shot_lift := 0.0
	var shot_day := "--shot-day" in args
	var shot_mula := -1000.0
	_shot_frames = 20
	for a in args:
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
			mode = "shot"
		elif a.begins_with("--shot-s="):
			shot_s = float(a.substr(9))
		elif a.begins_with("--shot-yaw="):
			shot_yaw = float(a.substr(11))
		elif a.begins_with("--shot-pitch="):
			shot_pitch = float(a.substr(13))
		elif a.begins_with("--quality="):
			Config.quality = clampi(int(a.substr(10)), 0, 2)
		elif a.begins_with("--shot-frames="):
			_shot_frames = int(a.substr(14))
		elif a.begins_with("--shot-mula="):
			shot_mula = float(a.substr(12))
		elif a.begins_with("--shot-lift="):
			shot_lift = float(a.substr(12))
		elif a.begins_with("--shot-stage="):
			shot_stage = int(a.substr(13))
	if mode == "shot" or mode == "escape":
		_place_player(shot_s, shot_yaw, shot_pitch)
		if shot_lift > 0.0:
			player.global_position.y += shot_lift
			player.set_physics_process(false)

	if shot_day:   # só para inspecionar a geometria de dia
		var env := ($Vila/Ambiente as WorldEnvironment).environment
		env.ambient_light_energy = 2.2
		env.ambient_light_color = Color(0.8, 0.85, 1.0)
		env.fog_density = 0.003
		($Vila/Lua as DirectionalLight3D).light_energy = 1.4
	# modelos 3D reais (assets/models/*.glb), se existirem, substituem os modelos simples
	if Modelos.aplicar(bradador, Modelos.BRADADOR):
		print("[modelos] bradador.glb carregado")
	if Modelos.aplicar(mula, Modelos.MULA):
		print("[modelos] mula.glb carregada")
	screams.setup(player, hud, bradador, mode == "")
	screams.audio = audio
	audio.setup(player, screams)
	eventos.setup(player, screams, audio, mula, hud)
	eventos.enabled = (mode == "" or mode == "auto")
	hud.apply_config()
	player.interact_hint.connect(hud.show_interact)
	if mode == "shot" and shot_mula > -999.0:
		mula.player = player
		mula.s_m = shot_s + shot_mula
		mula.dir = -1.0
		mula.visible = true
		mula._update_pose(0.0)
	if mode == "shot":
		screams.enabled = false
		screams.stage = shot_stage
		screams._axis = 1.0
		screams._place_bradador()
	screams.player_died.connect(_on_died)
	screams.log_line.connect(func(t: String) -> void: print("[game] ", t))

	church_door.body_entered.connect(_on_door)
	player.oil_changed.connect(func(v: float) -> void: hud.set_status(v, player.lantern_on))
	hud.set_status(player.oil, true)

	if mode == "":
		menu = Menu.new()
		add_child(menu)
		menu.options_changed.connect(_on_options)
		menu.restart_requested.connect(_restart)

	if mode == "selftest":
		Engine.time_scale = 8.0
		screams.forced_results = [true, true, false, false, false, false]
		screams.interval_range = Vector2(1.0, 1.0)
		screams._timer = 1.0
	elif mode == "walk":
		Engine.time_scale = 8.0
		screams.enabled = false
		Input.action_press("move_forward")
	elif mode == "escape":
		Engine.time_scale = 8.0
		screams.enabled = false
	elif mode == "mula":
		Engine.time_scale = 8.0
		_setup_mula_test(mula_case)
	elif mode == "auto":
		Engine.time_scale = 6.0
		Input.action_press("shout")   # responde a todos os gritos (segurando R)


func _setup_input() -> void:
	var map := {
		"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"lantern": [KEY_F], "shout": [KEY_R], "threshold_down": [KEY_BRACKETLEFT],
		"threshold_up": [KEY_BRACKETRIGHT], "restart": [KEY_ENTER],
		"sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C], "interact": [KEY_E],
	}
	for action: String in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key: int in map[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key as Key
				InputMap.action_add_event(action, ev)


func _on_options() -> void:
	Config.apply(self)
	hud.apply_config()
	screams.mic_threshold = Config.mic_threshold


func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _on_died() -> void:
	finished = true
	print("[game] DEAD")
	await get_tree().create_timer(1.4, true, false, true).timeout
	hud.end_screen("O Bradador te achou.", "Ele não ouviu a resposta.", Color(0.05, 0, 0, 0.92))


func _on_door(body: Node3D) -> void:
	if body != player or finished:
		return
	finished = true
	screams.enabled = false
	player.frozen = true
	print("[game] WIN at z=%.1f y=%.2f (rua %.2f)" % [player.global_position.z, player.global_position.y, Route.ground_near(player.global_position)])
	hud.end_screen("Amanheceu.", "(por enquanto)", Color(0.9, 0.8, 0.55, 0.85))


## Teste da Mula: "rua" (deve morrer), "refugio" (lampião apagado: salvo), "refugio_aceso" (penalidade).
func _setup_mula_test(case_name: String) -> void:
	screams.enabled = false
	if case_name == "rua":
		_place_player(100.0, 0.0, 0.0)
		player.lantern_on = false
	else:
		var refuge := get_tree().get_first_node_in_group("refugio") as Area3D
		player.global_position = refuge.global_position - Vector3(0, 1.2, 0)
		player.lantern_on = (case_name == "refugio_aceso")
	await get_tree().create_timer(0.5, true, false, true).timeout
	print("[mula-teste] caso=%s jogador s=%.0f refugios=%d luz=%s" % [case_name, Route.nearest_s(player.global_position), mula.refuge_count, str(player.is_lantern_lit())])
	eventos.start_mula(true)


func _place_player(s: float, yaw_deg: float, pitch_deg: float) -> void:
	var t := Route.tangent(s)
	player.global_position = Route.pos(s) + Vector3(0, 0.25, 0)
	player.rotation.y = atan2(-t.x, -t.z) + deg_to_rad(yaw_deg)
	player.cam.rotation.x = deg_to_rad(pitch_deg)


func _process(delta: float) -> void:
	_t += delta
	if finished and Input.is_action_just_pressed("restart"):
		_restart()
	hud.set_fear(audio.fear, audio.get_bpm())
	hud.set_stamina(player.stamina / Player.STAMINA_MAX, player.exhausted)
	var env := ($Vila/Ambiente as WorldEnvironment).environment
	env.fog_density = lerpf(env.fog_density, 0.030 + 0.022 * audio.fear, clampf(delta * 2.0, 0.0, 1.0))
	_frames += 1
	if mode == "shot":
		if _frames == _shot_frames:
			print("[perf] chamadas de desenho=%d objetos=%d triangulos=%d" % [
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
			get_viewport().get_texture().get_image().save_png(shot_path)
			print("[shot] saved ", shot_path)
			get_tree().quit()
	elif mode == "walk":
		_walk_bot()
	elif mode == "escape":
		_escape_test(delta)
	elif mode == "auto":
		if _t > 420.0 or finished:
			print("[auto] fim: t=%.0f morreu=%s stage=%d" % [_t, str(finished), screams.stage])
			get_tree().quit()
	elif mode == "mula":
		if _t > 40.0 or finished:
			print("[mula-teste] fim: morreu=%s stage=%d" % [str(finished), screams.stage])
			get_tree().quit()
	elif mode == "selftest" and finished:
		await get_tree().create_timer(0.3, true, false, true).timeout
		get_tree().quit()


## Robô que segue a rota (testa subida, curvas e colisões).
func _walk_bot() -> void:
	var s_p := Route.nearest_s(player.global_position)
	var tgt := Route.pos(minf(s_p + 3.0, Route.length()))
	var d := tgt - player.global_position
	d.y = 0.0
	if d.length() > 0.05:
		player.rotation.y = atan2(-d.x, -d.z)
	if int(_t) != int(_t - get_process_delta_time()) and int(_t) % 10 == 0:
		print("[walk] t=%.0f s=%.1f desvio=%.2f y=%.2f rua=%.2f" % [_t, s_p, Route.dist_to_center(player.global_position), player.global_position.y, Route.ground_near(player.global_position)])
	if finished:
		await get_tree().create_timer(0.3, true, false, true).timeout
		get_tree().quit()
	elif _t > 400.0:
		print("[walk] TIMEOUT s=%.1f" % s_p)
		get_tree().quit()


var _esc_i := 0
var _esc_t := 0.0
var _esc_worst := 0.0
var _esc_leaks: Array[String] = []

## Para cada ponto da rua, anda para a esquerda e para a direita; não pode sair do corredor.
func _escape_test(delta: float) -> void:
	var points: Array[float] = [12.0, 30.0, 50.0, 70.0, 95.0, 120.0, 150.0, 165.0, 200.0, 225.0, 250.0, 275.0, 290.0, 310.0, 330.0]
	var total := points.size() * 2
	if _esc_i >= total:
		print("[escape] pior distancia=%.1f m | vazamentos=%d %s" % [_esc_worst, _esc_leaks.size(), str(_esc_leaks)])
		get_tree().quit()
		return
	var s := points[_esc_i / 2]
	var sigma := -1.0 if _esc_i % 2 == 0 else 1.0
	if _esc_t == 0.0:
		var r := Route.right(s)
		player.global_position = Route.pos(s) + Vector3(0, 0.3, 0)
		player.velocity = Vector3.ZERO
		var dirv := r * sigma
		player.rotation.y = atan2(-dirv.x, -dirv.z)
		player.cam.rotation.x = 0.0
		Input.action_press("move_forward")
	_esc_t += delta
	if _esc_t > 5.0:
		var dist := Route.dist_to_center(player.global_position)
		_esc_worst = maxf(_esc_worst, dist)
		if dist > 23.0:
			_esc_leaks.append("s=%.0f lado=%d dist=%.1f" % [s, int(sigma), dist])
		Input.action_release("move_forward")
		_esc_t = 0.0
		_esc_i += 1
