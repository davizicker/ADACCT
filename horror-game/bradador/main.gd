extends Node3D
## Monta o jogo inteiro por código. Argumentos de teste (depois de "--"):
##   --selftest       simula respostas certas/erradas até a morte
##   --selftest-walk  anda pela rua inteira até a igreja (sem gritos)
##   --shot=<arquivo.png> [--shot-z=<z>] [--shot-stage=<n>]  salva um print e sai

var player: Player
var hud: Hud
var screams: ScreamSystem
var world: World
var finished := false
var mode := ""
var shot_path := ""
var _t := 0.0
var _frames := 0


func _ready() -> void:
	_setup_input()
	var args := OS.get_cmdline_user_args()
	if "--selftest" in args:
		mode = "selftest"
	elif "--selftest-walk" in args:
		mode = "walk"
	var shot_z := -2.0
	var shot_stage := 0
	for a in args:
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
			mode = "shot"
		elif a.begins_with("--shot-z="):
			shot_z = float(a.substr(9))
		elif a.begins_with("--shot-stage="):
			shot_stage = int(a.substr(13))

	world = World.new()
	add_child(world)
	world.build()

	player = Player.new()
	add_child(player)
	player.position = Vector3(0, World.ground_y(shot_z) + 0.2, shot_z)

	hud = Hud.new()
	add_child(hud)

	screams = ScreamSystem.new()
	add_child(screams)
	screams.setup(player, hud, mode == "")
	if mode == "shot":
		screams.enabled = false
		screams.stage = shot_stage
		screams._axis = -1.0
		screams._place_bradador()
		player.rotation.y = 0.0
	screams.player_died.connect(_on_died)
	screams.log_line.connect(func(t: String) -> void: print("[game] ", t))

	world.church_door.body_entered.connect(_on_door)
	player.oil_changed.connect(func(v: float) -> void: hud.set_status(v, player.lantern_on))
	hud.set_status(player.oil, true)

	_add_ambience()

	if mode == "selftest":
		Engine.time_scale = 8.0
		screams.forced_results = [true, true, false, false, false, false]
		screams.interval_range = Vector2(1.0, 1.0)
		screams._timer = 1.0
	elif mode == "walk":
		Engine.time_scale = 8.0
		screams.enabled = false
		Input.action_press("move_forward")


func _setup_input() -> void:
	var map := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"lantern": KEY_F, "shout": KEY_R, "threshold_down": KEY_BRACKETLEFT,
		"threshold_up": KEY_BRACKETRIGHT, "restart": KEY_ENTER,
	}
	for action: String in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = map[action]
		InputMap.action_add_event(action, ev)


func _add_ambience() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = Synth.wind()
	wind.volume_db = -14.0
	add_child(wind)
	wind.play()
	var bell := AudioStreamPlayer3D.new()
	bell.stream = Synth.bell()
	bell.position = Vector3(0, 40, -World.STREET_LEN)
	bell.unit_size = 40.0
	bell.volume_db = -4.0
	bell.name = "Bell"
	add_child(bell)


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
	print("[game] WIN at z=%.1f y=%.2f (ground %.2f)" % [player.global_position.z, player.global_position.y, World.ground_y(player.global_position.z)])
	hud.end_screen("Amanheceu.", "(por enquanto)", Color(0.9, 0.8, 0.55, 0.85))


func _process(delta: float) -> void:
	_t += delta
	if int(_t) != int(_t - delta) and int(_t) % 30 == 15:
		var bell := get_node_or_null("Bell") as AudioStreamPlayer3D
		if bell:
			bell.play()
	if finished and Input.is_action_just_pressed("restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
	_frames += 1
	if mode == "shot" and _frames == 15:
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("[shot] saved ", shot_path)
		get_tree().quit()
	elif mode != "" and mode != "shot":
		_selftest_tick()


func _selftest_tick() -> void:
	if mode == "walk" and int(_t) != int(_t - get_process_delta_time()) and int(_t) % 3 == 0:
		print("[walk] t=%.0f z=%.1f y=%.2f ground=%.2f" % [_t, player.global_position.z, player.global_position.y, World.ground_y(player.global_position.z)])
	if finished:
		await get_tree().create_timer(0.3, true, false, true).timeout
		get_tree().quit()
