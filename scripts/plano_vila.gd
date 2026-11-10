class_name PlanoVila
extends RefCounted
## PLANO DA VILA (mapa do zero, docs/27). Calcula no papel a rua em zigue-zague, os lotes, as casas, os becos e os largos,
## num CADASTRO de retângulos alinhados aos eixos. Nada entra se tocar no que já está cadastrado: colisão impossível por construção.
## Eixos: x = leste, z = sul (a subida vai para z negativo). Medidas em metros.

const LARG_RUA := 5.0          # largura do leito da rua
const CALCADA := 0.7           # calçada de cada lado
const R_GRAMPO := 17.0         # raio da curva de 180° (as pernas ficam 34 m uma da outra)
const R_CANTO := 9.0           # raio das curvas de 90°
const FUNDO_MAX := 11.0        # profundidade máxima de casa comum
const FUNDO_MIN := 5.0
const BECO_L := 3.4            # largura útil dos becos-escada
const BECO_PAREDE := 0.45
const X_PONTE := 37.5           # ponte sobre o córrego, no meio da 1ª perna
const FINAL_L := 60.0           # reta final: fim do casario e o adro da igreja

## Pernas: [x0, x1, z] (andam ao longo de x). A entrada e o fim andam ao longo de z.
const X_OESTE := 6.0
const X_LESTE := 66.0
const Z_PERNA: Array[float] = [-16.0, -50.0, -84.0, -118.0]

var pecas: Array = []          # trechos da rua: {tipo:"reta"/"arco", ...}
var cadastro: Array = []       # {id, tipo, r: Rect2 (x,z), ...}
var avisos: Array[String] = []
var rng := RandomNumberGenerator.new()


func _init() -> void:
	pecas = tracado()


## Entrada (sul -> norte), 4 pernas em zigue-zague e subida final até o adro.
func tracado() -> Array:
	var p: Array = []
	var x_entrada := 0.0
	p.append({"tipo": "reta", "a": Vector2(x_entrada, 14.0), "b": Vector2(x_entrada, Z_PERNA[0] + R_CANTO)})
	p.append({"tipo": "arco", "c": Vector2(x_entrada + R_CANTO, Z_PERNA[0] + R_CANTO), "r": R_CANTO, "a0": PI, "a1": PI * 1.5})
	var x_ini := x_entrada + R_CANTO
	for i in Z_PERNA.size():
		var leste := i % 2 == 0
		var xa := x_ini if i == 0 else (X_OESTE if leste else X_LESTE)
		var xb := X_LESTE if leste else X_OESTE
		if i == Z_PERNA.size() - 1:
			xb = 20.0                                                   # última perna para no meio: dali sobe ao adro
		p.append({"tipo": "reta", "a": Vector2(xa, Z_PERNA[i]), "b": Vector2(xb, Z_PERNA[i])})
		if i < Z_PERNA.size() - 1:
			var cz := Z_PERNA[i] - R_GRAMPO
			if leste:
				p.append({"tipo": "arco", "c": Vector2(X_LESTE, cz), "r": R_GRAMPO, "a0": PI * 0.5, "a1": -PI * 0.5})
			else:
				p.append({"tipo": "arco", "c": Vector2(X_OESTE, cz), "r": R_GRAMPO, "a0": PI * 0.5, "a1": PI * 1.5})
	var zf := Z_PERNA[Z_PERNA.size() - 1]
	p.append({"tipo": "arco", "c": Vector2(20.0, zf - R_CANTO), "r": R_CANTO, "a0": PI * 0.5, "a1": PI})
	p.append({"tipo": "reta", "a": Vector2(20.0 - R_CANTO, zf - R_CANTO), "b": Vector2(20.0 - R_CANTO, zf - R_CANTO - FINAL_L)})
	return p


## Inclinação (subida por metro) de cada peça, na ordem do traçado: entrada, curva de 90°, pernas, grampos, curva final, adro.
func rampa(i: int) -> float:
	var pc: Dictionary = pecas[i]
	if i == 0:
		return 0.08
	if i == pecas.size() - 1:
		return 0.03
	if pc["tipo"] == "arco":
		return 0.06 if float(pc["r"]) < R_GRAMPO - 0.1 else 0.10
	return 0.045


## Eixo da rua com altura: Vector3(x, y, z) a cada `passo` m. A altura sobe conforme a rampa de cada peça.
func eixo3(passo := 0.5) -> PackedVector3Array:
	var out := PackedVector3Array()
	var h := 0.0
	var prev := Vector2.INF
	for i in pecas.size():
		var pc: Dictionary = pecas[i]
		var g := rampa(i)
		var pts := PackedVector2Array()
		if pc["tipo"] == "reta":
			var a: Vector2 = pc["a"]
			var b: Vector2 = pc["b"]
			var n := maxi(1, int(round(a.distance_to(b) / passo)))
			for k in n:
				pts.append(a.lerp(b, float(k) / n))
		else:
			var c: Vector2 = pc["c"]
			var r: float = pc["r"]
			var a0: float = pc["a0"]
			var a1: float = pc["a1"]
			var n2 := maxi(2, int(round(absf(a1 - a0) * r / passo)))
			for k in n2:
				var t := lerpf(a0, a1, float(k) / n2)
				pts.append(c + Vector2(cos(t), sin(t)) * r)
		for pt in pts:
			if prev != Vector2.INF:
				h += prev.distance_to(pt) * g
			out.append(Vector3(pt.x, h, pt.y))
			prev = pt
	var ult: Dictionary = pecas[pecas.size() - 1]
	var fim: Vector2 = ult["b"]
	h += prev.distance_to(fim) * rampa(pecas.size() - 1)
	out.append(Vector3(fim.x, h, fim.y))
	return out


## Pontos densos do eixo da rua (a cada `passo` m), na ordem de quem sobe.
func eixo(passo := 0.5) -> PackedVector2Array:
	var out := PackedVector2Array()
	for pc in pecas:
		if pc["tipo"] == "reta":
			var a: Vector2 = pc["a"]
			var b: Vector2 = pc["b"]
			var n := maxi(1, int(a.distance_to(b) / passo))
			for k in n:
				out.append(a.lerp(b, float(k) / n))
		else:
			var c: Vector2 = pc["c"]
			var r: float = pc["r"]
			var a0: float = pc["a0"]
			var a1: float = pc["a1"]
			var n2 := maxi(2, int(absf(a1 - a0) * r / passo))
			for k in n2:
				var t := lerpf(a0, a1, float(k) / n2)
				out.append(c + Vector2(cos(t), sin(t)) * r)
	var ult: Dictionary = pecas[pecas.size() - 1]
	out.append(ult["b"] if ult["tipo"] == "reta" else (ult["c"] as Vector2) + Vector2(cos(float(ult["a1"])), sin(float(ult["a1"]))) * float(ult["r"]))
	return out


# ------------------------------------------------------------------ cadastro

func livre(r: Rect2, folga := 0.0) -> bool:
	var rr := r.grow(-folga) if folga > 0.0 else r
	for c in cadastro:
		var o: Rect2 = c["r"]
		var inter := rr.intersection(o)
		if inter.size.x > 0.001 and inter.size.y > 0.001:
			return false
	return true


func cadastrar(id: String, tipo: String, r: Rect2, extra := {}) -> Dictionary:
	var d := {"id": id, "tipo": tipo, "r": r}
	d.merge(extra)
	cadastro.append(d)
	return d


## Faixa da rua (leito + calçadas) de cada reta vira retângulo cadastrado; as curvas viram quadrados que cobrem o arco inteiro
## (nada de casa em curva).
func _cadastrar_rua() -> void:
	var meia := LARG_RUA * 0.5 + CALCADA
	var i := 0
	for pc in pecas:
		if pc["tipo"] == "reta":
			var a: Vector2 = pc["a"]
			var b: Vector2 = pc["b"]
			var r := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(b.x - a.x), absf(b.y - a.y))).grow(meia)
			cadastrar("rua_%d" % i, "rua", r)
		else:
			# curva: a faixa da rua vira uma fileira de quadrados ao longo do arco (cobre o leito sem engolir o quarteirão)
			var c: Vector2 = pc["c"]
			var r0: float = pc["r"]
			var a0: float = pc["a0"]
			var a1: float = pc["a1"]
			var n := maxi(2, int(absf(a1 - a0) * r0 / 1.2))
			for k in n + 1:
				var t := lerpf(a0, a1, float(k) / n)
				var pt := c + Vector2(cos(t), sin(t)) * r0
				cadastrar("curva_%d_%d" % [i, k], "curva", Rect2(pt - Vector2(meia, meia), Vector2(meia, meia) * 2.0))
		i += 1


## Lotes de um lado de uma reta. `lado` = +1 (esquerda de quem anda) ou -1. Devolve a frente do lote: posição ao longo da reta,
## e a direção "para dentro do lote".
func _quadro_lote(pc: Dictionary, lado: float) -> Dictionary:
	var a: Vector2 = pc["a"]
	var b: Vector2 = pc["b"]
	var t := (b - a).normalized()
	var n := Vector2(-t.y, t.x) * lado              # normal para o lado do lote
	return {"a": a, "b": b, "t": t, "n": n, "frente": LARG_RUA * 0.5 + CALCADA}


## Retângulo (alinhado) de um lote: começa em `u` ao longo da reta, largura `w`, profundidade `d`.
func _ret_lote(q: Dictionary, u: float, w: float, d: float) -> Rect2:
	var a: Vector2 = q["a"]
	var t: Vector2 = q["t"]
	var n: Vector2 = q["n"]
	var f: float = q["frente"]
	var p0 := a + t * u + n * f
	var p1 := p0 + t * w + n * d
	return Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), Vector2(absf(p1.x - p0.x), absf(p1.y - p0.y)))


## Reservas que não podem virar casa: a ponte e o vale do córrego na 1ª perna (dos dois lados da rua) e o largo do chafariz
## no miolo do 1º grampo.
func _reservas_fixas() -> void:
	var meia := LARG_RUA * 0.5 + CALCADA
	var xp := X_PONTE
	cadastrar("ponte_sul", "ponte", Rect2(Vector2(xp - 5.0, Z_PERNA[0] + meia), Vector2(10.0, 30.0)))
	cadastrar("ponte_norte", "ponte", Rect2(Vector2(xp - 5.0, Z_PERNA[1] + meia), Vector2(10.0, Z_PERNA[0] - Z_PERNA[1] - 2.0 * meia)))
	var c := Vector2(X_LESTE, Z_PERNA[0] - R_GRAMPO)
	var ri := (R_GRAMPO - meia - 0.3) * 0.62                  # quadrado inscrito no miolo do grampo (não toca a curva)
	cadastrar("largo_chafariz", "largo", Rect2(c - Vector2(ri, ri), Vector2(ri, ri) * 2.0))


## Becos-escada que ligam duas pernas vizinhas (atalhos): corredor reto em z, de uma calçada até a outra.
func _becos_ligacao() -> void:
	var meia := LARG_RUA * 0.5 + CALCADA
	var xs := [[24.0, 46.0], [20.0, 50.0], [26.0, 44.0]]
	for i in Z_PERNA.size() - 1:
		var z_baixo := Z_PERNA[i] - meia
		var z_cima := Z_PERNA[i + 1] + meia
		for x: float in xs[i]:
			var r := Rect2(Vector2(x - BECO_L * 0.5 - BECO_PAREDE, z_cima), Vector2(BECO_L + 2.0 * BECO_PAREDE, z_baixo - z_cima))
			if livre(r):
				cadastrar("beco_%d_%d" % [i, int(x)], "beco", r, {"x": x, "z_baixo": z_baixo, "z_cima": z_cima, "perna_baixo": i})
			else:
				avisos.append("beco %d/%d não coube" % [i, int(x)])


## Becos sem saída (portas das casas dos becos): 12 m para dentro do quarteirão, do lado de cima da perna.
func _becos_cegos() -> void:
	var meia := LARG_RUA * 0.5 + CALCADA
	var defs := [["ferraria", 0, 16.0], ["casa_vazia", 1, 33.0], ["pensao", 2, 56.0], ["costureira", 1, 58.0], ["deposito", 2, 14.0]]
	for d in defs:
		var i: int = d[1]
		var achou := false
		for k in 40:
			var x: float = float(d[2]) + float(k / 2) * 1.5 * (1.0 if k % 2 == 0 else -1.0)
			if x < X_OESTE + 4.0 or x > X_LESTE - 4.0:
				continue
			var z0 := Z_PERNA[i] - meia
			var r := Rect2(Vector2(x - BECO_L * 0.5 - BECO_PAREDE, z0 - 12.0), Vector2(BECO_L + 2.0 * BECO_PAREDE, 12.0))
			if livre(r):
				cadastrar("cego_" + str(d[0]), "cego", r, {"x": x, "z_rua": z0, "perna": i, "sala": d[0]})
				achou = true
				break
		if not achou:
			avisos.append("beco sem saída %s não coube" % d[0])


## Casas visitáveis: lote do tamanho exato da casa da sala (dimensões vindas das salas). `quero` = [id, peça, lado, u preferido].
func _casas_visitaveis(dims: Dictionary) -> void:
	var quero := [["benedita", 0, -1.0, 6.0], ["carpintaria", 2, 1.0, 22.0], ["padaria", 2, -1.0, 6.0], ["venda", 2, -1.0, 36.0],
		["escola", 4, 1.0, 4.0], ["barbearia", 4, -1.0, 16.0], ["casarao", 6, -1.0, 20.0], ["sineiro", 8, 1.0, 4.0]]
	for qd in quero:
		var id: String = qd[0]
		if not dims.has(id):
			continue
		var dm: Vector2 = dims[id]               # (largura de fachada, profundidade) da casa inteira
		var achou := false
		# primeiro a peça/lado preferidos; se não couber, as outras retas, dos dois lados
		var opcoes: Array = [[int(qd[1]), float(qd[2]), float(qd[3])]]
		for ip in pecas.size():
			if pecas[ip]["tipo"] == "reta":
				for ld: float in [float(qd[2]), -float(qd[2])]:
					opcoes.append([ip, ld, 2.0])
		for op in opcoes:
			if achou:
				break
			var pc: Dictionary = pecas[int(op[0])]
			var q := _quadro_lote(pc, float(op[1]))
			var comp: float = (pc["b"] as Vector2).distance_to(pc["a"])
			var u: float = op[2]
			var tent := 0
			while tent < 160 and not achou:
				var uu := u + (tent / 2) * 0.5 * (1.0 if tent % 2 == 0 else -1.0)
				tent += 1
				if uu < 1.0 or uu + dm.x > comp - 1.0:
					continue
				var r := _ret_lote(q, uu, dm.x, dm.y)
				if livre(r):
					cadastrar("visita_" + id, "visitavel", r, {"sala": id, "peca": int(op[0]), "lado": float(op[1]), "u": uu, "w": dm.x, "d": dm.y})
					achou = true
		if not achou:
			avisos.append("casa visitável %s não coube na peça %d" % [id, int(qd[1])])


## Casas comuns: enchem cada lado de cada reta com lotes de 6,5 a 11 m, encolhendo a profundidade até caber; o que não cabe vira quintal.
func _casas_comuns() -> void:
	var n_casa := 0
	for ip in pecas.size():
		var pc: Dictionary = pecas[ip]
		if pc["tipo"] != "reta":
			continue
		for lado: float in [1.0, -1.0]:
			var q := _quadro_lote(pc, lado)
			var comp: float = (pc["b"] as Vector2).distance_to(pc["a"])
			var u := 0.5
			while u < comp - 2.0:
				var w0 := rng.randf_range(6.5, 11.0)
				var pos := false
				# tenta a largura sorteada e, se não cabe, lotes mais estreitos (até 4,5 m); para cada largura, o fundo maior que couber
				var w := minf(w0, comp - 0.5 - u)
				while w >= 4.5 and not pos:
					var d := FUNDO_MAX
					while d >= FUNDO_MIN:
						if livre(_ret_lote(q, u, w, d)):
							cadastrar("casa_%d" % n_casa, "casa", _ret_lote(q, u, w, d), {"peca": ip, "lado": lado, "u": u, "w": w, "d": d})
							n_casa += 1
							u += w
							pos = true
							break
						d -= 0.5
					w -= 0.5
				if not pos:
					# nem casa estreita cabe: quintal murado raso (2,5 m) até o próximo obstáculo, para a rua não ficar com buraco
					var wq := 0.5
					while u + wq < comp - 0.5 and wq < 6.0 and livre(_ret_lote(q, u, wq + 0.5, 2.5)):
						wq += 0.5
					if wq >= 1.5 and livre(_ret_lote(q, u, wq, 2.5)):
						cadastrar("quintal_%d" % n_casa, "quintal", _ret_lote(q, u, wq, 2.5), {"peca": ip, "lado": lado, "u": u, "w": wq, "d": 2.5})
						n_casa += 1
						u += wq
					else:
						u += 0.5
	print("[plano] casas comuns: ", n_casa)


## Monta o plano inteiro. `dims` = {id_sala: Vector2(largura, profundidade)} das casas visitáveis (das salas reais).
func montar(dims := {}) -> Dictionary:
	rng.seed = 1961
	pecas = tracado()
	cadastro.clear()
	avisos.clear()
	_cadastrar_rua()
	_reservas_fixas()
	_becos_ligacao()
	_becos_cegos()
	_casas_visitaveis(dims)
	_casas_comuns()
	# prova: nenhuma sobreposição em todo o cadastro
	var sob := 0
	for i in cadastro.size():
		for j in range(i + 1, cadastro.size()):
			var a: Rect2 = cadastro[i]["r"]
			var b: Rect2 = cadastro[j]["r"]
			var inter := a.intersection(b)
			if inter.size.x > 0.001 and inter.size.y > 0.001:
				var ta: String = cadastro[i]["tipo"]
				var tb: String = cadastro[j]["tipo"]
				if (ta == "rua" or ta == "curva") and (tb == "rua" or tb == "curva"):
					continue                                         # trechos de rua se emendam
				sob += 1
				avisos.append("SOBREPOSIÇÃO %s x %s" % [cadastro[i]["id"], cadastro[j]["id"]])
	return {"pecas": pecas, "cadastro": cadastro, "sobreposicoes": sob, "avisos": avisos}
