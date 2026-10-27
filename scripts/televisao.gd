class_name Televisao
extends Node3D
## TV antiga ligada, sem sinal (estática). Pisca a luz azulada, tem som de chuvisco ao redor e, de vez em quando,
## um "surto" (brilho forte + ruído mais agudo). Nós esperados (criados em tools/vila_builder.gd): "Tela" (MeshInstance3D) e "Luz" (OmniLight3D).
## É o tipo de detalhe que faz o jogador desconfiar: ninguém desligou aquilo.

@export var alcance_som := 16.0
var _luz: OmniLight3D
var _tela: MeshInstance3D
var _som: AudioStreamPlayer3D
var _base := 1.0
var _t := 0.0
var _surto := 0.0
var _prox_surto := 8.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_luz = get_node_or_null("Luz") as OmniLight3D
	_tela = get_node_or_null("Tela") as MeshInstance3D
	if _luz != null:
		_base = _luz.light_energy
	_som = AudioStreamPlayer3D.new()
	_som.stream = Synth.tv_static()
	_som.bus = "Ambiente" if AudioServer.get_bus_index("Ambiente") != -1 else "Master"
	_som.unit_size = 5.0
	_som.max_distance = alcance_som
	_som.volume_db = -10.0
	_som.position = Vector3(0, 0.3, 0.2)
	add_child(_som)
	_som.play()


func _process(delta: float) -> void:
	_t += delta
	_prox_surto -= delta
	if _prox_surto <= 0.0:
		_surto = 1.0
		_prox_surto = _rng.randf_range(7.0, 16.0)
	_surto = maxf(0.0, _surto - delta * 2.2)
	if _luz != null:
		var n := sin(_t * 23.0) * 0.5 + sin(_t * 41.0 + 1.3) * 0.3 + sin(_t * 9.0) * 0.2
		_luz.light_energy = _base * (0.75 + 0.25 * n) * (1.0 + _surto * 1.6)
	if _tela != null:
		var m := _tela.get_surface_override_material(0) as ShaderMaterial
		if m != null:
			m.set_shader_parameter("tremor", _surto)
	if _som != null:
		_som.pitch_scale = 1.0 + _surto * 0.18
