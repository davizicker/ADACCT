class_name Rato
extends Node3D
## Rato de rua: fica parado perto da parede e, quando o jogador chega perto, corre em linha reta por uns segundos e some.
## (os ratos têm ouvido bom: correr na pedra os assusta de mais longe)

@export var dist_fuga := 3.2
@export var velocidade := 3.4

var _jogador: Node3D
var _fugindo := false
var _t := 0.0
var _dir := Vector3.ZERO


func _ready() -> void:
	_jogador = get_tree().get_first_node_in_group("jogador") as Node3D


func _process(delta: float) -> void:
	if _jogador == null:
		return
	if not _fugindo:
		var d := global_position.distance_to(_jogador.global_position)
		var susto := dist_fuga * (1.5 if _jogador.get("noise") != null and float(_jogador.get("noise")) > 0.9 else 1.0)
		if d < susto:
			_fugindo = true
			var longe := global_position - _jogador.global_position
			longe.y = 0.0
			_dir = longe.normalized() if longe.length() > 0.01 else Vector3.FORWARD
			rotation.y = atan2(_dir.x, _dir.z)
		return
	_t += delta
	global_position += _dir * velocidade * delta
	rotation.z = sin(_t * 28.0) * 0.12          # balançando enquanto corre
	if _t > 2.6:
		queue_free()
