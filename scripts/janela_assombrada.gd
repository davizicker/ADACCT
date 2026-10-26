class_name JanelaAssombrada
extends Node3D
## Janela acesa com um vulto parado atrás da cortina. Quando o jogador chega perto, a luz se apaga,
## o vulto some e uma porta range. Acontece uma vez por janela.

@export var distancia := 9.0
var _done := false
var _glass: MeshInstance3D
var _figure: MeshInstance3D
var _light: OmniLight3D
var _t := 0.0
var _player: Node3D


func _ready() -> void:
	_glass = get_node_or_null("Vidro") as MeshInstance3D
	_figure = get_node_or_null("Vulto") as MeshInstance3D
	_light = get_node_or_null("Luz") as OmniLight3D


func _process(delta: float) -> void:
	if _done:
		_t += delta
		if _t > 0.5 and _glass != null and _glass.visible:
			_glass.visible = false
			if _light != null:
				_light.visible = false
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("jogador") as Node3D
		return
	if global_position.distance_to(_player.global_position) < distancia:
		_done = true
		if _figure != null:
			_figure.visible = false
		get_tree().call_group("audio", "play_creak_at", global_position)
		get_tree().call_group("audio", "bump_fear", 0.18)
