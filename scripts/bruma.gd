class_name Bruma
extends Node3D
## Bruma rasteira: cartões grandes e macios de névoa que derivam devagar rente ao chão, ao redor do jogador.
## Dá profundidade e "corpo" à neblina (além da neblina do ambiente). Some dentro das casas.

var player: Player
var _p: CPUParticles3D


static func _textura() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _ready() -> void:
	_p = CPUParticles3D.new()
	_p.amount = 56
	_p.lifetime = 16.0
	_p.preprocess = 16.0
	_p.local_coords = false
	_p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_p.emission_box_extents = Vector3(30, 0.4, 30)
	_p.direction = Vector3(1, 0, 0.3)
	_p.spread = 60.0
	_p.initial_velocity_min = 0.15
	_p.initial_velocity_max = 0.5
	_p.gravity = Vector3.ZERO
	_p.scale_amount_min = 4.0
	_p.scale_amount_max = 8.0
	var rampa := Gradient.new()
	rampa.set_color(0, Color(1, 1, 1, 0))
	rampa.add_point(0.25, Color(1, 1, 1, 1))
	rampa.add_point(0.75, Color(1, 1, 1, 1))
	rampa.set_color(rampa.get_point_count() - 1, Color(1, 1, 1, 0))
	_p.color_ramp = rampa
	var q := QuadMesh.new()
	q.size = Vector2(1, 0.45)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _textura()
	m.albedo_color = Color(0.46, 0.52, 0.66, 0.085)
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.disable_fog = true
	m.no_depth_test = false
	q.material = m
	_p.mesh = q
	add_child(_p)


func _process(_delta: float) -> void:
	if player == null:
		return
	var dentro := false
	var mi := get_tree().get_first_node_in_group("missao")
	if mi != null:
		dentro = str(mi.get("dentro")) != ""
	_p.emitting = not dentro
	global_position = player.global_position + Vector3(0, 0.9, 0)
