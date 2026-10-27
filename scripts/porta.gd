class_name Porta
extends Area3D
## Porta interativa (tecla E). `destino` = id do interior para entrar; vazio = sair do interior para a rua.
## `requer` = item do inventário necessário (ex.: "chave_casarao"); sem ele a porta está trancada.

@export var destino := ""
@export var texto_interacao := "Entrar"
@export var requer := ""
@export var texto_trancada := "Está trancada."


func _ready() -> void:
	add_to_group("interagivel")
	monitoring = false


func interagir(player: Player) -> void:
	get_tree().call_group("missao", "usar_porta", self, player)
