class_name Altar
extends Area3D
## Altar da igreja: com o livro de registros, o jogador lê os nomes em voz alta e a noite termina.

@export var texto_interacao := "Ler os nomes em voz alta"
@export var requer := "livro"


func _ready() -> void:
	add_to_group("interagivel")
	monitoring = false


func interagir(_player: Player) -> void:
	var m := get_tree().get_first_node_in_group("missao")
	if m == null or not m.tem(requer):
		get_tree().call_group("hud", "show_prompt", "Falta o livro dos Vaz.", 3.0)
		return
	m.finalizar()
