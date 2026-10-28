class_name Vagalumes
extends Node3D
## Vaga-lumes: pontinhos amarelo-esverdeados que derivam devagar e pulsam, em volta do jogador (seguem o jogador).
## Só aparecem fora das casas (Missao.dentro == ""). Leve: ~70 partículas.

var _p: GPUParticles3D
var _player: Node3D


func _ready() -> void:
	_p = GPUParticles3D.new()
	_p.name = "Particulas"
	_p.amount = 70
	_p.lifetime = 9.0
	_p.local_coords = false
	_p.visibility_aabb = AABB(Vector3(-30, -6, -30), Vector3(60, 14, 60))
	_p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 3, 22)
	pm.direction = Vector3(0.3, 0.2, 0.1)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.45
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 2.5
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var grad := Gradient.new()                    # acende e apaga (pulso)
	grad.set_color(0, Color(0.8, 1.0, 0.4, 0.0))
	grad.add_point(0.2, Color(0.85, 1.0, 0.35, 1.0))
	grad.add_point(0.5, Color(0.8, 1.0, 0.3, 0.15))
	grad.add_point(0.75, Color(0.85, 1.0, 0.35, 1.0))
	grad.set_color(grad.get_point_count() - 1, Color(0.8, 1.0, 0.4, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	_p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var tex := GradientTexture2D.new()
	var g2 := Gradient.new()
	g2.set_color(0, Color(1, 1, 1, 1))
	g2.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g2
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	m.albedo_texture = tex
	m.emission_enabled = true
	m.emission_energy_multiplier = 2.5
	m.emission = Color(0.8, 1.0, 0.4)
	m.emission_texture = tex
	q.material = m
	_p.draw_pass_1 = q
	add_child(_p)


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("jogador") as Node3D
		return
	global_position = _player.global_position + Vector3(0, 1.2, 0)
	var missao := get_tree().get_first_node_in_group("missao")
	_p.emitting = not (missao != null and str(missao.get("dentro")) != "")
