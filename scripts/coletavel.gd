class_name Coletavel
extends Area3D
## Objeto que o jogador pega com a tecla E: frasco de óleo (recarrega o lampião), bilhete (lore) ou item da trama (chave, livro, terço).
## O Player procura nós do grupo "interagivel" com o método `interagir` e a propriedade `texto_interacao`.

@export_enum("oleo", "nota", "item", "reliquia", "comida") var tipo := "oleo"
@export var item_id := ""
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
	elif tipo == "comida":
		# comida que CURA: devolve o fôlego, tira o cansaço e acalma o medo (o Bradador não fica mais perto por isso)
		_usado = true
		var lt := {"pao": ["pão", "Você comeu um pedaço de pão dormido. O fôlego volta."], "feijao": ["lata de feijão", "Feijão frio, direto da lata. Você se sente firme de novo."],
			"sardinha": ["lata de sardinha", "Sardinha em óleo. Salgada, mas segura as pernas."], "leite": ["leite condensado", "Doce e grosso: a cabeça para de girar."],
			"tomate": ["lata de tomate", "Tomate ácido. Acorda você."], "cafe": ["café coado", "Café ainda morno. O frio sai dos ossos."]}
		var d: Array = lt.get(item_id, ["comida", "Você come. O fôlego volta."])
		player.stamina = Player.STAMINA_MAX
		player.exhausted = false
		get_tree().call_group("audio", "acalmar", 0.7)
		get_tree().call_group("audio", "play_clink")
		get_tree().call_group("hud", "show_prompt", str(d[1]), 4.5)
		visible = false
		set_deferred("monitorable", false)
		remove_from_group("interagivel")
	elif tipo == "reliquia":
		_usado = true
		get_tree().call_group("missao", "registrar_reliquia")
		visible = false
		set_deferred("monitorable", false)
		remove_from_group("interagivel")
	elif tipo == "item":
		_usado = true
		get_tree().call_group("missao", "dar_item", item_id)
		visible = false
		set_deferred("monitorable", false)
		remove_from_group("interagivel")
	else:
		var n: Array = Notas.TEXTOS[clampi(nota_id, 0, Notas.TEXTOS.size() - 1)]
		get_tree().call_group("missao", "registrar_nota", nota_id)
		get_tree().call_group("audio", "play_papel")
		get_tree().call_group("hud", "show_note", n[0], n[1])
		player.frozen = true
