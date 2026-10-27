class_name LuzTremula
extends OmniLight3D
## Luz de chama (vela, lampião): a intensidade treme de leve. Edite `forca` e `velocidade` no Inspetor.
## `ligada = false` apaga a luz com um fade (e escurece o vidro do lampião, se houver um nó "Vidro" irmão).
## Usada pelos eventos de apagão (scripts/event_director.gd).

@export var forca := 0.18
@export var velocidade := 7.0
var ligada := true

var _base := 1.0
var _seed := 0.0
var _fade := 1.0
var _glass: MeshInstance3D = null
var _halo: MeshInstance3D = null
var _glass_base := 2.0


var _bulb_mi: MeshInstance3D = null
var _bulb_idx := -1
var _bulb_base := 3.2


func _ready() -> void:
	_base = light_energy
	_seed = randf() * 100.0
	var parent := get_parent()
	if parent != null:
		_glass = parent.get_node_or_null("Vidro") as MeshInstance3D
		_halo = parent.get_node_or_null("Halo") as MeshInstance3D
		# lâmpada de um modelo real (.glb): superfície emissiva guardada em metadados pelo construtor
		if parent.has_meta("bulb_mi"):
			_bulb_mi = parent.get_node_or_null(parent.get_meta("bulb_mi")) as MeshInstance3D
			_bulb_idx = int(parent.get_meta("bulb_idx"))
			if _bulb_mi != null:
				var bm := _bulb_mi.get_surface_override_material(_bulb_idx) as StandardMaterial3D
				if bm != null:
					_bulb_base = bm.emission_energy_multiplier
		if _glass != null and _glass.material_override is StandardMaterial3D:
			_glass_base = (_glass.material_override as StandardMaterial3D).emission_energy_multiplier


func _process(delta: float) -> void:
	_fade = move_toward(_fade, 1.0 if ligada else 0.0, delta * 3.5)
	var t := Time.get_ticks_msec() / 1000.0 * velocidade + _seed
	var n := sin(t) * 0.5 + sin(t * 2.37 + 1.3) * 0.3 + sin(t * 5.1 + 4.0) * 0.2
	light_energy = _base * (1.0 + n * forca) * _fade
	if _halo != null:
		_halo.visible = _fade > 0.03
		_halo.scale = Vector3.ONE * (0.25 + 0.75 * _fade) * (1.0 + n * forca * 0.5)
	if _glass != null and _glass.material_override is StandardMaterial3D:
		(_glass.material_override as StandardMaterial3D).emission_energy_multiplier = _glass_base * (0.04 + 0.96 * _fade)
	if _bulb_mi != null:
		var bm2 := _bulb_mi.get_surface_override_material(_bulb_idx) as StandardMaterial3D
		if bm2 != null:
			bm2.emission_energy_multiplier = _bulb_base * (0.03 + 0.97 * _fade) * (1.0 + n * forca * 0.3)
