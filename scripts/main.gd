extends Node3D
## Liga as peças da cena principal. Argumentos de teste (depois de "--"):
##   --selftest       simula respostas certas/erradas até a morte
##   --selftest-walk  anda pela rua inteira até a igreja (sem gritos)
##   --selftest-mula=rua|refugio|refugio_aceso  testa a regra da Mula-sem-cabeça
##   --selftest-becos sobe cada beco em escada (não pode travar)
##   --selftest-itens pega todos os frascos e lê todos os bilhetes (interação com E)
##   --walk-offset=<m> (com --selftest-walk) anda deslocado do centro da rua, para achar paredes invisíveis
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
@onready var missao: Missao = $Missao
@onready var church_door: Area3D = $Vila/Adro/Igreja/Porta
var finished := false
var menu: Menu = null
var mode := ""
var _shot_frames := 20
var _walk_offset := 0.0
var _test_state := 0
var _test_i := 0
var _test_t := 0.0
var _test_fail := 0
var _hint := ""
var _test_seen := false
var _test_oil0 := 0.0
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
	elif "--selftest-becos" in args:
		mode = "becos"
	elif "--selftest-itens" in args:
		mode = "itens"
	elif "--selftest-casas" in args:
		mode = "casas"
	var mula_case := ""
	for a in args:
		if a.begins_with("--selftest-mula="):
			mode = "mula"
			mula_case = a.substr(16)
	for a in args:
		if a.begins_with("--walk-offset="):
			_walk_offset = float(a.substr(14))
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
	add_to_group("jogo")
	missao.modo_teste = mode != "" and mode != "casas"
	missao.setup(player, hud, screams, eventos, ($Vila/Ambiente as WorldEnvironment).environment, mode == "")
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
	elif mode == "casas":
		Engine.time_scale = 1.0
		screams.enabled = false
		_test_casas()
	elif mode == "becos" or mode == "itens":
		Engine.time_scale = 4.0
		screams.enabled = false
		_test_state = 0
	elif mode == "auto":
		Engine.time_scale = 6.0
		Input.action_press("crouch")   # responde a todos os gritos (agachado e parado)


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
	if missao.modo_teste:
		vitoria()
	else:
		missao.tentar_igreja()


func vitoria() -> void:
	if finished:
		return
	finished = true
	screams.enabled = false
	player.frozen = true
	print("[game] WIN at z=%.1f y=%.2f (rua %.2f)" % [player.global_position.z, player.global_position.y, Route.ground_near(player.global_position)])
	hud.end_screen("Amanheceu.", "Os nomes foram lidos. A terra calou.\n(fim da primeira noite)", Color(0.9, 0.8, 0.55, 0.85))


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
	var fog_alvo := 0.004 if missao.dentro != "" else 0.030 + 0.022 * audio.fear
	env.fog_density = lerpf(env.fog_density, fog_alvo, clampf(delta * 2.0, 0.0, 1.0))
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
	elif mode == "becos":
		_test_becos(delta)
	elif mode == "itens":
		_test_itens(delta)
	elif mode == "mula":
		if _t > 40.0 or finished:
			print("[mula-teste] fim: morreu=%s stage=%d" % [str(finished), screams.stage])
			get_tree().quit()
	elif mode == "selftest" and finished:
		await get_tree().create_timer(0.3, true, false, true).timeout
		get_tree().quit()


## Teste das casas: entra em cada porta, confere o chão, pega os itens, sai, cumpre a trama e vence na igreja.
func _test_casas() -> void:
	eventos.enabled = false
	await get_tree().create_timer(0.6, true, false, true).timeout
	var falhas := 0
	var portas: Array = get_tree().get_nodes_in_group("interagivel").filter(func(n: Node) -> bool: return n is Porta and str((n as Porta).destino) != "")
	portas.sort_custom(func(a: Porta, b: Porta) -> bool: return str(a.requer) != "" and str(b.requer) == "")      # a porta trancada primeiro
	print("[casas] portas na rua: %d" % portas.size())
	var space := get_viewport().world_3d.direct_space_state
	var vistos := {}
	for p: Porta in portas:
		var pid: String = p.destino
		var out: Vector3 = -(p.get_parent() as Node3D).global_transform.basis.x
		var pe := p.global_position + out * 1.0
		var qg := PhysicsRayQueryParameters3D.create(pe + Vector3(0, 2.0, 0), pe - Vector3(0, 4.0, 0))
		qg.exclude = [player.get_rid()]
		var hg := space.intersect_ray(qg)
		if not hg.is_empty():
			pe.y = (hg["position"] as Vector3).y + 0.05
		player.global_position = pe
		player.velocity = Vector3.ZERO
		var d := p.global_position - player.cam.global_position
		player.rotation.y = atan2(-d.x, -d.z)
		player.cam.rotation.x = 0.0
		_hint = ""
		player.interact_hint.connect(func(t: String) -> void: _hint = t, CONNECT_ONE_SHOT)
		await get_tree().create_timer(0.5, true, false, true).timeout
		var aviso_ok := _hint.contains("Entrar")
		if str(p.requer) != "" and not missao.tem(str(p.requer)):
			_press_interact()
			await get_tree().create_timer(0.4, true, false, true).timeout
			var ficou_fora := missao.dentro == ""
			print("[casas] %s trancada sem %s: ficou fora=%s -> %s" % [pid, str(p.requer), str(ficou_fora), "OK" if ficou_fora else "FALHOU"])
			if not ficou_fora:
				falhas += 1
				missao.sair()
			missao.inv[str(p.requer)] = true
			await get_tree().create_timer(1.1, true, false, true).timeout
		_press_interact()
		await get_tree().create_timer(0.6, true, false, true).timeout
		if missao.dentro != pid:
			print("[casas]   DEBUG %s: alvo=%s dentro=%s frozen=%s pos=%s" % [pid, str(player._target), missao.dentro, str(player.frozen), str(player.global_position)])
		var dentro_ok := missao.dentro == pid
		var sala := get_node("Vila/Interiores/" + pid) as Node3D
		var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 0.5, 0), player.global_position - Vector3(0, 2.0, 0))
		q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		var chao_ok := (not hit.is_empty()) and absf((hit["position"] as Vector3).y - sala.global_position.y) < 0.35
		# itens da sala: nenhum dentro de móvel; pegar todos
		var embutidos := 0
		var pegos := 0
		for it in sala.get_children():
			if it is Area3D and it.is_in_group("interagivel") and not (it is Porta):
				var pq := PhysicsPointQueryParameters3D.new()
				pq.position = (it as Node3D).global_position + Vector3(0, 0.1, 0)
				pq.collide_with_areas = false
				if space.intersect_point(pq, 1).size() > 0:
					embutidos += 1
					print("[casas]   item dentro de móvel: %s em %s" % [it.name, pid])
				it.call("interagir", player)
				pegos += 1
				if hud.note_open():
					hud.hide_note()
					player.frozen = false
		await get_tree().create_timer(0.3, true, false, true).timeout
		var obj_ok := missao.objetivo() != ""
		print("[casas] %s: aviso=%s dentro=%s chao=%s itens=%d embutidos=%d -> %s" % [pid, str(aviso_ok), str(dentro_ok), str(chao_ok), pegos, embutidos, "OK" if (aviso_ok and dentro_ok and chao_ok and embutidos == 0 and obj_ok) else "FALHOU"])
		if not (aviso_ok and dentro_ok and chao_ok and embutidos == 0):
			falhas += 1
		vistos[pid] = true
		player.frozen = false
		missao.sair()
		await get_tree().create_timer(1.1, true, false, true).timeout
		if missao.dentro != "":
			falhas += 1
	var completo := missao.completo()
	print("[casas] trama completa (livro + chave da igreja): %s" % str(completo))
	if not completo:
		falhas += 1
	# vitória pela igreja
	_place_player(Route.CHURCH_S - 4.0, 0.0, 0.0)
	missao.tentar_igreja()
	await get_tree().create_timer(0.8, true, false, true).timeout
	var igreja_ok := missao.dentro == "igreja"
	print("[casas] igreja destrancada e interior carregado: %s" % str(igreja_ok))
	if not igreja_ok:
		falhas += 1
	else:
		var altar := get_node("Vila/Interiores/igreja/Altar") as Altar
		altar.interagir(player)
		await get_tree().create_timer(0.4, true, false, true).timeout
		if not finished:
			falhas += 1
	print("[casas] RESULTADO: salas=%d falhas=%d" % [vistos.size(), falhas])
	get_tree().quit()


## Robô que segue a rota (testa subida, curvas e colisões).
func _walk_bot() -> void:
	var s_p := Route.nearest_s(player.global_position)
	var s_t := minf(s_p + 3.0, Route.length())
	var tgt := Route.pos(s_t) + Route.right(s_t) * clampf(_walk_offset, -Route.width(s_t) * 0.5 + 0.5, Route.width(s_t) * 0.5 - 0.5)
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
		var why := ""
		for i in player.get_slide_collision_count():
			var col := player.get_slide_collision(i)
			var cn := col.get_collider() as Node
			why += " [%s/%s em %s n=%s]" % [cn.get_parent().name if cn else "?", cn.name if cn else "?", str((cn as Node3D).global_position) if cn is Node3D else "", str(col.get_normal())]
		print("[walk] TIMEOUT s=%.1f pos=%s%s" % [s_p, str(player.global_position), why])
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


## Sobe cada beco: coloca o jogador na rua, de frente para a entrada, anda 16 s e confere se chegou ao topo.
func _test_becos(delta: float) -> void:
	var refs := get_tree().get_nodes_in_group("refugio")
	if _test_i >= refs.size():
		print("[becos] testados=%d falhas=%d" % [refs.size(), _test_fail])
		get_tree().quit()
		return
	var area := refs[_test_i] as Area3D
	var beco := area.get_parent() as Node3D
	var x_axis := beco.global_transform.basis.x      # para dentro do beco
	if _test_t == 0.0:
		var start := beco.global_position - x_axis * 2.2 + Vector3(0, 0.4, 0)
		player.global_position = start
		player.velocity = Vector3.ZERO
		player.rotation.y = atan2(-x_axis.x, -x_axis.z)
		player.cam.rotation.x = 0.0
		Input.action_press("move_forward")
		_hint = str(start.y)
	_test_t += delta
	if _test_t > 12.0:
		Input.action_release("move_forward")
		var along := (player.global_position - beco.global_position).dot(x_axis)
		var rise := player.global_position.y - float(_hint)
		var ok := along > 12.0 and rise > 4.0
		var why := ""
		for i in player.get_slide_collision_count():
			var col := player.get_slide_collision(i)
			var cn := col.get_collider() as Node
			why += " [%s/%s n=%s]" % [cn.get_parent().name if cn else "?", cn.name if cn else "?", str(col.get_normal())]
		print("[becos] %s: avançou %.1f m, subiu %.1f m -> %s%s" % [beco.name, along, rise, "OK" if ok else "TRAVOU", why if not ok else ""])
		if not ok:
			_test_fail += 1
		_test_t = 0.0
		_test_i += 1


## Pega todos os frascos e lê todos os bilhetes pelo caminho real (raycast + tecla E).
var _test_items: Array = []


func _press_interact() -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)


func _test_itens(delta: float) -> void:
	if _test_state == 0:
		_test_items = get_tree().get_nodes_in_group("interagivel").filter(func(n: Node) -> bool: return n is Coletavel and not str(n.get_path()).contains("Interiores"))
		player.oil = 60.0
		player.interact_hint.connect(func(t: String) -> void: _hint = t)
		_test_state = 1
		return
	if _test_i >= _test_items.size():
		print("[itens] testados=%d falhas=%d" % [_test_items.size(), _test_fail])
		get_tree().quit()
		return
	var it := _test_items[_test_i] as Area3D
	_test_t += delta
	match _test_state:
		1:  # em frente ao item, a 1,3 m, olhando para ele
			var s := Route.nearest_s(it.global_position)
			var to_street := Route.pos(s) - it.global_position
			to_street.y = 0.0
			var from := it.global_position + to_street.normalized() * 1.3
			player.global_position = Vector3(from.x, it.global_position.y + 0.05, from.z)
			player.velocity = Vector3.ZERO
			var d := it.global_position + Vector3(0, 0.3, 0) - player.cam.global_position
			player.rotation.y = atan2(-d.x, -d.z)
			player.cam.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
			_hint = ""
			_test_t = 0.0
			_test_state = 2
		2:  # espera a física, confere o aviso [E] e aperta E
			if _test_t > 0.5:
				var expected := "Pegar" if it.get("tipo") == "oleo" else "Ler"
				_test_seen = _hint.contains(expected)
				_test_oil0 = player.oil
				_press_interact()
				_test_t = 0.0
				_test_state = 3
		3:  # confere o efeito
			if _test_t > 0.3:
				var ok := false
				if it.get("tipo") == "oleo":
					ok = _test_seen and (not it.visible) and player.oil > _test_oil0 + 20.0
					print("[itens] %s: aviso=%s oleo %.0f -> %.0f visivel=%s -> %s" % [it.name, str(_test_seen), _test_oil0, player.oil, str(it.visible), "OK" if ok else "FALHOU"])
					player.oil = 40.0
					if not ok:
						_test_fail += 1
					_test_i += 1
					_test_state = 1
				else:
					ok = _test_seen and player.frozen and hud.note_open()
					print("[itens] %s: aviso=%s bilhete aberto=%s congelado=%s -> %s" % [it.name, str(_test_seen), str(hud.note_open()), str(player.frozen), "OK" if ok else "FALHOU"])
					if not ok:
						_test_fail += 1
					_press_interact()      # E fecha o bilhete
					_test_state = 4
				_test_t = 0.0
		4:
			if _test_t > 0.3:
				if hud.note_open() or player.frozen:
					print("[itens] %s: NAO FECHOU o bilhete com E" % it.name)
					_test_fail += 1
					hud.hide_note()
					player.frozen = false
				_test_i += 1
				_test_t = 0.0
				_test_state = 1
