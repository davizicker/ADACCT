class_name Esconderijo
extends Area3D
## Esconderijo (tecla E): atrás de um carro coberto ou no canto de um beco sem saída. Escondido, o Bradador não ouve
## nem vê: o grito não te penaliza e a Mula passa. Demorar demais (25 s) faz ele farejar o lugar. E sai.

@export var texto_interacao := "Esconder-se"
## onde o jogador fica (posição global) e para onde olha (yaw em radianos)
var pos_oculto := Vector3.ZERO
var yaw_oculto := 0.0


func _ready() -> void:
	add_to_group("interagivel")
	add_to_group("esconderijos")
	monitoring = false


func interagir(player: Player) -> void:
	get_tree().call_group("missao", "esconder", self)
