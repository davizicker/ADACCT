class_name Coletavel
extends Area3D
## Objeto que o jogador pega com a tecla E: frasco de óleo (recarrega o lampião) ou bilhete (lore).
## O Player procura nós do grupo "interagivel" com o método `interagir` e a propriedade `texto_interacao`.

@export_enum("oleo", "nota") var tipo := "oleo"
@export var nota_id := 0
@export var texto_interacao := "Pegar"

var _usado := false


func _ready() -> void:
	add_to_group("interagivel")
	monitoring = false


func interagir(player: Player) -> void:
	if _usado:
		return
	if tipo == "oleo":
		_usado = true
		player.oil = minf(Player.OIL_MAX, player.oil + 70.0)
		player.oil_changed.emit(player.oil)
		get_tree().call_group("audio", "play_clink")
		get_tree().call_group("hud", "show_prompt", "Você pegou querosene.", 3.0)
		visible = false
		set_deferred("monitorable", false)
		remove_from_group("interagivel")
	else:
		var n: Array = Notas.TEXTOS[clampi(nota_id, 0, Notas.TEXTOS.size() - 1)]
		get_tree().call_group("hud", "show_note", n[0], n[1])
		player.frozen = true
