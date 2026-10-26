class_name Player
extends CharacterBody3D
## Jogador em primeira pessoa com lampião de óleo.

signal oil_changed(value: float)

const WALK_SPEED := 2.8
const GRAVITY := 20.0
const MOUSE_SENS := 0.0025
const OIL_MAX := 180.0

var oil := OIL_MAX
var lantern_on := true
var frozen := false
## 0 quando parado, WALK_SPEED quando andando (usado pela regra "pare e responda")
var move_speed := 0.0

var _blackout_t := 0.0
var _shake_t := 0.0
var _shake_amp := 0.0
var _base_energy := 1.7

# Os nós abaixo existem em scenes/player.tscn: edite-os no editor (FOV, luz, cápsula...).
@onready var cam: Camera3D = $Camera
@onready var lantern: OmniLight3D = $Camera/Lampiao


func _ready() -> void:
	_base_energy = lantern.light_energy  # a intensidade vem da cena
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not frozen:
		rotate_y(-event.relative.x * MOUSE_SENS)
		cam.rotation.x = clampf(cam.rotation.x - event.relative.y * MOUSE_SENS, -1.4, 1.4)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("lantern"):
		lantern_on = not lantern_on


func blackout(seconds: float) -> void:
	_blackout_t = seconds


func shake(amount: float, seconds: float) -> void:
	_shake_amp = amount
	_shake_t = seconds


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO if frozen else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	velocity.x = dir.x * WALK_SPEED
	velocity.z = dir.z * WALK_SPEED
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_speed = input.length() * WALK_SPEED
	move_and_slide()


func _process(delta: float) -> void:
	if lantern_on and oil > 0.0:
		oil = maxf(0.0, oil - delta)
		oil_changed.emit(oil)
	_blackout_t = maxf(0.0, _blackout_t - delta)
	var lit := lantern_on and oil > 0.0 and _blackout_t <= 0.0
	if lit:
		var flicker := 0.88 + 0.12 * randf()
		var low_oil := clampf(oil / 25.0, 0.0, 1.0)
		if low_oil < 1.0 and randf() < 0.08:
			flicker *= 0.3
		lantern.light_energy = _base_energy * flicker * (0.4 + 0.6 * low_oil)
	else:
		lantern.light_energy = 0.0
	if _shake_t > 0.0:
		_shake_t -= delta
		var a := _shake_amp * clampf(_shake_t, 0.0, 1.0)
		cam.h_offset = randf_range(-a, a)
		cam.v_offset = randf_range(-a, a)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
