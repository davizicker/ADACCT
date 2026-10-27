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
const OIL_MAX := 180.0
const STAND_H := 1.6
const CROUCH_H := 1.05
const STAMINA_MAX := 100.0
const BASE_FOV := 75.0

var oil := OIL_MAX
var lantern_on := true
var frozen := false
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

var _blackout_t := 0.0
var _shake_t := 0.0
var _shake_amp := 0.0
var _base_energy := 1.7
var _lantern_home := Vector3.ZERO
var _lantern_glass: StandardMaterial3D = null
var _lantern_rot := Vector3.ZERO
var _bob_phase := 0.0
var _last_step_sign := 1.0
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
	if lantern_model != null:
		_lantern_home = lantern_model.position
		_lantern_rot = lantern_model.rotation
		cam.near = 0.03     # a lanterna fica colada na câmera: não pode ser cortada
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


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO if frozen else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	crouching = (Input.is_action_pressed("crouch") and not frozen)
	var wants_sprint := Input.is_action_pressed("sprint") and input.y < -0.1 and not crouching and not frozen
	if exhausted and stamina > 30.0:
		exhausted = false
	sprinting = wants_sprint and stamina > 0.0 and not exhausted
	var speed := CROUCH_SPEED if crouching else (SPRINT_SPEED if sprinting else WALK_SPEED)
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	var real := get_real_velocity()
	move_speed = Vector2(real.x, real.z).length()

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
	cam.position.x = lerpf(cam.position.x, bob_x, clampf(delta * 8.0, 0.0, 1.0))
	cam.fov = lerpf(cam.fov, BASE_FOV + (7.0 if sprinting else 0.0) + fear * 3.0, clampf(delta * 6.0, 0.0, 1.0))
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
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collide_with_areas = true
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
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
