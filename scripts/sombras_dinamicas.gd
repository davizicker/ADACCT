extends Node
## Sombras dinâmicas dos lampiões (só Forward+, qualidade Alta/Cinematográfico): a cada 0,3 s liga a sombra dos
## lampiões mais próximos do jogador e desliga a dos distantes. Assim cada luz perto projeta a sombra do jogador,
## das grades, das sacadas e dos postes, sem o custo de 200 luzes com sombra ao mesmo tempo.

var max_sombras := 8
var alcance := 32.0
var _luzes: Array[OmniLight3D] = []
var _t := 0.0
var _jog: Node3D


func configurar(jogador: Node3D, n: int) -> void:
	_jog = jogador
	max_sombras = n
	_luzes.clear()
	var vila := get_tree().current_scene.get_node_or_null("Vila")
	if vila == null:
		return
	for l in vila.find_children("*", "OmniLight3D", true, false):
		var o := l as OmniLight3D
		if o.light_cull_mask & 1 and o.omni_range > 3.0:      # luzes da rua (as das salas ficam com a sombra que já têm)
			_luzes.append(o)
			o.shadow_enabled = false
			o.shadow_blur = 1.6
			o.shadow_normal_bias = 1.4
			o.distance_fade_enabled = true
			o.distance_fade_begin = 60.0
			o.distance_fade_length = 20.0
			o.distance_fade_shadow = alcance
			o.light_volumetric_fog_energy = 1.6               # halo de luz na neblina em volta de cada lampião


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or _jog == null or _luzes.is_empty():
		return
	_t = 0.3
	var p := _jog.global_position
	var ord := _luzes.duplicate()
	ord.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool: return a.global_position.distance_squared_to(p) < b.global_position.distance_squared_to(p))
	for i in ord.size():
		var o := ord[i] as OmniLight3D
		var quer := i < max_sombras and o.global_position.distance_to(p) < alcance and o.visible
		if o.shadow_enabled != quer:
			o.shadow_enabled = quer
