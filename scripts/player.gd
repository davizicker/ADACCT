class_name Player
extends CharacterBody3D
## Jogador em primeira pessoa: lampião, corrida com fôlego, agachar, balanço de câmera,
## passos (som) e interação com objetos (tecla E).

signal oil_changed(value: float)
signal footstep(loudness: float)
signal interact_hint(text: String)

const WALK_SPEED := 2.8
const SPRINT_SPEED := 4.8
const CROUCH_SPEED := 1.4
const GRAVITY := 20.0
const ACEL_CHAO := 18.0      # m/s²: chega na velocidade de andar em ~0,15 s (antes era instantâneo, parecia robô)
const FREIO_CHAO := 24.0
const ACEL_AR := 4.0         # no ar quase não dá para mudar de direção
const PASSO_MAX := 0.22      # sobe sozinho meio-fio, soleira e degrau até 22 cm (a cápsula sozinha só subia ~12 cm e enroscava)
const JUMP_V := 3.3          # pulinho: ~27 cm de altura (v² / 2g)
const OIL_MAX := 180.0
const STAND_H := 1.6
const CROUCH_H := 1.05
const STAMINA_MAX := 100.0
const BASE_FOV := 75.0

var oil := OIL_MAX
var lantern_on := true
var frozen := false
## escondido num Esconderijo: lanterna apagada, parado, invisível para o Bradador
var hidden := false
## velocidade horizontal real (m/s): usada pela regra "pare e responda"
var move_speed := 0.0
var stamina := STAMINA_MAX
var exhausted := false
var sprinting := false
var crouching := false
## medo 0..1 (vem do diretor de áudio): faz o lampião tremer mais
var fear := 0.0
## 0 = silencioso, 1 = barulhento (passos); outros sistemas podem consultar
var noise := 0.0

var _ultimo_chao := Vector3.ZERO      # último ponto firme visitado (para resgatar se cair do mundo)
var _t_chao := 0.0
var _blackout_t := 0.0
var _shake_t := 0.0
var _shake_amp := 0.0
var _base_energy := 1.7
var _lantern_home := Vector3.ZERO
var _bracos: Node3D = null
var _corpo_sombra: MeshInstance3D = null
var _lantern_glass: StandardMaterial3D = null
var _lantern_rot := Vector3.ZERO
var _bob_phase := 0.0
var _last_step_sign := 1.0
var _estava_no_chao := true
var _t_ar := 0.0
var _target: Node = null
var _t := 0.0

# Os nós abaixo existem em scenes/jogador.tscn: edite-os no editor (FOV, luz, cápsula...).
@onready var cam: Camera3D = $Camera
@onready var lantern: OmniLight3D = $Camera/Lampiao
@onready var body_shape: CollisionShape3D = $Colisao
@onready var lantern_model: Node3D = get_node_or_null("Camera/LanternaModelo") as Node3D


func _ready() -> void:
	add_to_group("jogador")
	_base_energy = lantern.light_energy  # a intensidade vem da cena
	lantern.light_volumetric_fog_energy = 2.2    # o facho da lanterna aparece na neblina
	if lantern_model != null:
		_lantern_home = lantern_model.position
		_lantern_rot = lantern_model.rotation
		cam.near = 0.03     # a lanterna fica colada na câmera: não pode ser cortada
		# braços em primeira pessoa (FPS ARMS RIG): a mão direita segura a lanterna (scripts/bracos.gd)
		if ResourceLoader.exists("res://assets/models/arms/fps_arms.glb"):
			_bracos = (load("res://scripts/bracos.gd") as GDScript).new() as Node3D
			_bracos.name = "Bracos"
			_bracos.set("lanterna", lantern_model)
			cam.add_child(_bracos)
	# sombras: a lanterna projeta sombra dos objetos (inclusive do corpo do jogador, que aparece nas paredes atrás dele) e a Lua também.
	# Os modelos presos à câmera (braços, lanterna) NÃO projetam sombra: a lanterna fica dentro da própria malha e se apagaria.
	for n in cam.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lantern.shadow_enabled = true
	lantern.shadow_bias = 0.06
	lantern.shadow_blur = 1.6
	_corpo_sombra = MeshInstance3D.new()
	_corpo_sombra.name = "CorpoSombra"
	var cm := CapsuleMesh.new()
	cm.radius = 0.26
	cm.height = 1.62
	_corpo_sombra.mesh = cm
	_corpo_sombra.position = Vector3(0.0, 0.81, 0.0)
	_corpo_sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY      # só a sombra existe (o corpo é invisível em 1ª pessoa)
	_corpo_sombra.layers = 3                                                                 # camadas 1 e 2: a Lua (rua) e as luzes das salas enxergam
	add_child(_corpo_sombra)
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if body_shape.shape is CapsuleShape3D:
		body_shape.shape = (body_shape.shape as CapsuleShape3D).duplicate()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not frozen:
		rotate_y(-event.relative.x * Config.mouse_sens)
		cam.rotation.x = clampf(cam.rotation.x - event.relative.y * Config.mouse_sens, -1.4, 1.4)
	elif event.is_action_pressed("lantern") and not frozen:
		lantern_on = not lantern_on
	elif event.is_action_pressed("interact") and not frozen and _target != null and _target.has_method("interagir"):
		_target.call("interagir", self)


func blackout(seconds: float) -> void:
	_blackout_t = seconds


func shake(amount: float, seconds: float) -> void:
	_shake_amp = amount
	_shake_t = seconds


func is_lantern_lit() -> bool:
	return lantern_on and oil > 0.0 and _blackout_t <= 0.0


## Degrau: se o caminho à frente está fechado embaixo mas livre 22 cm acima, e lá tem chão plano, sobe o corpo
## (a câmera sobe suave). Paredes, muretas contra o vazio e móveis altos continuam bloqueando.
func _subir_degrau(delta: float) -> void:
	var mov := Vector3(velocity.x, 0.0, velocity.z) * delta
	if mov.length() < 0.002:
		return
	var xf := global_transform
	if not test_move(xf, mov):
		return
	var cima := Vector3(0.0, PASSO_MAX, 0.0)
	if test_move(xf, cima):
		return
	var adiante := mov.normalized() * maxf(mov.length(), 0.10)
	var xf2 := xf.translated(cima)
	if test_move(xf2, adiante):
		return
	xf2 = xf2.translated(adiante)
	var col := KinematicCollision3D.new()
	if not test_move(xf2, Vector3(0.0, -PASSO_MAX - 0.05, 0.0), col):
		return
	if col.get_normal().y < 0.75:
		return
	var subida := PASSO_MAX - col.get_travel().length()
	if subida < 0.03 or subida > PASSO_MAX:
		return
	global_position.y += subida + 0.004
	cam.position.y -= subida            # o corpo subiu de uma vez; a câmera acompanha suave


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO if frozen else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	crouching = (Input.is_action_pressed("crouch") and not frozen)
	var wants_sprint := Input.is_action_pressed("sprint") and input.y < -0.1 and not crouching and not frozen
	if exhausted and stamina > 30.0:
		exhausted = false
	sprinting = wants_sprint and stamina > 0.0 and not exhausted
	var speed := CROUCH_SPEED if crouching else (SPRINT_SPEED if sprinting else WALK_SPEED)
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	var no_chao := is_on_floor()
	var horiz := Vector2(velocity.x, velocity.z)
	var alvo := Vector2(dir.x, dir.z) * speed
	var taxa := (ACEL_CHAO if alvo.length() > 0.01 else FREIO_CHAO) if no_chao else ACEL_AR
	horiz = horiz.move_toward(alvo, taxa * delta)
	velocity.x = horiz.x
	velocity.z = horiz.y
	if no_chao:
		velocity.y = 0.0
		if Input.is_action_just_pressed("jump") and not frozen and not crouching and not hidden:
			velocity.y = JUMP_V
			footstep.emit(0.9)                # o salto faz barulho no chão de pedra
	else:
		velocity.y -= GRAVITY * delta
	if no_chao and not hidden and velocity.y <= 0.0:
		_subir_degrau(delta)
	move_and_slide()
	if is_on_floor() and not _estava_no_chao and _t_ar > 0.18:
		footstep.emit(1.0)                    # aterrissagem
	_t_ar = 0.0 if is_on_floor() else _t_ar + delta
	_estava_no_chao = is_on_floor()
	var real := get_real_velocity()
	move_speed = Vector2(real.x, real.z).length()
	_resgate_de_queda(delta)

	# fôlego
	if sprinting and move_speed > 1.0:
		stamina = maxf(0.0, stamina - 24.0 * delta)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(STAMINA_MAX, stamina + (10.0 if exhausted else 18.0) * delta)
	noise = 0.0 if move_speed < 0.3 else (0.25 if crouching else (1.0 if sprinting else 0.55))

	# ciclo de passos e balanço
	if move_speed > 0.3:
		_bob_phase += delta * move_speed * 2.3
		var s := signf(sin(_bob_phase))
		if s != _last_step_sign and s != 0.0:
			_last_step_sign = s
			footstep.emit(noise)
	_update_camera(delta)
	_update_interaction()


## Rede de segurança: se um buraco do terreno, um beco ou um objeto jogar o jogador para fora do mundo, ele volta ao último chão firme
## (em vez de cair para sempre e travar a partida).
func _resgate_de_queda(delta: float) -> void:
	var m := get_tree().get_first_node_in_group("missao")
	if hidden or frozen:
		_t_chao = 0.0                        # escondido/parado: a posição é controlada pelo esconderijo, não cai
		return
	if m != null and str(m.get("dentro")) != "":
		_ultimo_chao = Vector3.ZERO          # os interiores ficam longe e abaixo do mapa: nada de resgate lá dentro
		_t_chao = 0.0
		return
	if is_on_floor():
		_t_chao += delta
		if _t_chao > 0.4:
			_t_chao = 0.0
			_ultimo_chao = global_position
	elif _ultimo_chao != Vector3.ZERO and (global_position.y < _ultimo_chao.y - 14.0):
		global_position = _ultimo_chao + Vector3(0, 0.3, 0)
		velocity = Vector3.ZERO
	elif global_position.y < -80.0:
		global_position = Route.pos(0.0) + Vector3(0, 1.0, 0)
		velocity = Vector3.ZERO


func _update_camera(delta: float) -> void:
	_t += delta
	var target_h := CROUCH_H if crouching else STAND_H
	var bob_y := 0.0
	var bob_x := 0.0
	if Config.head_bob:
		var amp := 0.045 if sprinting else (0.025 if move_speed > 0.3 else 0.0)
		bob_y = absf(sin(_bob_phase)) * amp - amp * 0.5
		bob_x = cos(_bob_phase) * amp * 0.6
		# respiração em repouso (mais forte quando cansado ou com medo)
		bob_y += sin(_t * (1.4 + fear * 1.2 + (1.0 if exhausted else 0.0))) * (0.004 + 0.006 * fear + (0.006 if exhausted else 0.0))
	cam.position.y = lerpf(cam.position.y, target_h + bob_y, clampf(delta * 10.0, 0.0, 1.0))
	if _corpo_sombra != null:                                   # a sombra acompanha o agachar
		var k := clampf(cam.position.y / STAND_H, 0.55, 1.0)
		_corpo_sombra.scale = Vector3(1.0, k, 1.0)
		_corpo_sombra.position.y = 0.81 * k
		_corpo_sombra.visible = not hidden
	cam.position.x = lerpf(cam.position.x, bob_x, clampf(delta * 8.0, 0.0, 1.0))
	cam.fov = lerpf(cam.fov, Config.campo_visao + (7.0 if sprinting else 0.0) + fear * 3.0, clampf(delta * 6.0, 0.0, 1.0))
	if body_shape.shape is CapsuleShape3D:
		var cap := body_shape.shape as CapsuleShape3D
		var h := 1.1 if crouching else 1.7
		cap.height = lerpf(cap.height, h, clampf(delta * 10.0, 0.0, 1.0))
		body_shape.position.y = cap.height * 0.5


func _update_interaction() -> void:
	var found: Node = null
	if not frozen:
		var from := cam.global_position
		var to := from + (-cam.global_transform.basis.z) * 2.6
		var space := get_world_3d().direct_space_state
		# 1) o gatilho interagível mais próximo no caminho do olhar (só áreas)
		var qa := PhysicsRayQueryParameters3D.create(from, to)
		qa.collide_with_areas = true
		qa.collide_with_bodies = false
		qa.exclude = [get_rid()]
		var ha := space.intersect_ray(qa)
		if not ha.is_empty() and (ha["collider"] as Node).is_in_group("interagivel"):
			found = ha["collider"] as Node
			# 2) uma parede entre você e o gatilho bloqueia; mas um objeto que está DENTRO do próprio gatilho (o carro do
			#    esconderijo) não bloqueia: antes dava para ficar ao lado do carro, dentro da zona, sem a dica [E] aparecer
			var qb := PhysicsRayQueryParameters3D.create(from, ha["position"])
			qb.collide_with_areas = false
			qb.exclude = [get_rid()]
			var hb := space.intersect_ray(qb)
			if not hb.is_empty() and from.distance_to(hb["position"]) < from.distance_to(ha["position"]) - 0.03:
				var qp := PhysicsPointQueryParameters3D.new()
				qp.position = hb["position"]
				qp.collide_with_bodies = false
				qp.collide_with_areas = true
				var dentro := false
				for r in space.intersect_point(qp, 8):
					if r["collider"] == found:
						dentro = true
				if not dentro:
					found = null
		if found == null:
			var q := PhysicsRayQueryParameters3D.create(from, to)
			q.collide_with_areas = true
			q.exclude = [get_rid()]
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				var c := hit["collider"] as Node
				if c != null and c.is_in_group("interagivel"):
					found = c
	if found != _target:
		_target = found
		interact_hint.emit("" if found == null else "[E] %s" % str(found.get("texto_interacao")))


func _process(delta: float) -> void:
	if lantern_on and oil > 0.0:
		oil = maxf(0.0, oil - delta)
		oil_changed.emit(oil)
	_blackout_t = maxf(0.0, _blackout_t - delta)
	if is_lantern_lit():
		var flicker := 0.88 + 0.12 * randf()
		var low_oil := clampf(oil / 25.0, 0.0, 1.0)
		if (low_oil < 1.0 or fear > 0.45) and randf() < 0.08 + 0.12 * fear:
			flicker *= 0.3
		lantern.light_energy = _base_energy * flicker * (0.4 + 0.6 * low_oil)
	else:
		lantern.light_energy = 0.0
	_update_lantern_model(delta, is_lantern_lit())
	if _shake_t > 0.0:
		_shake_t -= delta
		var a := _shake_amp * clampf(_shake_t, 0.0, 1.0)
		cam.h_offset = randf_range(-a, a)
		cam.v_offset = randf_range(-a, a)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


## Lanterna na mão: balança com a caminhada (mais forte ao correr), a chama tremula, apaga com F ou sem querosene.
func _update_lantern_model(delta: float, lit: bool) -> void:
	if lantern_model == null:
		return
	if _bracos != null:
		_bracos.visible = not hidden
	var sway := 0.012 if move_speed > 0.3 else 0.003
	if sprinting:
		sway = 0.028
	var tt := _t * (7.5 if sprinting else 5.0 if move_speed > 0.3 else 1.4)
	var target := _lantern_home + Vector3(cos(tt * 0.5) * sway * 0.6, sin(tt) * sway, 0.0)
	if crouching:
		target.y -= 0.03
	lantern_model.position = lantern_model.position.lerp(target, clampf(delta * 8.0, 0.0, 1.0))
	lantern_model.rotation = _lantern_rot + Vector3(sin(tt * 0.7) * sway * 1.5, 0.0, cos(tt * 0.5) * sway * 2.0)
	var chama := lantern_model.get_node_or_null("Chama") as Node3D
	var halo := lantern_model.get_node_or_null("Halo") as Node3D
	if chama != null:
		chama.visible = lit
		chama.scale = Vector3(1.0, 0.85 + 0.35 * randf(), 1.0)
	if halo != null:
		halo.visible = lit
		halo.scale = Vector3.ONE * (0.9 + 0.2 * randf()) * (0.5 + 0.5 * clampf(oil / 25.0, 0.0, 1.0))
