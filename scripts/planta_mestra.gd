class_name PlantaMestra
extends RefCounted
## PLANTA MESTRA (docs/31): o mapa decidido ANTES dos objetos. Cada objeto da rua tem
##  - uma FAIXA onde pode ficar (medida da parede para o meio da rua),
##  - um ENVELOPE (o espaço máximo que ocupa: largura x profundidade x altura, já com folga),
##  - e não pode entrar em ZONA PROIBIDA (frente de porta, boca de beco, volta de item, corredor do jogador),
##    nem no envelope de outro objeto.
## `fiscalizar` confere a vila montada; com `corrigir = true` desliza o objeto ao longo da parede até a vaga
## mais próxima que obedece à planta (ou tira, se não houver vaga a menos de 5 m).
## Coordenadas da rua: s = metros ao longo da rua, d = distância lateral ao eixo (+ à direita de quem sobe).

const CORREDOR := 1.45          # meio da rua livre para andar e fugir (1,45 m para cada lado do eixo)
const ALTO := 2.3               # acima disto (lampião de parede, sacada) não atrapalha quem passa

## Faixas: profundidade máxima a partir da parede (m) e quanto pode entrar na parede.
const FAIXAS := {
	"parede": {"prof": 1.25, "embute": 0.15, "cor": "#c8a060"},    # junto à parede: recipientes, vasos, bancos, oratórios
	"calcada": {"prof": 2.2, "embute": 0.15, "cor": "#a0a0a0"},    # até a beira da calçada: postes, carroça, carro coberto
	"livre": {"prof": 99.0, "embute": 99.0, "cor": "#808080"},     # não é da rua (adro, encosta): só confere zonas e encostos
}

## Catálogo: prefixo do nome -> tipo, faixa, envelope [largura, profundidade, altura] (m) e se é móvel.
const CATALOGO := [
	["wine_barrel", "barril", "parede", [1.15, 1.15, 0.95], true],
	["Barrel", "barril", "parede", [0.80, 0.80, 0.95], true],
	["Crate1", "caixote_comprido", "parede", [1.15, 0.80, 0.85], true],
	["Crate2", "caixote_comprido", "parede", [1.15, 0.80, 0.85], true],
	["Crate", "caixote", "parede", [0.90, 0.90, 1.60], true],
	["Basket", "cesto", "parede", [0.65, 0.65, 0.60], true],
	["Bucket", "balde", "parede", [0.50, 0.50, 0.35], true],
	["Jug", "jarro", "parede", [0.45, 0.45, 0.45], true],
	["Sack", "saco", "parede", [0.45, 0.45, 0.45], true],
	["watering_can", "regador", "parede", [0.50, 0.40, 0.25], true],
	["wooden_bucket", "balde", "parede", [0.45, 0.45, 0.60], true],
	["wooden_stool", "banquinho", "parede", [0.60, 0.60, 0.50], true],
	["rusted_wheel_rim", "aro", "parede", [0.45, 0.40, 0.40], true],
	["Lantern", "lanterna", "parede", [0.20, 0.20, 0.30], true],
	["BolaEsquecida", "bola", "parede", [0.55, 0.30, 0.25], true],
	["Televisao", "tv_do_bar", "parede", [0.70, 0.60, 0.50], false],
	["Lousa", "lousa", "parede", [1.15, 1.00, 1.55], false],
	["ColBanco", "banco", "parede", [1.80, 0.55, 0.95], false],
	["ColCarroca", "carroca", "calcada", [1.75, 1.15, 1.00], false],
	["covered_car", "carro_coberto", "calcada", [1.85, 4.45, 1.45], false],
	["Pedestal", "pedestal", "livre", [1.55, 1.60, 2.90], false],
	["Nicho", "oratorio", "parede", [1.60, 0.95, 3.90], false],
	["Poste", "poste", "calcada", [0.75, 0.45, 3.90], false],
	["LampiaoParede", "lampiao_parede", "parede", [0.55, 0.60, 1.10], false],
	["Oleo", "item_oleo", "livre", [0.20, 0.20, 0.40], false],
	["Bilhete", "item_bilhete", "livre", [0.50, 0.50, 0.05], false],
	["Reliquia", "item_medalha", "livre", [0.25, 0.25, 0.25], false],
]
## Objetos feitos para entrar um pouco na parede (oratório embutido 12 cm, suporte de lampião chumbado).
const EMBUTE := {"oratorio": 0.30, "lampiao_parede": 0.30}
const GRUPOS := ["Adornos", "Props", "Nichos", "Coletaveis", "Iluminacao"]
const IGNORA := ["Pecas", "Varais", "FiosDeLuz", "EsconderijoCarro", "Rato", "LuzesDistantes"]

## Zonas proibidas (no quadro local de quem as cria; x = para fora da parede é NEGATIVO, como nos lotes).
const PORTA_LARG := 1.9         # vão de 1,6 m + folga
const PORTA_PROF := 1.4         # ninguém põe nada a menos de 1,4 m na frente de uma porta
const BOCA_PROF := 1.8          # boca de beco livre até 1,8 m para fora da parede
const ITEM_RAIO := 0.75         # volta de cada item (frasco, bilhete, medalha) livre, menos o apoio dele

var zonas: Array = []           # {tipo, xf: Transform3D, ret: Rect2 (x, z locais), nome}
var objetos: Array = []         # {no, tipo, faixa, movel, bb: AABB, s, d, parede}
var violacoes: Array = []       # {obj, regra, detalhe}
var correcoes: Array = []       # textos
var fora_do_catalogo: Array = []   # objetos de rua sem tipo na planta (todo objeto precisa de envelope)


## Encolhe a caixa sem deixar nenhum lado negativo (bilhete tem 2 cm de altura).
static func encolher(bb: AABB, m: float) -> AABB:
	var t := Vector3(minf(m, bb.size.x * 0.45), minf(m, bb.size.y * 0.45), minf(m, bb.size.z * 0.45))
	return AABB(bb.position + t, bb.size - t * 2.0)


static func tipo_de(nome: String) -> Array:
	for c in CATALOGO:
		if nome.begins_with(String(c[0])):
			return c
	return []


## Caixa do objeto no quadro dele mesmo (não infla quando ele está girado): [AABB local, Transform3D do nó].
static func caixa_local(n: Node3D) -> AABB:
	var inv := n.global_transform.affine_inverse()
	var out := AABB()
	var ok := false
	if n is StaticBody3D:
		for cs in n.find_children("*", "CollisionShape3D", true, false):
			var sh := (cs as CollisionShape3D).shape
			if sh is BoxShape3D:
				var b := ((inv * (cs as Node3D).global_transform) * AABB(-(sh as BoxShape3D).size * 0.5, (sh as BoxShape3D).size)).abs()
				out = b if not ok else out.merge(b)
				ok = true
		return out
	for vi in n.find_children("*", "VisualInstance3D", true, false):
		if vi is Light3D or vi is Decal or vi is GPUParticles3D or vi is Label3D or String(vi.name).begins_with("Halo"):
			continue
		var g := vi as VisualInstance3D
		var bb := ((inv * g.global_transform) * g.get_aabb()).abs()
		if bb.size.length() > 30.0:
			continue
		out = bb if not ok else out.merge(bb)
		ok = true
	if n is VisualInstance3D and not ok:
		out = (n as VisualInstance3D).get_aabb().abs()
	return out


static func caixa(n: Node) -> AABB:
	var out := AABB()
	var ok := false
	if n is StaticBody3D:
		for cs in n.find_children("*", "CollisionShape3D", true, false):
			var sh := (cs as CollisionShape3D).shape
			if sh is BoxShape3D:
				var b := ((cs as Node3D).global_transform * AABB(-(sh as BoxShape3D).size * 0.5, (sh as BoxShape3D).size)).abs()
				out = b if not ok else out.merge(b)
				ok = true
		return out
	for vi in n.find_children("*", "VisualInstance3D", true, false):
		if vi is Light3D or vi is Decal or vi is GPUParticles3D or vi is Label3D or String(vi.name).begins_with("Halo"):
			continue
		var g := vi as VisualInstance3D
		var bb := (g.global_transform * g.get_aabb()).abs()
		if bb.size.length() > 30.0:
			continue
		out = bb if not ok else out.merge(bb)
		ok = true
	if n is VisualInstance3D and not ok:
		out = ((n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()).abs()
	return out


## Distância do eixo até a parede das casas (linha de fachada) na posição s.
static func parede(s: float) -> float:
	return Route.width(s) * 0.5 + Route.SIDEWALK


## (s, d) de um ponto do mundo.
static func sd(p: Vector3) -> Vector2:
	var s := Route.nearest_s(p)
	var o := Route.pos(s)
	return Vector2(s, Route.right(s).dot(Vector3(p.x - o.x, 0.0, p.z - o.z)))


# ------------------------------------------------------------------ montagem das zonas e do cadastro

func montar(vila: Node) -> void:
	zonas.clear()
	objetos.clear()
	fora_do_catalogo.clear()
	var casas := vila.get_node_or_null("Casas")
	if casas:
		for c in casas.get_children():
			if not (c is Node3D) or not c.has_meta("door_z"):
				continue
			var dz := float(c.get_meta("door_z"))
			zonas.append({"tipo": "porta", "nome": String(c.name), "xf": (c as Node3D).global_transform, "visitavel": c.has_meta("sala_id"),
				"ret": Rect2(-PORTA_PROF, dz - PORTA_LARG * 0.5, PORTA_PROF + 0.05, PORTA_LARG)})
	var becos := vila.get_node_or_null("Becos")
	if becos:
		for b in becos.get_children():
			if not (b is Node3D):
				continue
			var w := float(b.get_meta("largura", 0.0))
			if w <= 0.0:
				continue
			var xf := (b as Node3D).global_transform
			zonas.append({"tipo": "boca_de_beco", "nome": String(b.name), "xf": xf, "ret": Rect2(-BOCA_PROF, -w * 0.5 - 0.2, BOCA_PROF + 0.6, w + 0.4)})
			if b.has_meta("comprimento"):            # beco-escada de ligação: boca de cima também
				var L := float(b.get_meta("comprimento"))
				zonas.append({"tipo": "boca_de_beco", "nome": String(b.name) + "_cima", "xf": xf, "ret": Rect2(L - 0.6, -w * 0.5 - 0.2, BOCA_PROF + 0.6, w + 0.4)})
	for gn in GRUPOS:
		var g := vila.get_node_or_null(gn)
		if g == null:
			continue
		for n in g.get_children():
			if not (n is Node3D):
				continue
			var nome := String(n.name)
			var ign := false
			for pf in IGNORA:
				if nome.begins_with(pf):
					ign = true
			if ign:
				continue
			var c := tipo_de(nome)
			if c.is_empty():
				fora_do_catalogo.append("%s/%s" % [gn, nome])
				continue
			var bb := caixa(n)
			if bb.size == Vector3.ZERO:
				continue
			objetos.append(_registro(n as Node3D, c, bb))
	for o in objetos:                                   # cada item cria a sua volta livre
		if String(o["tipo"]).begins_with("item_"):
			var c3: Vector3 = (o["bb"] as AABB).get_center()
			zonas.append({"tipo": "volta_de_item", "nome": String((o["no"] as Node).name), "xf": Transform3D(Basis.IDENTITY, c3),
				"ret": Rect2(-ITEM_RAIO, -ITEM_RAIO, ITEM_RAIO * 2.0, ITEM_RAIO * 2.0), "y": (o["bb"] as AABB).position.y})


func _registro(n: Node3D, c: Array, bb: AABB) -> Dictionary:
	var o := {"no": n, "nome": String(n.name), "tipo": c[1], "faixa": c[2], "env": c[3], "movel": c[4]}
	_medir(o)
	return o


## Mede de novo o objeto (depois de mover): caixa do mundo, caixa local e os 4 cantos da pegada.
func _medir(o: Dictionary) -> void:
	var n := o["no"] as Node3D
	o["bb"] = caixa(n)
	var lb := caixa_local(n)
	o["lb"] = lb
	var cantos: Array = []
	for k in 4:
		cantos.append(n.global_transform * Vector3(lb.position.x + lb.size.x * float(k & 1), lb.position.y, lb.position.z + lb.size.z * float((k >> 1) & 1)))
	o["cantos"] = cantos
	var m := sd((o["bb"] as AABB).get_center())
	o["s"] = m.x
	o["d"] = m.y
	o["parede"] = parede(m.x)


# ------------------------------------------------------------------ regras

## Lista de regras quebradas por um objeto (vazia = obedece à planta).
func regras(o: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var bb: AABB = o["bb"]
	var tipo: String = o["tipo"]
	var item := tipo.begins_with("item_")
	var alto := bb.position.y - Route.pos(float(o["s"])).y > ALTO
	# 1) envelope do catálogo: o objeto real não pode ser maior que o espaço reservado para o tipo
	var env: Array = o["env"]
	var lb: AABB = o["lb"]
	var maior := maxf(lb.size.x, lb.size.z)
	var menor := minf(lb.size.x, lb.size.z)
	if maior > maxf(float(env[0]), float(env[1])) + 0.08 or menor > minf(float(env[0]), float(env[1])) + 0.08 or lb.size.y > float(env[2]) + 0.1:
		out.append("maior que o envelope %.2fx%.2fx%.2f (tem %.2fx%.2fx%.2f)" % [env[0], env[1], env[2], maior, menor, lb.size.y])
	# 2) faixa: quanto sai da parede para a rua e quanto entra na parede
	var f: Dictionary = FAIXAS[o["faixa"]]
	if String(o["faixa"]) != "livre" and float(o["s"]) < Route.S_END and absf(float(o["d"])) < float(o["parede"]) + 3.0:
		var dmin := INF
		var dmax := 0.0
		for q in o["cantos"]:
			var m := sd(q)
			dmin = minf(dmin, absf(m.y))
			dmax = maxf(dmax, absf(m.y))
		var par := float(o["parede"])
		if par - dmin > float(f["prof"]) + 0.05:
			out.append("sai %.2f m da parede (faixa '%s' permite %.2f)" % [par - dmin, o["faixa"], f["prof"]])
		if dmax - par > float(EMBUTE.get(tipo, f["embute"])) + 0.05 and not alto:
			out.append("entra %.2f m na parede" % (dmax - par))
		# 3) corredor do jogador
		if dmin < CORREDOR and not item:
			out.append("invade o corredor do meio da rua (|d| %.2f < %.2f)" % [dmin, CORREDOR])
	# 4) zonas proibidas
	if not alto:
		for z in zonas:
			if z["tipo"] == "volta_de_item":
				if item or _apoio(o, z):
					continue
			if z["tipo"] == "porta" and item and not bool(z.get("visitavel", false)):
				continue                                 # frasco/bilhete na soleira de casa fechada: não atrapalha (em porta de sala, sim: o E pegaria o item em vez de entrar)
			if _na_zona(bb, z):
				out.append("dentro da zona '%s' de %s" % [z["tipo"], z["nome"]])
	# 5) encosto com outro objeto
	for o2 in objetos:
		if o2 == o or o2.get("tirado", false):
			continue
		var b2: AABB = o2["bb"]
		if absf(b2.get_center().x - bb.get_center().x) > 6.0 or absf(b2.get_center().z - bb.get_center().z) > 6.0:
			continue
		var a1 := encolher(bb, 0.04)
		var a2 := encolher(b2, 0.04)
		if a1.intersects(a2):
			if (item and b2.end.y <= bb.position.y + 0.08) or (String(o2["tipo"]).begins_with("item_") and bb.end.y <= b2.position.y + 0.08):
				continue                                 # item em cima do apoio
			var it := a1.intersection(a2)
			if it.size.x * it.size.z > 0.004 and it.size.y > 0.02:
				out.append("atravessa %s (%.0fx%.0f cm)" % [o2["nome"], it.size.x * 100.0, it.size.z * 100.0])
	return out


## O objeto é o apoio do item da zona (o item está em cima dele)?
func _apoio(o: Dictionary, z: Dictionary) -> bool:
	var bb: AABB = o["bb"]
	var c: Vector3 = (z["xf"] as Transform3D).origin
	return c.x > bb.position.x - 0.1 and c.x < bb.end.x + 0.1 and c.z > bb.position.z - 0.1 and c.z < bb.end.z + 0.1 and float(z.get("y", 0.0)) >= bb.end.y - 0.15


func _na_zona(bb: AABB, z: Dictionary) -> bool:
	var inv := (z["xf"] as Transform3D).affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var enc := encolher(bb, 0.05)
	for k in 4:
		var q := inv * Vector3(enc.position.x + enc.size.x * float(k & 1), 0.0, enc.position.z + enc.size.z * float((k >> 1) & 1))
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.z))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.z))
	var r: Rect2 = z["ret"]
	return Rect2(lo, hi - lo).intersects(r)


# ------------------------------------------------------------------ fiscal

func fiscalizar(vila: Node, corrigir := false) -> Dictionary:
	montar(vila)
	violacoes.clear()
	correcoes.clear()
	var movidos := 0
	var tirados := 0
	for o in objetos:
		var r := regras(o)
		if r.is_empty():
			continue
		if corrigir and bool(o["movel"]) and _deslizar(o):
			movidos += 1
			continue
		if corrigir and bool(o["movel"]):
			correcoes.append("TIRADO %s (s=%.0f): %s" % [o["nome"], o["s"], r[0]])
			for pil in _pilha(o):
				pil["tirado"] = true
				(pil["no"] as Node).get_parent().remove_child(pil["no"])
				(pil["no"] as Node).free()
			o["tirado"] = true
			var no := o["no"] as Node
			no.get_parent().remove_child(no)
			no.free()
			tirados += 1
			continue
		violacoes.append({"obj": o["nome"], "tipo": o["tipo"], "s": snappedf(float(o["s"]), 0.1), "regras": r})
	for nome in fora_do_catalogo:
		violacoes.append({"obj": nome, "tipo": "?", "s": 0.0, "regras": ["fora do catálogo da planta (sem envelope definido)"]})
	return {"objetos": objetos.size(), "zonas": zonas.size(), "violacoes": violacoes.size(), "movidos": movidos, "tirados": tirados}


## Objetos empilhados em cima deste (caixote sobre caixote): vão junto.
func _pilha(o: Dictionary) -> Array:
	var out: Array = []
	var bb: AABB = o["bb"]
	for o2 in objetos:
		if o2 == o or o2.get("tirado", false):
			continue
		var b2: AABB = o2["bb"]
		var c := b2.get_center()
		if c.x > bb.position.x and c.x < bb.end.x and c.z > bb.position.z and c.z < bb.end.z and b2.position.y >= bb.end.y - 0.1 and b2.position.y < bb.end.y + 0.3:
			out.append(o2)
	return out


## Procura, ao longo da parede (mesma distância do eixo), a vaga mais próxima onde o objeto obedece a todas as regras.
func _deslizar(o: Dictionary) -> bool:
	var no := o["no"] as Node3D
	var s0 := float(o["s"])
	var d0 := float(o["d"])
	var pilha := _pilha(o)
	var orig := no.global_transform
	var orig_p: Array = []
	for p in pilha:
		orig_p.append((p["no"] as Node3D).global_transform)
	var base0 := Route.pos(s0)
	var motivo := regras(o)[0] if not regras(o).is_empty() else ""
	for k in range(1, 21):
		var ds := 0.25 * float((k + 1) / 2) * (1.0 if k % 2 == 1 else -1.0)
		var s1 := s0 + ds
		if s1 < 2.0 or s1 > Route.S_END:
			continue
		if absf(Route.width(s1) - Route.width(s0)) > 0.3:
			continue
		var giro := Basis(Vector3.UP, atan2(-Route.tangent(s1).x, -Route.tangent(s1).z) - atan2(-Route.tangent(s0).x, -Route.tangent(s0).z))
		var alvo := Route.pos(s1) + Route.right(s1) * d0
		var delta_xf := func(x: Transform3D) -> Transform3D:
			var rel := x.origin - (base0 + Route.right(s0) * d0)
			var y := x.origin.y - base0.y + Route.pos(s1).y
			var p := alvo + giro * Vector3(rel.x, 0.0, rel.z)
			return Transform3D(giro * x.basis, Vector3(p.x, y, p.z))
		no.global_transform = delta_xf.call(orig)
		for i in pilha.size():
			(pilha[i]["no"] as Node3D).global_transform = delta_xf.call(orig_p[i])
		_medir(o)
		var m := Vector2(float(o["s"]), float(o["d"]))
		if regras(o).is_empty():
			var ok := true
			for p in pilha:
				_medir(p)
				if not regras(p).is_empty():
					ok = false
			if ok:
				correcoes.append("MOVIDO %s (%s): %.2f m ao longo da parede, de s=%.1f (%s)" % [o["nome"], o["tipo"], ds, s0, motivo])
				return true
	no.global_transform = orig
	for i in pilha.size():
		(pilha[i]["no"] as Node3D).global_transform = orig_p[i]
		_medir(pilha[i])
	_medir(o)
	return false


## Dados para desenhar a planta (docs/planta/planta_mestra.json).
func exportar() -> Dictionary:
	var zs: Array = []
	for z in zonas:
		var r: Rect2 = z["ret"]
		var xf: Transform3D = z["xf"]
		var cantos: Array = []
		for q in [Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y)]:
			var p: Vector3 = xf * q
			cantos.append([snappedf(p.x, 0.01), snappedf(p.z, 0.01)])
		zs.append({"tipo": z["tipo"], "nome": z["nome"], "cantos": cantos})
	var os: Array = []
	for o in objetos:
		if o.get("tirado", false) or not is_instance_valid(o["no"]):
			continue
		var bb: AABB = o["bb"]
		os.append({"nome": o["nome"], "tipo": o["tipo"], "faixa": o["faixa"], "s": snappedf(float(o["s"]), 0.1), "d": snappedf(float(o["d"]), 0.01),
			"caixa_xz": [snappedf(bb.position.x, 0.01), snappedf(bb.position.z, 0.01), snappedf(bb.end.x, 0.01), snappedf(bb.end.z, 0.01)],
			"altura": snappedf(bb.size.y, 0.01), "ok": regras(o).is_empty()})
	var cat: Array = []
	for c in CATALOGO:
		cat.append({"prefixo": c[0], "tipo": c[1], "faixa": c[2], "envelope": c[3], "movel": c[4]})
	return {"faixas": FAIXAS, "corredor": CORREDOR, "catalogo": cat, "zonas": zs, "objetos": os, "violacoes": violacoes, "correcoes": correcoes}
