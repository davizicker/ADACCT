class_name Interiores
extends RefCounted
## Interiores visitáveis. Cada sala é construída num ponto distante do mapa (BASE + índice*PASSO) e o jogador é
## transportado para lá quando abre a porta da casa (scripts/missao.gd). Sistema de coordenadas de cada sala:
##   x = 0..largura, z = 0..profundidade, y = 0..altura. A porta de saída fica na parede z=0, no meio.
## O jogador nasce em (largura/2, 0.12, 1.7) olhando para +z.
##
## Para criar uma sala nova: copie uma função _sala_xxx, adicione o id em ORDEM e uma entrada em
## VilaBuilder.ENTRADAS (a porta na fachada).

const BASE := Vector3(4000.0, 0.0, 0.0)
const PASSO := 60.0
const ORDEM: Array[String] = ["benedita", "padaria", "venda", "barbearia", "sineiro", "casarao", "igreja", "carpintaria", "escola", "ferraria", "casa_vazia", "pensao", "costureira", "deposito"]

var b: VilaBuilder
var _bb: MeshBatch
var _g: Node3D
var _w := 0.0
var _d := 0.0
var _h := 0.0
var _w0 := 1.0                         # largura/profundidade ORIGINAIS da sala (o layout foi desenhado para elas); a sala real é maior
var _d0 := 1.0
const K_SALA := 1.0                    # (remapear cada móvel separado desalinhava mesas e cadeiras; agora a sala inteira é ampliada por escala uniforme em construir())
const ESCALA_SALA := 1.25              # ampliação uniforme da sala inteira (paredes, móveis, luzes, colisão)
var _cadeiras: Array[Vector2] = []
var _parede_mat := ""
var _andar_sup := 0.0                   # altura do piso do 2º andar (0 = sala de um andar só): a parede da frente ganha a 2ª fileira de janelas
var _divisorias_x: Array[float] = []    # x das paredes internas que tocam a parede da frente (janela não pode cair nelas)
var _n_casca := 0                      # quantas caixas de _bb são da casca da sala (o resto é mobília)


## Salas das casas da RUA: nascem dentro da própria casa (lote ajustado às medidas da sala), sem teleporte.
const SALAS_RUA: Array[String] = ["benedita", "padaria", "venda", "barbearia", "sineiro", "casarao", "carpintaria", "escola"]
var na_rua := false                    # true enquanto uma sala de rua é montada (parede da frente com vãos reais, colisões justas)


## Monta UMA sala de rua (origem no canto da parede da frente, já ampliada). Quem chama a encaixa na casa.
func sala_rua(builder: VilaBuilder, id: String) -> Node3D:
	b = builder
	na_rua = true
	var g := Node3D.new()
	g.name = "Sala_" + id
	_g = g
	_montar(id, g)
	na_rua = false
	g.set_meta("sala_id", id)
	g.add_to_group("sala_rua", true)
	return g


func _montar(id: String, g: Node3D) -> void:
	call("_sala_" + id, g)
	_camada(g)
	if id != "igreja":
		for l in g.find_children("*", "OmniLight3D", true, false):
			(l as OmniLight3D).omni_range *= ESCALA_SALA
		g.set_meta("spawn", (g.get_meta("spawn") as Vector3) * ESCALA_SALA)
		g.set_meta("dim", (g.get_meta("dim") as Vector3) * ESCALA_SALA)
		if not na_rua:
			g.scale = Vector3.ONE * ESCALA_SALA


## `cubos`: monta TODAS as salas no depósito distante (necessário só para fotografar as salas que as janelas das casas fechadas mostram).
## Sem isso, só ficam lá as salas que ainda usam teleporte (becos sem saída e a igreja).
func construir(builder: VilaBuilder, cubos := false) -> Node3D:
	b = builder
	var root := Node3D.new()
	root.name = "Interiores"
	for i in ORDEM.size():
		var id := ORDEM[i]
		if SALAS_RUA.has(id) and not cubos:
			continue
		var g := Node3D.new()
		g.name = id
		g.position = BASE + Vector3(i * PASSO, 0.0, 0.0)
		root.add_child(g)
		_g = g
		_montar(id, g)
	var rel := FileAccess.open("res://docs/23-medidas-dos-moveis.md", FileAccess.WRITE)
	if rel != null:
		rel.store_string("# Medidas dos móveis e objetos de modelo, por sala\n\nGerado pelo bake (tools/interiores.gd). Medidas em metros no desenho da sala (antes da ampliação de %.2fx). `Folga` = distância até a parede mais próxima.\n\n| Sala | Peça | Centro (x, z) | Tamanho (x, y, z) | Giro | Múltiplo de 90° | Folga |\n|---|---|---|---|---|---|---|\n" % ESCALA_SALA)
		rel.store_string("\n".join(_relatorio_linhas) + "\n")
		rel.close()
	var aud := FileAccess.open("res://docs/26-auditoria-salas.md", FileAccess.WRITE)
	if aud != null:
		aud.store_string("# Auditoria de arrumação das salas\n\nGerada pelo bake (tools/interiores.gd, `_auditar`). Medidas no desenho da sala (antes da ampliação). Cada linha é algo que NÃO está em seu devido lugar (ou uma informação).\n\n| Sala | Problema | Detalhe |\n|---|---|---|\n")
		aud.store_string("\n".join(_auditoria_linhas) + "\n")
		aud.close()
	print("[salas] auditoria: %d avisos" % _auditoria_linhas.size())
	return root


## Interior só recebe luz das lâmpadas dele (a Lua usa a máscara de camada 1).
func _camada(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).layers = 2
	elif n is Light3D:
		(n as Light3D).light_cull_mask = 2          # a luz da sala não vaza para a rua (nem a das lâmpadas da rua para dentro)
	for c in n.get_children():
		_camada(c)


# ------------------------------------------------------------------ casca e utilidades

## Posição do layout original -> sala ampliada. Quem está junto de uma parede continua junto dela; quem está no meio fica no meio.
func _mx(x: float) -> float:
	return x + (_w - _w0) * smoothstep(0.22, 0.78, x / _w0)


func _mz(z: float) -> float:
	return z + (_d - _d0) * smoothstep(0.22, 0.78, z / _d0)


func _casca(nome: String, w: float, d: float, h: float, parede: String, piso: String, teto := "madeira_escura") -> void:
	_w0 = w
	_d0 = d
	_cadeiras = []
	_janelas_lat = []
	_andar_sup = 0.0
	_divisorias_x = []
	_tem_tapete = false
	if nome != "Igreja Matriz":                      # a igreja já é grande
		w = snappedf(w * K_SALA, 0.1)
		d = snappedf(d * K_SALA, 0.1)
	_w = w
	_d = d
	_h = h
	# paredes de perto: reboco com relevo mais suave (a lanterna fica a centímetros da parede)
	var pm := b.mat(parede).duplicate() as Material
	if pm is StandardMaterial3D:
		(pm as StandardMaterial3D).normal_scale = 0.25
	b._cache["i_" + parede] = pm
	parede = "i_" + parede
	_g.set_meta("nome", nome)
	_g.set_meta("dim", Vector3(w, h, d))         # largura, altura, profundidade: usadas por tools/interior_cubes.gd (janelas mostram a sala de verdade)
	_g.set_meta("spawn", Vector3(w / 2.0, 0.12, 1.7))
	_bb = b._batch()
	_bb.box(piso, Vector3(w + 0.6, 0.2, d + 0.6), Vector3(w / 2.0, -0.1, d / 2.0))
	_bb.box(teto, Vector3(w + 0.6, 0.2, d + 0.6), Vector3(w / 2.0, h + 0.1, d / 2.0))
	var x := 0.6
	while x < w:
		_bb.box("madeira_natural", Vector3(0.16, 0.2, d), Vector3(x, h - 0.1, d / 2.0))      # vigas
		x += 1.4
	_bb.box(parede, Vector3(0.3, h + 0.4, d + 0.6), Vector3(-0.15, h / 2.0, d / 2.0))
	_bb.box(parede, Vector3(0.3, h + 0.4, d + 0.6), Vector3(w + 0.15, h / 2.0, d / 2.0))
	if not na_rua:
		_bb.box(parede, Vector3(w + 0.6, h + 0.4, 0.3), Vector3(w / 2.0, h / 2.0, -0.15))
	_bb.box(parede, Vector3(w + 0.6, h + 0.4, 0.3), Vector3(w / 2.0, h / 2.0, d + 0.15))
	_parede_mat = parede
	# rodapé
	_bb.box("madeira_escura", Vector3(w - 0.08, 0.14, 0.04), Vector3(w / 2.0, 0.07, 0.02))
	_bb.box("madeira_escura", Vector3(w - 0.08, 0.14, 0.04), Vector3(w / 2.0, 0.07, d - 0.02))
	_bb.box("madeira_escura", Vector3(0.04, 0.14, d), Vector3(0.02, 0.07, d / 2.0))
	_bb.box("madeira_escura", Vector3(0.04, 0.14, d), Vector3(w - 0.02, 0.07, d / 2.0))
	# lambri de madeira (1 m) em volta da sala e sanca no teto: acabamento de casa de verdade
	if h < 5.0:
		var lamb := "madeira_escura"
		_bb.box(lamb, Vector3(0.03, 0.95, d), Vector3(0.015, 0.5, d / 2.0))
		_bb.box(lamb, Vector3(0.03, 0.95, d), Vector3(w - 0.015, 0.5, d / 2.0))
		_bb.box(lamb, Vector3(w, 0.95, 0.03), Vector3(w / 2.0, 0.5, d - 0.015))
		_bb.box(lamb, Vector3(w / 2.0 - 0.85, 0.95, 0.03), Vector3((w / 2.0 - 0.85) / 2.0, 0.5, 0.015))
		_bb.box(lamb, Vector3(w / 2.0 - 0.85, 0.95, 0.03), Vector3(w - (w / 2.0 - 0.85) / 2.0, 0.5, 0.015))
		_bb.box("madeira_natural", Vector3(0.06, 0.04, d), Vector3(0.03, 0.97, d / 2.0))              # corrimão do lambri
		_bb.box("madeira_natural", Vector3(0.06, 0.04, d), Vector3(w - 0.03, 0.97, d / 2.0))
		_bb.box("madeira_natural", Vector3(w, 0.04, 0.06), Vector3(w / 2.0, 0.97, d - 0.03))
		for k in int(d / 0.9):                                                                                # frisos verticais do lambri
			_bb.box("madeira_natural", Vector3(0.035, 0.9, 0.025), Vector3(0.02, 0.5, 0.45 + k * 0.9))
			_bb.box("madeira_natural", Vector3(0.035, 0.9, 0.025), Vector3(w - 0.02, 0.5, 0.45 + k * 0.9))
		_bb.box("cantaria", Vector3(0.14, 0.12, d), Vector3(0.07, h - 0.06, d / 2.0))                       # sanca de gesso
		_bb.box("cantaria", Vector3(0.14, 0.12, d), Vector3(w - 0.07, h - 0.06, d / 2.0))
		_bb.box("cantaria", Vector3(w, 0.12, 0.14), Vector3(w / 2.0, h - 0.06, d - 0.07))
		_bb.box("cantaria", Vector3(w, 0.12, 0.14), Vector3(w / 2.0, h - 0.06, 0.07))
	# colisões (a sala é uma caixa fechada)
	var ext := 0.6 if na_rua else 4.0
	var ver := 0.4 if na_rua else 2.0
	b._blocker(_g, "Piso", Vector3(w + ext, 0.6, d + ext), Vector3(w / 2.0, -0.3, d / 2.0))
	b._blocker(_g, "Teto", Vector3(w + ext, 0.6, d + ext), Vector3(w / 2.0, h + 0.3, d / 2.0))
	b._blocker(_g, "ParedeO", Vector3(0.6, h + ver, d + ext), Vector3(-0.3, h / 2.0, d / 2.0))
	b._blocker(_g, "ParedeL", Vector3(0.6, h + ver, d + ext), Vector3(w + 0.3, h / 2.0, d / 2.0))
	b._blocker(_g, "ParedeN", Vector3(w + ext, h + ver, 0.6), Vector3(w / 2.0, h / 2.0, d + 0.3))
	if not na_rua:
		b._blocker(_g, "ParedeS", Vector3(w + 4.0, h + 2.0, 0.6), Vector3(w / 2.0, h / 2.0, -0.3))
		# porta de saída (parede sul) e gatilho de interação
		_bb.box("cantaria", Vector3(1.5, 2.55, 0.12), Vector3(w / 2.0, 1.27, 0.06))
		_bb.box("madeira_escura", Vector3(1.2, 2.3, 0.1), Vector3(w / 2.0, 1.15, 0.11))
		_bb.box("ferro", Vector3(0.05, 0.12, 0.06), Vector3(w / 2.0 + 0.42, 1.05, 0.2))
		_bb.box("pano_cru", Vector3(1.0, 0.02, 0.6), Vector3(w / 2.0, 0.01, 0.55))                          # capacho
		_bb.box("madeira_escura", Vector3(1.04, 0.015, 0.64), Vector3(w / 2.0, 0.006, 0.55))
		var a := _area("Saida", Vector3(w / 2.0, 1.2, 0.8), Vector3(1.9, 2.4, 1.5), "res://scripts/porta.gd")
		a.set("destino", "")
		a.set("texto_interacao", "Sair para a rua")
	else:
		_bb.box("pano_cru", Vector3(1.0, 0.02, 0.6), Vector3(w / 2.0, 0.01, 0.55))                          # capacho
		_bb.box("madeira_escura", Vector3(1.04, 0.015, 0.64), Vector3(w / 2.0, 0.006, 0.55))
	_n_casca = _bb._boxes.size()
	# luz de preenchimento: a sala não é mais um poço escuro. Brilho quente baixo no teto (a lamparina "vaza" pelo ar) e um toque frio junto ao piso (luar)
	var fill := OmniLight3D.new()
	fill.name = "Preenchimento"
	fill.position = Vector3(w * 0.5, h - 0.5, d * 0.5)
	fill.light_color = Color(1.0, 0.78, 0.55)
	fill.light_energy = 1.15
	fill.omni_range = maxf(w, d) * 1.1
	fill.light_specular = 0.2
	fill.shadow_enabled = true            # a luz geral da sala projeta sombra dos móveis nas paredes (mais realista)
	fill.shadow_blur = 2.0
	fill.shadow_bias = 0.08
	_g.add_child(fill)
	var luar := OmniLight3D.new()
	luar.name = "LuarDoChao"
	luar.position = Vector3(w * 0.5, 0.5, d * 0.5)
	luar.light_color = Color(0.66, 0.70, 0.82)
	luar.light_energy = 0.22
	luar.omni_range = maxf(w, d) * 1.2
	luar.light_specular = 0.0
	_g.add_child(luar)
	# sonda de reflexo da sala: o latão, o vidro e a madeira envernizada refletem o próprio cômodo (e não só o céu da rua)
	var rp := ReflectionProbe.new()
	rp.name = "SondaDeReflexo"
	rp.position = Vector3(w / 2.0, h * 0.5, d / 2.0)
	rp.size = Vector3(w, h, d)
	rp.interior = true
	rp.box_projection = true
	rp.update_mode = ReflectionProbe.UPDATE_ONCE
	rp.intensity = 0.2          # (a 1.0 refletia o céu azul da captura em blocos azuis e brancos nas paredes)
	_g.add_child(rp)


func _area(nome: String, pos: Vector3, size: Vector3, script: String) -> Area3D:
	var a := Area3D.new()
	a.name = nome
	a.position = pos
	a.set_script(load(script))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	a.add_child(cs)
	_g.add_child(a)
	return a


var _tem_tapete := false


## Tapete persa com desenho (textura própria) e franjas; um por sala.
func _tapete(x: float, z: float, lx: float, lz: float, qual := 0, yaw := 0.0, y := 0.0) -> void:
	_tem_tapete = true
	var m := "tapete_a" if qual == 0 else "tapete_b"
	_bb.quad_h(m, Vector2(lx, lz), Vector3(x, y + 0.012, z), yaw)
	var c := cos(yaw)
	var sn := sin(yaw)
	for k in int(lx / 0.12):                                                  # franjas nas duas pontas menores
		var t := -lx * 0.5 + 0.06 + k * 0.12
		for sg: float in [-1.0, 1.0]:
			_bb.box("pano_cru", Vector3(0.02, 0.004, 0.10), Vector3(x + c * t - sn * sg * (lz * 0.5 + 0.05), y + 0.007, z + sn * t + c * sg * (lz * 0.5 + 0.05)), Vector3(0, yaw, 0))


## Objeto para examinar (E): uma frase da história ou um arrepio. Várias frases separadas por " | " alternam a cada exame.
func _examinar(x: float, y: float, z: float, rotulo: String, texto: String, som := "papel", medo := 0.0, tam := Vector3(0.9, 0.9, 0.9)) -> void:
	var a := _area("Examinar_%d" % _g.get_child_count(), Vector3(x, y, z), tam, "res://scripts/examinar.gd")
	a.set("texto_interacao", rotulo)
	a.set("texto", texto)
	a.set("som", som)
	a.set("medo", medo)


## Algo (mobília ou item) já ocupa esta caixa? A casca da sala não conta; a porta de saída e os itens coletáveis contam.
func _ocupado(a: AABB) -> bool:
	for i in range(_n_casca, _bb._boxes.size()):
		if (_bb._boxes[i][1] as AABB).intersects(a):
			return true
	for n in _g.get_children():
		if n is Node3D and n.has_meta("bb"):
			var bb: AABB = n.get_meta("bb")
			var t := n as Node3D
			var c: Vector3 = t.position + t.transform.basis * bb.get_center()
			var r := maxf(bb.size.x, bb.size.z) * 0.5
			if AABB(c - Vector3(r, bb.size.y * 0.5, r), Vector3(r * 2.0, bb.size.y, r * 2.0)).intersects(a):
				return true
		elif n is Area3D:
			var ap := (n as Node3D).position
			if Rect2(a.position.x, a.position.z, a.size.x, a.size.z).grow(0.3).has_point(Vector2(ap.x, ap.z)):
				return true
	# entrada: corredor livre do portal até o centro da sala
	if AABB(Vector3(_w * 0.5 - 1.1, 0.0, 0.0), Vector3(2.2, 3.0, 2.2)).intersects(a):
		return true
	return false


## Detalhes automáticos de acabamento em TODAS as salas: tapete, vasos nos cantos, quadros e relógio nas paredes, crucifixo e teias.
## Só entra onde o espaço está livre (não sobrepõe móvel nem item).
func _decorar() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(_g.name)) + 77
	# 1) tapete persa no meio da sala (ou o primeiro lugar livre), se a sala ainda não tem um
	var tapetes := ["tapete_a", "tapete_b"]
	var cands := [Vector2(_w * 0.5, _d * 0.5), Vector2(_w * 0.5, _d * 0.68), Vector2(_w * 0.35, _d * 0.5), Vector2(_w * 0.65, _d * 0.45)]
	for c in cands:
		if _tem_tapete:
			break
		var lx := minf(2.4, _w * 0.34)
		var lz := minf(1.6, _d * 0.26)
		if not _ocupado(AABB(Vector3(c.x - lx * 0.5, 0.02, c.y - lz * 0.5), Vector3(lx, 0.7, lz))):
			_tapete(c.x, c.y, lx, lz, rng.randi() % 2)
			break
	# 2) vasos de barro com antúrio nos cantos livres (até dois)
	var vasos := 0
	var cantos := [Vector2(0.5, _d - 0.5), Vector2(_w - 0.5, _d - 0.5), Vector2(0.5, 1.9), Vector2(_w - 0.5, 1.9)]
	cantos.shuffle()
	for c in cantos:
		if vasos >= 2:
			break
		if not _ocupado(AABB(Vector3(c.x - 0.32, 0.0, c.y - 0.32), Vector3(0.64, 1.0, 0.64))):
			var yaw := rng.randf() * TAU
			_prop_c("planter_pot_clay", c.x, c.y, yaw, 1.3, 0.0)
			_parte("anthurium_botany_01", [["anthurium_botany_01_a", "anthurium_botany_04_d", "anthurium_botany_05_e", "anthurium_botany_06_f"][vasos % 4]], c.x, c.y, yaw, 0.2, 0.28)
			vasos += 1
	# 3) quadros nas paredes (retratos a óleo): até 3, em lugares livres
	var quadros := 0
	var tentativas := [["O", 0.04, 0.0], ["L", _w - 0.04, 0.0], ["N", 0.0, _d - 0.04], ["O", 0.04, 0.0], ["L", _w - 0.04, 0.0]]
	for t in tentativas:
		if quadros >= 3:
			break
		var lado: String = t[0]
		var ext := _d if lado == "O" or lado == "L" else _w
		var pos := ext * rng.randf_range(0.22, 0.78)
		var qx: float = float(t[1]) if lado == "O" or lado == "L" else pos
		var qz: float = pos if lado == "O" or lado == "L" else float(t[2])
		var caixa := AABB(Vector3(qx - (0.35 if lado == "N" else 0.25), 1.35, qz - (0.35 if lado != "N" else 0.25)), Vector3(0.7 if lado == "N" else 0.5, 0.9, 0.7 if lado != "N" else 0.5))
		if not _ocupado(caixa):
			_quadro(qx, 1.8, qz, lado, 0.42, 0.55)
			quadros += 1
	# 4) relógio de parede na parede norte, se houver espaço
	if _h > 2.8:
		var rx := _w * rng.randf_range(0.3, 0.7)
		if not _ocupado(AABB(Vector3(rx - 0.3, 1.5, _d - 0.4), Vector3(0.6, 1.2, 0.4))):
			_bb.cylinder("ouro_velho", 0.19, 0.19, 0.05, Vector3(rx, 2.15, _d - 0.05), Vector3(PI / 2.0, 0, 0), 18)
			_bb.cylinder("pano_cru", 0.16, 0.16, 0.055, Vector3(rx, 2.15, _d - 0.058), Vector3(PI / 2.0, 0, 0), 18)
			_bb.box("ferro", Vector3(0.015, 0.12, 0.01), Vector3(rx, 2.19, _d - 0.09), Vector3(0, 0, 0.5))
			_bb.box("ferro", Vector3(0.012, 0.09, 0.01), Vector3(rx, 2.15, _d - 0.09), Vector3(0, 0, -1.1))
			_bb.box("madeira_escura", Vector3(0.025, 0.42, 0.02), Vector3(rx, 1.8, _d - 0.05))
			_bb.sphere("ouro_velho", 0.05, Vector3(rx, 1.58, _d - 0.05), 8, 5)
	# 5) crucifixo sobre a porta de saída
	if _h > 3.1:
		_bb.box("madeira_escura", Vector3(0.05, 0.36, 0.03), Vector3(_w * 0.5, 2.9, 0.04))
		_bb.box("madeira_escura", Vector3(0.24, 0.05, 0.03), Vector3(_w * 0.5, 2.98, 0.04))
		_bb.sphere("ouro_velho", 0.025, Vector3(_w * 0.5, 2.98, 0.06), 6, 4)
	_vida(rng)
	# lustre de latão pendurado no centro (corrente do forro): iluminação de casa de verdade
	if _h < 5.0 and String(_g.name) != "casarao" and not _ocupado(AABB(Vector3(_w * 0.5 - 0.5, 1.2, _d * 0.5 - 0.5), Vector3(1.0, 2.0, 1.0))):
		_bb.cylinder("ferro", 0.01, 0.01, 0.9, Vector3(_w * 0.5, _h - 0.45, _d * 0.5), Vector3.ZERO, 6)
		_prop("brass_diya_lantern", _w * 0.5, _d * 0.5, 0.0, 1.5, _h - 1.25)
	# 6) teias de aranha nos cantos do teto (fios finos): sala velha, casa abandonada
	for cx: float in [0.0, _w]:
		for cz: float in [0.0, _d]:
			var sx := 1.0 if cx < 1.0 else -1.0
			var sz := 1.0 if cz < 1.0 else -1.0
			var cy := _h - 0.15
			for k in 4:
				var f := 0.12 + 0.11 * float(k)
				_bb.box("pano_cru", Vector3(0.004, 0.004, f * 1.6), Vector3(cx + sx * 0.02, cy - f * 0.2, cz + sz * f * 0.8))
				_bb.box("pano_cru", Vector3(f * 1.6, 0.004, 0.004), Vector3(cx + sx * f * 0.8, cy - f * 0.2, cz + sz * 0.02))
			for k in 3:
				var a := 0.18 + 0.15 * float(k)
				_bb.box("pano_cru", Vector3(0.004, 0.004, 0.55 - 0.1 * float(k)), Vector3(cx + sx * a * 0.5, cy - a * 0.5, cz + sz * (0.3 - 0.05 * float(k))), Vector3(0, 0, 0))


## Lençol jogado sobre uma cadeira: a casa foi fechada às pressas.
func _lencol(x: float, z: float) -> void:
	_bb.box("pano_cru", Vector3(0.64, 0.035, 0.6), Vector3(x, 0.97, z))
	_bb.box("pano_cru", Vector3(0.66, 0.55, 0.025), Vector3(x, 0.7, z + 0.3), Vector3(-0.08, 0, 0))
	_bb.box("pano_cru", Vector3(0.66, 0.55, 0.025), Vector3(x, 0.7, z - 0.3), Vector3(0.08, 0, 0))
	_bb.box("pano_cru", Vector3(0.025, 0.55, 0.6), Vector3(x + 0.32, 0.7, z), Vector3(0, 0, 0.08))
	_bb.box("pano_cru", Vector3(0.025, 0.55, 0.6), Vector3(x - 0.32, 0.7, z), Vector3(0, 0, -0.08))


## Vestígios de quem morou aqui: lençóis sobre cadeiras, quadro caído, caixas de mudança, relógio parado. Só onde há espaço.
func _vida(rng: RandomNumberGenerator) -> void:
	# uma cadeira tombada no meio da sala, como se alguém tivesse se levantado às pressas
	for t in [Vector2(_w * 0.5, _d * 0.55), Vector2(_w * 0.35, _d * 0.5), Vector2(_w * 0.62, _d * 0.45)]:
		if not _ocupado(AABB(Vector3(t.x - 0.5, 0.0, t.y - 0.5), Vector3(1.0, 0.8, 1.9))):      # deitada ela ocupa ~1,3 m para +z
			var ch := _prop("painted_wooden_chair_02", t.x, t.y, rng.randf() * TAU, 1.0, 0.24)
			ch.rotation.x = PI * 0.5
			break
	# relógio de lareira numa prateleirinha na parede norte
	var pr := PropKit.make("mantel_clock_01", 1.0)
	var hh := maxf((pr.get_meta("bb") as AABB).size.y, 0.05)
	pr.free()
	for fx: float in [0.28, 0.72, 0.5]:
		var cx := _w * fx
		if not _ocupado(AABB(Vector3(cx - 0.4, 1.0, _d - 0.5), Vector3(0.8, 0.8, 0.5))):
			_bb.box("madeira_escura", Vector3(0.75, 0.04, 0.26), Vector3(cx, 1.6, _d - 0.13))
			for sx: float in [-1.0, 1.0]:
				_bb.box("madeira_escura", Vector3(0.04, 0.2, 0.2), Vector3(cx + sx * 0.3, 1.5, _d - 0.12))
			_prop("mantel_clock_01", cx, _d - 0.17, PI, 0.34 / hh, 1.62)
			break
	# quadro caído no chão, de cara para baixo, encostado numa parede
	for t in [Vector2(_w - 0.6, _d * 0.6), Vector2(0.6, _d * 0.45), Vector2(_w * 0.4, _d - 0.5)]:
		if not _ocupado(AABB(Vector3(t.x - 0.35, 0.0, t.y - 0.3), Vector3(0.7, 0.4, 0.6))):
			var yw := rng.randf() * PI
			_bb.box("ouro_velho", Vector3(0.52, 0.03, 0.42), Vector3(t.x, 0.02, t.y), Vector3(0, yw, 0))
			_bb.box("pano_cru", Vector3(0.42, 0.006, 0.32), Vector3(t.x, 0.038, t.y), Vector3(0, yw, 0))
			break
	# caixas de mudança e uma mala num canto livre: alguém ia embora e nunca foi
	for cn in [Vector2(_w - 0.6, _d - 0.6), Vector2(0.6, _d - 0.6), Vector2(_w - 0.6, 1.8)]:
		if not _ocupado(AABB(Vector3(cn.x - 0.55, 0.0, cn.y - 0.55), Vector3(1.1, 1.0, 1.1))):
			_prop_c("cardboard_box_01", cn.x, cn.y, rng.randf() * TAU, 0.9, 0.0)
			_prop("cardboard_box_01", cn.x, cn.y, rng.randf() * TAU, 0.75, 0.38)
			_parte("vintage_suitcase", ["vintage_suitcase_02_"], cn.x + (0.7 if cn.x < _w * 0.5 else -0.7), cn.y, rng.randf() * TAU, 0.7, 0.0)
			break


## Parede de galeria (como nos casarões mineiros): muitos quadros pequenos em grade, com molduras douradas.
func _galeria(lado: String, centro: float, cols: int, rows: int, y0 := 1.35) -> void:
	var mats := ["paisagem_a", "paisagem_b", "foto_antiga"]
	for r in rows:
		for c in cols:
			var along := centro + (c - (cols - 1) * 0.5) * 0.46
			var yy := y0 + r * 0.52
			var m: String = mats[(r * 2 + c) % 3]
			var qx := 0.04
			var qz := 0.0
			match lado:
				"O":
					qx = 0.04
					qz = along
				"L":
					qx = _w - 0.04
					qz = along
				_:
					qx = along
					qz = _d - 0.04
			_quadro(qx, yy, qz, lado, 0.32, 0.4, m)


var _relatorio_linhas: PackedStringArray = []
var _auditoria_linhas: PackedStringArray = []
var _janelas_lat: Array = []           # janelas laterais/fundos da sala em construção: [lado, p, y, w, h]


## Pegada (retângulo no chão + altura) de cada coisa sólida da sala: móveis (colisões "Col*") e modelos (props com "bb").
func _pegadas() -> Array:
	var out: Array = []
	for n in _g.get_children():
		if n is StaticBody3D and String(n.name).begins_with("Col"):
			var cs: CollisionShape3D = n.get_child(0)
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			var c: Vector3 = (n as Node3D).position
			out.append({"nome": String(n.name), "tipo": "mov", "c": c, "sz": sz, "ymin": c.y - sz.y / 2.0, "ymax": c.y + sz.y / 2.0, "no": n})
		elif n is Node3D and n.has_meta("bb"):
			var bb: AABB = n.get_meta("bb")
			var t := n as Node3D
			var esc := t.transform.basis.get_scale()
			var sz2 := Vector3(bb.size.x * esc.x, bb.size.y * esc.y, bb.size.z * esc.z)
			var ctr := t.position + t.transform.basis * bb.get_center()
			var yaw := t.rotation.y
			var ex := absf(cos(yaw)) * sz2.x + absf(sin(yaw)) * sz2.z
			var ez := absf(sin(yaw)) * sz2.x + absf(cos(yaw)) * sz2.z
			var base := t.position.y + bb.position.y * esc.y
			out.append({"nome": String(n.name), "tipo": "prop", "c": ctr, "sz": Vector3(ex, sz2.y, ez), "ymin": base, "ymax": base + sz2.y, "no": n, "yaw": yaw, "caido": absf(t.rotation.x) > 0.1})
	return out


## Auditoria de arrumação da sala (tudo no lugar?). Vai para docs/26-auditoria-salas.md. Mede: fora da sala, atravessando, flutuando,
## cadeiras (de frente para a mesa, ao alcance), móveis de frente para a parede, janelas tapadas, luz dentro de móvel e itens sem apoio.
func _auditar() -> void:
	var sala := String(_g.name)
	var itens := _pegadas()
	var aviso := func(tipo: String, texto: String) -> void:
		_auditoria_linhas.append("| %s | %s | %s |" % [sala, tipo, texto])
	var rect := func(e: Dictionary) -> Rect2:
		var c: Vector3 = e["c"]
		var sz: Vector3 = e["sz"]
		return Rect2(c.x - sz.x / 2.0, c.z - sz.z / 2.0, sz.x, sz.z)
	var mesas: Array = itens.filter(func(e: Dictionary) -> bool: return String(e["nome"]).begins_with("ColMesa") or String(e["nome"]).to_lower().contains("table"))
	for e in itens:
		var r: Rect2 = rect.call(e)
		var nome: String = e["nome"]
		if r.position.x < -0.02 or r.end.x > _w + 0.02 or r.position.y < -0.02 or r.end.y > _d + 0.02:
			aviso.call("FORA DA SALA", "%s (%.2f, %.2f) tamanho %.2f x %.2f" % [nome, (e["c"] as Vector3).x, (e["c"] as Vector3).z, r.size.x, r.size.y])
		if float(e["ymax"]) > _h + 0.02:
			aviso.call("ALTO DEMAIS", "%s topo %.2f m, pé-direito %.2f m" % [nome, float(e["ymax"]), _h])
	# atravessando
	for i in itens.size():
		for j in range(i + 1, itens.size()):
			var a: Dictionary = itens[i]
			var c2: Dictionary = itens[j]
			if bool(a.get("caido", false)) or bool(c2.get("caido", false)):
				continue                                               # cadeira/quadro caído de propósito
			if float(a["ymin"]) >= float(c2["ymax"]) - 0.08 or float(c2["ymin"]) >= float(a["ymax"]) - 0.08:
				continue                                               # um em cima do outro
			var chair_a := String(a["nome"]).to_lower().contains("chair")
			var chair_b := String(c2["nome"]).to_lower().contains("chair")
			if (chair_a and float(c2["ymin"]) >= 0.55) or (chair_b and float(a["ymin"]) >= 0.55):
				continue                                               # objeto em cima da mesa, na altura do encosto da cadeira que está sob ela
			var ra: Rect2 = rect.call(a)
			var rb: Rect2 = rect.call(c2)
			var inter := ra.intersection(rb)
			if inter.size.x <= 0.03 or inter.size.y <= 0.03:
				continue
			var na := String(a["nome"]).to_lower()
			var nb2 := String(c2["nome"]).to_lower()
			var cad_mesa := (na.contains("chair") and (nb2.begins_with("colmesa") or nb2.contains("table"))) or (nb2.contains("chair") and (na.begins_with("colmesa") or na.contains("table")))
			if cad_mesa and minf(inter.size.x, inter.size.y) < 0.24:
				continue                                               # cadeira encaixada sob a mesa (até 24 cm; o encosto não entra)
			if (na.begins_with("colsaco") and nb2.begins_with("sack")) or (nb2.begins_with("colsaco") and na.begins_with("sack")):
				continue                                               # o saco e a colisão dele são a mesma coisa
			aviso.call("ATRAVESSA", "%s (%.2f, %.2f, y %.2f-%.2f) com %s (%.2f, %.2f, y %.2f-%.2f): %.0f x %.0f cm" % [a["nome"], (a["c"] as Vector3).x, (a["c"] as Vector3).z, float(a["ymin"]), float(a["ymax"]), c2["nome"], (c2["c"] as Vector3).x, (c2["c"] as Vector3).z, float(c2["ymin"]), float(c2["ymax"]), inter.size.x * 100.0, inter.size.y * 100.0])
	# flutuando: base acima do chão e nada embaixo (prateleiras e tampos feitos de caixas também apoiam)
	var apoios: Array = []
	for bi in range(_n_casca, _bb._boxes.size()):
		var ab: AABB = _bb._boxes[bi][1]
		if ab.size.x > 0.15 and ab.size.z > 0.1:
			apoios.append(ab)
	for e in itens:
		if float(e["ymin"]) < 0.04 or bool(e.get("caido", false)) or float(e["ymax"]) > _h - 0.45 or float(e["ymin"]) > 3.3 or String(e["nome"]).begins_with("lightbulb") or String(e["nome"]).begins_with("brass_diya_lantern"):
			continue                                                   # no chão, caído, pendurado no teto ou no 2º andar
		var c: Vector3 = e["c"]
		var apoiado := false
		for o in itens:
			if o == e:
				continue
			var ro: Rect2 = rect.call(o)
			if ro.has_point(Vector2(c.x, c.z)) and absf(float(o["ymax"]) - float(e["ymin"])) < 0.12:
				apoiado = true
		for ab2: AABB in apoios:
			if Rect2(ab2.position.x, ab2.position.z, ab2.size.x, ab2.size.z).has_point(Vector2(c.x, c.z)) and absf(ab2.end.y - float(e["ymin"])) < 0.1:
				apoiado = true
		if not apoiado and not String(e["nome"]).begins_with("Col"):
			aviso.call("FLUTUA", "%s a %.0f cm do chão sem apoio embaixo" % [e["nome"], float(e["ymin"]) * 100.0])
	# cadeiras
	for e in itens:
		var nm := String(e["nome"]).to_lower()
		if e["tipo"] != "prop" or not nm.contains("chair") or bool(e.get("caido", false)):
			continue
		var t: Node3D = e["no"]
		var frente := Vector3(1, 0, 0) if nm.contains("painted_wooden_chair") else Vector3(0, 0, 1)
		var fw: Vector3 = t.transform.basis * frente
		var f2 := Vector2(fw.x, fw.z).normalized()
		var c: Vector3 = e["c"]
		var melhor := 99.0
		var ponto := Vector2.ZERO
		for m in mesas:
			var rm: Rect2 = rect.call(m)
			var q := Vector2(clampf(c.x, rm.position.x, rm.end.x), clampf(c.z, rm.position.y, rm.end.y))
			var d := q.distance_to(Vector2(c.x, c.z))
			if d < melhor:
				melhor = d
				ponto = q
		if melhor > 1.0:
			aviso.call("INFO", "%s solta (a %.1f m da mesa mais próxima)" % [e["nome"], melhor])
			continue
		var para := (ponto - Vector2(c.x, c.z))
		if para.length() > 0.05:
			var ang := rad_to_deg(f2.angle_to(para.normalized()))
			if absf(ang) > 25.0:
				aviso.call("CADEIRA TORTA", "%s em (%.2f, %.2f) olha %.0f° fora da mesa" % [e["nome"], c.x, c.z, absf(ang)])
		if melhor > 0.5:
			aviso.call("CADEIRA LONGE", "%s a %.0f cm da borda da mesa (deveria estar sob ela)" % [e["nome"], melhor * 100.0])
	# móveis de frente para a parede (armários, estantes, camas)
	for e in itens:
		var nm2 := String(e["nome"]).to_lower()
		if e["tipo"] != "prop" or not (nm2.contains("cabinet") or nm2.contains("bookshelf") or nm2.contains("rack")):
			continue
		var t2: Node3D = e["no"]
		var fw2: Vector3 = t2.transform.basis * Vector3(0, 0, 1)
		var c3: Vector3 = e["c"]
		var r3: Rect2 = rect.call(e)
		var gaps := {"O": r3.position.x, "L": _w - r3.end.x, "S": r3.position.y, "N": _d - r3.end.y}
		var mais := "O"
		for k in gaps:
			if float(gaps[k]) < float(gaps[mais]):
				mais = k
		var into := {"O": Vector3(1, 0, 0), "L": Vector3(-1, 0, 0), "S": Vector3(0, 0, 1), "N": Vector3(0, 0, -1)}[mais] as Vector3
		if float(gaps[mais]) < 0.6 and fw2.normalized().dot(into) < 0.7:
			aviso.call("DE COSTAS PARA A SALA", "%s (parede %s a %.0f cm) com a frente virada para a parede" % [e["nome"], mais, float(gaps[mais]) * 100.0])
		if float(gaps[mais]) > 0.03 and float(gaps[mais]) < 0.16:
			aviso.call("QUASE ENCOSTADO", "%s a %.0f cm da parede %s (nem colado, nem solto)" % [e["nome"], float(gaps[mais]) * 100.0, mais])
	# janelas laterais tapadas por móvel alto
	for jn in _janelas_lat:
		var lado: String = jn[0]
		var pj: float = jn[1]
		var wj: float = jn[3]
		for e in itens:
			if float(e["ymax"]) < float(jn[2]) - float(jn[4]) / 2.0:
				continue
			var r4: Rect2 = rect.call(e)
			var perto := false
			match lado:
				"O":
					perto = r4.position.x < 0.5 and r4.position.y < pj + wj / 2.0 and r4.end.y > pj - wj / 2.0
				"L":
					perto = r4.end.x > _w - 0.5 and r4.position.y < pj + wj / 2.0 and r4.end.y > pj - wj / 2.0
				_:
					perto = r4.end.y > _d - 0.5 and r4.position.x < pj + wj / 2.0 and r4.end.x > pj - wj / 2.0
			if perto:
				aviso.call("TAPA A JANELA", "%s na janela %s (posição %.2f)" % [e["nome"], lado, pj])
	# luzes dentro de móvel
	for n in _g.get_children():
		if n is OmniLight3D and (n as OmniLight3D).light_energy > 0.3:
			var lp := (n as Node3D).position
			for e in itens:
				var c5: Vector3 = e["c"]
				var sz5: Vector3 = e["sz"]
				if absf(lp.x - c5.x) < sz5.x / 2.0 - 0.03 and absf(lp.z - c5.z) < sz5.z / 2.0 - 0.03 and lp.y > float(e["ymin"]) + 0.03 and lp.y < float(e["ymax"]) - 0.03:
					aviso.call("LUZ DENTRO DE MÓVEL", "%s em (%.2f, %.2f, %.2f) dentro de %s" % [n.name, lp.x, lp.y, lp.z, e["nome"]])
					break
	# itens (coletáveis/examináveis) dentro de móvel
	for n in _g.get_children():
		if n is Area3D and String(n.name) != "Saida" and not String(n.name).begins_with("Examinar"):
			var ap0 := (n as Node3D).position
			if ap0.y < 0.02:
				continue
			var ap := (n as Node3D).position
			for e in itens:
				if bool(e.get("caido", false)):
					continue
				var c6: Vector3 = e["c"]
				var sz6: Vector3 = e["sz"]
				if absf(ap.x - c6.x) < sz6.x / 2.0 - 0.02 and absf(ap.z - c6.z) < sz6.z / 2.0 - 0.02 and ap.y > float(e["ymin"]) + 0.05 and ap.y < float(e["ymax"]) - 0.05:
					aviso.call("ITEM DENTRO DE MÓVEL", "%s em (%.2f, %.2f, %.2f) dentro de %s" % [n.name, ap.x, ap.y, ap.z, e["nome"]])
					break


## Medida de cada móvel/objeto de modelo da sala: centro, dimensões, giro e distância (em mm) até a parede mais próxima. Sai no log do bake.
func _relatorio() -> void:
	for n in _g.get_children():
		if not (n is Node3D and n.has_meta("bb")):
			continue
		var bb: AABB = n.get_meta("bb")
		var t := n as Node3D
		var sz := bb.size
		var yaw_deg := rad_to_deg(t.rotation.y)
		var quarto := absf(fposmod(yaw_deg + 45.0, 90.0) - 45.0) < 0.5            # girado em múltiplo de 90°?
		var ext := Vector2(sz.x, sz.z)
		if absf(fposmod(yaw_deg, 180.0) - 90.0) < 45.0:
			ext = Vector2(sz.z, sz.x)
		var c := Vector2(t.position.x, t.position.z)
		var gap := minf(minf(c.x - ext.x * 0.5, _w - c.x - ext.x * 0.5), minf(c.y - ext.y * 0.5, _d - c.y - ext.y * 0.5))
		_relatorio_linhas.append("| %s | %s | (%.3f, %.3f) | %.3f x %.3f x %.3f | %.1f° | %s | %d mm |" % [String(_g.name), String(n.name).split("_")[0], c.x, c.y, sz.x, sz.y, sz.z, yaw_deg, "sim" if quarto else "NÃO", int(gap * 1000.0)])


func _fim() -> void:
	_relatorio()
	if na_rua:
		_parede_frente()
	_decorar()
	_auditar()
	for pc in _bb.coplanares(8, AABB(Vector3.ZERO, Vector3(_w, _h, _d))):
		_auditoria_linhas.append("| %s | PISCA (faces coplanares) | %s |" % [String(_g.name), pc])
	b._mesh_node(_g, "Mobilia", _bb.commit())


## Janela na parede: lado "L" (x = largura), "O" (x = 0) ou "N" (z = profundidade); `p` = posição ao longo da parede.
## Estilo colonial mineiro: portas-balcão altas em arco com folhas de madeira verde abertas, caixilhos e, atrás do vidro, a vista noturna do
## vale com a igreja e o guarda-corpo de ferro forjado.
func _janela(lado: String, p: float, y := 1.6, w := 1.0, h := 1.3) -> void:
	_janelas_lat.append([lado, p, y, w, h])
	var pos := Vector3.ZERO
	var yaw := 0.0
	var inw := 1.0                                   # sentido "para dentro da sala"
	match lado:
		"O":
			yaw = PI / 2.0
			inw = 1.0
		"L":
			yaw = -PI / 2.0
			inw = -1.0
		_:
			yaw = PI
	var alto := _h >= 3.1 and lado != "N" and h < 2.0 and _h < 7.0
	if alto:
		h = 2.1
		y = 0.3 + h * 0.5
	match lado:
		"O":
			pos = Vector3(0.02, y, p)
		"L":
			pos = Vector3(_w - 0.02, y, p)
		_:
			pos = Vector3(p, y, _d - 0.02)
	# nas casas da rua só a parede da frente dá para a rua de verdade; as janelas laterais e dos fundos ficam com as folhas fechadas
	_bb.quad("madeira_verde" if na_rua else "vista_noite", Vector2(w, h), pos, yaw)
	var dir := Vector3(sin(yaw), 0, cos(yaw))
	var side := Vector3(dir.z, 0, -dir.x)
	var verde := "madeira_verde"
	for k: float in [-1.0, 1.0]:                                                                       # batentes
		_bb.box(verde, Vector3(0.10, h + 0.1, 0.10) if lado != "N" else Vector3(0.10, h + 0.1, 0.08), pos + dir * 0.04 + side * k * (w / 2.0 + 0.04))
	_bb.box(verde, Vector3(0.10, 0.10, w + 0.18) if lado != "N" else Vector3(w + 0.18, 0.10, 0.08), pos + dir * 0.04 + Vector3(0, h / 2.0 + 0.04, 0))
	if lado != "N":                                                                              # arco de madeira sobre a verga (portas-balcão)
		var topy: float = y + h / 2.0 + 0.09
		if topy + w * 0.5 < _h - 0.1:
			_bb.arch(verde, Vector3(pos.x + dir.x * 0.04, topy, pos.z), w / 2.0 + 0.04, 0.07, 0.10, 12)
	# caixilhos: cruz e travessas
	var along := side.abs()
	for fr in [0.0, 0.33, -0.33]:
		_bb.box(verde, Vector3(0.03 + along.x * w, 0.035, 0.03 + along.z * w), pos + dir * 0.035 + Vector3(0, fr * h, 0))
	_bb.box(verde, Vector3(0.035, h, 0.035), pos + dir * 0.035)
	# folhas de madeira verde abertas para dentro, em ângulo (venezianas / folhas da porta-balcão)
	for k: float in [-1.0, 1.0]:
		var hinge := pos + dir * 0.06 + side * k * (w / 2.0 + 0.06)
		if lado != "N":
			var th := 1.15
			var vec := dir * sin(th) - side * k * cos(th)
			var c := hinge + vec * (w * 0.25)
			var phi := atan2(vec.x, vec.z)
			_bb.box(verde, Vector3(0.04, h, w * 0.5), c, Vector3(0, phi, 0))
			_bb.box("madeira_natural", Vector3(0.05, h * 0.78, w * 0.36), c + dir * 0.0, Vector3(0, phi, 0))
		else:
			_bb.box(verde, Vector3(w * 0.5, h, 0.04), hinge + side * k * (w * 0.25) * 1.0 + dir * 0.02)
	# peitoril de pedra
	var sill := Vector3(0.16, 0.05, w + 0.3) if lado != "N" else Vector3(w + 0.3, 0.05, 0.16)
	_bb.box("cantaria", sill, pos + dir * 0.09 + Vector3(0, -h / 2.0 - 0.03, 0))
	# luar frio entrando (sem sombra): pequena luz azul
	var l := OmniLight3D.new()
	l.position = pos + dir * 0.8
	l.light_color = Color(0.62, 0.70, 0.88)
	l.light_energy = 0.3
	l.omni_range = 6.0
	_g.add_child(l)

const PORTA_MEIA := 0.75               # meia largura do vão da porta (medidas de sala, antes da ampliação)
const PORTA_ALTA := 2.45
const JAN_W := 0.9                     # janela da frente (a mesma medida é usada na fachada da casa)
const JAN_H := 1.3


## Parede da frente das salas de rua: vão da porta e janelas VAZADAS de verdade (o vidro fica na fachada da casa, a rua aparece do lado de dentro
## e a sala aparece do lado de fora). As janelas só entram onde não há móvel encostado.
func _parede_frente() -> void:
	var w := _w
	var h := _h
	var vaos: Array = [[w / 2.0 - PORTA_MEIA, w / 2.0 + PORTA_MEIA, 0.0, PORTA_ALTA]]
	var jans: Array = []
	var yc := minf(1.6, (_andar_sup if _andar_sup > 0.0 else h) - 1.15)
	if _andar_sup > 0.0:                                         # 2º andar: janelas no meio de cada trecho entre divisórias
		var cortes: Array[float] = [2.3]
		cortes.append_array(_divisorias_x)
		cortes.append(w - 0.4)
		cortes.sort()
		var yc2 := _andar_sup + 1.6
		for i in cortes.size() - 1:
			var a0: float = cortes[i] + 0.5
			var a1: float = cortes[i + 1] - 0.5
			if a1 - a0 < JAN_W:
				continue
			var xc2 := (a0 + a1) * 0.5
			if _ocupado(AABB(Vector3(xc2 - 0.6, yc2 - 0.65, 0.0), Vector3(1.2, 1.3, 0.5))):
				continue
			jans.append({"x": xc2, "y": yc2, "w": JAN_W, "h": JAN_H})
			vaos.append([xc2 - JAN_W * 0.43, xc2 + JAN_W * 0.43, yc2 - JAN_H * 0.44, yc2 + JAN_H * 0.44])
	for lado in 2:
		var x0 := 0.75 if lado == 0 else w / 2.0 + PORTA_MEIA + 0.55
		var x1 := w / 2.0 - PORTA_MEIA - 0.55 if lado == 0 else w - 0.75
		if x1 - x0 < JAN_W * 0.9:
			continue
		var n := maxi(1, int(round((x1 - x0) / 2.3)))
		for k in n:
			var xc := x0 + (k + 0.5) * (x1 - x0) / n
			if _ocupado(AABB(Vector3(xc - 0.6, yc - 0.65, 0.0), Vector3(1.2, 1.3, 0.5))):      # só conta o que bloqueia a janela (móvel baixo embaixo dela não)
				continue
			jans.append({"x": xc, "y": yc, "w": JAN_W, "h": JAN_H})
			vaos.append([xc - JAN_W * 0.43, xc + JAN_W * 0.43, yc - JAN_H * 0.44, yc + JAN_H * 0.44])
	# paredes em faixas: para cada intervalo entre bordas de vão, as partes maciças acima/abaixo dos vãos
	var xs: Array[float] = [-0.3, w + 0.3]
	for v in vaos:
		xs.append(float(v[0]))
		xs.append(float(v[1]))
	xs.sort()
	for i in xs.size() - 1:
		var xa: float = xs[i]
		var xb: float = xs[i + 1]
		if xb - xa < 0.002:
			continue
		var cortes: Array = []
		for v in vaos:
			if float(v[0]) <= xa + 0.001 and float(v[1]) >= xb - 0.001:
				cortes.append([float(v[2]), float(v[3])])
		cortes.sort_custom(func(m: Array, n2: Array) -> bool: return float(m[0]) < float(n2[0]))
		var y := -0.2
		for c in cortes:
			if float(c[0]) - y > 0.01:
				_bb.box(_parede_mat, Vector3(xb - xa, float(c[0]) - y, 0.3), Vector3((xa + xb) / 2.0, (y + float(c[0])) / 2.0, -0.15))
			y = maxf(y, float(c[1]))
		if h + 0.2 - y > 0.01:
			_bb.box(_parede_mat, Vector3(xb - xa, h + 0.2 - y, 0.3), Vector3((xa + xb) / 2.0, (y + h + 0.2) / 2.0, -0.15))
	# colisão: a parede toda, menos o vão da porta (que tem um bloqueio próprio, tirado quando a porta abre)
	var xp0 := w / 2.0 - PORTA_MEIA
	var xp1 := w / 2.0 + PORTA_MEIA
	b._blocker(_g, "ParedeS_E", Vector3(xp0 + 0.3, h + 0.4, 0.4), Vector3((xp0 - 0.3) / 2.0, h / 2.0, -0.2))
	b._blocker(_g, "ParedeS_D", Vector3(w + 0.3 - xp1, h + 0.4, 0.4), Vector3((xp1 + w + 0.3) / 2.0, h / 2.0, -0.2))
	b._blocker(_g, "ParedeS_Verga", Vector3(PORTA_MEIA * 2.0, h + 0.2 - PORTA_ALTA, 0.4), Vector3(w / 2.0, (PORTA_ALTA + h + 0.2) / 2.0, -0.2))
	b._blocker(_g, "BloqueioPorta", Vector3(PORTA_MEIA * 2.0, PORTA_ALTA, 0.4), Vector3(w / 2.0, PORTA_ALTA / 2.0, -0.2))
	# batente da porta, por dentro
	for sg: float in [-1.0, 1.0]:
		_bb.box("cantaria", Vector3(0.12, PORTA_ALTA + 0.1, 0.34), Vector3(w / 2.0 + sg * (PORTA_MEIA + 0.05), (PORTA_ALTA + 0.1) / 2.0 - 0.05, -0.15))      # entra 1 cm no vão: sem faces coplanares (piscavam)
	_bb.box("cantaria", Vector3(PORTA_MEIA * 2.0 + 0.24, 0.12, 0.34), Vector3(w / 2.0, PORTA_ALTA + 0.05, -0.15))
	# guarnições das janelas, por dentro
	for j in jans:
		var xc: float = j["x"]
		var yj: float = j["y"]
		var hw := JAN_W * 0.43
		var hh := JAN_H * 0.44
		for sg: float in [-1.0, 1.0]:
			_bb.box("madeira_verde", Vector3(0.06, hh * 2.0 + 0.12, 0.34), Vector3(xc + sg * (hw + 0.02), yj, -0.15))      # 1 cm para dentro do vão: sem faces coplanares com a parede
		_bb.box("madeira_verde", Vector3(hw * 2.0 + 0.12, 0.06, 0.34), Vector3(xc, yj + hh + 0.02, -0.15))
		_bb.box("madeira_verde", Vector3(hw * 2.0 + 0.12, 0.06, 0.34), Vector3(xc, yj - hh - 0.02, -0.15))
		_bb.box("cantaria", Vector3(hw * 2.0 + 0.3, 0.05, 0.2), Vector3(xc, yj - hh - 0.08, 0.06))               # peitoril por dentro
	_g.set_meta("aberturas", jans)
	_g.set_meta("porta_x", w / 2.0)


## Parede interna (divisória) com vãos de porta (1,1 m x 2,15 m), batentes e colisão. eixo "x": vai de (a, fixo) a (b, fixo) ao longo de x;
## eixo "z": de (fixo, a) a (fixo, b) ao longo de z. y0/y1 = piso e teto daquele andar.
func _divisoria(eixo: String, fixo: float, a: float, fim: float, y0: float, y1: float, portas: Array = [], esp := 0.14) -> void:
	var furos: Array = []
	for pt in portas:
		furos.append([float(pt) - 0.55, float(pt) + 0.55])
	furos.sort_custom(func(m: Array, n2: Array) -> bool: return float(m[0]) < float(n2[0]))
	var cur := a
	var pecas: Array = []                                   # [s0, s1, ya, yb]
	for f in furos:
		if float(f[0]) - cur > 0.01:
			pecas.append([cur, float(f[0]), y0, y1])
		pecas.append([float(f[0]), float(f[1]), y0 + 2.15, y1])           # verga sobre a porta
		cur = float(f[1])
	if fim - cur > 0.01:
		pecas.append([cur, fim, y0, y1])
	for pc in pecas:
		var s0: float = pc[0]
		var s1: float = pc[1]
		var ya: float = pc[2]
		var yb: float = pc[3]
		if yb - ya < 0.01:
			continue
		var c := Vector3((s0 + s1) * 0.5, (ya + yb) * 0.5, fixo) if eixo == "x" else Vector3(fixo, (ya + yb) * 0.5, (s0 + s1) * 0.5)
		var sz := Vector3(s1 - s0, yb - ya, esp) if eixo == "x" else Vector3(esp, yb - ya, s1 - s0)
		_bb.box(_parede_mat, sz, c)
		b._blocker(_g, "ColDivisoria", sz, c)
		var rd := Vector3(s1 - s0 - 0.02, 0.12, esp + 0.04) if eixo == "x" else Vector3(esp + 0.04, 0.12, s1 - s0 - 0.02)
		if ya <= y0 + 0.01:
			_bb.box("madeira_escura", rd, Vector3(c.x, y0 + 0.06, c.z))       # rodapé dos dois lados
	for f in furos:                                                          # batentes de madeira em volta de cada vão
		var m0: float = f[0]
		var m1: float = f[1]
		for mm: float in [m0 + 0.04, m1 - 0.04]:
			var pj := Vector3(mm, y0 + 1.07, fixo) if eixo == "x" else Vector3(fixo, y0 + 1.07, mm)
			_bb.box("madeira_escura", Vector3(0.08, 2.15, esp + 0.06) if eixo == "x" else Vector3(esp + 0.06, 2.15, 0.08), pj)
		var pv := Vector3((m0 + m1) * 0.5, y0 + 2.11, fixo) if eixo == "x" else Vector3(fixo, y0 + 2.11, (m0 + m1) * 0.5)
		_bb.box("madeira_escura", Vector3(m1 - m0, 0.08, esp + 0.06) if eixo == "x" else Vector3(esp + 0.06, 0.08, m1 - m0), pv)
	if eixo == "z" and a < 0.3:
		_divisorias_x.append(fixo)


## Laje do 2º andar (retângulo x0..x1, z0..z1): piso de tacos por cima, forro de tábuas por baixo e colisão.
func _laje(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var c := Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
	_bb.box("piso_taco", Vector3(x1 - x0, 0.05, z1 - z0), Vector3(c.x, y - 0.025, c.z))
	_bb.box("forro_tabuas", Vector3(x1 - x0, 0.22, z1 - z0), Vector3(c.x, y - 0.16, c.z))
	b._blocker(_g, "PisoSuperior", Vector3(x1 - x0, 0.5, z1 - z0), Vector3(c.x, y - 0.25, c.z))


func _lamparina(x: float, y: float, z: float, energia := 0.85) -> void:
	y = _topo(x, y, z)
	_prop("vintage_oil_lamp", x, z, float(int(x * 10.0 + z * 7.0) % 6) * 1.05, 0.40, y)      # lamparina de óleo de verdade (Poly Haven, CC0)
	var l := b._lamp_light(_g, Vector3(x, y + 0.36, z), energia * 1.5)
	l.omni_range = 8.0
	l.shadow_blur = 2.5
	l.shadow_enabled = true            # a lamparina projeta sombras dos móveis: o cômodo ganha volume
	b._halo(_g, Vector3(x, y + 0.24, z), 0.9, "halo_vela")


func _vela(x: float, y: float, z: float, luz := false) -> void:
	_bb.cylinder("vela", 0.018, 0.018, 0.14, Vector3(x, y + 0.07, z), Vector3.ZERO, 6)
	_bb.sphere("chama", 0.022, Vector3(x, y + 0.165, z), 5, 3)
	b._halo(_g, Vector3(x, y + 0.17, z), 0.35, "halo_vela")
	if luz:
		var l := b._lamp_light(_g, Vector3(x, y + 0.3, z), 0.5)
		l.omni_range = 4.5



# ------------------------------------------------------------------ medição e encosto milimétrico
## Dimensões reais (m) do modelo já com a escala: x = largura, y = altura, z = profundidade (medidas do .glb).
## Frentes medidas nos modelos: cadeira painted_wooden_chair_02 olha para +X; gabinete, estante, cama (cabeceira em -Z), sofá-cama,
## poltrona e cadeira gótica olham para +Z. Por isso o encosto usa a TRASEIRA (-Z local) voltada para a parede.
var _dims_cache: Dictionary = {}


func _dim(key: String, escala := 1.0) -> Vector3:
	var k := "%s@%.3f" % [key, escala]
	if not _dims_cache.has(k):
		var pr := PropKit.make(key, escala)
		_dims_cache[k] = (pr.get_meta("bb") as AABB).size
		pr.free()
	return _dims_cache[k]


## Cadeira (modelo painted_wooden_chair_02). `olha` = direção para onde a cadeira olha: 0 = +Z, PI = -Z, PI/2 = +X, -PI/2 = -X.
func _cadeira(x: float, z: float, olha := 0.0, _mat := "madeira_natural") -> void:
	_cadeiras.append(Vector2(x, z))
	_prop("painted_wooden_chair_02", x, z, olha - PI / 2.0, 1.0)      # a frente do modelo é +X; o ângulo compensa


## Cadeira JUNTO da mesa, encaixada embaixo do tampo (assento 17 cm sob a mesa, encosto livre). lado: "S","N" (mesa ao norte/sul da cadeira) ou "O","L".
## (tx, tz) = centro da mesa; tw = comprimento em X; td = profundidade em Z; `ao_longo` = deslocamento ao longo da borda.
func _cadeira_mesa(tx: float, tz: float, tw: float, td: float, lado: String, ao_longo := 0.0) -> void:
	var cd := _dim("painted_wooden_chair_02").x
	var d := cd * 0.5 - 0.17          # cadeira empurrada para baixo da mesa: o assento entra 17 cm sob o tampo; o encosto fica fora
	match lado:
		"S":
			_cadeira(tx + ao_longo, tz - td * 0.5 - d, 0.0)
		"N":
			_cadeira(tx + ao_longo, tz + td * 0.5 + d, PI)
		"O":
			_cadeira(tx - tw * 0.5 - d, tz + ao_longo, PI / 2.0)
		_:
			_cadeira(tx + tw * 0.5 + d, tz + ao_longo, -PI / 2.0)


## Encosta um móvel de modelo na parede mais próxima de (x, z): traseira (-Z local) rente à parede (folga de 2 cm) e eixo alinhado.
func _encostar_auto(key: String, x: float, z: float, escala := 1.0, y := 0.0, colide := true) -> Node3D:
	var dm := _dim(key, escala)
	var dist := {"S": z, "N": _d - z, "O": x, "L": _w - x}
	var parede := "S"
	for k in dist:
		if dist[k] < dist[parede]:
			parede = k
	var folga := 0.02
	var pos := Vector2(x, z)
	var yaw := 0.0
	match parede:
		"S":
			pos.y = folga + dm.z * 0.5
			yaw = 0.0
		"N":
			pos.y = _d - folga - dm.z * 0.5
			yaw = PI
		"O":
			pos.x = folga + dm.z * 0.5
			yaw = PI / 2.0
		_:
			pos.x = _w - folga - dm.z * 0.5
			yaw = -PI / 2.0
	return _prop_c(key, pos.x, pos.y, yaw, escala, y) if colide else _prop(key, pos.x, pos.y, yaw, escala, y)


## Cama de caixas (1,0 x 2,0 m) com a cabeceira rente à parede `parede` e o lado maior perpendicular a ela.
func _cama_enc(parede: String, ao_longo: float, colcha := "pano_azul") -> void:
	var folga := 0.02
	var meia := 1.06                       # meio comprimento da cama (colisão 2,1 m): a cabeceira encosta na parede sem entrar nela
	match parede:
		"N":
			_cama(ao_longo, _d - folga - meia, 0.0, colcha)
		"S":
			_cama(ao_longo, folga + meia, PI, colcha)
		"O":
			_cama(folga + meia, ao_longo, -PI / 2.0, colcha)
		_:
			_cama(_w - folga - meia, ao_longo, PI / 2.0, colcha)


# ------------------------------------------------------------------ móveis (todos giram em torno de `yaw`)

func _bx(mat: String, c: Vector3, yaw: float, local: Vector3, size: Vector3) -> void:
	_bb.box(mat, size, c + Basis(Vector3.UP, yaw) * local, Vector3(0, yaw, 0))


func _mesa(x: float, z: float, w := 1.5, dd := 0.85, h := 0.78, mat := "madeira_escura", yaw := 0.0) -> void:
	var c := Vector3(x, 0, z)
	_bx(mat, c, yaw, Vector3(0, h, 0), Vector3(w, 0.07, dd))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bx(mat, c, yaw, Vector3(sx * (w / 2.0 - 0.07), h / 2.0, sz * (dd / 2.0 - 0.07)), Vector3(0.08, h, 0.08))
	if int(round(yaw / (PI / 2.0))) % 2 == 0:
		b._blocker(_g, "ColMesa", Vector3(w, h, dd), Vector3(x, h / 2.0, z))
	else:
		b._blocker(_g, "ColMesa", Vector3(dd, h, w), Vector3(x, h / 2.0, z))


func _cama(x: float, z: float, yaw := 0.0, colcha := "pano_azul") -> void:
	var c := Vector3(x, 0, z)
	_bx("madeira_escura", c, yaw, Vector3(0, 0.3, 0), Vector3(1.0, 0.1, 2.0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bx("madeira_escura", c, yaw, Vector3(sx * 0.48, 0.15, sz * 0.97), Vector3(0.07, 0.3, 0.07))
	_bx("madeira_escura", c, yaw, Vector3(0, 0.7, 1.0), Vector3(1.04, 0.8, 0.06))        # cabeceira
	_bx("pano_cru", c, yaw, Vector3(0, 0.42, 0), Vector3(0.94, 0.14, 1.9))               # colchão
	_bx(colcha, c, yaw, Vector3(0, 0.5, -0.3), Vector3(0.98, 0.04, 1.2))                 # coberta
	_bx("pano_cru", c, yaw, Vector3(0, 0.52, 0.78), Vector3(0.7, 0.12, 0.34))            # travesseiro
	b._blocker(_g, "ColCama", Vector3(1.1, 0.7, 2.1) if int(round(yaw / (PI / 2.0))) % 2 == 0 else Vector3(2.1, 0.7, 1.1), Vector3(x, 0.35, z))


func _armario(x: float, z: float, w := 1.3, h := 2.0, dd := 0.55, yaw := 0.0, mat := "madeira_escura") -> void:
	var c := Vector3(x, 0, z)
	_bx(mat, c, yaw, Vector3(0, h / 2.0, 0), Vector3(w, h, dd))
	_bx("madeira_natural", c, yaw, Vector3(0, h / 2.0, dd / 2.0 + 0.01), Vector3(0.03, h - 0.2, 0.03))
	_bx("ferro", c, yaw, Vector3(-0.08, h * 0.5, dd / 2.0 + 0.03), Vector3(0.04, 0.04, 0.04))
	_bx("ferro", c, yaw, Vector3(0.08, h * 0.5, dd / 2.0 + 0.03), Vector3(0.04, 0.04, 0.04))
	b._blocker(_g, "ColArmario", Vector3(w, h, dd) if int(round(yaw / (PI / 2.0))) % 2 == 0 else Vector3(dd, h, w), Vector3(x, h / 2.0, z))


func _prateleira(x: float, y: float, z: float, w: float, yaw := 0.0, garrafas := 0) -> void:
	var c := Vector3(x, y, z)
	_bx("madeira_natural", c, yaw, Vector3.ZERO, Vector3(w, 0.04, 0.3))
	for k in garrafas:
		var lx := -w / 2.0 + 0.15 + k * (w - 0.3) / maxf(garrafas - 1, 1.0)
		var p: Vector3 = c + Basis(Vector3.UP, yaw) * Vector3(lx, 0.14, 0)
		_bb.cylinder("vidro_oleo", 0.04, 0.04, 0.24, p, Vector3.ZERO, 7)
		_bb.cylinder("vidro_oleo", 0.015, 0.02, 0.07, p + Vector3(0, 0.15, 0), Vector3.ZERO, 6)


func _balcao(x: float, z: float, w: float, yaw := 0.0) -> void:
	var c := Vector3(x, 0, z)
	_bx("madeira_escura", c, yaw, Vector3(0, 0.5, 0), Vector3(w, 1.0, 0.7))
	_bx("madeira_natural", c, yaw, Vector3(0, 1.02, 0.02), Vector3(w + 0.1, 0.06, 0.82))
	for k in int(w / 0.9):
		_bx("madeira_natural", c, yaw, Vector3(-w / 2.0 + 0.45 + k * 0.9, 0.5, 0.36), Vector3(0.78, 0.84, 0.02))
	b._blocker(_g, "ColBalcao", Vector3(w, 1.0, 0.8) if int(round(yaw / (PI / 2.0))) % 2 == 0 else Vector3(0.8, 1.0, w), Vector3(x, 0.5, z))


func _fogao(x: float, z: float, yaw := 0.0) -> void:
	var c := Vector3(x, 0, z)
	_bx("cantaria", c, yaw, Vector3(0, 0.45, 0), Vector3(1.3, 0.9, 0.8))
	_bx("ferro", c, yaw, Vector3(0, 0.92, 0), Vector3(1.2, 0.04, 0.7))
	_bx("chama", c, yaw, Vector3(0, 0.45, 0.405), Vector3(0.4, 0.22, 0.02))                  # boca em brasa
	_bx("cantaria", c, yaw, Vector3(0, 2.0, -0.1), Vector3(0.7, 2.2, 0.55))                  # chaminé
	var l := b._lamp_light(_g, c + Basis(Vector3.UP, yaw) * Vector3(0, 0.6, 0.7), 0.7)
	l.light_color = Color(1.0, 0.45, 0.15)
	l.omni_range = 5.0
	b._blocker(_g, "ColFogao", Vector3(1.3, 0.9, 0.8) if int(round(yaw / (PI / 2.0))) % 2 == 0 else Vector3(0.8, 0.9, 1.3), Vector3(x, 0.45, z))


func _saco(x: float, z: float, yaw := 0.0) -> void:
	# sacos de pano do kit "Medieval Containers" (CC0)
	b._cont(_g, "Sack1" if int(x * 10.0) % 2 == 0 else "Sack2", Vector3(x, 0, z), yaw, 1.0, false)
	b._blocker(_g, "ColSaco", Vector3(0.5, 0.45, 0.4), Vector3(x, 0.22, z))


## Recipiente do kit "Medieval Containers" (CC0) numa posição da sala; `y` para pôr em cima de móvel/caixote.
func _cont(prefixo: String, x: float, z: float, yaw := 0.0, y := 0.0, escala := 1.0, colide := true) -> Node3D:
	return b._cont(_g, prefixo, Vector3(x, y, z), yaw, escala, colide)


func _quadro(x: float, y: float, z: float, lado: String, w := 0.5, h := 0.65, mat := "placa_preta") -> void:
	var dir := Vector3.ZERO
	var yaw := 0.0
	var p := Vector3(x, y, z)
	match lado:
		"O":
			yaw = PI / 2.0
		"L":
			yaw = -PI / 2.0
		"N":
			yaw = PI
		_:
			yaw = 0.0
	dir = Vector3(sin(yaw), 0, cos(yaw))
	if mat == "placa_preta":
		mat = ["paisagem_a", "paisagem_b", "foto_antiga"][int(absf(x * 7.0 + z * 3.0)) % 3]      # paisagens a óleo e fotos antigas (sem rostos)
	_bb.box("ouro_velho", Vector3(w + 0.08, h + 0.08, 0.03), p + dir * 0.02, Vector3(0, yaw, 0))
	_bb.quad(mat, Vector2(w, h), p + dir * 0.04, yaw)


func _oratorio(x: float, z: float) -> void:
	# ORATÓRIO colonial na parede norte: mesa de altar com almofadas entalhadas, retábulo com colunas, arco dourado, nicho forrado de roxo,
	# a imagem da santa (modelo de verdade), crucifixo, castiçais, ramo de flores e cortininha. (Antes eram só caixas: parecia Minecraft.)
	var zw := z + 0.195                                   # face da parede
	var zf := zw - 0.20                                   # frente do altar
	# soco e mesa
	_bb.box("cantaria", Vector3(1.75, 0.10, 0.50), Vector3(x, 0.05, zw - 0.25))
	_bb.box("madeira_escura", Vector3(1.55, 0.78, 0.42), Vector3(x, 0.49, zw - 0.21))
	_bb.box("madeira_natural", Vector3(1.70, 0.07, 0.52), Vector3(x, 0.925, zw - 0.26))              # tampo
	_bb.box("ouro_velho", Vector3(1.64, 0.02, 0.50), Vector3(x, 0.965, zw - 0.26))                      # filete dourado
	for k in 3:                                                                                          # almofadas entalhadas na frente
		var px := x + (k - 1) * 0.48
		_bb.box("madeira_natural", Vector3(0.40, 0.56, 0.03), Vector3(px, 0.49, zw - 0.435))
		_bb.box("madeira_escura", Vector3(0.32, 0.46, 0.035), Vector3(px, 0.49, zw - 0.44))
		_bb.box("ouro_velho", Vector3(0.40, 0.014, 0.036), Vector3(px, 0.77, zw - 0.44))
		_bb.box("ouro_velho", Vector3(0.40, 0.014, 0.036), Vector3(px, 0.21, zw - 0.44))
	# retábulo: fundo, pilastras, colunas e arco
	_bb.box("madeira_escura", Vector3(1.50, 1.30, 0.10), Vector3(x, 1.65, zw - 0.05))
	_bb.box("pano_roxo", Vector3(1.04, 1.05, 0.02), Vector3(x, 1.52, zw - 0.105))                       # nicho forrado
	_arco_xy("pano_roxo", Vector3(x, 2.04, zw - 0.105), 0.50, 0.03, 0.02, 14)
	_bb.box("pano_roxo", Vector3(1.0, 0.04, 0.02), Vector3(x, 2.06, zw - 0.105))
	for sg: float in [-1.0, 1.0]:
		_bb.box("ouro_velho", Vector3(0.05, 1.10, 0.06), Vector3(x + sg * 0.55, 1.52, zw - 0.13))        # umbrais dourados
		_bb.cylinder("ouro_velho", 0.055, 0.055, 1.10, Vector3(x + sg * 0.70, 1.55, zw - 0.17), Vector3.ZERO, 12)   # colunas
		_bb.cylinder("cantaria", 0.075, 0.075, 0.06, Vector3(x + sg * 0.70, 1.02, zw - 0.17), Vector3.ZERO, 12)      # bases
		_bb.cylinder("cantaria", 0.085, 0.085, 0.07, Vector3(x + sg * 0.70, 2.13, zw - 0.17), Vector3.ZERO, 12)     # capitéis
	_arco_xy("ouro_velho", Vector3(x, 2.04, zw - 0.14), 0.58, 0.07, 0.07, 16)                              # arco dourado
	_arco_xy("madeira_escura", Vector3(x, 2.04, zw - 0.12), 0.74, 0.14, 0.08, 18)                          # moldura externa do arco
	_bb.box("madeira_escura", Vector3(1.64, 0.10, 0.12), Vector3(x, 2.07 - 0.0, zw - 0.10))               # cornija atrás do arco
	_bb.box("ouro_velho", Vector3(0.03, 0.34, 0.03), Vector3(x, 2.88 - 0.0, zw - 0.10)) if _h > 3.1 else null
	# imagem da santa no nicho (modelo gothic_statue, medido: ~1,74 m de altura na escala 1)
	_prop("gothic_statue", x, zw - 0.30, PI, 0.30, 1.0)
	_bb.cylinder("ouro_velho", 0.16, 0.16, 0.012, Vector3(x, 1.78, zw - 0.20), Vector3(PI / 2.0, 0, 0), 14)   # auréola
	# crucifixo, castiçais e flores sobre o tampo
	_bb.box("ouro_velho", Vector3(0.03, 0.28, 0.03), Vector3(x - 0.34, 1.13, zw - 0.30))
	_bb.box("ouro_velho", Vector3(0.16, 0.03, 0.03), Vector3(x - 0.34, 1.19, zw - 0.30))
	for k in [-1.0, 1.0]:
		_bb.cylinder("ouro_velho", 0.05, 0.035, 0.03, Vector3(x + k * 0.58, 0.985, zw - 0.28), Vector3.ZERO, 10)    # prato do castiçal
		_bb.cylinder("ouro_velho", 0.018, 0.018, 0.22, Vector3(x + k * 0.58, 1.10, zw - 0.28), Vector3.ZERO, 8)     # haste
		_vela(x + k * 0.58, 1.20, zw - 0.28, k > 0)
	_bb.cylinder("vidro_oleo", 0.04, 0.03, 0.10, Vector3(x + 0.34, 1.02, zw - 0.28), Vector3.ZERO, 8)           # vasinho
	for fk in 5:
		_bb.sphere("flor_branca", 0.025, Vector3(x + 0.34 + (fk - 2) * 0.018, 1.10 + (fk % 2) * 0.04, zw - 0.28 + (fk - 2) * 0.008), 5, 3)
	# fitinhas de promessa penduradas na lateral do retábulo
	for fk in 7:
		_bb.box("pano_azul" if fk % 2 == 0 else "pano_cru", Vector3(0.012, 0.22 + (fk % 3) * 0.05, 0.02), Vector3(x - 0.92 + fk * 0.025, 1.50, zw - 0.04))


func _item(id: String, pos: Vector3, label: String) -> Area3D:
	var a := _area("Item_" + id, pos, Vector3(0.7, 0.6, 0.7), "res://scripts/coletavel.gd")
	a.set("tipo", "item")
	a.set("item_id", id)
	a.set("texto_interacao", label)
	var ib := b._batch()
	match id:
		"terco":
			for k in 9:
				var t := float(k) / 8.0
				var ang := PI * 0.15 + t * PI * 0.7
				ib.sphere("madeira_escura", 0.018, Vector3(cos(ang) * 0.09, 0.0, sin(ang) * 0.09 - 0.04), 5, 3)
			ib.box("ouro_velho", Vector3(0.02, 0.07, 0.01), Vector3(0.0, 0.01, 0.1))
			ib.box("ouro_velho", Vector3(0.05, 0.02, 0.01), Vector3(0.0, 0.02, 0.1))
		"chave_casarao", "chave_igreja":
			var m := "ferro" if id == "chave_casarao" else "ouro_velho"
			ib.cylinder(m, 0.035, 0.035, 0.015, Vector3(0, 0.0, 0.07), Vector3(PI / 2.0, 0, 0), 8)
			ib.box(m, Vector3(0.018, 0.012, 0.16), Vector3(0, 0.0, -0.04))
			ib.box(m, Vector3(0.05, 0.012, 0.02), Vector3(0.02, 0.0, -0.11))
		"livro":
			ib.box("couro", Vector3(0.26, 0.06, 0.34), Vector3(0, 0.0, 0))
			ib.box("papel", Vector3(0.24, 0.05, 0.32), Vector3(0.0, 0.0, 0.0))
			ib.box("couro", Vector3(0.27, 0.07, 0.03), Vector3(0, 0.0, -0.18))
		_:
			ib.box("papel", Vector3(0.2, 0.03, 0.2), Vector3.ZERO)
	b._mesh_node(a, "Malha", ib.commit(), Vector3(0, -0.05, 0))
	b._brilho(a, 0.12, 0.5)
	return a


## Há uma caixa de móvel (mesa, balcão, prateleira) logo abaixo do ponto? Então o objeto já está apoiado.
## Topos (altura) de móveis e modelos que têm (x, z) sobre a pegada deles (mesas de modelo, criados-mudos, bancos...).
func _topos_em(x: float, z: float) -> Array[float]:
	var r: Array[float] = []
	for e in _pegadas():
		if bool(e.get("caido", false)):
			continue
		var c: Vector3 = e["c"]
		var sz: Vector3 = e["sz"]
		if sz.x >= 0.25 and sz.z >= 0.25 and absf(x - c.x) <= sz.x / 2.0 and absf(z - c.z) <= sz.z / 2.0 and float(e["ymin"]) < 0.1 and float(e["ymax"]) < 1.3:
			r.append(float(e["ymax"]))
	return r


func _tem_apoio(x: float, y: float, z: float) -> bool:
	for tp in _topos_em(x, z):
		if absf(tp - (y - 0.05)) < 0.15:
			return true
	for e in _bb._boxes:
		var bb: AABB = e[1]
		if bb.size.x < 0.3 or bb.size.z < 0.3:
			continue                                    # pernas e peças pequenas não são superfície de apoio; o tampo fino da mesa é
		if x >= bb.position.x and x <= bb.end.x and z >= bb.position.z and z <= bb.end.z and absf(bb.end.y - (y - 0.05)) < 0.12:
			return true
	return false


## Altura do tampo (de _bb) logo abaixo de (x, y, z): objetos pequenos "assentam" na superfície em vez de pairar a poucos cm dela.
func _topo(x: float, y: float, z: float) -> float:
	var melhor := y
	var achou := false
	for tp in _topos_em(x, z):
		if tp <= y + 0.03 and tp >= y - 0.30 and (not achou or tp > melhor):
			melhor = tp
			achou = true
	for e in _bb._boxes:
		var bb: AABB = e[1]
		if bb.size.x < 0.3 or bb.size.z < 0.3:
			continue
		if x < bb.position.x or x > bb.end.x or z < bb.position.z or z > bb.end.z:
			continue
		var t: float = bb.end.y
		if t <= y + 0.03 and t >= y - 0.30 and (not achou or t > melhor):
			melhor = t
			achou = true
	return melhor


func _oleo(x: float, y: float, z: float) -> void:
	# o frasco de querosene nunca fica no ar: se há móvel embaixo (mesa, balcão), ele fica lá; se não há, vai sobre um banquinho
	y = _topo(x, y, z) if y > 0.15 else y
	if y > 0.15 and not _tem_apoio(x, y, z):
		# sem móvel embaixo: banquinho, mas num lugar LIVRE perto (antes caía em cima de cama, barril...)
		var achou_l := false
		for rr: float in [0.0, 0.5, 0.8, 1.1]:
			for ang in 8:
				var q := Vector2(x, z) + Vector2.from_angle(float(ang) * TAU / 8.0) * rr
				if q.x < 0.4 or q.x > _w - 0.4 or q.y < 0.4 or q.y > _d - 0.4:
					continue
				if not _ocupado(AABB(Vector3(q.x - 0.4, 0.0, q.y - 0.4), Vector3(0.8, 0.6, 0.8))):
					x = q.x
					z = q.y
					achou_l = true
					break
			if achou_l:
				break
		if achou_l:
			_prop("WoodenTable_02", x, z, float(int(x * 13.0 + z * 7.0) % 6), 1.0, 0.0)
			y = 0.47
		else:
			y = 0.05                      # sem lugar livre para banquinho: o frasco fica no chão
	b._coletavel(_g, "Oleo_%d" % _g.get_child_count(), Vector3(x, y, z), "oleo", 0, "Pegar querosene")


func _nota(x: float, y: float, z: float, id: int, label: String) -> void:
	b._coletavel(_g, "Nota_%d" % id, Vector3(x, _topo(x, y, z) + 0.01, z), "nota", id, label)


## Modelo real COM colisão em caixa (móveis grandes). `yaw`: 0 = frente para +z (parede sul); PI = frente para -z (parede norte).
func _prop_c(key: String, x: float, z: float, yaw := 0.0, escala := 1.0, y := 0.0) -> Node3D:
	var p := b._prop(_g, key, Vector3(x, y, z), yaw, escala)
	var bb: AABB = p.get_meta("bb")
	b._prop_collision(p, "caixa", bb.size, bb.get_center())
	return p


func _parte(key: String, manter: Array, x: float, z: float, yaw := 0.0, escala := 1.0, y := 0.0) -> Node3D:
	return b._parte(_g, key, manter, Vector3(x, y, z), yaw, escala)


## Papelaria sobre uma mesa: copo de lápis, borracha e canetas/lápis soltos (cada peça separada, deitada no tampo, em ângulos diferentes).
func _papelaria(x: float, z: float, y: float, yaw := 0.0) -> void:
	# cada peça do modelo de papelaria é usada SOZINHA (copo, borracha, canetas, lápis), apoiada no tampo e em ordem:
	# o copo em pé no canto, a borracha ao lado e as canetas/lápis paralelos, deitados lado a lado
	y = _topo(x, y, z)
	var c := cos(yaw)
	var s := sin(yaw)
	var esc := 1.3
	var base := Vector2(x, z)
	var dir := Vector2(c, s)                          # ao longo da mesa
	var lado := Vector2(-s, c)                        # de frente para trás
	var p_copo := base - dir * 0.20
	_parte("stationery_supplies", ["stationery_supplies_pencilcup"], p_copo.x, p_copo.y, yaw, esc, y)
	var p_borr := base - dir * 0.07 + lado * 0.07
	_parte("stationery_supplies", ["stationery_supplies_eraser"], p_borr.x, p_borr.y, yaw + 0.25, esc, y)
	var nomes := ["pen_red", "pencil_new_a", "pen_blue"]
	for k in 3:
		var p := base + dir * 0.06 + lado * (-0.08 + 0.075 * k)
		_parte("stationery_supplies", ["stationery_supplies_" + String(nomes[k])], p.x, p.y, yaw + 0.08 * (k - 1), esc, y)


## Comida que cura (coletável): lata de leite/tomate/feijão/sardinha (modelo separado) ou pão. `kind`: pao, feijao, sardinha, leite, tomate, cafe.
func _comida(x: float, z: float, y: float, kind: String, rotulo := "Comer") -> void:
	y = _topo(x, y, z)
	var a := _area("Comida_%d" % _g.get_child_count(), Vector3(x, y + 0.15, z), Vector3(0.5, 0.4, 0.5), "res://scripts/coletavel.gd")
	a.set("tipo", "comida")
	a.set("item_id", kind)
	a.set("texto_interacao", rotulo)
	var nomes := {"feijao": "beans", "sardinha": "sardines", "leite": "milk", "tomate": "tomatoes"}
	if nomes.has(kind):
		var pr := PropKit.make_filtrado("long_life_food", ["long_life_food_" + String(nomes[kind])], 1.0)
		pr.position = Vector3(0, -0.15, 0)
		a.add_child(pr)
	else:
		var lb := b._batch()
		if kind == "cafe":
			lb.cylinder("cantaria", 0.05, 0.04, 0.09, Vector3(0, -0.105, 0), Vector3.ZERO, 12)
			lb.cylinder("madeira_escura", 0.045, 0.045, 0.01, Vector3(0, -0.06, 0), Vector3.ZERO, 12)
		else:                                                             # pão: broa com cortes
			lb.sphere("pao", 0.13, Vector3(0, -0.05, 0), 12, 8)
			for k in 3:
				lb.box("madeira_natural", Vector3(0.02, 0.012, 0.16), Vector3(-0.07 + k * 0.07, 0.07, 0), Vector3(0.0, 0.5, 0.0))
		b._mesh_node(a, "Malha", lb.commit())
	b._halo(a, Vector3(0, 0.05, 0), 0.5, "halo_vela")


## Lata de comida isolada (leite, tomate, feijão ou sardinha, conforme a posição).
func _lata(x: float, z: float, y: float, yaw := 0.0) -> void:
	var nomes := ["milk", "tomatoes", "beans", "sardines"]
	var n: String = nomes[int(absf(x * 13.0 + z * 7.0)) % nomes.size()]
	_parte("long_life_food", ["long_life_food_" + n], x, z, yaw, 1.0, _topo(x, y, z))


func _prop(key: String, x: float, z: float, yaw := 0.0, escala := 1.0, y := 0.0) -> Node3D:
	return b._prop(_g, key, Vector3(x, y, z), yaw, escala)


# ------------------------------------------------------------------ salas

func _sala_benedita(g: Node3D) -> void:
	_casca("Casa de Dona Benedita", 7.0, 6.0, 3.0, "reboco_creme", "piso_taco", "forro_tabuas")
	_cama_enc("N", 1.2)
	_armario(0.55 * 0.5 + 0.02, 2.2, 1.3, 2.0, 0.55, PI / 2.0)                       # rente à parede oeste (folga de 2 cm)
	_fogao(_mx(6.0), _mz(5.4), PI)
	_mesa(_mx(4.6), _mz(2.9), 1.6, 0.9)
	_cadeira_mesa(4.6, 2.9, 1.6, 0.9, "O")
	_cadeira_mesa(4.6, 2.9, 1.6, 0.9, "L")
	_cadeira_mesa(4.6, 2.9, 1.6, 0.9, "S")
	_lamparina(_mx(4.6), 0.82, _mz(3.1))
	_oratorio(_mx(3.6), _d - 0.195)
	_tapete(_mx(3.0), _mz(3.4), 2.4, 1.6, 1)
	_janela("L", _mz(3.2))
	_quadro(_mx(0.04), 1.8, _mz(3.5), "O", 0.4, 0.5)
	_nota(_mx(4.3), 0.85, _mz(2.7), 1, "Ler a carta de Dona Benedita")
	_nota(_mx(5.0), 0.86, _mz(3.15), 25, "Ler o papel atrás do retrato")
	_encostar_auto("painted_wooden_nightstand", 1.7 + 0.02 + _dim("painted_wooden_nightstand").x * 0.5, 5.9, 1.0)
	_prop("planter_pot_clay", _mx(6.5), _mz(0.5), 0.0, 1.3, 0.0)
	_parte("anthurium_botany_01", ["anthurium_botany_01_a"], _mx(6.5), _mz(0.5), 0.3, 0.2, 0.28)
	_item("terco", Vector3(_mx(3.2), 1.07, _mz(5.55)), "Pegar o terço de Dona Benedita")
	_oleo(_mx(6.3), 0.95, _mz(3.3))
	_oleo(_mx(0.6), 1.4, _mz(4.2))
	_examinar(1.2, 0.9, _d - 1.02, "Examinar a cama", "A cama está feita, com a colcha dobrada ao pé. Ninguém dormiu aqui depois que o último trem de minério partiu. | Sob o travesseiro, um terço quebrado e um recibo da Companhia: 'indenização recusada'.")
	_examinar(_mx(3.6), 1.2, _mz(5.6), "Examinar o oratório", "O oratório tem quarenta e duas fitinhas amarradas. Quarenta e duas famílias, e nenhuma resposta.", "clink")
	_examinar(_mx(6.0), 1.0, _mz(5.2), "Examinar o fogão", "As cinzas ainda estão mornas. Não foi Dona Benedita que acendeu o fogo. | Há uma panela com café coado, intocada. A xícara tem batom, mas a casa nunca recebeu visita.", "creak", 0.12)
	_examinar(_mx(0.5), 1.0, _mz(2.2), "Abrir o armário", "Vestidos de luto, todos do mesmo tamanho, todos com uma flor de papel presa na gola. Dona Benedita ensaiava os velórios antes que acontecessem.", "creak")
	_prop("wooden_bucket_01", _mx(5.7), _mz(0.5), 0.5)
	_prop("wooden_stool_01", _mx(5.4), _mz(4.2), 0.3)
	_prop_c("round_wooden_table_02", _mx(1.5), _mz(1.2), 0.0, 1.0)
	_comida(4.95, 3.2, 0.82, "feijao", "Comer a lata de feijão")
	_prop("watering_can_metal_01", _mx(6.4), _mz(1.3), 2.5, 1.0)
	_papelaria(_mx(1.5), _mz(1.2), 0.75, 0.3)
	_fim()


func _sala_padaria(g: Node3D) -> void:
	# PADARIA de vila mineira: forno de tijolo com cúpula e chaminé, balcão comprido com vitrine de vidro e cestos de pão,
	# prateleiras de pães e potes no fundo, mesa de sovar com massa, rolo e farinha, sacos e barril de farinha, pá de forno.
	_casca("Padaria da esquina", 8.0, 6.4, 3.1, "reboco_amarelo", "piso_taco", "forro_tabuas")
	# --- forno de lenha na parede leste (x = 8)
	_bb.box("muro", Vector3(1.7, 1.15, 2.6), Vector3(7.12, 0.575, 3.5))                       # soco de tijolo
	_bb.box("cantaria", Vector3(1.74, 0.08, 2.64), Vector3(7.12, 1.17, 3.5))                   # tampo de pedra
	_bb.box("muro", Vector3(1.45, 0.62, 2.2), Vector3(7.2, 1.5, 3.5))                          # câmara
	_bb.box("muro", Vector3(1.1, 0.40, 1.8), Vector3(7.35, 1.98, 3.5))                         # cúpula (em dois degraus)
	_bb.box("muro", Vector3(0.8, 0.30, 1.4), Vector3(7.5, 2.30, 3.5))
	_bb.box("muro", Vector3(0.85, 1.0, 0.85), Vector3(7.55, 2.8, 3.5))                         # chaminé até o forro
	_bb.box("cantaria", Vector3(0.95, 0.10, 0.95), Vector3(7.55, 3.05, 3.5))
	_bb.box("janela_escura", Vector3(0.04, 0.46, 0.86), Vector3(6.37, 1.5, 3.5))              # boca do forno (escura)
	_arco_xy_x("cantaria", Vector3(6.36, 1.5, 3.5), 0.50, 0.10, 0.06, 12)                   # arco de pedra em volta da boca
	_bb.box("chama", Vector3(0.02, 0.28, 0.6), Vector3(6.38, 1.36, 3.5))                       # brasas
	var lf := b._lamp_light(g, Vector3(6.1, 1.4, 3.5), 0.9)
	lf.light_color = Color(1.0, 0.42, 0.12)
	lf.omni_range = 6.0
	b._blocker(g, "ColForno", Vector3(1.74, 1.2, 2.64), Vector3(7.12, 0.6, 3.5))
	_bb.box("madeira_natural", Vector3(0.04, 1.55, 0.26), Vector3(7.9, 0.8, 1.55))             # pá de forno encostada ao lado
	_bb.box("madeira_natural", Vector3(0.04, 0.34, 0.40), Vector3(7.9, 1.62, 1.55))
	_examinar(6.6, 1.3, 3.5, "Examinar o forno", "O forno de lenha está morno, com pães de ontem ainda dentro. Dizem que a padeira nunca saiu: ela assa para quem não tem mais boca.", "creak", 0.1)
	# --- balcão comprido com vitrine e cestos (corre ao longo de z, junto à parede oeste)
	_balcao(1.9, 4.0, 3.6, PI / 2.0)
	_bb.box("vidro_claro", Vector3(0.52, 0.46, 3.2), Vector3(1.9, 1.32, 4.0))                  # vitrine de vidro sobre o balcão
	for sz2: float in [-1.0, 1.0]:
		_bb.box("madeira_escura", Vector3(0.56, 0.5, 0.04), Vector3(1.9, 1.32, 4.0 + sz2 * 1.62))
	_bb.box("madeira_escura", Vector3(0.56, 0.04, 3.28), Vector3(1.9, 1.56, 4.0))
	for k in 9:                                                                                 # pães na vitrine
		_bb.cylinder("pao", 0.085, 0.085, 0.20, Vector3(1.86, 1.15, 2.6 + k * 0.30), Vector3(0, 0, PI / 2.0), 8)
	_cont("Basket1", 1.9, 5.45, 0.0, 1.05, 0.9, false)
	_cont("Basket1", 1.9, 2.55, 0.5, 1.05, 0.9, false)
	_examinar(1.9, 1.1, 4.0, "Examinar o balcão", "Uma caderneta de fiado aberta: nomes, valores, e uma coluna riscada com a letra do Capataz. 'Quitado em sangue.'")
	# --- fundo: prateleiras de pães e potes, sacos de farinha
	_prateleira(4.0, 1.45, 6.2, 3.6, 0.0, 0)
	_prateleira(4.0, 2.0, 6.2, 3.6, 0.0, 0)
	for k in 8:
		_bb.cylinder("pao", 0.09, 0.09, 0.30, Vector3(2.5 + k * 0.42, 1.60, 6.18), Vector3(0, 0, PI / 2.0), 8)
	for k in 6:
		_bb.cylinder("vidro_oleo", 0.07, 0.07, 0.20, Vector3(2.6 + k * 0.55, 2.12, 6.18), Vector3.ZERO, 8)
	_saco(0.7, 5.9, 0.3)
	_saco(1.25, 6.0, 0.0)
	_saco(0.75, 5.35, 0.6)
	_prop("wine_barrel_01", 6.2, 5.9, 0.0, 1.0, 0.0)                                           # barril de farinha
	# --- mesa de sovar (massa, rolo, farinha) e banquinho
	_mesa(4.6, 4.9, 2.2, 1.0, 0.92, "madeira_natural")
	_bb.box("pano_cru", Vector3(0.95, 0.004, 0.55), Vector3(4.4, 0.924, 4.9))                  # farinha espalhada
	_bb.sphere("pano_cru", 0.11, Vector3(4.6, 1.0, 4.85), 8, 5)                                 # bola de massa
	_bb.sphere("pano_cru", 0.09, Vector3(4.9, 0.98, 5.1), 8, 5)
	_bb.cylinder("madeira_natural", 0.03, 0.03, 0.50, Vector3(4.0, 0.95, 4.7), Vector3(PI / 2.0, 0, 0.1), 8)   # rolo
	_prop("wooden_stool_01", 3.2, 4.9, 0.3)
	# --- entrada
	_tapete(4.0, 1.25, 1.6, 0.9, 1)
	_prop("planter_pot_clay", 0.55, 0.55, 0.0, 1.3, 0.0)
	_parte("anthurium_botany_01", ["anthurium_botany_01_a"], 0.55, 0.55, 0.3, 0.2, 0.28)
	_prop("wooden_bucket_01", 7.4, 0.6, 0.0)
	_prop("watering_can_metal_01", 6.7, 0.7, 0.4, 1.0)
	_janela("N", 4.0)
	# --- itens (bilhetes, querosene, pão que cura) e luz
	_lamparina(1.9, 1.05, 3.0)
	_nota(1.85, 1.05, 3.5, 4, "Ler o recado")
	_nota(1.85, 1.05, 4.6, 10, "Ler o caderno de fiado")
	_oleo(5.2, 0.95, 5.2)
	_comida(1.85, 4.2, 1.05, "pao", "Comer o pão")
	_fim()


## Arco no plano YZ (para bocas na parede leste/oeste): centro c, raio r, espessura esp, profundidade prof (em x).
func _arco_xy_x(mat: String, c: Vector3, r: float, esp: float, prof: float, segs := 12) -> void:
	for k in segs:
		var t0 := PI * float(k) / segs
		var t1 := PI * float(k + 1) / segs
		var tm := (t0 + t1) * 0.5
		var corda := 2.0 * r * sin((t1 - t0) * 0.5) + 0.03
		_bb.box(mat, Vector3(prof, esp, corda), c + Vector3(0, sin(tm) * r, cos(tm) * r), Vector3(tm + PI / 2.0, 0, 0))


func _sala_venda(g: Node3D) -> void:
	_casca("Venda do Seu Zé", 8.0, 6.0, 3.1, "reboco_ocre", "piso_taco", "forro_tabuas")
	_balcao(_mx(4.0), _mz(4.7), 4.4)
	_prateleira(_mx(4.0), 1.55, _mz(5.82), 3.6, 0.0, 9)
	_prateleira(_mx(4.0), 2.05, _mz(5.82), 3.6, 0.0, 8)
	_prop("wine_barrel_01", _mx(0.7), _mz(1.4), 0.0)
	_prop("wine_barrel_01", _mx(0.7), _mz(2.5), 1.0)
	for k in 3:
		_prop("wooden_stool_01", _mx(2.7 + k * 1.2), _mz(3.55), k * 0.7)
	_saco(_mx(7.2), _mz(4.9), 0.3)
	_saco(_mx(7.5), _mz(5.4))
	_cont("Crate3", _mx(1.5), _mz(0.65), 0.2)
	_cont("Basket1", _mx(2.6), _mz(0.6), 0.0)
	_cont("Jug1", _mx(3.3), _mz(0.7), 0.8)
	_mesa(_mx(7.4), _mz(2.5), 1.0, 0.8, 0.9, "madeira_escura", PI / 2.0)       # mesinha da TV
	b._tv(g, Vector3(_mx(7.4), 0.94, _mz(2.5)), -PI / 2.0)
	_lamparina(_mx(2.4), 1.08, _mz(4.7))
	_janela("O", _mz(3.0))
	_quadro(_mx(5.0), 1.9, _mz(5.82), "N", 0.6, 0.5)
	_nota(_mx(5.8), 1.1, _mz(4.6), 6, "Ler o bilhete do Seu Zé")
	_prop_c("cardboard_box_01", _mx(6.7), _mz(5.45), 0.3, 1.0)
	_prop("vintage_lighter", _mx(3.5), _mz(4.55), 1.0, 1.0, 1.1)
	_prop("cardboard_box_01", _mx(6.72), _mz(5.45), 0.7, 1.0, 0.34)
	_prop("lightbulb_01", _mx(4.2), _mz(2.2), 0.0, 1.0, 2.52)                                              # lâmpada apagada pendurada pelo fio
	_bb.cylinder("ferro", 0.008, 0.008, 0.55, Vector3(_mx(4.2), 2.85, _mz(2.2)), Vector3.ZERO, 4)
	_nota(_mx(4.5), 1.1, _mz(4.7), 23, "Ler a confissão do Seu Zé")
	_item("chave_casarao", Vector3(_mx(3.3), 1.1, _mz(4.6)), "Abrir a gaveta: pegar a chave do casarão")
	_oleo(_mx(6.2), 1.1, _mz(4.7))
	_prop("cigarette_pack", _mx(4.9), _mz(4.45), 0.4, 1.5, 1.05)
	_comida(3.0, 4.9, 1.05, "sardinha", "Comer a lata de sardinha")
	_comida(5.2, 4.9, 1.05, "leite", "Tomar o leite condensado")
	_encostar_auto("worn_metal_rack", _mx(7.4), _mz(0.8), 1.0)
	_encostar_auto("standing_chalkboard_01", _mx(6.2), _mz(1.2), 1.0)
	_fim()


func _sala_barbearia(g: Node3D) -> void:
	# BARBEARIA: duas cadeiras de barbeiro de couro e ferro diante do espelho comprido, bancada com pia de louça, navalhas, pincéis e
	# frascos, toalhas penduradas, banco de espera com jornais, cabideiro com chapéus, cartazes antigos na parede.
	_casca("Barbearia", 6.0, 5.0, 3.0, "reboco_azul", "piso_taco", "forro_tabuas")
	for cx: float in [2.0, 4.0]:
		_bb.box("couro", Vector3(0.62, 0.12, 0.6), Vector3(cx, 0.62, 3.3))
		_bb.box("couro", Vector3(0.62, 0.78, 0.12), Vector3(cx, 1.08, 3.66))
		_bb.box("couro", Vector3(0.36, 0.16, 0.10), Vector3(cx, 1.55, 3.64))                         # apoio de cabeça
		_bb.box("couro", Vector3(0.5, 0.06, 0.4), Vector3(cx, 0.30, 2.85))                            # apoio dos pés
		_bb.cylinder("ferro", 0.09, 0.16, 0.55, Vector3(cx, 0.28, 3.3), Vector3.ZERO, 10)
		_bb.cylinder("ferro", 0.22, 0.24, 0.04, Vector3(cx, 0.02, 3.3), Vector3.ZERO, 14)
		for k in [-1.0, 1.0]:
			_bb.box("couro", Vector3(0.08, 0.06, 0.5), Vector3(cx + k * 0.35, 0.92, 3.3))
			_bb.box("ferro", Vector3(0.03, 0.30, 0.03), Vector3(cx + k * 0.35, 0.76, 3.1))
		b._blocker(g, "ColCadeira", Vector3(0.9, 1.4, 1.1), Vector3(cx, 0.7, 3.3))
	# espelho comprido e bancada com pia (parede norte)
	_bb.box("ouro_velho", Vector3(3.6, 1.1, 0.04), Vector3(3.0, 1.85, 4.97))
	_bb.quad("vidro_noite", Vector2(3.5, 1.0), Vector3(3.0, 1.85, 4.94), PI)
	_bb.box("madeira_escura", Vector3(3.6, 0.85, 0.45), Vector3(3.0, 0.425, 4.75))
	_bb.box("cantaria", Vector3(3.7, 0.05, 0.5), Vector3(3.0, 0.875, 4.73))
	for px: float in [2.0, 4.0]:
		_bb.cylinder("pano_cru", 0.17, 0.12, 0.10, Vector3(px, 0.93, 4.72), Vector3.ZERO, 12)         # pia de louça
		_bb.cylinder("ferro", 0.012, 0.012, 0.18, Vector3(px, 1.0, 4.88), Vector3.ZERO, 6)           # torneira
	b._blocker(g, "ColBancada", Vector3(3.6, 0.9, 0.5), Vector3(3.0, 0.45, 4.75))
	for k in 7:
		_bb.cylinder("vidro_oleo", 0.03, 0.03, 0.14, Vector3(1.4 + k * 0.2 + (0.45 if k > 3 else 0.0), 0.97, 4.82), Vector3.ZERO, 7)   # loções
	_bb.box("ferro", Vector3(0.14, 0.01, 0.03), Vector3(2.5, 0.905, 4.62), Vector3(0, 0.4, 0))      # navalha
	_bb.cylinder("madeira_natural", 0.02, 0.025, 0.09, Vector3(3.5, 0.95, 4.62), Vector3.ZERO, 6)   # pincel de barba
	_bb.sphere("pano_cru", 0.03, Vector3(3.5, 1.01, 4.62), 6, 4)
	# toalhas penduradas num varão (parede leste) e cabideiro com chapéus
	_bb.cylinder("madeira_natural", 0.015, 0.015, 1.4, Vector3(5.92, 1.5, 2.6), Vector3(PI / 2.0, 0, 0), 6)
	for k in 3:
		_bb.box("pano_cru", Vector3(0.02, 0.55, 0.35), Vector3(5.9, 1.25, 2.1 + k * 0.5))
	_bb.cylinder("madeira_escura", 0.025, 0.03, 1.75, Vector3(5.6, 0.88, 0.5), Vector3.ZERO, 8)
	_bb.cylinder("madeira_escura", 0.18, 0.2, 0.03, Vector3(5.6, 0.02, 0.5), Vector3.ZERO, 10)
	_bb.cylinder("pano_azul", 0.16, 0.16, 0.08, Vector3(5.6, 1.78, 0.5), Vector3.ZERO, 12)          # chapéu
	_bb.cylinder("pano_azul", 0.10, 0.10, 0.10, Vector3(5.6, 1.86, 0.5), Vector3.ZERO, 10)
	# banco de espera (parede oeste) com jornais
	_bb.box("madeira_natural", Vector3(0.45, 0.06, 1.8), Vector3(0.3, 0.45, 2.6))
	_bb.box("madeira_natural", Vector3(0.06, 0.45, 1.8), Vector3(0.06, 0.75, 2.6))
	for sz: float in [-1.0, 1.0]:
		_bb.box("madeira_escura", Vector3(0.4, 0.45, 0.06), Vector3(0.3, 0.22, 2.6 + sz * 0.85))
	b._blocker(g, "ColBanco", Vector3(0.5, 0.5, 1.8), Vector3(0.3, 0.25, 2.6))
	_bb.box("pano_cru", Vector3(0.32, 0.01, 0.42), Vector3(0.3, 0.485, 2.2), Vector3(0, 0.2, 0))
	_nota(0.3, 0.49, 3.0, 9, "Ler o recorte de jornal")
	_prop("cigarette_pack", 0.32, 2.75, 0.8, 1.5, 0.48)
	# cartazes antigos e quadros
	_quadro(0.04, 1.8, 1.3, "O", 0.5, 0.7)
	_quadro(5.96, 1.9, 4.3, "L", 0.5, 0.65)
	_lamparina(3.0, 0.9, 4.75)
	_janela("L", 3.6)
	_oleo(5.4, 0.95, 4.0)
	_fim()


func _sala_sineiro(g: Node3D) -> void:
	_casca("Casa do sineiro", 6.0, 5.0, 2.9, "reboco_branco", "piso_taco", "forro_tabuas")
	_cama_enc("N", 0.9, "pano_cru")
	# caixa de madeira embaixo da cama (onde está a chave)
	_bb.box("madeira_natural", Vector3(0.5, 0.26, 0.4), Vector3(_mx(1.0), 0.13, _mz(2.45)))
	_bb.box("ferro", Vector3(0.52, 0.03, 0.42), Vector3(_mx(1.0), 0.27, _mz(2.45)))
	_mesa(_mx(4.2), _mz(3.4), 1.4, 0.8)
	_cadeira_mesa(4.2, 3.4, 1.4, 0.8, "S")
	_cadeira_mesa(4.2, 3.4, 1.4, 0.8, "N")
	_lamparina(_mx(4.1), 0.82, _mz(3.4))
	# corda do sino pendurada
	_bb.cylinder("pano_cru", 0.025, 0.025, 2.3, Vector3(_mx(5.5), 1.75, _mz(4.6)), Vector3.ZERO, 6)
	_bb.sphere("pano_cru", 0.1, Vector3(_mx(5.5), 0.55, _mz(4.6)), 6, 4)
	_oratorio(_mx(3.0), _d - 0.195)
	_janela("L", _mz(2.0))
	_nota(_mx(3.8), 0.85, _mz(3.5), 8, "Ler a carta do Seu Tobias")
	_nota(_mx(4.6), 0.85, _mz(3.3), 3, "Ler a anotação do sacristão")
	_nota(_mx(3.6), 0.85, _mz(3.1), 24, "Ler a ata da Irmandade")
	_item("chave_igreja", Vector3(_mx(1.0), 0.4, _mz(2.45)), "Abrir a caixa: pegar a chave da igreja")
	_oleo(_mx(5.6), 0.95, _mz(1.0))
	_prop("wooden_bucket_01", _mx(5.4), _mz(1.6), 0.2)
	_prop("vintage_binocular", _mx(4.55), _mz(3.75), 0.9, 1.0, 0.82)
	_prop("wooden_axe_02", _mx(5.4), _mz(3.2), 0.0, 1.0, 0.0).rotation.z = 0.25
	_comida(4.9, 3.4, 0.84, "pao", "Comer o pão")
	_fim()


func _sala_casarao(g: Node3D) -> void:
	# CASARÃO de dois andares completos. Térreo: sala de estar (entrada) com a escada, sala de jantar à direita, cozinha nos fundos.
	# Andar de cima (piso inteiro): quarto do capataz (escrivaninha e o Livro), quarto de Eulália e o corredor com a galeria de retratos.
	var up := 3.75                                   # altura do piso do andar de cima
	_casca("Casarão dos Vaz", 10.0, 8.0, 7.6, "reboco_branco", "piso_taco", "forro_tabuas")
	_andar_sup = up
	# ---------------- divisórias do térreo
	_divisoria("z", 6.5, 0.0, 8.0, 0.0, up, [2.3, 6.4])                 # estar | jantar ; cozinha | jantar
	_divisoria("x", 4.75, 2.15, 6.5, 0.0, up, [2.9])                     # estar | cozinha
	_divisoria("z", 2.15, 4.75, 8.0, 0.0, up, [])                        # cozinha | vão sob o patamar
	# ---------------- escada de madeira (19 degraus) subindo rente à parede oeste
	var n := 19
	var rise := up / float(n)
	var run := 0.27
	var z0 := 0.9
	for k in n:
		var top := rise * float(k + 1)
		_bb.box("madeira_escura", Vector3(1.2, top, run), Vector3(0.85, top * 0.5, z0 + run * 0.5 + k * run))
		_bb.box("madeira_natural", Vector3(1.22, 0.04, run + 0.02), Vector3(0.85, top + 0.02, z0 + run * 0.5 + k * run))
	var ang := atan2(up, n * run)
	var ramp := StaticBody3D.new()
	ramp.name = "RampaEscada"
	var rcs := CollisionShape3D.new()
	var rbs := BoxShape3D.new()
	rbs.size = Vector3(1.2, 0.4, sqrt(pow(n * run, 2.0) + up * up) + 0.3)
	rcs.shape = rbs
	ramp.add_child(rcs)
	ramp.position = Vector3(0.85, up * 0.5 - 0.2, z0 + n * run * 0.5)
	ramp.rotation.x = -ang
	g.add_child(ramp)
	for k in range(0, n, 2):                                                       # balaústres e corrimão do lado aberto
		var top2 := rise * float(k + 1)
		_bb.cylinder("madeira_escura", 0.025, 0.025, 0.9, Vector3(1.5, top2 + 0.45, z0 + run * 0.5 + k * run), Vector3.ZERO, 8)
	_bb.box("madeira_natural", Vector3(0.07, 0.07, sqrt(pow(n * run, 2.0) + up * up)), Vector3(1.5, up * 0.5 + 0.92, z0 + n * run * 0.5), Vector3(-ang, 0, 0))
	b._blocker(g, "ColCorrimaoEscada", Vector3(0.1, 1.2, 1.2), Vector3(1.5, 0.6, z0 + 0.5))
	# ---------------- laje do 2º andar inteira (menos o vão da escada x 0..2,15 / z 0..6,03)
	_laje(2.15, 10.0, 0.0, 8.0, up)
	_laje(0.0, 2.15, z0 + n * run, 8.0, up)
	# ---------------- divisórias do 2º andar
	_divisoria("z", 2.15, 0.0, 6.1, up, 7.6, [])                         # fecha o vão da escada (ninguém cai)
	_divisoria("x", 6.1, 2.15, 10.0, up, 7.6, [2.9, 8.3])                # corredor | quartos
	_divisoria("z", 6.5, 0.0, 6.1, up, 7.6, [])                          # quarto do capataz | quarto de Eulália
	# ================= TÉRREO =================
	# --- sala de estar (x 2,15–6,5 / z 0–4,75): sofá encostado na cozinha, poltrona, mesinha, estante
	_tapete(4.6, 3.1, 2.8, 1.8, 0)
	_prop_c("vintage_day_bed", 4.55, 4.25, PI, 1.0)
	_prop_c("gothic_coffee_table", 4.55, 3.05, 0.0, 0.62)
	_prop_c("chinese_armchair", 2.95, 3.0, PI / 2.0, 0.85)
	_prop_c("wooden_bookshelf_worn", 6.1, 3.8, -PI / 2.0, 1.0)
	_prop("planter_pot_clay", 2.55, 0.5, 0.0, 1.4, 0.0)
	_parte("anthurium_botany_01", ["anthurium_botany_04_d"], 2.55, 0.5, 0.9, 0.22, 0.30)
	var lz := b._lamp_light(_g, Vector3(4.4, up - 0.6, 2.4), 0.8)
	lz.omni_range = 7.0
	# --- sala de jantar (x 6,5–10 / z 0–8): mesa de jantar ao longo de z, seis cadeiras, aparador
	_tapete(8.3, 4.6, 2.2, 3.4, 1, PI / 2.0)
	_prop_c("dining_table", 8.3, 4.6, PI / 2.0, 1.0)
	var dtm := _dim("dining_table")                                                  # 2,26 x 1,39 m (medido no modelo); girada: 1,39 em x
	for k in 3:
		_cadeira_mesa(8.3, 4.6, dtm.z, dtm.x, "O", (k - 1) * 0.72)
		_cadeira_mesa(8.3, 4.6, dtm.z, dtm.x, "L", (k - 1) * 0.72)
	_examinar(8.3, 0.95, 4.6, "Examinar a mesa", "Sete lugares postos. Seis cadeiras. Quem faltava à mesa dos Vaz? | O castiçal central tem sete velas. Seis derreteram até o fim; a sétima nunca foi acesa.")
	_parte("brass_candleholders", ["brass_candleholder_01"], 8.3, 3.9, 0.0, 0.55, 0.89)
	_parte("brass_candleholders", ["brass_candleholder_02"], 8.3, 4.6, 0.0, 0.55, 0.89)
	_parte("brass_candleholders", ["brass_candleholder_03"], 8.3, 5.3, 0.0, 0.55, 0.89)
	_nota(8.05, 0.9, 4.15, 21, "Ler o telegrama da Companhia")
	_nota(8.55, 0.9, 5.05, 22, "Ler o rascunho amassado")
	_bb.cylinder("ferro", 0.012, 0.012, up - 2.6, Vector3(8.3, (up + 2.6) * 0.5, 4.6), Vector3.ZERO, 6)
	_prop("brass_diya_lantern", 8.3, 4.6, 0.0, 1.6, 2.15)
	var lj := b._lamp_light(_g, Vector3(8.3, 2.0, 4.6), 0.9)
	lj.omni_range = 6.5
	_prop_c("GothicCabinet_01", 9.47, 1.25, -PI / 2.0, 0.85)
	_bx("madeira_natural", Vector3(9.3, 0, 7.3), 0.4, Vector3(0, 0.22, 0), Vector3(0.44, 0.44, 0.04))     # cadeira tombada
	_examinar(9.3, 0.5, 7.3, "Examinar a cadeira caída", "A cadeira tombou quando o Dr. Anselmo se levantou da ceia para nunca mais voltar. O prato dele ainda tem a sopa, seca, rachada como a terra.", "creak", 0.1)
	_oleo(9.6, 0.0, 0.5)
	# --- cozinha (x 2,15–6,5 / z 4,75–8): fogão a lenha, mesa com duas cadeiras, prateleira, sacos
	_fogao(4.4, 7.58, PI)
	_mesa(4.0, 6.0, 1.2, 0.7, 0.8, "madeira_natural")
	_cadeira_mesa(4.0, 6.0, 1.2, 0.7, "S")
	_cadeira_mesa(4.0, 6.0, 1.2, 0.7, "O")
	_prateleira(2.9, 1.6, 7.85, 1.2, 0.0, 4)
	_saco(6.1, 7.6, 0.2)
	_prop("wooden_bucket_01", 6.15, 5.2, 0.0)
	_comida(4.2, 6.0, 0.84, "feijao", "Comer a lata de feijão")
	# ================= 2º ANDAR =================
	# --- quarto do capataz (x 2,15–6,5 / z 0–6,1): cama, criados-mudos, guarda-roupa, escrivaninha com o Livro
	_tapete(4.6, 4.2, 2.2, 1.6, 0, 0.0, up)
	_prop_c("old_bed_frame", 4.6, 5.0, PI, 1.0, up)
	_examinar(4.6, up + 0.9, 5.0, "Examinar a cama", "A cama de Eulália Vaz. O travesseiro ainda tem um fio de cabelo branco e, debaixo do colchão, uma lista com trinta e um nomes riscados a lápis.", "papel", 0.1)
	_prop("painted_wooden_nightstand", 3.85, 5.7, PI, 1.0, up)
	_prop("painted_wooden_nightstand", 5.35, 5.7, PI, 1.0, up)
	_prop_c("GothicCabinet_01", 2.74, 2.4, PI / 2.0, 0.9, up)
	_examinar(2.9, up + 1.1, 2.4, "Abrir o guarda-roupa", "Só casacos de homem, todos do mesmo corte, todos com a gola cortada. Quem usava isto sabia que um dia ia precisar sair depressa.", "creak", 0.08)
	_bx("madeira_escura", Vector3(5.2, up, 1.0), 0.0, Vector3(0, 0.78, 0), Vector3(1.7, 0.07, 0.8))        # escrivaninha
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_bx("madeira_escura", Vector3(5.2, up, 1.0), 0.0, Vector3(sx * 0.78, 0.39, sz * 0.34), Vector3(0.08, 0.78, 0.08))
	b._blocker(g, "ColEscrivaninha", Vector3(1.7, 0.8, 0.8), Vector3(5.2, up + 0.4, 1.0))
	_prop_c("chinese_armchair", 5.2, 1.75, PI, 0.72, up)
	_item("livro", Vector3(5.6, up + 0.88, 1.0), "Pegar o livro de registros dos Vaz")
	_nota(4.6, up + 0.83, 1.05, 26, "Ler o diário de Eulália Vaz")
	_vela(4.45, up + 0.82, 0.8, true)
	_prop("seadogs_compass", 5.9, 0.85, 0.4, 1.0, up + 0.78)
	_papelaria(5.0, 1.15, up + 0.82, 0.0)
	var lq := b._lamp_light(_g, Vector3(4.3, up + 2.6, 3.0), 0.8)
	lq.omni_range = 6.0
	# --- quarto de Eulália (x 6,5–10 / z 0–6,1): cama, baú de malas, cadeirinha e mesinha, cômoda
	_tapete(8.3, 3.2, 2.0, 1.5, 1, 0.0, up)
	_prop_c("old_bed_frame", 8.3, 5.0, PI, 1.0, up)
	_prop("painted_wooden_nightstand", 9.55, 5.7, PI, 1.0, up)
	_parte("vintage_suitcase", ["vintage_suitcase_01_"], 9.5, 2.2, 1.57, 0.75, up)
	_parte("vintage_suitcase", ["vintage_suitcase_02_"], 9.5, 2.95, 1.57, 0.75, up)
	_prop_c("WoodenChair_01", 7.2, 1.2, PI / 4.0, 0.5, up)
	_prop("WoodenTable_02", 7.75, 1.0, 0.0, 1.0, up)
	_prop_c("wooden_bookshelf_worn", 6.9, 3.6, PI / 2.0, 1.0, up)
	var le := b._lamp_light(_g, Vector3(8.3, up + 2.6, 3.0), 0.7)
	le.omni_range = 6.0
	# --- corredor de cima (z 6,1–8): passadeira, galeria de retratos e aparador com lampião
	_tapete(5.8, 7.05, 6.4, 0.9, 0, 0.0, up)
	_galeria("N", 5.8, 6, 2, up + 1.4)
	_prop("painted_wooden_nightstand", 9.5, 7.55, PI, 1.0, up)
	_lamparina(9.5, up + 0.66, 7.55)
	var lc := b._lamp_light(_g, Vector3(4.0, up + 2.7, 7.0), 0.7)
	lc.omni_range = 7.0
	_fim()


func _sala_igreja(g: Node3D) -> void:
	_casca("Igreja Matriz", 10.0, 22.0, 8.0, "reboco_branco", "piso_xadrez", "forro_ceu")
	# fileiras de bancos dos dois lados do corredor central
	for k in 8:
		var z := 4.0 + k * 1.5
		for lado in [0, 1]:
			var x0 := 1.2 if lado == 0 else 6.2
			_bb.box("madeira_natural", Vector3(2.6, 0.06, 0.45), Vector3(x0 + 1.3, 0.45, z))
			_bb.box("madeira_escura", Vector3(2.6, 0.6, 0.06), Vector3(x0 + 1.3, 0.85, z - 0.24))
			for lx in [0.1, 1.3, 2.5]:
				_bb.box("madeira_escura", Vector3(0.06, 0.45, 0.4), Vector3(x0 + lx, 0.22, z))
		b._blocker(g, "ColBanco_%d" % k, Vector3(2.7, 0.9, 0.5), Vector3(2.5, 0.45, z))
		b._blocker(g, "ColBancoD_%d" % k, Vector3(2.7, 0.9, 0.5), Vector3(7.5, 0.45, z))
	_presbiterio(g)
	_igreja_exuberante(g)
	# janelas altas com luar e arcos
	for k in 3:
		_janela("O", 5.0 + k * 5.5, 5.0, 1.0, 2.4)
		_janela("L", 5.0 + k * 5.5, 5.0, 1.0, 2.4)
	# luz do fundo da nave (cruzeiro) e lampadário de ferro
	var lc := b._lamp_light(g, Vector3(5.0, 6.2, 10.0), 0.9)
	lc.omni_range = 12.0
	b._halo(g, Vector3(5.0, 6.2, 10.0), 2.0, "halo_vela")
	_bb.cylinder("ferro", 0.45, 0.45, 0.05, Vector3(5.0, 6.2, 10.0), Vector3.ZERO, 10)
	_bb.cylinder("ferro", 0.015, 0.015, 1.6, Vector3(5.0, 7.2, 10.0), Vector3.ZERO, 5)
	_oleo(1.0, 0.95, 3.0)
	_prop_c("WoodenTable_01", 0.95, 1.4, PI / 2.0, 1.2)
	_prop("wooden_candlestick", 0.95, 1.1, 0.0, 1.3, 0.66)
	_vela(0.95, 0.93, 1.1, true)
	_nota(5.0, 1.78, 19.8, 2, "Ler o que a Irmandade deixou no altar")
	var al := _area("Altar", Vector3(5.0, 1.2, 18.9), Vector3(3.2, 2.4, 1.6), "res://scripts/altar.gd")
	al.set("texto_interacao", "Ler os nomes em voz alta")
	al.set("requer", "livro")
	_fim()


## Exuberância da igreja: tapete vermelho, lustres de velas, altares laterais com santos, vitrais coloridos, púlpito dourado e estandartes.
func _igreja_exuberante(g: Node3D) -> void:
	_tem_tapete = true
	_tapete(5.0, 9.6, 1.7, 17.0, 0)                                                                  # passadeira vermelha do portal ao presbitério
	# lustres de latão com velas (três ao longo da nave)
	for zc: float in [5.5, 10.5, 15.5]:
		var yl := 5.6
		_bb.cylinder("ferro", 0.012, 0.012, 8.0 - yl, Vector3(5.0, (8.0 + yl) * 0.5, zc), Vector3.ZERO, 6)
		_bb.cylinder("ouro_velho", 0.75, 0.75, 0.07, Vector3(5.0, yl, zc), Vector3.ZERO, 24)
		_bb.cylinder("ouro_velho", 0.55, 0.55, 0.05, Vector3(5.0, yl - 0.25, zc), Vector3.ZERO, 20)
		_bb.sphere("ouro_velho", 0.14, Vector3(5.0, yl - 0.5, zc), 10, 8)
		for k in 8:
			var a := TAU * float(k) / 8.0
			_vela(5.0 + cos(a) * 0.66, yl + 0.03, zc + sin(a) * 0.66, false)
		var ll := b._lamp_light(g, Vector3(5.0, yl + 0.3, zc), 1.1)
		ll.omni_range = 10.0
		b._halo(g, Vector3(5.0, yl + 0.35, zc), 2.2, "halo_vela")
	# altares laterais entre as janelas: moldura dourada, nicho escuro, santo, castiçais e vaso de antúrio
	for zl: float in [7.75, 13.25]:
		for lado: float in [-1.0, 1.0]:
			var x0 := 0.0 if lado < 0.0 else 10.0
			var dir := 1.0 if lado < 0.0 else -1.0          # sentido "para dentro da nave"
			_bb.box("cantaria", Vector3(0.9, 1.05, 2.0), Vector3(x0 + dir * 0.45, 0.52, zl))             # mesa do altar
			_bb.box("ouro_velho", Vector3(0.14, 0.05, 2.1), Vector3(x0 + dir * 0.95, 1.07, zl))
			_bb.box("pano_cru", Vector3(0.9, 0.04, 1.8), Vector3(x0 + dir * 0.45, 1.07, zl))
			_bb.box("ouro_velho", Vector3(0.18, 4.4, 2.1), Vector3(x0 + dir * 0.09, 3.3, zl))             # retábulo dourado
			_bb.box("madeira_escura", Vector3(0.10, 2.6, 1.3), Vector3(x0 + dir * 0.2, 2.9, zl))          # nicho
			_bb.cylinder("ouro_velho", 0.65, 0.65, 0.2, Vector3(x0 + dir * 0.16, 4.3, zl), Vector3(0, 0, PI / 2.0), 18)   # arco do topo
			_bb.box("ouro_velho", Vector3(0.3, 0.4, 2.3), Vector3(x0 + dir * 0.18, 5.65, zl))             # frontão
			_prop("gothic_statue", x0 + dir * 0.38, zl, PI / 2.0 * dir, 1.5, 1.62)                      # santo no nicho
			for sz: float in [-1.0, 1.0]:
				_vela(x0 + dir * 0.6, 1.1, zl + sz * 0.75, false)
				_bb.cylinder("ouro_velho", 0.05, 0.07, 0.12, Vector3(x0 + dir * 0.6, 1.13, zl + sz * 0.75), Vector3.ZERO, 12)
			_parte("anthurium_botany_01", ["anthurium_botany_04_d"], x0 + dir * 0.6, zl, 0.0, 0.18, 1.1)
			var lc := b._lamp_light(g, Vector3(x0 + dir * 0.7, 1.6, zl), 0.55)
			lc.omni_range = 4.0
			b._blocker(g, "ColAltarLat_%d_%d" % [int(lado), int(zl)], Vector3(1.0, 1.2, 2.1), Vector3(x0 + dir * 0.5, 0.6, zl))
	# vitrais coloridos nas janelas altas (emissivos) com uma luz colorida entrando
	for k in 3:
		for lado2: String in ["O", "L"]:
			_vitral(lado2, 5.0 + k * 5.5, 5.0, 1.0, 2.4, k)
	# púlpito dourado na parede oeste, com escada e dossel
	_bb.cylinder("madeira_escura", 0.5, 0.45, 1.5, Vector3(0.9, 1.95, 12.0), Vector3.ZERO, 14)
	_bb.cylinder("ouro_velho", 0.55, 0.55, 0.1, Vector3(0.9, 2.75, 12.0), Vector3.ZERO, 14)
	_bb.box("madeira_escura", Vector3(0.1, 2.6, 1.0), Vector3(0.08, 3.3, 12.0))
	_bb.cylinder("ouro_velho", 0.95, 0.2, 0.7, Vector3(0.7, 5.0, 12.0), Vector3.ZERO, 14)           # dossel (sino invertido)
	_bb.sphere("ouro_velho", 0.14, Vector3(0.7, 5.45, 12.0), 10, 8)
	b._blocker(g, "ColPulpito", Vector3(1.1, 2.9, 1.1), Vector3(0.9, 1.45, 12.0))
	# estandartes vermelhos e dourados nas colunas do arco triunfal
	for sx: float in [-1.0, 1.0]:
		_bb.box("bandeira_a", Vector3(0.06, 2.4, 0.9), Vector3(5.0 + sx * 4.3, 4.6, 16.6))
		_bb.box("ouro_velho", Vector3(0.08, 0.08, 1.0), Vector3(5.0 + sx * 4.3, 5.85, 16.6))
	# fonte batismal de pedra junto à porta
	_bb.cylinder("cantaria", 0.55, 0.45, 0.9, Vector3(8.6, 0.45, 1.8), Vector3.ZERO, 14)
	_bb.cylinder("cantaria", 0.7, 0.7, 0.12, Vector3(8.6, 0.96, 1.8), Vector3.ZERO, 14)
	_bb.cylinder("agua_chafariz", 0.55, 0.55, 0.02, Vector3(8.6, 1.02, 1.8), Vector3.ZERO, 14)
	b._blocker(g, "ColBatismal", Vector3(1.4, 1.1, 1.4), Vector3(8.6, 0.55, 1.8))


## Vitral em mosaico (células de vidro colorido com chumbo escuro) com uma luz colorida entrando na nave.
func _vitral(lado: String, p: float, y: float, w: float, h: float, tom: int) -> void:
	var mats := ["vitral_vermelho", "vitral_azul", "vitral_ambar", "vitral_verde"]
	var x := 0.05 if lado == "O" else _w - 0.05
	var yaw := PI / 2.0 if lado == "O" else -PI / 2.0
	var cols := 3
	var rows := 7
	for r in rows:
		for c in cols:
			var m: String = mats[(r * 2 + c + tom) % 4]
			var cw := w / cols
			var ch := h / rows
			var zz := p - w * 0.5 + cw * (c + 0.5)
			var yy := y - h * 0.5 + ch * (r + 0.5)
			_bb.quad(m, Vector2(cw - 0.05, ch - 0.05), Vector3(x, yy, zz), yaw)
	var cor: Color = [Color(0.9, 0.2, 0.2), Color(0.25, 0.35, 1.0), Color(1.0, 0.7, 0.2)][tom % 3]
	var l := OmniLight3D.new()
	l.position = Vector3(x + (0.9 if lado == "O" else -0.9), y - 0.5, p)
	l.light_color = cor
	l.light_energy = 0.6
	l.omni_range = 5.5
	_g.add_child(l)


## Arco em pé (plano X-Y, olhando para -Z): anel de caixas ao redor de `c`.
func _arco_xy(mat: String, c: Vector3, r: float, esp: float, prof: float, segs := 12) -> void:
	for k in segs:
		var t0 := PI * float(k) / segs
		var t1 := PI * float(k + 1) / segs
		var tm := (t0 + t1) * 0.5
		var corda := 2.0 * r * sin((t1 - t0) * 0.5) + 0.03
		_bb.box(mat, Vector3(corda, esp, prof), c + Vector3(cos(tm) * r, sin(tm) * r, 0), Vector3(0, 0, tm + PI / 2.0))


## Coluna torça (salomônica) dourada: pilhas de caixas girando, com base e capitel.
func _coluna_torsa(x: float, z: float, y0: float, alt: float) -> void:
	_bb.box("ouro_velho", Vector3(0.62, 0.22, 0.62), Vector3(x, y0 + 0.11, z))
	_bb.box("cantaria", Vector3(0.5, 0.12, 0.5), Vector3(x, y0 + 0.28, z))
	var n := int((alt - 0.7) / 0.18)
	for k in n:
		var yy := y0 + 0.34 + 0.18 * k + 0.09
		_bb.box("ouro_velho", Vector3(0.34, 0.2, 0.34), Vector3(x, yy, z), Vector3(0, k * 0.42, 0))
		_bb.box("ouro_velho", Vector3(0.34, 0.2, 0.34), Vector3(x, yy, z), Vector3(0, k * 0.42 + PI / 4.0, 0))
	_bb.cylinder("madeira_escura", 0.13, 0.13, alt - 0.7, Vector3(x, y0 + 0.34 + (alt - 0.7) * 0.5, z), Vector3.ZERO, 8)
	_bb.box("ouro_velho", Vector3(0.62, 0.22, 0.62), Vector3(x, y0 + alt - 0.11, z))
	_bb.sphere("ouro_velho", 0.2, Vector3(x, y0 + alt + 0.05, z), 8, 4)


func _castical(x: float, y: float, z: float, alt: float, luz := false) -> void:
	_bb.cylinder("ouro_velho", 0.16, 0.16, 0.05, Vector3(x, y + 0.025, z), Vector3.ZERO, 10)
	_bb.cylinder("ouro_velho", 0.035, 0.05, alt, Vector3(x, y + 0.05 + alt * 0.5, z), Vector3.ZERO, 8)
	_bb.sphere("ouro_velho", 0.065, Vector3(x, y + 0.05 + alt * 0.45, z), 6, 4)
	_bb.cylinder("ouro_velho", 0.075, 0.04, 0.05, Vector3(x, y + 0.05 + alt, z), Vector3.ZERO, 8)
	_vela(x, y + 0.075 + alt, z, luz)


## Presbitério barroco: três degraus, grade da comunhão, altar com toalha, sacrário e castiçais, e o retábulo dourado
## (colunas torças, nicho com santa, glória de raios, crucifixo) encostado na parede do fundo.
func _presbiterio(g: Node3D) -> void:
	# degraus (o topo, a 0,6 m, é onde o altar fica; os blocos de colisão cobrem o conjunto)
	_bb.box("cantaria", Vector3(9.4, 0.2, 4.4), Vector3(5.0, 0.1, 19.8))
	_bb.box("cantaria", Vector3(9.4, 0.2, 3.5), Vector3(5.0, 0.3, 20.25))
	_bb.box("cantaria", Vector3(9.4, 0.2, 2.6), Vector3(5.0, 0.5, 20.7))
	b._blocker(g, "ColDegrau", Vector3(9.4, 0.6, 3.8), Vector3(5.0, 0.3, 19.9))
	# grade da comunhão: balaústres torneados com corrimão, aberta no meio
	for lado: float in [-1.0, 1.0]:
		var x0: float = 5.0 + lado * 0.9
		for k in 7:
			var xx: float = x0 + lado * (0.25 + k * 0.55)
			_bb.cylinder("madeira_escura", 0.05, 0.05, 0.5, Vector3(xx, 0.45, 17.75), Vector3.ZERO, 6)
			_bb.sphere("ouro_velho", 0.06, Vector3(xx, 0.72, 17.75), 5, 3)
		var cx: float = 5.0 + lado * (0.9 + 2.0)
		_bb.box("madeira_escura", Vector3(4.2, 0.07, 0.16), Vector3(cx, 0.76, 17.75))
		_bb.box("madeira_escura", Vector3(4.2, 0.08, 0.2), Vector3(cx, 0.2, 17.75))
		b._blocker(g, "ColGrade_%d" % int(lado), Vector3(4.2, 0.9, 0.3), Vector3(cx, 0.45, 17.75))
	# altar: mesa de pedra com painéis dourados na frente, tampo, toalha branca com franja
	_bb.box("cantaria", Vector3(2.6, 1.05, 0.95), Vector3(5.0, 1.12, 20.2))
	for k in 3:
		var px := 5.0 + (k - 1) * 0.82
		_bb.box("ouro_velho", Vector3(0.7, 0.8, 0.03), Vector3(px, 1.1, 19.715))
		_bb.box("madeira_escura", Vector3(0.6, 0.7, 0.04), Vector3(px, 1.1, 19.712))
		_bb.sphere("ouro_velho", 0.09, Vector3(px, 1.1, 19.69), 6, 4)
	_bb.box("cantaria", Vector3(2.9, 0.08, 1.1), Vector3(5.0, 1.68, 20.2))
	_bb.box("pano_cru", Vector3(3.3, 0.04, 1.2), Vector3(5.0, 1.73, 20.2))
	_bb.box("pano_cru", Vector3(2.3, 0.78, 0.03), Vector3(5.0, 1.3, 19.69))               # frontal pendurado
	_bb.box("ouro_velho", Vector3(2.3, 0.06, 0.04), Vector3(5.0, 0.9, 19.685))
	_bb.box("ouro_velho", Vector3(3.3, 0.03, 0.05), Vector3(5.0, 1.72, 19.6))
	b._blocker(g, "ColAltar", Vector3(2.7, 1.2, 1.05), Vector3(5.0, 1.2, 20.2))
	# sobre o altar: sacrário dourado com cúpula e cruz, castiçais de alturas diferentes e vasos de flores
	_bb.box("ouro_velho", Vector3(0.6, 0.62, 0.42), Vector3(5.0, 2.05, 20.55))
	_bb.box("madeira_escura", Vector3(0.38, 0.44, 0.03), Vector3(5.0, 2.05, 20.33))
	_bb.sphere("ouro_velho", 0.05, Vector3(5.0, 2.05, 20.31), 5, 3)
	_bb.sphere("ouro_velho", 0.3, Vector3(5.0, 2.36, 20.55), 8, 4)
	_bb.box("ouro_velho", Vector3(0.04, 0.3, 0.04), Vector3(5.0, 2.78, 20.55))
	_bb.box("ouro_velho", Vector3(0.18, 0.04, 0.04), Vector3(5.0, 2.82, 20.55))
	for k: float in [-1.0, 1.0]:
		_castical(5.0 + k * 0.62, 1.77, 20.35, 0.36, true)
		_castical(5.0 + k * 1.02, 1.77, 20.35, 0.52)
		_castical(5.0 + k * 1.34, 1.77, 20.35, 0.30)
		_prop("brass_vase_03", 5.0 + k * 0.82, 20.7, 0.0, 1.5, 1.74)                                  # vaso de latão trabalhado (Poly Haven, CC0)
		for fl in 6:
			_bb.sphere("flor_rosa" if fl % 2 == 0 else "flor_amarela", 0.05, Vector3(5.0 + k * 0.82 + (fl % 3 - 1) * 0.04, 2.06 + (fl % 2) * 0.06, 20.7 + ((fl * 7) % 3 - 1) * 0.035), 5, 3)
	# retábulo dourado encostado na parede do fundo (z = 22)
	_bb.box("ouro_velho", Vector3(8.0, 7.0, 0.3), Vector3(5.0, 4.1, 21.85))
	_bb.box("madeira_escura", Vector3(2.4, 3.2, 0.12), Vector3(5.0, 3.9, 21.66))              # fundo do nicho
	_bb.box("ouro_velho", Vector3(2.7, 0.18, 0.26), Vector3(5.0, 2.2, 21.62))                 # base do nicho
	_bb.box("ouro_velho", Vector3(0.18, 3.0, 0.26), Vector3(3.75, 3.7, 21.62))
	_bb.box("ouro_velho", Vector3(0.18, 3.0, 0.26), Vector3(6.25, 3.7, 21.62))
	_arco_xy("ouro_velho", Vector3(5.0, 5.2, 21.62), 1.25, 0.18, 0.26, 14)
	_bb.box("madeira_escura", Vector3(2.4, 0.5, 0.12), Vector3(5.0, 5.35, 21.66))
	_bb.sphere("ouro_velho", 0.16, Vector3(5.0, 6.55, 21.6), 6, 4)                           # fecho do arco
	# santa no nicho: estátua de verdade (modelo gothic_statue) com auréola dourada
	_prop("gothic_statue", 5.0, 21.4, PI, 2.2 / 1.0, 2.3)
	_bb.cylinder("ouro_velho", 0.34, 0.34, 0.03, Vector3(5.0, 4.5, 21.55), Vector3(PI / 2.0, 0, 0), 20)
	# colunas torças dos dois lados e entablamento
	for k: float in [-1.0, 1.0]:
		_coluna_torsa(5.0 + k * 2.2, 21.2, 0.6, 5.8)
		_coluna_torsa(5.0 + k * 3.35, 21.4, 0.6, 5.2)
		_bb.box("ouro_velho", Vector3(0.9, 6.0, 0.35), Vector3(5.0 + k * 4.05, 3.7, 21.7))
	_bb.box("ouro_velho", Vector3(8.4, 0.35, 0.9), Vector3(5.0, 6.65, 21.35))
	_bb.box("cantaria", Vector3(8.6, 0.1, 1.0), Vector3(5.0, 6.88, 21.3))
	_bb.box("ouro_velho", Vector3(8.8, 0.18, 1.1), Vector3(5.0, 7.0, 21.25))
	# glória: raios dourados em leque sobre o nicho, com o crucifixo (e a figura pálida) no centro
	for k in 11:
		var ang := PI * (0.12 + 0.76 * float(k) / 10.0)
		var dir := Vector2(cos(ang), sin(ang))
		_bb.box("ouro_velho", Vector3(0.07, 1.25, 0.05), Vector3(5.0 + dir.x * 0.95, 7.35 + dir.y * 0.95, 21.55), Vector3(0, 0, ang - PI / 2.0))
	_bb.box("ferro", Vector3(0.14, 1.5, 0.1), Vector3(5.0, 7.3, 21.5))
	_bb.box("ferro", Vector3(0.95, 0.14, 0.1), Vector3(5.0, 7.7, 21.5))
	_bb.sphere("ouro_velho", 0.14, Vector3(5.0, 7.3, 21.42), 12, 8)                           # coração radiante no centro da cruz
	# lâmpada do santíssimo: pendurada à frente do altar, chama vermelha
	_bb.cylinder("ferro", 0.012, 0.012, 2.2, Vector3(5.0, 6.7, 19.0), Vector3.ZERO, 4)
	_prop("brass_diya_lantern", 5.0, 19.0, 0.0, 1.5, 5.0)                                          # lampião diya de latão pendurado (Poly Haven, CC0)
	b._halo(g, Vector3(5.0, 5.52, 19.0), 0.9, "halo_quente")
	# castiçais altos de chão dos dois lados
	for k: float in [-1.0, 1.0]:
		_castical(5.0 + k * 3.9, 0.6, 19.2, 1.6)
		_bb.box("ouro_velho", Vector3(0.9, 0.9, 0.9), Vector3(5.0 + k * 4.0, 1.05, 20.6))                 # pedestal dourado
		_prop("gothic_statue", 5.0 + k * 4.0, 20.6, PI + k * 0.5, 1.5, 1.5)                          # santos de cada lado do altar


func _sala_carpintaria(g: Node3D) -> void:
	# CARPINTARIA do Seu Mateus: bancada de marceneiro com torno, painel de ferramentas na parede, cavaletes com tábua, pilha de
	# tábuas, serragem no chão, cepo de rachar lenha e, no fundo, os caixões de pinho da encomenda da Companhia (a história do lugar).
	_casca("Carpintaria do Seu Mateus", 8.0, 6.0, 3.2, "reboco_branco", "piso_taco", "forro_tabuas")
	# --- bancada de marceneiro na parede norte: tampo grosso, prateleira embaixo, torno de madeira
	var bz := 5.45
	_bb.box("madeira_natural", Vector3(3.0, 0.10, 0.80), Vector3(3.6, 0.88, bz))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_bb.box("madeira_escura", Vector3(0.10, 0.83, 0.10), Vector3(3.6 + sx * 1.38, 0.415, bz + sz * 0.33))
	_bb.box("madeira_escura", Vector3(2.8, 0.04, 0.66), Vector3(3.6, 0.22, bz))                       # prateleira de baixo
	_bb.box("madeira_natural", Vector3(0.30, 0.22, 0.10), Vector3(2.35, 0.82, bz - 0.44))              # torno de bancada
	_bb.cylinder("ferro", 0.018, 0.018, 0.35, Vector3(2.35, 0.82, bz - 0.55), Vector3(PI / 2.0, 0, 0), 6)
	b._blocker(g, "ColBancada", Vector3(3.0, 0.93, 0.8), Vector3(3.6, 0.465, bz))
	_prop("hand_plane_no4", 3.1, bz - 0.1, 0.4, 1.0, 0.93)
	_prop("handsaw_wood", 4.2, bz + 0.05, 1.2, 1.0, 0.93)
	_prop("trowel_01", 4.8, bz - 0.15, 0.7, 1.0, 0.93)
	for k in 6:                                                                                   # aparas e serragem no tampo e no chão
		_bb.box("pano_cru", Vector3(0.10 + 0.04 * (k % 3), 0.006, 0.05), Vector3(2.7 + k * 0.32, 0.935, bz + 0.12 - (k % 2) * 0.2), Vector3(0, k * 0.7, 0))
	_bb.box("pano_cru", Vector3(1.6, 0.004, 0.9), Vector3(3.4, 0.003, bz - 1.0))                   # serragem espalhada no piso
	# --- painel de ferramentas na parede norte, acima da bancada
	_bb.box("madeira_escura", Vector3(2.6, 1.0, 0.04), Vector3(3.6, 1.75, _d - 0.03))
	for k in 7:
		var tx := 2.5 + k * 0.36
		_bb.box("ferro", Vector3(0.02, 0.02, 0.06), Vector3(tx, 2.05, _d - 0.07))                  # pregos
		if k % 2 == 0:
			_bb.box("madeira_natural", Vector3(0.04, 0.32, 0.03), Vector3(tx, 1.86, _d - 0.08))    # cabos pendurados
			_bb.box("ferro", Vector3(0.10, 0.06, 0.02), Vector3(tx, 1.70, _d - 0.08))
		else:
			_bb.box("ferro", Vector3(0.22, 0.03, 0.02), Vector3(tx, 1.95, _d - 0.08), Vector3(0, 0, 0.6))  # esquadros e formões
	_lamparina(3.6, 0.93, bz + 0.2)
	_nota(2.85, 0.93, bz - 0.2, 12, "Ler o bilhete do Seu Mateus")
	_comida(4.5, bz + 0.2, 0.93, "cafe", "Beber o café")
	# --- cavaletes com uma tábua no meio da oficina
	for cx: float in [4.6, 6.2]:
		for sz: float in [-1.0, 1.0]:
			_bb.box("madeira_natural", Vector3(0.06, 0.72, 0.06), Vector3(cx, 0.36, 2.9 + sz * 0.22), Vector3(sz * 0.25, 0, 0))
		_bb.box("madeira_natural", Vector3(0.08, 0.06, 0.62), Vector3(cx, 0.72, 2.9))
	_bb.box("madeira_natural", Vector3(2.6, 0.05, 0.30), Vector3(5.4, 0.78, 2.9))
	b._blocker(g, "ColCavaletes", Vector3(2.6, 0.8, 0.7), Vector3(5.4, 0.4, 2.9))
	# --- pilha de tábuas e cepo de rachar lenha com machado
	for k in 6:
		_bb.box("madeira_natural", Vector3(0.28, 0.05, 2.4), Vector3(7.55, 0.03 + k * 0.06, 2.2), Vector3(0, (k % 2) * 0.03, 0))
	b._blocker(g, "ColTabuas", Vector3(0.4, 0.4, 2.4), Vector3(7.55, 0.2, 2.2))
	_bb.cylinder("madeira_escura", 0.28, 0.30, 0.5, Vector3(1.0, 0.25, 1.4), Vector3.ZERO, 10)
	b._blocker(g, "ColCepo", Vector3(0.6, 0.5, 0.6), Vector3(1.0, 0.25, 1.4))
	_prop("wooden_axe_02", 1.0, 1.4, 0.6, 1.0, 0.5).rotation.z = 0.45
	# --- os caixões de pinho, encostados na parede oeste (a encomenda dos 31): tampa lisa, sem nome
	for k in 3:
		var cz := 2.4 + k * 0.85
		_bb.box("madeira_natural", Vector3(0.40, 1.85, 0.62), Vector3(0.30, 0.95, cz), Vector3(0, 0, -0.10))
		_bb.box("madeira_escura", Vector3(0.03, 1.80, 0.56), Vector3(0.51, 0.95, cz), Vector3(0, 0, -0.10))
	b._blocker(g, "ColCaixoes", Vector3(0.6, 1.9, 2.4), Vector3(0.32, 0.95, 3.25))
	_examinar(0.8, 1.1, 3.25, "Examinar os caixões", "Pinho sem verniz, tampa lisa, sem nome. | No fundo de um deles, a lápis, escondido: um nome. O Seu Mateus escreveu um em cada caixão.", "creak", 0.12)
	_nota(0.85, 0.02, 4.4, 27, "Ler a encomenda da Companhia")
	_encostar_auto("worn_metal_rack", 7.5, 5.4, 1.0)
	_prop_c("wooden_ladder", 7.45, 4.3, -PI / 2.0, 1.5).rotation.x = -0.18
	_prop("rusted_spade_01", 7.6, 0.6, 0.0, 1.0, 0.0).rotation.z = 0.10
	_janela("L", 2.2)
	_oleo(6.9, 0.95, 0.9)
	_fim()


func _sala_escola(g: Node3D) -> void:
	# ESCOLA RURAL ampla: quadro-negro grande na parede do fundo, mesa da professora, 12 carteiras em dois blocos com corredor no meio,
	# estante, armário, cabideiro com bolsas e lâmpadas penduradas. Tudo medido: cadeiras sob as carteiras, nada encostando em nada.
	_casca("Escola Rural", 10.0, 8.0, 3.4, "reboco_creme", "piso_taco", "forro_tabuas")
	# quadro-negro na parede do fundo (z = 8) com moldura e calha de giz
	_bb.box("madeira_escura", Vector3(3.3, 1.42, 0.05), Vector3(5.0, 1.75, 7.97))
	_bb.quad("placa_verde", Vector2(3.1, 1.22), Vector3(5.0, 1.75, 7.94), PI)
	_bb.box("madeira_natural", Vector3(3.2, 0.04, 0.10), Vector3(5.0, 1.02, 7.92))
	for k in 4:
		_bb.cylinder("pano_cru", 0.008, 0.008, 0.07, Vector3(4.2 + k * 0.3, 1.05, 7.9), Vector3(0, 0, PI / 2.0), 5)    # gizes
	_examinar(5.0, 1.75, 7.6, "Ler o quadro-negro", "Escrito com letra de criança, por cima da lição: 'TODO NOME MERECE SER DITO.' | Embaixo, apagado pela metade, uma lista de sobrenomes da vila. Os da Galeria Três estão sublinhados.", "papel", 0.05)
	# mesa da professora (perto do quadro) com cadeira atrás, voltada para a turma
	_mesa(7.6, 6.7, 1.6, 0.8, 0.8, "madeira_escura")
	_cadeira_mesa(7.6, 6.7, 1.6, 0.8, "N")
	_papelaria(7.35, 6.6, 0.84, 0.0)
	_lamparina(8.1, 0.84, 6.85)
	_nota(7.0, 0.9, 6.55, 13, "Ler o caderno de caligrafia")
	_comida(8.1, 6.45, 0.84, "cafe", "Beber o café")
	# carteiras: dois blocos (x 1,6/3,2 e 6,8/8,4) x três fileiras; cadeira do lado sul (o aluno olha para o quadro)
	for xc: float in [1.6, 3.2, 6.8, 8.4]:
		for zr: float in [2.9, 4.2, 5.5]:
			if xc > 6.0 and zr > 5.0:
				continue                                                  # perto da mesa da professora fica livre
			_mesa(xc, zr, 1.0, 0.5, 0.7, "madeira_natural")
			_cadeira_mesa(xc, zr, 1.0, 0.5, "S")
	# estante (parede oeste, perto do quadro), armário (parede leste, na frente) e cabideiro com bolsas (parede oeste, na entrada)
	_prop_c("wooden_bookshelf_worn", 0.31, 6.9, PI / 2.0, 1.0)
	_prop_c("GothicCabinet_01", 9.5, 1.3, -PI / 2.0, 0.85)
	_bb.box("madeira_escura", Vector3(0.04, 0.10, 2.2), Vector3(0.03, 1.55, 2.4))
	for k in 5:
		_bb.box("ferro", Vector3(0.10, 0.02, 0.02), Vector3(0.08, 1.52, 1.5 + k * 0.45))
		if k % 2 == 0:
			_bb.box("pano_cru" if k == 0 else "pano_azul", Vector3(0.10, 0.34, 0.26), Vector3(0.10, 1.3, 1.5 + k * 0.45))   # bolsa de pano pendurada
	# duas lâmpadas apagadas penduradas pelo fio (a luz da sala vem das lamparinas)
	for lx: float in [3.0, 7.0]:
		_prop("lightbulb_01", lx, 4.2, 0.0, 1.0, 2.75)
		_bb.cylinder("ferro", 0.008, 0.008, 0.55, Vector3(lx, 3.13, 4.2), Vector3.ZERO, 4)
	_lamparina(3.2, 0.74, 4.3)
	_janela("O", 4.2)
	_janela("L", 4.2)
	_oleo(9.5, 0.95, 4.2)
	_examinar(3.2, 0.8, 2.9, "Examinar a carteira", "Alguém entalhou um nome no tampo, letra por letra, com a ponta de um compasso. O mesmo nome está riscado no livro de chamada.", "papel")
	_fim()


func _sala_ferraria(g: Node3D) -> void:
	_casca("Ferraria", 7.0, 5.0, 3.4, "reboco_ocre", "cantaria")
	# forja de pedra com brasa e fole, bigorna, tonel d'água, aros de roda
	_bb.box("cantaria", Vector3(1.8, 1.0, 1.4), Vector3(_mx(5.8), 0.5, _mz(4.1)))
	_bb.box("chama", Vector3(1.2, 0.04, 0.8), Vector3(_mx(5.8), 1.01, _mz(4.1)))
	_bb.box("cantaria", Vector3(0.9, 2.4, 0.9), Vector3(_mx(5.8), 2.2, _mz(4.5)))
	var lf := b._lamp_light(g, Vector3(_mx(5.8), 1.5, _mz(3.5)), 1.0)
	lf.light_color = Color(1.0, 0.4, 0.1)
	lf.omni_range = 6.0
	b._blocker(g, "ColForja", Vector3(1.8, 1.0, 1.4), Vector3(_mx(5.8), 0.5, _mz(4.1)))
	_bb.box("ferro", Vector3(0.5, 0.35, 0.3), Vector3(_mx(3.6), 0.7, _mz(3.4)))                              # bigorna
	_bb.box("madeira_escura", Vector3(0.4, 0.55, 0.4), Vector3(_mx(3.6), 0.27, _mz(3.4)))
	b._blocker(g, "ColBigorna", Vector3(0.6, 0.9, 0.5), Vector3(_mx(3.6), 0.45, _mz(3.4)))
	_prop_c("wine_barrel_01", _mx(0.7), _mz(4.2), 0.0, 1.0)
	_encostar_auto("worn_metal_rack", _mx(0.4), _mz(2.0), 1.0)
	_prop("rusted_wheel_rim_02", _mx(1.5), _mz(1.2), 0.5, 1.5).rotation.x = -0.2
	_prop("wooden_axe_02", _mx(1.1), _mz(2.0), 0.0, 1.0, 0.0).rotation.z = 0.25
	_prop("hand_plane_no4", _mx(3.6), _mz(3.4), 0.3, 1.0, 0.89)
	_lamparina(_mx(2.4), 0.01, _mz(4.6), 0.7)
	_janela("L", _mz(2.0))
	_oleo(_mx(6.4), 1.05, _mz(1.0))
	_prop("can_rusted", _mx(2.0), _mz(0.6), 0.5, 1.4, 0.0)
	_prop("can_rusted", _mx(2.25), _mz(0.75), 1.5, 1.4, 0.0)
	_nota(_mx(2.4), 0.2, _mz(4.4), 14, "Ler a encomenda do ferreiro")
	_fim()


func _sala_casa_vazia(g: Node3D) -> void:
	_casca("Casa abandonada", 6.0, 5.0, 2.9, "reboco_verde", "madeira_escura")
	_encostar_auto("old_bed_frame", _mx(1.1), _mz(3.8), 1.0)
	_cadeira(_mx(3.6), _mz(2.4), 1.0)                                                    # cadeira virada
	_bx("madeira_natural", Vector3(_mx(4.6), 0, _mz(3.4)), 0.9, Vector3(0, 0.2, 0), Vector3(0.44, 0.44, 0.04))
	_mesa(_mx(4.4), _mz(3.8), 1.2, 0.8)
	_encostar_auto("GothicCabinet_01", _mx(3.0), _mz(4.35), 0.9)
	_prop("cigarette_pack", _mx(4.4), _mz(3.8), 0.2, 1.5, 0.82)
	_vela(_mx(4.9), 0.82, _mz(4.0), true)
	_janela("L", _mz(2.5))
	_nota(_mx(4.2), 0.85, _mz(3.6), 15, "Ler o diário abandonado")
	_encostar_auto("wooden_bookshelf_worn", _mx(3.6), _mz(0.34), 1.0)
	_prop("WoodenTable_02", _mx(2.1), _mz(2.3), 0.4, 1.0)
	_oleo(_mx(5.5), 0.95, _mz(1.0))
	_comida(4.0, 3.9, 0.82, "sardinha", "Comer a lata de sardinha")
	_fim()


func _sala_pensao(g: Node3D) -> void:
	_casca("Pensão da Dona Elvira", 7.0, 6.0, 3.0, "reboco_verde", "piso_taco", "forro_tabuas")
	_encostar_auto("old_bed_frame", _mx(1.0), _mz(4.6), 1.0)
	_encostar_auto("old_bed_frame", _mx(6.0), _mz(4.6), 1.0)
	_encostar_auto("vintage_day_bed", _mx(3.5), _mz(0.9), 1.0)
	_tapete(_mx(3.5), _mz(2.6), 2.4, 1.6, 1)
	_prop_c("gothic_coffee_table", _mx(3.5), _mz(2.6), 0.0, 1.0)
	_prop("vintage_binocular", _mx(3.2), _mz(2.6), 0.4, 1.0, 0.56)
	_prop("cigarette_pack", _mx(3.9), _mz(2.4), 1.0, 1.5, 0.56)
	_mesa(_mx(3.5), _mz(5.3), 1.2, 0.7, 0.8, "madeira_escura")
	_papelaria(_mx(3.2), _mz(5.3), 0.84, 0.4)
	_lamparina(_mx(3.9), 0.84, _mz(5.3))
	_janela("L", _mz(1.7))
	_janela("O", _mz(1.7))
	_nota(_mx(3.6), 0.88, _mz(5.0), 16, "Ler o livro de hóspedes")
	_encostar_auto("painted_wooden_nightstand", _mx(2.0), _mz(5.55), 1.0)
	_prop("vintage_lighter", _mx(3.55), _mz(5.5), 0.5, 1.0, 0.8)
	_encostar_auto("painted_wooden_nightstand", _mx(5.0), _mz(5.55), 1.0)
	_parte("vintage_suitcase", ["vintage_suitcase_01_"], _mx(5.6), _mz(2.1), 0.5, 0.75, 0.0)
	_parte("vintage_suitcase", ["vintage_suitcase_02_"], _mx(6.25), _mz(2.55), -0.4, 0.75, 0.0)                                              # as malas do Dr. Anselmo, esquecidas no quarto
	_oleo(_mx(6.5), 0.95, _mz(1.0))
	_comida(4.0, 5.3, 0.84, "pao", "Comer o pão")
	_fim()


func _sala_costureira(g: Node3D) -> void:
	_casca("Casa da costureira", 6.0, 5.0, 2.9, "reboco_azul", "piso_taco", "forro_tabuas")
	_mesa(_mx(3.0), _mz(3.6), 1.8, 0.9, 0.8, "madeira_natural")                           # mesa de corte
	_bb.box("pano_rosa", Vector3(1.4, 0.03, 0.8), Vector3(_mx(3.0), 0.83, _mz(3.6)))
	_papelaria(_mx(3.4), _mz(3.4), 0.84, 0.6)
	for k in 4:
		_bb.cylinder(["pano_azul", "pano_rosa", "pano_cru", "listra_vermelha"][k], 0.1, 0.1, 0.8, Vector3(_mx(0.5), 0.1 + k * 0.2, _mz(1.4 + k * 0.01)), Vector3(PI / 2.0, 0, 0), 8)
	_encostar_auto("GothicCabinet_01", _mx(1.25), _mz(4.35), 0.9)
	_lamparina(_mx(3.0), 0.83, _mz(3.4))
	_janela("L", _mz(2.0))
	_nota(_mx(2.5), 0.88, _mz(3.5), 17, "Ler a encomenda do vestido")
	_oleo(_mx(5.5), 0.95, _mz(1.0))
	_fim()


func _sala_deposito(g: Node3D) -> void:
	_casca("Depósito", 7.0, 5.0, 3.2, "reboco_branco", "cantaria")
	_examinar(_mx(0.8), 1.2, _mz(2.4), "Examinar as prateleiras", "Latas sem rótulo. Na única que tem, lê-se 'Companhia Minas do Ouro Preto, ração de campanha, 1958'. A data da carta é a mesma.")
	_examinar(_mx(6.0), 1.0, _mz(1.5), "Examinar os barris", "O vinho nos barris virou vinagre há anos. Alguém escreveu a giz na madeira: 'Eles contaram os mortos errado.'", "clink", 0.08)
	_encostar_auto("worn_metal_rack", _mx(0.4), _mz(1.6), 1.0)
	_encostar_auto("worn_metal_rack", _mx(0.4), _mz(3.2), 1.0)
	for k in 4:                       # só onde há prateleira embaixo (as duas últimas latas ficavam no ar)
		_lata(_mx(0.45), _mz(1.0 + k * 0.5), 0.95 if k % 2 == 0 else 1.45, PI / 2.0)
	_prop_c("wine_barrel_01", _mx(6.3), _mz(1.0), 0.0, 1.0)
	_prop_c("wine_barrel_01", _mx(6.3), _mz(2.0), 1.0, 1.0)
	_saco(_mx(5.4), _mz(3.8))
	_saco(_mx(5.9), _mz(4.2), 0.5)
	_saco(_mx(6.4), _mz(3.7))
	_prop("can_rusted", _mx(3.0), _mz(4.5), 0.3, 1.4, 0.0)
	# caixotes, cestos e jarros do depósito (kit Medieval Containers, CC0)
	var cx := _cont("Crate3", _mx(2.4), _mz(0.6), 0.1)
	_cont("Crate3", _mx(2.4), _mz(0.6), 0.5, (cx.get_meta("bb") as AABB).size.y, 0.9, false)
	_cont("Crate1", _mx(3.6), _mz(0.65), 0.0)
	_cont("Basket1", _mx(4.7), _mz(0.6), 0.4)
	_cont("Jug1", _mx(4.3), _mz(1.5), 1.0)
	_cont("Jug2", _mx(4.7), _mz(1.8), 2.0)
	_cont("Crate2", _mx(1.5), _mz(4.15), PI / 2.0)
	_prop_c("wooden_ladder", _mx(3.5), _mz(4.55), PI, 1.5).rotation.x = 0.18
	_prop("watering_can_metal_01", _mx(2.5), _mz(3.8), 0.3, 1.0)
	_lamparina(_mx(3.5), 0.01, _mz(1.2), 0.7)
	_janela("L", _mz(2.0))
	_oleo(_mx(2.0), 0.95, _mz(4.5))
	_oleo(_mx(6.0), 1.25, _mz(1.5))
	_fim()
