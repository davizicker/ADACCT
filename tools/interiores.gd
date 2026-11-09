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
const K_SALA := 1.3                    # as casas ficaram 30% maiores: móveis encostados nas paredes acompanham as paredes, o meio da sala fica livre
var _cadeiras: Array[Vector2] = []
var _n_casca := 0                      # quantas caixas de _bb são da casca da sala (o resto é mobília)


func construir(builder: VilaBuilder) -> Node3D:
	b = builder
	var root := Node3D.new()
	root.name = "Interiores"
	for i in ORDEM.size():
		var id := ORDEM[i]
		var g := Node3D.new()
		g.name = id
		g.position = BASE + Vector3(i * PASSO, 0.0, 0.0)
		root.add_child(g)
		_g = g
		call("_sala_" + id, g)
		_camada(g)
	return root


## Interior só recebe luz das lâmpadas dele (a Lua usa a máscara de camada 1).
func _camada(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).layers = 2
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
	_tem_tapete = false
	if nome != "Igreja Matriz":                      # a igreja já é grande
		w = snappedf(w * K_SALA, 0.1)
		d = snappedf(d * K_SALA, 0.1)
		h = snappedf(h * 1.1, 0.1)                  # pé-direito mais alto, como nas casas coloniais
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
	_bb.box(parede, Vector3(w + 0.6, h + 0.4, 0.3), Vector3(w / 2.0, h / 2.0, -0.15))
	_bb.box(parede, Vector3(w + 0.6, h + 0.4, 0.3), Vector3(w / 2.0, h / 2.0, d + 0.15))
	# rodapé
	_bb.box("madeira_escura", Vector3(w, 0.14, 0.04), Vector3(w / 2.0, 0.07, 0.02))
	_bb.box("madeira_escura", Vector3(w, 0.14, 0.04), Vector3(w / 2.0, 0.07, d - 0.02))
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
	b._blocker(_g, "Piso", Vector3(w + 4.0, 0.6, d + 4.0), Vector3(w / 2.0, -0.3, d / 2.0))
	b._blocker(_g, "Teto", Vector3(w + 4.0, 0.6, d + 4.0), Vector3(w / 2.0, h + 0.3, d / 2.0))
	b._blocker(_g, "ParedeO", Vector3(0.6, h + 2.0, d + 4.0), Vector3(-0.3, h / 2.0, d / 2.0))
	b._blocker(_g, "ParedeL", Vector3(0.6, h + 2.0, d + 4.0), Vector3(w + 0.3, h / 2.0, d / 2.0))
	b._blocker(_g, "ParedeS", Vector3(w + 4.0, h + 2.0, 0.6), Vector3(w / 2.0, h / 2.0, -0.3))
	b._blocker(_g, "ParedeN", Vector3(w + 4.0, h + 2.0, 0.6), Vector3(w / 2.0, h / 2.0, d + 0.3))
	# porta de saída (parede sul) e gatilho de interação
	_bb.box("cantaria", Vector3(1.5, 2.55, 0.12), Vector3(w / 2.0, 1.27, 0.06))
	_bb.box("madeira_escura", Vector3(1.2, 2.3, 0.1), Vector3(w / 2.0, 1.15, 0.11))
	_bb.box("ferro", Vector3(0.05, 0.12, 0.06), Vector3(w / 2.0 + 0.42, 1.05, 0.2))
	_bb.box("pano_cru", Vector3(1.0, 0.02, 0.6), Vector3(w / 2.0, 0.01, 0.55))                          # capacho
	_bb.box("madeira_escura", Vector3(1.04, 0.015, 0.64), Vector3(w / 2.0, 0.006, 0.55))
	var a := _area("Saida", Vector3(w / 2.0, 1.2, 0.8), Vector3(1.9, 2.4, 1.5), "res://scripts/porta.gd")
	a.set("destino", "")
	a.set("texto_interacao", "Sair para a rua")
	_n_casca = _bb._boxes.size()
	# luz de preenchimento: a sala não é mais um poço escuro. Brilho quente baixo no teto (a lamparina "vaza" pelo ar) e um toque frio junto ao piso (luar)
	var fill := OmniLight3D.new()
	fill.name = "Preenchimento"
	fill.position = Vector3(w * 0.5, h - 0.5, d * 0.5)
	fill.light_color = Color(1.0, 0.78, 0.55)
	fill.light_energy = 0.75
	fill.omni_range = maxf(w, d) * 1.1
	fill.light_specular = 0.2
	_g.add_child(fill)
	var luar := OmniLight3D.new()
	luar.name = "LuarDoChao"
	luar.position = Vector3(w * 0.5, 0.5, d * 0.5)
	luar.light_color = Color(0.5, 0.6, 0.9)
	luar.light_energy = 0.35
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
	rp.intensity = 1.0
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
func _tapete(x: float, z: float, lx: float, lz: float, qual := 0, yaw := 0.0) -> void:
	_tem_tapete = true
	var m := "tapete_a" if qual == 0 else "tapete_b"
	_bb.quad_h(m, Vector2(lx, lz), Vector3(x, 0.012, z), yaw)
	var c := cos(yaw)
	var sn := sin(yaw)
	for k in int(lx / 0.12):                                                  # franjas nas duas pontas menores
		var t := -lx * 0.5 + 0.06 + k * 0.12
		for sg: float in [-1.0, 1.0]:
			_bb.box("pano_cru", Vector3(0.02, 0.004, 0.10), Vector3(x + c * t - sn * sg * (lz * 0.5 + 0.05), 0.007, z + sn * t + c * sg * (lz * 0.5 + 0.05)), Vector3(0, yaw, 0))


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
			if a.grow(0.25).has_point((n as Node3D).position):
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
		if not _ocupado(AABB(Vector3(t.x - 0.5, 0.0, t.y - 0.5), Vector3(1.0, 0.8, 1.0))):
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


func _fim() -> void:
	_decorar()
	b._mesh_node(_g, "Mobilia", _bb.commit())


## Janela na parede: lado "L" (x = largura), "O" (x = 0) ou "N" (z = profundidade); `p` = posição ao longo da parede.
func _janela(lado: String, p: float, y := 1.6, w := 1.0, h := 1.3) -> void:
	var pos := Vector3.ZERO
	var yaw := 0.0
	match lado:
		"O":
			pos = Vector3(0.02, y, p)
			yaw = PI / 2.0
		"L":
			pos = Vector3(_w - 0.02, y, p)
			yaw = -PI / 2.0
		_:
			pos = Vector3(p, y, _d - 0.02)
			yaw = PI
	_bb.quad("vidro_noite", Vector2(w, h), pos, yaw)
	var dir := Vector3(sin(yaw), 0, cos(yaw))
	var side := Vector3(dir.z, 0, -dir.x)
	for k in [-1.0, 1.0]:
		_bb.box("madeira_escura", Vector3(0.06, h + 0.12, 0.06) if lado == "N" else Vector3(0.06, h + 0.12, 0.06), pos + dir * 0.03 + side * k * (w / 2.0 + 0.03))
	_bb.box("madeira_escura", Vector3(0.06, 0.06, 0.06), pos + dir * 0.03 + Vector3(0, h / 2.0 + 0.03, 0))
	# caixilho em cruz
	var along := side.abs()
	_bb.box("madeira_escura", Vector3(0.03 + along.x * w, 0.04, 0.03 + along.z * w), pos + dir * 0.03)
	_bb.box("madeira_escura", Vector3(0.04, h, 0.04), pos + dir * 0.03)
	# peitoril de pedra, varão e cortinas (as cores variam por janela)
	var pano: String = ["pano_rosa", "pano_azul", "pano_cru", "pano_rosa"][int(p * 3.0 + y * 5.0) % 4]
	var sill := Vector3(0.16, 0.05, w + 0.3) if lado != "N" else Vector3(w + 0.3, 0.05, 0.16)
	_bb.box("cantaria", sill, pos + dir * 0.09 + Vector3(0, -h / 2.0 - 0.03, 0))
	var rod := Vector3(0.03, 0.03, w + 0.8) if lado != "N" else Vector3(w + 0.8, 0.03, 0.03)
	_bb.box("ferro", rod, pos + dir * 0.10 + Vector3(0, h / 2.0 + 0.3, 0))
	var csz := Vector3(0.03, h + 0.45, 0.3) if lado != "N" else Vector3(0.3, h + 0.45, 0.03)
	for k in [-1.0, 1.0]:
		for dobra in 2:
			_bb.box(pano, csz, pos + dir * (0.08 + 0.02 * dobra) + side * k * (w / 2.0 + 0.14 - 0.09 * dobra) + Vector3(0, 0.02, 0))
	# luar frio entrando (sem sombra): pequena luz azul
	var l := OmniLight3D.new()
	l.position = pos + dir * 0.8
	l.light_color = Color(0.45, 0.58, 0.9)
	l.light_energy = 0.55
	l.omni_range = 6.0
	_g.add_child(l)


func _lamparina(x: float, y: float, z: float, energia := 0.85) -> void:
	y = _topo(x, y, z)
	_prop("vintage_oil_lamp", x, z, float(int(x * 10.0 + z * 7.0) % 6) * 1.05, 0.40, y)      # lamparina de óleo de verdade (Poly Haven, CC0)
	var l := b._lamp_light(_g, Vector3(x, y + 0.36, z), energia * 1.5)
	l.omni_range = 8.0
	l.shadow_enabled = true            # a lamparina projeta sombras dos móveis: o cômodo ganha volume
	b._halo(_g, Vector3(x, y + 0.24, z), 0.9, "halo_vela")


func _vela(x: float, y: float, z: float, luz := false) -> void:
	_bb.cylinder("vela", 0.018, 0.018, 0.14, Vector3(x, y + 0.07, z), Vector3.ZERO, 6)
	_bb.sphere("chama", 0.022, Vector3(x, y + 0.165, z), 5, 3)
	b._halo(_g, Vector3(x, y + 0.17, z), 0.35, "halo_vela")
	if luz:
		var l := b._lamp_light(_g, Vector3(x, y + 0.3, z), 0.5)
		l.omni_range = 4.5


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


func _cadeira(x: float, z: float, yaw := 0.0, _mat := "madeira_natural") -> void:
	_cadeiras.append(Vector2(x, z))
	_prop("painted_wooden_chair_02", x, z, yaw + PI, 1.0)      # cadeira pintada e descascada (Poly Haven, CC0); sem colisão, para não travar o caminho


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
	# nicho na parede norte com santa (cone + esfera), velas e prateleira
	_bb.box("madeira_escura", Vector3(1.3, 1.6, 0.35), Vector3(x, 1.3, z))
	_bb.box("cantaria", Vector3(1.1, 0.05, 0.3), Vector3(x, 1.0, z - 0.2))
	_bb.cylinder("pano_azul", 0.14, 0.05, 0.42, Vector3(x, 1.28, z - 0.2), Vector3.ZERO, 8)
	_bb.sphere("bradador_palido", 0.06, Vector3(x, 1.56, z - 0.2), 8, 5)
	_bb.box("ouro_velho", Vector3(0.04, 0.3, 0.04), Vector3(x, 2.25, z - 0.12))
	_bb.box("ouro_velho", Vector3(0.18, 0.04, 0.04), Vector3(x, 2.3, z - 0.12))
	for k in [-1.0, 1.0]:
		_vela(x + k * 0.42, 1.02, z - 0.2, k > 0)


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
func _tem_apoio(x: float, y: float, z: float) -> bool:
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
		_prop("WoodenTable_02", x, z, float(int(x * 13.0 + z * 7.0) % 6), 1.0, 0.0)
		y = 0.47
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
	y = _topo(x, y, z)
	var c := cos(yaw)
	var s := sin(yaw)
	_parte("stationery_supplies", ["stationery_supplies_pencilcup"], x, z, yaw, 1.3, y)
	_parte("stationery_supplies", ["stationery_supplies_eraser"], x + 0.17 * c, z + 0.1 * s, yaw + 0.6, 1.3, y)
	var nomes := ["pen_red", "pencil_new_a", "pen_fancy", "pencil_used", "pen_blue"]
	for k in 3:
		var ang := yaw + 0.9 + float(k) * 1.15 + float(int(x * 10.0 + z * 3.0) % 5) * 0.2
		_parte("stationery_supplies", ["stationery_supplies_" + String(nomes[(k + int(x * 7.0)) % nomes.size()])], x - 0.16 + 0.09 * k, z + 0.17 - 0.07 * k, ang, 1.3, y)


## Lata de comida isolada (leite, tomate, feijão ou sardinha, conforme a posição).
func _lata(x: float, z: float, y: float, yaw := 0.0) -> void:
	var nomes := ["milk", "tomatoes", "beans", "sardines"]
	var n: String = nomes[int(absf(x * 13.0 + z * 7.0)) % nomes.size()]
	_parte("long_life_food", ["long_life_food_" + n], x, z, yaw, 1.0, _topo(x, y, z))


func _prop(key: String, x: float, z: float, yaw := 0.0, escala := 1.0, y := 0.0) -> Node3D:
	return b._prop(_g, key, Vector3(x, y, z), yaw, escala)


# ------------------------------------------------------------------ salas

func _sala_benedita(g: Node3D) -> void:
	_casca("Casa de Dona Benedita", 7.0, 6.0, 3.0, "reboco_creme", "madeira_natural")
	_cama(_mx(1.2), _mz(4.7), 0.0)
	_armario(_mx(0.4), _mz(2.2), 1.3, 2.0, 0.55, PI / 2.0)
	_fogao(_mx(6.0), _mz(5.4), PI)
	_mesa(_mx(4.6), _mz(2.9), 1.6, 0.9)
	_cadeira(_mx(3.4), _mz(2.9), -PI / 2.0)
	_cadeira(_mx(5.8), _mz(2.9), PI / 2.0)
	_cadeira(_mx(4.6), _mz(2.0), 0.0)
	_lamparina(_mx(4.6), 0.82, _mz(3.1))
	_oratorio(_mx(3.6), _mz(5.75))
	_tapete(_mx(3.0), _mz(3.4), 2.4, 1.6, 1)
	_janela("L", _mz(3.2))
	_quadro(_mx(0.04), 1.8, _mz(3.5), "O", 0.4, 0.5)
	_nota(_mx(4.3), 0.85, _mz(2.7), 1, "Ler a carta de Dona Benedita")
	_nota(_mx(5.0), 0.86, _mz(3.15), 25, "Ler o papel atrás do retrato")
	_prop_c("painted_wooden_nightstand", _mx(2.35), _mz(5.6), PI, 1.0)
	_prop("planter_pot_clay", _mx(6.5), _mz(0.7), 0.0, 1.3, 0.0)
	_parte("anthurium_botany_01", ["anthurium_botany_01_a"], _mx(6.5), _mz(0.7), 0.3, 0.2, 0.28)
	_item("terco", Vector3(_mx(3.2), 1.07, _mz(5.55)), "Pegar o terço de Dona Benedita")
	_oleo(_mx(6.3), 0.95, _mz(3.3))
	_oleo(_mx(0.6), 1.4, _mz(4.2))
	_examinar(_mx(1.2), 0.9, _mz(4.7), "Examinar a cama", "A cama está feita, com a colcha dobrada ao pé. Ninguém dormiu aqui depois que o último trem de minério partiu. | Sob o travesseiro, um terço quebrado e um recibo da Companhia: 'indenização recusada'.")
	_examinar(_mx(3.6), 1.2, _mz(5.6), "Examinar o oratório", "O oratório tem quarenta e duas fitinhas amarradas. Quarenta e duas famílias, e nenhuma resposta.", "clink")
	_examinar(_mx(6.0), 1.0, _mz(5.2), "Examinar o fogão", "As cinzas ainda estão mornas. Não foi Dona Benedita que acendeu o fogo. | Há uma panela com café coado, intocada. A xícara tem batom, mas a casa nunca recebeu visita.", "creak", 0.12)
	_examinar(_mx(0.5), 1.0, _mz(2.2), "Abrir o armário", "Vestidos de luto, todos do mesmo tamanho, todos com uma flor de papel presa na gola. Dona Benedita ensaiava os velórios antes que acontecessem.", "creak")
	_prop("wooden_bucket_01", _mx(6.4), _mz(1.2), 0.5)
	_prop("wooden_stool_01", _mx(5.4), _mz(4.2), 0.3)
	_prop_c("round_wooden_table_02", _mx(1.5), _mz(1.2), 0.0, 1.0)
	_lata(_mx(4.95), _mz(3.2), 0.82, 0.6)
	_prop("watering_can_metal_01", _mx(6.4), _mz(0.9), 2.5, 1.0)
	_papelaria(_mx(1.5), _mz(1.2), 0.75, 0.3)
	_fim()


func _sala_padaria(g: Node3D) -> void:
	_casca("Padaria da esquina", 6.0, 5.0, 3.0, "reboco_amarelo", "madeira_escura")
	# forno de lenha na parede leste: arco de pedra, boca em brasa e luz de fogo
	_bb.box("cantaria", Vector3(1.4, 1.7, 2.0), Vector3(_mx(5.3), 0.85, _mz(3.4)))
	_bb.box("cantaria", Vector3(0.9, 1.7, 0.9), Vector3(_mx(5.4), 2.0, _mz(3.4)))
	_bb.box("chama", Vector3(0.02, 0.5, 0.9), Vector3(_mx(4.59), 0.9, _mz(3.4)))
	var lf := b._lamp_light(g, Vector3(_mx(4.2), 0.9, _mz(3.4)), 0.9)
	lf.light_color = Color(1.0, 0.42, 0.12)
	lf.omni_range = 6.0
	b._blocker(g, "ColForno", Vector3(1.4, 1.7, 2.0), Vector3(_mx(5.3), 0.85, _mz(3.4)))
	_examinar(_mx(5.0), 1.0, _mz(3.4), "Examinar o forno", "O forno de lenha está morno, com pães de ontem ainda dentro. Dizem que a padeira nunca saiu: ela assa para quem não tem mais boca.", "creak", 0.1)
	_examinar(_mx(2.0), 1.1, _mz(3.4), "Examinar o balcão", "Uma caderneta de fiado aberta: nomes, valores, e uma coluna riscada com a letra do Capataz. 'Quitado em sangue.'")
	_balcao(_mx(2.0), _mz(3.4), 2.6, PI / 2.0)
	_prateleira(_mx(0.35), 1.6, _mz(1.4), 1.6, PI / 2.0)
	for k in 5:
		_bb.cylinder("pao", 0.1, 0.1, 0.18, Vector3(_mx(0.35), 1.7, _mz(0.8 + k * 0.32)), Vector3(0, 0, PI / 2.0), 7)
	_mesa(_mx(3.5), _mz(1.7), 1.4, 0.9, 0.9)
	_saco(_mx(5.3), _mz(0.7))
	_saco(_mx(5.6), _mz(1.2), 0.5)
	_saco(_mx(5.2), _mz(1.7))
	_lamparina(_mx(2.0), 1.06, _mz(3.6))
	_janela("N", _mx(3.0))
	_nota(_mx(2.0), 1.15, _mz(2.9), 4, "Ler o recado")
	_nota(_mx(2.0), 1.15, _mz(4.1), 10, "Ler o caderno de fiado")
	_oleo(_mx(3.1), 0.95, _mz(1.9))
	_prop("wooden_bucket_01", _mx(1.2), _mz(4.4), 0.0)
	_lata(_mx(2.0), _mz(3.5), 1.05, 1.2)
	_prop("watering_can_metal_01", _mx(4.4), _mz(4.5), 0.4, 1.0)
	_fim()


func _sala_venda(g: Node3D) -> void:
	_casca("Venda do Seu Zé", 8.0, 6.0, 3.1, "reboco_ocre", "madeira_escura")
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
	_prop_c("cardboard_box_01", _mx(6.2), _mz(5.35), 0.3, 1.0)
	_prop("vintage_lighter", _mx(3.5), _mz(4.55), 1.0, 1.0, 1.1)
	_prop("cardboard_box_01", _mx(6.25), _mz(5.35), 0.7, 1.0, 0.34)
	_prop("lightbulb_01", _mx(4.2), _mz(2.2), 0.0, 1.0, 2.52)                                              # lâmpada apagada pendurada pelo fio
	_bb.cylinder("ferro", 0.008, 0.008, 0.55, Vector3(_mx(4.2), 2.85, _mz(2.2)), Vector3.ZERO, 4)
	_nota(_mx(4.5), 1.1, _mz(4.7), 23, "Ler a confissão do Seu Zé")
	_item("chave_casarao", Vector3(_mx(3.3), 1.1, _mz(4.6)), "Abrir a gaveta: pegar a chave do casarão")
	_oleo(_mx(6.2), 1.1, _mz(4.7))
	_prop("cigarette_pack", _mx(4.9), _mz(4.45), 0.4, 1.5, 1.05)
	_lata(_mx(3.0), _mz(4.9), 1.05, 0.0)
	_lata(_mx(5.2), _mz(4.9), 1.05, 0.5)
	_prop_c("worn_metal_rack", _mx(7.4), _mz(0.8), -PI / 2.0, 1.0)
	_prop_c("standing_chalkboard_01", _mx(6.2), _mz(1.2), 0.3, 1.0)
	_fim()


func _sala_barbearia(g: Node3D) -> void:
	_casca("Barbearia", 5.0, 5.0, 3.0, "reboco_azul", "madeira_natural")
	# cadeira de barbeiro: assento, encosto, apoio e pé de ferro
	_bb.box("couro", Vector3(0.6, 0.12, 0.6), Vector3(_mx(2.5), 0.62, _mz(2.8)))
	_bb.box("couro", Vector3(0.6, 0.8, 0.12), Vector3(_mx(2.5), 1.1, _mz(3.15)))
	_bb.box("couro", Vector3(0.5, 0.06, 0.4), Vector3(_mx(2.5), 0.32, _mz(2.35)))
	_bb.cylinder("ferro", 0.09, 0.14, 0.55, Vector3(_mx(2.5), 0.28, _mz(2.8)), Vector3.ZERO, 8)
	for k in [-1.0, 1.0]:
		_bb.box("couro", Vector3(0.08, 0.06, 0.5), Vector3(_mx(2.5 + k * 0.34), 0.9, _mz(2.8)))
	b._blocker(g, "ColCadeira", Vector3(0.9, 1.4, 1.1), Vector3(_mx(2.5), 0.7, _mz(2.8)))
	# espelho grande na parede norte, prateleira com frascos
	_bb.box("ouro_velho", Vector3(1.9, 1.3, 0.04), Vector3(_mx(2.5), 1.7, _mz(4.97)))
	_bb.quad("vidro_noite", Vector2(1.8, 1.2), Vector3(_mx(2.5), 1.7, _mz(4.94)), PI)
	_prateleira(_mx(2.5), 1.0, _mz(4.82), 2.0, 0.0, 6)
	_mesa(_mx(0.9), _mz(4.2), 0.8, 0.6, 0.8)
	_lamparina(_mx(0.9), 0.84, _mz(4.2))
	_janela("L", _mz(2.5))
	_nota(_mx(0.9), 0.92, _mz(4.0), 9, "Ler o recorte de jornal")
	_oleo(_mx(4.4), 0.95, _mz(1.5))
	_cadeira(_mx(4.3), _mz(3.8), -PI / 2.0)
	_prop("cigarette_pack", _mx(0.9), _mz(4.1), 0.8, 1.5, 0.75)
	_prop_c("worn_metal_rack", _mx(4.55), _mz(4.5), PI, 0.9)
	_fim()


func _sala_sineiro(g: Node3D) -> void:
	_casca("Casa do sineiro", 6.0, 5.0, 2.9, "reboco_branco", "madeira_escura")
	_cama(_mx(0.9), _mz(3.7), 0.0, "pano_cru")
	# caixa de madeira embaixo da cama (onde está a chave)
	_bb.box("madeira_natural", Vector3(0.5, 0.26, 0.4), Vector3(_mx(1.0), 0.13, _mz(2.45)))
	_bb.box("ferro", Vector3(0.52, 0.03, 0.42), Vector3(_mx(1.0), 0.27, _mz(2.45)))
	_mesa(_mx(4.2), _mz(3.4), 1.4, 0.8)
	_cadeira(_mx(4.2), _mz(2.7), 0.0)
	_cadeira(_mx(4.2), _mz(4.1), PI)
	_lamparina(_mx(4.1), 0.82, _mz(3.4))
	# corda do sino pendurada
	_bb.cylinder("pano_cru", 0.025, 0.025, 2.3, Vector3(_mx(5.5), 1.75, _mz(4.6)), Vector3.ZERO, 6)
	_bb.sphere("pano_cru", 0.1, Vector3(_mx(5.5), 0.55, _mz(4.6)), 6, 4)
	_oratorio(_mx(3.0), _mz(4.75))
	_janela("L", _mz(2.0))
	_nota(_mx(3.8), 0.85, _mz(3.5), 8, "Ler a carta do Seu Tobias")
	_nota(_mx(4.6), 0.85, _mz(3.3), 3, "Ler a anotação do sacristão")
	_nota(_mx(3.6), 0.85, _mz(3.1), 24, "Ler a ata da Irmandade")
	_item("chave_igreja", Vector3(_mx(1.0), 0.4, _mz(2.45)), "Abrir a caixa: pegar a chave da igreja")
	_oleo(_mx(5.6), 0.95, _mz(1.0))
	_prop("wooden_bucket_01", _mx(5.4), _mz(1.6), 0.2)
	_prop("vintage_binocular", _mx(4.55), _mz(3.75), 0.9, 1.0, 0.82)
	_prop("wooden_axe_02", _mx(5.4), _mz(3.2), 0.0, 1.0, 0.0).rotation.z = 0.25
	_fim()


func _sala_casarao(g: Node3D) -> void:
	_casca("Casarão dos Vaz", 10.0, 8.0, 3.8, "reboco_ocre", "madeira_escura")
	# mesa de jantar comprida com cadeiras (uma caída), castiçal apagado
	_tapete(_mx(5.0), _mz(3.8), 3.4, 2.3, 0)
	_examinar(_mx(7.4), 0.5, _mz(3.8), "Examinar a cadeira caída", "A cadeira tombou quando o Dr. Anselmo se levantou da ceia para nunca mais voltar. O prato dele ainda tem a sopa, seca, rachada como a terra.", "creak", 0.1)
	_examinar(_mx(5.0), 0.95, _mz(3.8), "Examinar a mesa", "Sete lugares postos. Seis cadeiras. Quem faltava à mesa dos Vaz? | O castiçal central tem sete velas. Seis derreteram até o fim; a sétima nunca foi acesa.")
	_prop_c("dining_table", _mx(5.0), _mz(3.8), 0.0, 1.0)                                                      # mesa de jantar com toalha xadrez (Poly Haven, CC0)
	for k in 3:
		_cadeira(_mx(3.9 + k * 1.1), _mz(4.78), PI)
	for k in 2:
		_cadeira(_mx(3.9 + k * 1.1), _mz(2.82), 0.0)
	_bx("madeira_natural", Vector3(_mx(7.4), 0, _mz(3.8)), 0.4, Vector3(0, 0.22, 0), Vector3(0.44, 0.44, 0.04))     # cadeira tombada
	_parte("brass_candleholders", ["brass_candleholder_01"], _mx(4.3), _mz(3.8), 0.0, 0.55, 0.89)
	_parte("brass_candleholders", ["brass_candleholder_02"], _mx(5.0), _mz(3.8), 0.0, 0.55, 0.89)
	_parte("brass_candleholders", ["brass_candleholder_03"], _mx(5.7), _mz(3.8), 0.0, 0.55, 0.89)                                          # conjunto de candelabros de latão sobre a mesa
	var lcd := b._lamp_light(_g, Vector3(_mx(5.0), 1.45, _mz(3.8)), 0.5)
	lcd.omni_range = 5.0
	_prop_c("WoodenChair_01", _mx(2.55), _mz(3.8), PI / 2.0, 0.5)                                                # cadeira gótica na cabeceira
	# retratos escuros, um espelho quebrado, lustre apagado
	for k in 4:
		_quadro(_mx(1.6 + k * 2.2), 2.2, _mz(7.95), "N", 0.7, 0.9)
	_quadro(_mx(0.04), 1.9, _mz(4.0), "O", 0.9, 1.3, "vidro_noite")
	_prop("brass_diya_lantern", _mx(5.0), _mz(3.8), 0.0, 2.2, _h - 2.2)                                 # lustre de latão pendurado do forro
	# escada que sobe e para numa parede (a ala de cima está desabada)
	for k in 8:
		_bb.box("madeira_escura", Vector3(1.2, 0.18, 0.3), Vector3(_mx(9.2), 0.09 + k * 0.18, _mz(1.0 + k * 0.3)))
	b._blocker(g, "ColEscada", Vector3(1.2, 1.5, 2.4), Vector3(_mx(9.2), 0.75, _mz(2.2)))
	# escrivaninha do capataz no canto: o livro está aqui
	_mesa(_mx(1.4), _mz(6.7), 1.6, 0.8, 0.78, "madeira_escura")
	_prop_c("chinese_armchair", _mx(1.4), _mz(5.95), 0.0, 0.72)                                                  # poltrona de espaldar alto na escrivaninha
	_prop("planter_pot_clay", _mx(9.3), _mz(0.8), 0.0, 1.4, 0.0)
	_parte("anthurium_botany_01", ["anthurium_botany_04_d"], _mx(9.3), _mz(0.8), 0.9, 0.22, 0.30)
	_vela(_mx(1.0), 0.82, _mz(6.9), true)
	_item("livro", Vector3(_mx(1.8), 0.88, _mz(6.7)), "Pegar o livro de registros dos Vaz")
	_nota(_mx(4.1), 0.9, _mz(3.55), 21, "Ler o telegrama da Companhia")
	_nota(_mx(5.95), 0.9, _mz(4.05), 22, "Ler o rascunho amassado")
	_nota(_mx(1.1), 0.83, _mz(6.75), 26, "Ler o diário de Eulália Vaz")
	_prop("seadogs_compass", _mx(2.05), _mz(6.45), 0.4, 1.0, 0.78)                                             # bússola de latão do capataz, sobre a escrivaninha
	_oleo(_mx(8.8), 0.9, _mz(6.9))
	_janela("L", _mz(5.5), 1.9, 1.0, 1.6)
	_janela("O", _mz(1.8), 1.9, 1.0, 1.6)
	_prop_c("GothicCabinet_01", _mx(6.0), _mz(7.35), PI, 1.0)
	_prop_c("vintage_day_bed", _mx(2.0), _mz(0.75), 0.0, 1.0)
	_prop_c("gothic_coffee_table", _mx(2.0), _mz(2.6), 0.5, 1.0)
	_papelaria(_mx(1.55), _mz(6.5), 0.82, 0.4)
	_fim()
	# poeira: nada de lamparina acesa aqui, só a vela do escritório e o luar


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
	_casca("Carpintaria do Seu Mateus", 8.0, 6.0, 3.2, "reboco_branco", "madeira_natural")
	# bancada comprida com plaina, serrote e tábuas; ferramentas na prateleira de metal
	_mesa(_mx(4.0), _mz(4.6), 3.2, 0.9, 0.9, "madeira_natural")
	_prop("hand_plane_no4", _mx(3.3), _mz(4.5), 0.4, 1.0, 0.94)
	_prop("handsaw_wood", _mx(4.6), _mz(4.7), 1.2, 1.0, 0.94)
	_prop_c("worn_metal_rack", _mx(0.5), _mz(4.2), PI / 2.0, 1.0)
	_prop("wooden_axe_02", _mx(1.3), _mz(4.2), 0.0, 1.0, 0.0).rotation.z = 0.25
	_prop_c("wooden_ladder", _mx(7.45), _mz(3.0), -PI / 2.0, 1.5).rotation.x = -0.18
	for k in 5:
		_bb.box("madeira_natural", Vector3(2.2, 0.06, 0.28), Vector3(_mx(6.4), 0.05 + k * 0.07, _mz(5.4)))      # pilha de tábuas
	_bb.box("madeira_natural", Vector3(0.8, 0.5, 0.8), Vector3(_mx(1.2), 0.25, _mz(1.2)))                         # cepos
	b._blocker(g, "ColCepo", Vector3(0.8, 0.5, 0.8), Vector3(_mx(1.2), 0.25, _mz(1.2)))
	_lamparina(_mx(4.0), 0.95, _mz(4.4))
	_janela("L", _mz(2.0))
	_nota(_mx(2.6), 0.95, _mz(4.6), 12, "Ler o bilhete do Seu Mateus")
	_nota(_mx(4.0), 0.93, _mz(4.2), 27, "Ler a encomenda da Companhia")
	_prop("rusted_spade_01", _mx(0.45), _mz(5.6), 0.0, 1.0, 0.0).rotation.z = 0.10
	_prop("trowel_01", _mx(4.95), _mz(4.5), 0.7, 1.0, 0.94)
	_oleo(_mx(6.9), 0.95, _mz(0.9))
	_prop("watering_can_metal_01", _mx(7.2), _mz(5.2), 0.3, 1.0)
	_fim()


func _sala_escola(g: Node3D) -> void:
	_casca("Escola Rural", 7.0, 6.0, 3.2, "reboco_creme", "madeira_natural")
	_prop_c("standing_chalkboard_01", _mx(3.5), _mz(5.3), PI, 1.5)
	_quadro(_mx(6.96), 1.8, _mz(3.0), "L", 1.4, 0.9, "placa_verde")
	for fila in 2:
		for col in 3:
			var x := 1.4 + col * 1.7
			var z := 1.9 + fila * 1.3
			_mesa(_mx(x), _mz(z), 1.0, 0.5, 0.7, "madeira_natural")
			_cadeira(_mx(x), _mz(z - 0.55), PI, "madeira_escura")
	_mesa(_mx(5.6), _mz(4.8), 1.4, 0.7, 0.8, "madeira_escura")                # mesa da professora
	_papelaria(_mx(5.6), _mz(4.8), 0.84, 0.4)
	_lamparina(_mx(5.2), 0.84, _mz(4.9))
	_janela("O", _mz(3.0))
	_nota(_mx(6.0), 0.9, _mz(4.8), 13, "Ler o caderno de caligrafia")
	_prop_c("wooden_bookshelf_worn", _mx(6.62), _mz(1.0), -PI / 2.0, 1.0)
	_oleo(_mx(0.6), 0.95, _mz(5.3))
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
	_prop_c("worn_metal_rack", _mx(0.4), _mz(2.0), PI / 2.0, 1.0)
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
	_prop_c("old_bed_frame", _mx(1.1), _mz(3.8), 0.0, 1.0)
	_cadeira(_mx(3.6), _mz(2.4), 1.0)                                                    # cadeira virada
	_bx("madeira_natural", Vector3(_mx(4.6), 0, _mz(3.4)), 0.9, Vector3(0, 0.2, 0), Vector3(0.44, 0.44, 0.04))
	_mesa(_mx(4.4), _mz(3.8), 1.2, 0.8)
	_prop_c("GothicCabinet_01", _mx(3.0), _mz(4.35), PI, 0.9)
	_prop("cigarette_pack", _mx(4.4), _mz(3.8), 0.2, 1.5, 0.82)
	_vela(_mx(4.9), 0.82, _mz(4.0), true)
	_janela("L", _mz(2.5))
	_nota(_mx(4.2), 0.85, _mz(3.6), 15, "Ler o diário abandonado")
	_prop_c("wooden_bookshelf_worn", _mx(3.6), _mz(0.34), 0.0, 1.0)
	_prop("WoodenTable_02", _mx(2.1), _mz(2.3), 0.4, 1.0)
	_oleo(_mx(5.5), 0.95, _mz(1.0))
	_fim()


func _sala_pensao(g: Node3D) -> void:
	_casca("Pensão da Dona Elvira", 7.0, 6.0, 3.0, "reboco_salmao", "madeira_natural")
	_prop_c("old_bed_frame", _mx(1.0), _mz(4.6), 0.0, 1.0)
	_prop_c("old_bed_frame", _mx(6.0), _mz(4.6), 0.0, 1.0)
	_prop_c("vintage_day_bed", _mx(3.5), _mz(0.9), 0.0, 1.0)
	_tapete(_mx(3.5), _mz(2.6), 2.4, 1.6, 1)
	_prop_c("gothic_coffee_table", _mx(3.5), _mz(2.6), 0.0, 1.0)
	_prop("vintage_binocular", _mx(3.2), _mz(2.6), 0.4, 1.0, 0.56)
	_prop("cigarette_pack", _mx(3.9), _mz(2.4), 1.0, 1.5, 0.56)
	_mesa(_mx(3.5), _mz(5.3), 1.2, 0.7, 0.8, "madeira_escura")
	_papelaria(_mx(3.2), _mz(5.3), 0.84, 0.4)
	_lamparina(_mx(3.9), 0.84, _mz(5.3))
	_janela("L", _mz(4.0))
	_janela("O", _mz(4.0))
	_nota(_mx(3.6), 0.88, _mz(5.0), 16, "Ler o livro de hóspedes")
	_prop_c("painted_wooden_nightstand", _mx(2.0), _mz(5.55), PI, 1.0)
	_prop("vintage_lighter", _mx(3.55), _mz(5.5), 0.5, 1.0, 0.8)
	_prop_c("painted_wooden_nightstand", _mx(5.0), _mz(5.55), PI, 1.0)
	_parte("vintage_suitcase", ["vintage_suitcase_01_"], _mx(5.6), _mz(2.1), 0.5, 0.75, 0.0)
	_parte("vintage_suitcase", ["vintage_suitcase_02_"], _mx(6.25), _mz(2.55), -0.4, 0.75, 0.0)                                              # as malas do Dr. Anselmo, esquecidas no quarto
	_oleo(_mx(6.5), 0.95, _mz(1.0))
	_fim()


func _sala_costureira(g: Node3D) -> void:
	_casca("Casa da costureira", 6.0, 5.0, 2.9, "reboco_azul", "madeira_natural")
	_mesa(_mx(3.0), _mz(3.6), 1.8, 0.9, 0.8, "madeira_natural")                           # mesa de corte
	_bb.box("pano_rosa", Vector3(1.4, 0.03, 0.8), Vector3(_mx(3.0), 0.83, _mz(3.6)))
	_papelaria(_mx(3.8), _mz(3.4), 0.84, 0.6)
	for k in 4:
		_bb.cylinder(["pano_azul", "pano_rosa", "pano_cru", "listra_vermelha"][k], 0.1, 0.1, 0.8, Vector3(_mx(0.5), 0.1 + k * 0.2, _mz(1.4 + k * 0.01)), Vector3(PI / 2.0, 0, 0), 8)
	_prop_c("GothicCabinet_01", _mx(1.25), _mz(4.35), PI, 0.9)
	_lamparina(_mx(3.0), 0.83, _mz(3.1))
	_janela("L", _mz(2.0))
	_nota(_mx(2.5), 0.88, _mz(3.5), 17, "Ler a encomenda do vestido")
	_oleo(_mx(5.5), 0.95, _mz(1.0))
	_fim()


func _sala_deposito(g: Node3D) -> void:
	_casca("Depósito", 7.0, 5.0, 3.2, "reboco_branco", "cantaria")
	_examinar(_mx(0.8), 1.2, _mz(2.4), "Examinar as prateleiras", "Latas sem rótulo. Na única que tem, lê-se 'Companhia Minas do Ouro Preto, ração de campanha, 1958'. A data da carta é a mesma.")
	_examinar(_mx(6.0), 1.0, _mz(1.5), "Examinar os barris", "O vinho nos barris virou vinagre há anos. Alguém escreveu a giz na madeira: 'Eles contaram os mortos errado.'", "clink", 0.08)
	_prop_c("worn_metal_rack", _mx(0.4), _mz(1.6), PI / 2.0, 1.0)
	_prop_c("worn_metal_rack", _mx(0.4), _mz(3.2), PI / 2.0, 1.0)
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
	_cont("Crate2", _mx(1.5), _mz(4.4), PI / 2.0)
	_prop_c("wooden_ladder", _mx(3.5), _mz(4.55), PI, 1.5).rotation.x = 0.18
	_prop("watering_can_metal_01", _mx(2.5), _mz(3.8), 0.3, 1.0)
	_lamparina(_mx(3.5), 0.01, _mz(1.2), 0.7)
	_janela("L", _mz(2.0))
	_oleo(_mx(2.0), 0.95, _mz(4.5))
	_oleo(_mx(6.0), 1.25, _mz(1.5))
	_fim()
