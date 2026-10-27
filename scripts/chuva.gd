class_name Chuva
extends Node3D
## Chuva: partículas que seguem o jogador + som. Ligada/desligada pela opção "Chuva" (Config.chuva).
## Dentro das casas (Missao.dentro != "") a chuva some e o som fica abafado.

var player: Player
var _gotas: CPUParticles3D
var _som: AudioStreamPlayer


func _ready() -> void:
	_gotas = CPUParticles3D.new()
	_gotas.amount = 3600
	_gotas.lifetime = 0.8
	_gotas.local_coords = false
	_gotas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_gotas.emission_box_extents = Vector3(14, 0.5, 14)
	_gotas.direction = Vector3(0.12, -1, 0.05)
	_gotas.spread = 3.0
	_gotas.initial_velocity_min = 17.0
	_gotas.initial_velocity_max = 21.0
	_gotas.gravity = Vector3.ZERO
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.72, 0.8, 0.95, 0.28)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	q.material = m
	_gotas.mesh = q
	add_child(_gotas)
	_som = AudioStreamPlayer.new()
	_som.stream = Synth.rain()
	_som.bus = "Ambiente"
	_som.volume_db = -16.0
	add_child(_som)
	set_ligada(Config.chuva)


func set_ligada(on: bool) -> void:
	_gotas.emitting = on
	if on and not _som.playing:
		_som.play()
	elif not on:
		_som.stop()


func _process(_delta: float) -> void:
	if player == null:
		return
	var dentro := false
	var m := get_tree().get_first_node_in_group("missao")
	if m != null:
		dentro = str(m.get("dentro")) != ""
	global_position = player.global_position + Vector3(0, 9.0, 0)
	_gotas.emitting = Config.chuva and not dentro
	if Config.chuva:
		_som.volume_db = lerpf(_som.volume_db, -30.0 if dentro else -16.0, 0.1)
		if not _som.playing:
			_som.play()
