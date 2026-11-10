class_name Missao
extends Node
## Trama da noite: objetivo atual, inventário e entrada/saída das casas.
##
## Cadeia: Venda do Seu Zé (chave do casarão) -> Casarão dos Vaz (livro de registros) + Casa do sineiro (chave da igreja)
## -> porta da igreja (destrancada com os dois) -> altar: ler os nomes em voz alta -> amanhecer.
## O terço de Dona Benedita é um item de proteção opcional (perdoa UM erro com o Bradador).
## Os interiores ficam longe da vila (assets em Vila/Interiores) e o jogador é transportado para lá.

signal item_obtido(id: String)

## id -> [nome curto, descrição]
const ITENS := {
	"chave_casarao": ["Chave do Casarão dos Vaz", "Chave grande de ferro, fria demais."],
	"livro": ["Livro de Registros dos Vaz", "Páginas riscadas, nomes apagados."],
	"chave_igreja": ["Chave da igreja", "Chave de bronze, gasta pelo uso."],
	"terco": ["Terço de Dona Benedita", "Contas de madeira escura. Ainda está morno."],
}

var player: Player
var hud: Hud
var screams: ScreamSystem
var eventos: EventDirector
var inv := {}
var dentro := ""                  # id do interior onde o jogador está ("" = na rua)
var modo_teste := false           # os testes automáticos ignoram a trama (a porta da igreja abre direto)
var terco_usado := false

var _ret_pos := Vector3.ZERO
var _ret_rot := 0.0
var _env: Environment
var _eventos_antes := true
var _cooldown := 0.0
var _auto_t := 0.0
var _oculto_t := 0.0
var _esc_pos := Vector3.ZERO
var _esc_rot := 0.0
var _lanterna_antes := true
var lidas: Array[int] = []        # notas já lidas (tecla J reabre)
var _diario_i := 0


func _ready() -> void:
	add_to_group("missao")


func setup(p_player: Player, p_hud: Hud, p_screams: ScreamSystem, p_eventos: EventDirector, p_env: Environment, intro := true) -> void:
	player = p_player
	hud = p_hud
	screams = p_screams
	eventos = p_eventos
	_env = p_env
	atualizar_hud()
	if SaveGame.carregar_ao_iniciar and SaveGame.existe():
		SaveGame.carregar_ao_iniciar = false
		aplicar_save(SaveGame.ler())
		intro = false
	if intro:
		hud.show_note(Notas.TEXTOS[11][0], Notas.TEXTOS[11][1])
		player.frozen = true


## Entra/sai de um Esconderijo.
func esconder(spot: Node) -> void:
	if player.hidden or dentro != "" or _cooldown > 0.0:
		return
	_cooldown = 0.6
	_esc_pos = player.global_position
	_esc_rot = player.rotation.y
	_lanterna_antes = player.lantern_on
	player.global_position = spot.get("pos_oculto")
	player.velocity = Vector3.ZERO
	player.rotation.y = float(spot.get("yaw_oculto"))
	player.cam.rotation.x = 0.0
	player.lantern_on = false
	player.hidden = true
	player.frozen = true
	_oculto_t = 0.0
	hud.show_prompt("Escondido. Prenda a respiração. [E] sai.", 4.0)
	hud.flash(Color(0, 0, 0, 0.6), 0.4)


func sair_esconderijo() -> void:
	if not player.hidden:
		return
	player.hidden = false
	player.frozen = false
	player.lantern_on = _lanterna_antes
	player.global_position = _esc_pos
	player.velocity = Vector3.ZERO
	player.rotation.y = _esc_rot
	_cooldown = 0.6
	hud.flash(Color(0, 0, 0, 0.5), 0.3)


var reliquias := 0                  # medalhas da Irmandade achadas (12 espalhadas pela vila)
const TOTAL_RELIQUIAS := 12


## Achou uma medalha: +querosene, e a cada quatro uma recompensa (o Bradador recua; no fim, uma pista final).
func registrar_reliquia() -> void:
	reliquias += 1
	player.oil = minf(Player.OIL_MAX, player.oil + 18.0)
	player.oil_changed.emit(player.oil)
	var msg := "Medalha da Irmandade %d/%d (+querosene)" % [reliquias, TOTAL_RELIQUIAS]
	if reliquias % 4 == 0 and reliquias < TOTAL_RELIQUIAS:
		var jogo := get_tree().get_first_node_in_group("jogo")
		if jogo != null:
			var sc: Variant = jogo.get("screams")
			if sc != null and int(sc.get("stage")) > 0:
				sc.set("stage", int(sc.get("stage")) - 1)
				sc.call("_place_bradador")
		msg += "  Algo se acalma, e o Bradador recua."
	elif reliquias == TOTAL_RELIQUIAS:
		msg = "As doze medalhas estão com você. A Irmandade te reconhece: a igreja abrirá mais fácil esta noite."
		dar_item("terco") if not tem("terco") else null
	hud.show_prompt(msg, 5.0)
	get_tree().call_group("audio", "play_clink")


func registrar_nota(id: int) -> void:
	if not lidas.has(id):
		lidas.append(id)


## Tecla J: reabre as cartas já lidas, uma por vez.
func _unhandled_input(event: InputEvent) -> void:
	if hud == null or player == null:
		return
	if player.hidden and event.is_action_pressed("interact"):
		sair_esconderijo()
		get_viewport().set_input_as_handled()
		return
	if modo_teste:
		return
	if event.is_action_pressed("diario") and not hud.note_open() and not player.frozen:
		if lidas.is_empty():
			hud.show_prompt("Você ainda não leu nenhum papel.", 3.0)
			return
		_diario_i = (_diario_i + 1) % lidas.size()
		var n: Array = Notas.TEXTOS[lidas[_diario_i]]
		hud.show_note("%s  (%d/%d)" % [str(n[0]), _diario_i + 1, lidas.size()], str(n[1]))
		player.frozen = true


func tem(id: String) -> bool:
	return inv.has(id)


func completo() -> bool:
	return modo_teste or (tem("livro") and tem("chave_igreja"))


func faltando() -> String:
	var f: Array[String] = []
	if not tem("chave_igreja"):
		f.append("a chave da igreja (casa do sineiro)")
	if not tem("livro"):
		f.append("o livro de registros dos Vaz (Casarão)")
	return " e ".join(f)


func objetivo() -> String:
	if tem("livro") and tem("chave_igreja"):
		return "Suba até a igreja e abra a porta."
	if tem("chave_casarao") and not tem("livro"):
		return "Entre no Casarão dos Vaz e ache o livro de registros."
	if not tem("chave_casarao") and not tem("livro"):
		if tem("chave_igreja"):
			return "Ache a chave do Casarão na Venda do Seu Zé."
		return "Descubra o que acontece à noite: procure as casas com luz na porta e leia os recados. Comece pela Venda e pela casa do sineiro."
	return "Ache a chave da igreja na casa do sineiro."


func atualizar_hud() -> void:
	if hud == null:
		return
	var t := "Objetivo: %s" % objetivo()
	var nomes: Array[String] = []
	for id: String in inv:
		nomes.append(str(ITENS[id][0]))
	if nomes.size() > 0:
		t += "\nCom você: " + ", ".join(nomes)
	hud.set_objetivo(t)


func dar_item(id: String) -> void:
	if inv.has(id):
		return
	inv[id] = true
	var d: Array = ITENS[id]
	get_tree().call_group("audio", "play_clink")
	hud.show_prompt("Você pegou: %s" % str(d[0]), 4.0)
	atualizar_hud()
	salvar()
	item_obtido.emit(id)
	if id == "livro":
		# o livro desperta o Bradador: susto da noite
		var nota: Array = Notas.TEXTOS[7]
		hud.show_note(nota[0], nota[1])
		player.frozen = true
		player.blackout(2.5)
		player.shake(0.12, 1.5)
		hud.flash(Color(1, 1, 1, 0.5), 0.15)
		get_tree().call_group("audio", "play_sting")
	elif id == "terco":
		hud.show_prompt("Você pegou o terço. Ele vai te dar UMA chance contra o Bradador.", 5.0)


## Usado pelo ScreamSystem quando o Bradador "pega" o jogador: o terço absorve um erro.
func absorver_erro() -> bool:
	if tem("terco") and not terco_usado:
		terco_usado = true
		hud.show_prompt("O terço esquentou na sua mão. O Bradador recuou.", 4.0)
		hud.flash(Color(1.0, 0.85, 0.5, 0.5), 0.3)
		return true
	return false


var _porta_aberta: Node = null


func usar_porta(porta: Node, p: Player) -> void:
	if _cooldown > 0.0:
		return
	var req: String = porta.get("requer")
	if req != "" and not tem(req):
		hud.show_prompt(str(porta.get("texto_trancada")), 4.0)
		get_tree().call_group("audio", "play_creak", (porta as Node3D).global_position)
		return
	var destino: String = porta.get("destino")
	if destino == "":
		sair()
	else:
		if porta.has_method("abrir_visual") and not modo_teste:
			_cooldown = 1.6
			_porta_aberta = porta
			porta.call("abrir_visual")
			get_tree().call_group("audio", "play_creak", (porta as Node3D).global_position)
			await get_tree().create_timer(0.6).timeout
			_cooldown = 0.0
		if bool(porta.get_meta("real", false)):
			if modo_teste:
				porta.call("abrir_visual")      # nos testes automáticos a porta abre sem a espera
				var sl := _sala_por_id(destino)
				if sl != null:
					player.global_transform.origin = _spawn_sala(sl)
			return                              # casa da rua: sem teleporte, o jogador entra andando
		entrar(destino)


## Salas das casas da rua (nós "Sala_<id>"): o jogador está dentro quando a posição dele cai na caixa da sala.
func _sala_por_id(id: String) -> Node3D:
	for n in get_tree().get_nodes_in_group("sala_rua"):
		if str(n.get_meta("sala_id", "")) == id:
			return n as Node3D
	return null


func _spawn_sala(sala: Node3D) -> Vector3:
	return sala.global_transform * ((sala.get_meta("spawn") as Vector3) / Interiores.ESCALA_SALA)


func _detecta_sala() -> void:
	if player == null or dentro == "igreja" or (dentro != "" and not _em_sala_rua):
		return                                   # teleportado (igreja, becos sem saída): quem manda é entrar()/sair()
	var achada := ""
	for n in get_tree().get_nodes_in_group("sala_rua"):
		var sl := n as Node3D
		var dim: Vector3 = sl.get_meta("dim")
		var q: Vector3 = sl.global_transform.affine_inverse() * player.global_position
		var s_e := 1.0 / Interiores.ESCALA_SALA
		if q.x > -0.1 and q.x < dim.x * s_e + 0.1 and q.z > 0.15 and q.z < dim.z * s_e + 0.1 and q.y > -0.6 and q.y < dim.y * s_e + 0.2:
			achada = str(sl.get_meta("sala_id"))
			break
	if achada == dentro:
		return
	if achada != "":
		dentro = achada
		_em_sala_rua = true
		get_tree().call_group("audio", "set_interior", true)
		if screams != null:
			screams.hold = true
		if eventos != null:
			_eventos_antes = eventos.enabled
			eventos.enabled = false
		var sl2 := _sala_por_id(achada)
		if sl2 != null and hud != null:
			hud.show_prompt(str(sl2.get_meta("nome")), 3.0)
	else:
		dentro = ""
		_em_sala_rua = false
		get_tree().call_group("audio", "set_interior", false)
		salvar()
		if screams != null:
			screams.hold = false
		if eventos != null:
			eventos.enabled = _eventos_antes


var _em_sala_rua := false


func entrar(id: String) -> void:
	var sala := get_tree().root.get_node_or_null("Main/Vila/Interiores/" + id) as Node3D
	if sala == null:
		push_warning("Interior inexistente: " + id)
		return
	_cooldown = 1.0
	_ret_pos = player.global_position
	_ret_rot = player.rotation.y
	dentro = id
	get_tree().call_group("audio", "set_interior", true)
	player.global_position = sala.global_position + (sala.get_meta("spawn") as Vector3)
	player.velocity = Vector3.ZERO
	player.rotation.y = PI
	player.cam.rotation.x = 0.0
	hud.flash(Color(0, 0, 0, 1), 0.7)
	get_tree().call_group("audio", "play_creak", player.global_position)
	if screams != null:
		screams.hold = true
	if eventos != null:
		_eventos_antes = eventos.enabled
		eventos.enabled = false
	hud.show_prompt(str(sala.get_meta("nome")), 3.0)


func sair() -> void:
	if _porta_aberta != null and is_instance_valid(_porta_aberta):
		_porta_aberta.call("fechar_visual")
	_porta_aberta = null
	_cooldown = 1.0
	player.global_position = _ret_pos
	player.velocity = Vector3.ZERO
	player.rotation.y = _ret_rot + PI
	player.cam.rotation.x = 0.0
	dentro = ""
	get_tree().call_group("audio", "set_interior", false)
	salvar()
	hud.flash(Color(0, 0, 0, 1), 0.7)
	get_tree().call_group("audio", "play_creak", player.global_position)
	if screams != null:
		screams.hold = false
	if eventos != null:
		eventos.enabled = _eventos_antes


## A porta da igreja: só abre com a chave e o livro.
func tentar_igreja() -> void:
	if dentro != "" or _cooldown > 0.0:
		return
	if completo():
		entrar("igreja")
	else:
		_cooldown = 5.0
		hud.show_prompt("A porta está trancada. Falta: %s." % faltando(), 5.0)
		get_tree().call_group("audio", "play_creak", player.global_position)


func finalizar() -> void:
	get_tree().call_group("jogo", "vitoria")


## Estado atual como dicionário (posição de RUA: dentro de uma casa, vale onde o jogador entrou).
func estado() -> Dictionary:
	var teleportado := dentro != "" and not _em_sala_rua
	var pos := _ret_pos if teleportado else player.global_position
	var rot := _ret_rot if teleportado else player.rotation.y
	return {
		"itens": ",".join(PackedStringArray(inv.keys())),
		"terco_usado": terco_usado,
		"lidas": ",".join(PackedStringArray(lidas.map(func(i: int) -> String: return str(i)))),
		"oleo": player.oil,
		"x": pos.x, "y": pos.y, "z": pos.z, "rot": rot,
	}


func salvar() -> void:
	if modo_teste or player == null:
		return
	SaveGame.gravar(estado())


func aplicar_save(d: Dictionary) -> void:
	if d.is_empty():
		return
	inv.clear()
	for id in str(d.get("itens", "")).split(",", false):
		if ITENS.has(id):
			inv[id] = true
	terco_usado = bool(d.get("terco_usado", false))
	lidas.clear()
	for t in str(d.get("lidas", "")).split(",", false):
		lidas.append(int(t))
	player.oil = float(d.get("oleo", Player.OIL_MAX))
	player.global_position = Vector3(float(d.get("x", 0)), float(d.get("y", 0)) + 0.1, float(d.get("z", 0)))
	player.velocity = Vector3.ZERO
	player.rotation.y = float(d.get("rot", 0))
	dentro = ""
	atualizar_hud()


func _process(delta: float) -> void:
	if player != null and player.hidden:
		_oculto_t += delta
		if _oculto_t > 20.0 and _oculto_t - delta <= 20.0:
			hud.show_prompt("Algo respira do outro lado...", 3.0)
		if _oculto_t > 25.0:
			sair_esconderijo()
			if screams != null:
				screams.penalize(1, "farejou o esconderijo")
			hud.show_prompt("Ele farejou você!", 3.0)
	_auto_t += delta
	if _auto_t > 60.0 and dentro == "" and not player.frozen and not player.hidden:
		_auto_t = 0.0
		salvar()
	_cooldown = maxf(0.0, _cooldown - delta)
	_detecta_sala()
	if _env == null:
		return
	var alvo_amb := 0.22 if dentro != "" else 0.38
	_env.ambient_light_energy = lerpf(_env.ambient_light_energy, alvo_amb, clampf(delta * 4.0, 0.0, 1.0))
	# dentro de casa a sombra é quente (lamparina), não azul-noite da rua
	var alvo_cor := Color(0.34, 0.22, 0.13) if dentro != "" else Color(0.10, 0.13, 0.20)
	_env.ambient_light_color = _env.ambient_light_color.lerp(alvo_cor, clampf(delta * 4.0, 0.0, 1.0))
