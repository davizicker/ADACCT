class_name Examinar
extends Area3D
## Objeto de cena que o jogador examina com E: mostra uma frase (um pedacinho da história, ou só um arrepio) e toca um som.
## Não some nem some do mundo: dá para examinar de novo (a frase varia se houver várias separadas por " | ").

@export var texto_interacao := "Examinar"
@export_multiline var texto := ""
@export_enum("papel", "creak", "clink", "nenhum") var som := "papel"
@export var medo := 0.0

var _vez := 0


func _ready() -> void:
	add_to_group("interagivel")
	monitoring = false


func interagir(_player: Player) -> void:
	var frases := texto.split(" | ")
	var f := frases[_vez % frases.size()]
	_vez += 1
	get_tree().call_group("hud", "show_prompt", f, 6.5)
	match som:
		"papel":
			get_tree().call_group("audio", "play_papel")
		"creak":
			get_tree().call_group("audio", "play_creak", global_position)
		"clink":
			get_tree().call_group("audio", "play_clink")
	if medo > 0.0:
		get_tree().call_group("audio", "bump_fear", medo)
