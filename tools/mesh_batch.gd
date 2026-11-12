class_name MeshBatch
extends RefCounted
## Funde muitas caixas/quadros pequenos numa única malha com uma superfície por material.
## Serve para detalhes (molduras, janelas, grades, degraus) sem criar milhares de nós:
## uma casa com 60 peças vira 1 nó com ~7 superfícies.

var _st := {}                 # nome do material -> SurfaceTool
var _loader: Callable         # nome -> Material
var _boxes: Array = []        # [material, AABB] de cada box() (para a auditoria de peças soltas)
## Afastamento anti-z-fighting: cada material recebe um "degrau" de 1,2 mm (0 a 6 mm) somado à meia-medida das caixas dele.
## Duas peças de materiais diferentes nunca ficam com a face no MESMO plano (era o que fazia moldura, veneziana, ferragem e
## remendo de tijolo piscarem e "entrarem" uns nos outros). Invisível a olho nu.
static var _ordem_mat := {}


static func _eps(mat: String) -> float:
	if not _ordem_mat.has(mat):
		var degrau := 0
		if mat.begins_with("cantaria") or mat == "pedra_sabao" or mat == "pedra_chao":
			degrau = 0                   # molduras e pedras: o plano de base
		elif mat == "muro" or mat.begins_with("reboco") or mat.begins_with("i_reboco"):
			degrau = 1
		elif mat.begins_with("janela") or mat.begins_with("vidro"):
			degrau = 2
		elif mat.begins_with("madeira") or mat.begins_with("piso"):
			degrau = 3
		elif mat == "listra_azul":
			degrau = 6
		elif mat.begins_with("listra") or mat.begins_with("pano") or mat.begins_with("tapete") or mat.begins_with("placa"):
			degrau = 4
		elif mat.begins_with("ferro") or mat == "ouro_velho":
			degrau = 5
		else:
			degrau = 7 + (_ordem_mat.size() % 3)
		_ordem_mat[mat] = degrau
	return 0.0017 * float(_ordem_mat[mat])


func _init(material_loader: Callable) -> void:
	_loader = material_loader


func _tool(mat: String) -> SurfaceTool:
	if not _st.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[mat] = st
	return _st[mat]


## Triângulo com a ordem de vértices escolhida para a face visível apontar para `expect`.
## (O Godot considera "frente" o sentido horário visto de fora.)
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, expect: Vector3) -> void:
	var n := -(b - a).cross(c - a)
	if n.length() < 0.000001:
		return
	n = n.normalized()
	if n.dot(expect) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	for v in [a, b, c]:
		st.set_smooth_group(-1)
		st.set_normal(n)
		st.add_vertex(v)


## Triângulo com UV (a ordem dos vértices é ajustada para a face visível apontar para `expect`).
static func tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, expect: Vector3) -> void:
	var n := -(b - a).cross(c - a)
	if n.length() < 0.000001:
		return
	n = n.normalized()
	if n.dot(expect) < 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
		n = -n
	var pts := [a, b, c]
	var uvs := [ua, ub, uc]
	for i in 3:
		st.set_smooth_group(-1)
		st.set_normal(n)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


## Faces de caixas que ficam NO MESMO PLANO, viradas para o mesmo lado e se sobrepondo: o motor não sabe qual desenhar e a superfície PISCA (z-fighting).
## Só confere caixas sem rotação. Retorna descrições curtas.
func coplanares(limite := 20, dentro := AABB(Vector3(-1e6, -1e6, -1e6), Vector3(2e6, 2e6, 2e6))) -> Array[String]:
	var out: Array[String] = []
	var n := _boxes.size()
	for i in n:
		if bool(_boxes[i][2]) if _boxes[i].size() > 2 else false:
			continue
		var a: AABB = _boxes[i][1]
		for j in range(i + 1, n):
			if bool(_boxes[j][2]) if _boxes[j].size() > 2 else false:
				continue
			if String(_boxes[i][0]) == String(_boxes[j][0]):
				continue                                           # mesmo material no mesmo plano: mesma cor, não pisca
			var b: AABB = _boxes[j][1]
			if not a.grow(0.004).intersects(b.grow(0.004)):
				continue
			for ax in 3:
				var o1 := (ax + 1) % 3
				var o2 := (ax + 2) % 3
				var ov1 := minf(a.end[o1], b.end[o1]) - maxf(a.position[o1], b.position[o1])
				var ov2 := minf(a.end[o2], b.end[o2]) - maxf(a.position[o2], b.position[o2])
				if ov1 < 0.02 or ov2 < 0.02:
					continue
				var mesmo_fim := absf(a.end[ax] - b.end[ax]) < 0.0015
				if mesmo_fim or absf(a.position[ax] - b.position[ax]) < 0.0015:
					var plano: float = a.end[ax] if mesmo_fim else a.position[ax]
					if plano < dentro.position[ax] - 0.01 or plano > dentro.end[ax] + 0.01:
						continue                                       # face por fora da sala: ninguém vê
					if (mesmo_fim and plano >= dentro.end[ax] - 0.01) or ((not mesmo_fim) and plano <= dentro.position[ax] + 0.01):
						continue                                       # face virada para a parede/forro/piso: fica escondida atrás dele
					out.append("%s x %s eixo %s (%.2f x %.2f m) perto de (%.2f, %.2f, %.2f)" % [_boxes[i][0], _boxes[j][0], "xyz"[ax], ov1, ov2, a.get_center().x, a.get_center().y, a.get_center().z])
					if out.size() >= limite:
						return out
					break
	return out


func box(mat: String, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var xf := Transform3D(Basis.from_euler(rot), pos)
	var st := _tool(mat)
	var h := size * 0.5 + Vector3.ONE * _eps(mat)
	_boxes.append([mat, xf * AABB(-h, h * 2.0), rot != Vector3.ZERO])
	for axis in 3:
		for sign in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = sign
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var c := n * h[axis]
			var hu: float = h[(axis + 1) % 3]
			var hv: float = h[(axis + 2) % 3]
			var p0 := xf * (c - u * hu - v * hv)
			var p1 := xf * (c + u * hu - v * hv)
			var p2 := xf * (c + u * hu + v * hv)
			var p3 := xf * (c - u * hu + v * hv)
			var en := (xf.basis * n).normalized()
			tri(st, p0, p1, p2, en)
			tri(st, p0, p2, p3, en)


## Quadro plano COM UV. Sem rotação ele "olha" para +Z. `yaw` gira em torno de Y.
## uv0 = canto de cima à esquerda da textura, uv1 = canto de baixo à direita (para usar só um pedaço).
func quad(mat: String, size: Vector2, pos: Vector3, yaw := 0.0, uv0 := Vector2(0, 0), uv1 := Vector2(1, 1)) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	var st := _tool(mat)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var p0 := xf * Vector3(-hx, -hy, 0)
	var p1 := xf * Vector3(hx, -hy, 0)
	var p2 := xf * Vector3(hx, hy, 0)
	var p3 := xf * Vector3(-hx, hy, 0)
	var en := (xf.basis * Vector3.BACK).normalized()
	tri_uv(st, p0, p1, p2, Vector2(uv0.x, uv1.y), Vector2(uv1.x, uv1.y), Vector2(uv1.x, uv0.y), en)
	tri_uv(st, p0, p2, p3, Vector2(uv0.x, uv1.y), Vector2(uv1.x, uv0.y), Vector2(uv0.x, uv0.y), en)


## Quadro horizontal COM UV, voltado para cima (tapetes, pisos decorativos). `size` = (x, z). `yaw` gira em torno de Y.
func quad_h(mat: String, size: Vector2, pos: Vector3, yaw := 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	var st := _tool(mat)
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var p0 := xf * Vector3(-hx, 0, -hz)
	var p1 := xf * Vector3(hx, 0, -hz)
	var p2 := xf * Vector3(hx, 0, hz)
	var p3 := xf * Vector3(-hx, 0, hz)
	var en := (xf.basis * Vector3.UP).normalized()
	tri_uv(st, p0, p3, p2, Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), en)
	tri_uv(st, p0, p2, p1, Vector2(0, 0), Vector2(1, 1), Vector2(1, 0), en)
	_boxes.append([mat, xf * AABB(Vector3(-hx, -0.002, -hz), Vector3(size.x, 0.004, size.y))])


## Telhado de duas águas COM UV: as telhas correm no sentido do caimento. Cumeeira ao longo de Z local.
## size = (vão X, altura da cumeeira Y, comprimento Z). Empenas (triângulos das pontas) usam `mat_gable`.
func roof(mat_roof: String, mat_gable: String, size: Vector3, pos: Vector3, yaw := 0.0, tile := 3.6, mat_soffit := "") -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	var st := _tool(mat_roof)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var slope := sqrt(hx * hx + size.y * size.y)
	var a := xf * Vector3(-hx, -hy, -hz)
	var b := xf * Vector3(hx, -hy, -hz)
	var c := xf * Vector3(0, hy, -hz)
	var a2 := xf * Vector3(-hx, -hy, hz)
	var b2 := xf * Vector3(hx, -hy, hz)
	var c2 := xf * Vector3(0, hy, hz)
	var nl := (xf.basis * Vector3(-size.y, hx, 0)).normalized()
	var nr := (xf.basis * Vector3(size.y, hx, 0)).normalized()
	var uz := size.z / tile
	var vs := slope / tile
	# águas em "capa e canal": a superfície ondula na direção da cumeeira (telhas curvas), com 3 fiadas ao longo do caimento
	_agua(st, c, c2, a, a2, nl, size.z, uz, vs, 0.032)
	_agua(st, c, c2, b, b2, nr, size.z, uz, vs, 0.032)
	var sg := _tool(mat_gable)
	tri(sg, a, b, c, xf.basis * Vector3(0, 0, -1))
	tri(sg, a2, c2, b2, xf.basis * Vector3(0, 0, 1))
	if mat_soffit != "":
		# forro: sem ele o beiral deixa ver o céu por baixo (o telhado é uma casca aberta)
		var ss := _tool(mat_soffit)
		var down := xf.basis * Vector3(0, -1, 0)
		tri(ss, a, a2, b2, down)
		tri(ss, a, b2, b, down)


## Uma água do telhado como grade ondulada. r0/r1 = cumeeira nas pontas, e0/e1 = beiral nas pontas.
func _agua(st: SurfaceTool, r0: Vector3, r1: Vector3, e0: Vector3, e1: Vector3, n: Vector3, comp: float, uz: float, vs: float, amp: float) -> void:
	var nz := maxi(6, int(comp / 0.15))
	var ns := 3
	var periodo := 0.30
	var grade: Array = []
	for i in nz + 1:
		var t := float(i) / nz
		var linha: Array[Vector3] = []
		var ridge := r0.lerp(r1, t)
		var eave := e0.lerp(e1, t)
		var onda := amp * (0.5 + 0.5 * sin(TAU * t * comp / periodo))
		for j in ns + 1:
			var v := float(j) / ns
			var fiada := amp * 0.5 * (1.0 if j % 2 == 1 else 0.0) * 0.4     # sobreposição de fiadas: leve degrau
			linha.append(ridge.lerp(eave, v) + n * (onda + fiada))
		grade.append(linha)
	for i in nz:
		for j in ns:
			var p00: Vector3 = grade[i][j]
			var p01: Vector3 = grade[i][j + 1]
			var p10: Vector3 = grade[i + 1][j]
			var p11: Vector3 = grade[i + 1][j + 1]
			var u0 := uz * float(i) / nz
			var u1 := uz * float(i + 1) / nz
			var v0 := vs * float(j) / ns
			var v1 := vs * float(j + 1) / ns
			tri_uv(st, p00, p10, p11, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), n)
			tri_uv(st, p00, p11, p01, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1), n)


## Prisma triangular (telhado de duas águas). Cumeeira ao longo de Z local.
## size = (largura da base em X, altura em Y, comprimento em Z); `yaw` gira em torno de Y.
func prism(mat: String, size: Vector3, pos: Vector3, yaw := 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	var st := _tool(mat)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var a := xf * Vector3(-hx, -hy, -hz)
	var b := xf * Vector3(hx, -hy, -hz)
	var c := xf * Vector3(0, hy, -hz)
	var a2 := xf * Vector3(-hx, -hy, hz)
	var b2 := xf * Vector3(hx, -hy, hz)
	var c2 := xf * Vector3(0, hy, hz)
	var nl := (xf.basis * Vector3(-2.0 * hy, hx, 0)).normalized()
	var nr := (xf.basis * Vector3(2.0 * hy, hx, 0)).normalized()
	tri(st, a, c, c2, nl)
	tri(st, a, c2, a2, nl)
	tri(st, b, b2, c2, nr)
	tri(st, b, c2, c, nr)
	tri(st, a, b, c, xf.basis * Vector3(0, 0, -1))
	tri(st, a2, c2, b2, xf.basis * Vector3(0, 0, 1))


## Arco de pedra (meia coroa) no plano Y-Z, voltado para -X. `r` = raio médio, `thick` = espessura radial.
func arch(mat: String, center: Vector3, r: float, thick: float, depth: float, segs := 8) -> void:
	segs = maxi(segs, 14)                      # arcos mais suaves
	for k in segs:
		var t0 := PI * float(k) / segs
		var t1 := PI * float(k + 1) / segs
		var tm := (t0 + t1) * 0.5
		var chord := 2.0 * r * sin((t1 - t0) * 0.5) + 0.03
		box(mat, Vector3(depth, thick, chord), center + Vector3(0, r * sin(tm), r * cos(tm)), Vector3(-tm - PI / 2.0, 0, 0))


## Meio disco (vidro/folha com topo em arco), no plano Y-Z, voltado para -X. `center` = meio da base.
## uv = (v da base do disco, altura total da janela em m) para continuar a textura do quadro abaixo dele.
func half_disc(mat: String, center: Vector3, r: float, segs := 10, uv := Vector2(-1, 1)) -> void:
	var st := _tool(mat)
	for k in segs:
		var t0 := PI * float(k) / segs
		var t1 := PI * float(k + 1) / segs
		var p0 := center
		var p1 := center + Vector3(0, r * sin(t0), r * cos(t0))
		var p2 := center + Vector3(0, r * sin(t1), r * cos(t1))
		if uv.x >= 0.0:
			var f := func(p: Vector3) -> Vector2:
				return Vector2(0.5 + (p.z - center.z) / (2.0 * r), uv.x - (p.y - center.y) / uv.y)
			tri_uv(st, p0, p1, p2, f.call(p0), f.call(p1), f.call(p2), Vector3(-1, 0, 0))
		else:
			tri(st, p0, p1, p2, Vector3(-1, 0, 0))


## Cilindro (eixo Y local; use `rot` para deitar). Serve para barris, rodas, bueiros, colunas.
func cylinder(mat: String, r_bottom: float, r_top: float, h: float, pos: Vector3, rot := Vector3.ZERO, segs := 10) -> void:
	segs = maxi(segs, 12)                      # nada de cilindro "quadradão": no mínimo 12 lados
	var xf := Transform3D(Basis.from_euler(rot), pos)
	var st := _tool(mat)
	var hh := h * 0.5
	for k in segs:
		var a0 := TAU * float(k) / segs
		var a1 := TAU * float(k + 1) / segs
		var b0 := xf * Vector3(cos(a0) * r_bottom, -hh, sin(a0) * r_bottom)
		var b1 := xf * Vector3(cos(a1) * r_bottom, -hh, sin(a1) * r_bottom)
		var t0 := xf * Vector3(cos(a0) * r_top, hh, sin(a0) * r_top)
		var t1 := xf * Vector3(cos(a1) * r_top, hh, sin(a1) * r_top)
		var am := (a0 + a1) * 0.5
		var out := (xf.basis * Vector3(cos(am), 0, sin(am))).normalized()
		tri(st, b0, t0, t1, out)
		tri(st, b0, t1, b1, out)
		var up := (xf.basis * Vector3.UP).normalized()
		tri(st, xf * Vector3(0, hh, 0), t1, t0, up)
		tri(st, xf * Vector3(0, -hh, 0), b0, b1, -up)


## Esfera de baixa resolução (folhagem de vaso, flores, bolas de pedra).
func sphere(mat: String, r: float, pos: Vector3, segs := 8, rings := 5) -> void:
	segs = maxi(segs, 10)                      # esferas (flores, bolas de pedra, cabeças) menos facetadas
	rings = maxi(rings, 6)
	var st := _tool(mat)
	for j in rings:
		var p0 := PI * float(j) / rings
		var p1 := PI * float(j + 1) / rings
		for k in segs:
			var a0 := TAU * float(k) / segs
			var a1 := TAU * float(k + 1) / segs
			var v00 := pos + Vector3(sin(p0) * cos(a0), cos(p0), sin(p0) * sin(a0)) * r
			var v01 := pos + Vector3(sin(p0) * cos(a1), cos(p0), sin(p0) * sin(a1)) * r
			var v10 := pos + Vector3(sin(p1) * cos(a0), cos(p1), sin(p1) * sin(a0)) * r
			var v11 := pos + Vector3(sin(p1) * cos(a1), cos(p1), sin(p1) * sin(a1)) * r
			var c := (v00 + v01 + v10 + v11) * 0.25 - pos
			tri(st, v00, v01, v11, c)
			tri(st, v00, v11, v10, c)


## Triângulo visível dos dois lados (bandeirinhas, panos no varal).
func tri2(mat: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	var st := _tool(mat)
	var n := (b - a).cross(c - a).normalized()
	tri(st, a, b, c, n)
	tri(st, a, b, c, -n)


func is_empty() -> bool:
	return _st.is_empty()


## Gera a malha final (uma superfície por material, com o material já atribuído).
func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat_name: String in _st:
		var before := mesh.get_surface_count()
		if mat_name.ends_with("_uv"):
			(_st[mat_name] as SurfaceTool).generate_tangents()   # normal map precisa de tangentes
		(_st[mat_name] as SurfaceTool).commit(mesh)
		if mesh.get_surface_count() > before:
			mesh.surface_set_material(before, _loader.call(mat_name))
	return mesh


## Junta uma malha pronta (do kit modelado no Blender, assets/models/kit/) ao lote, com transformação `xf`.
## `mapa` troca o nome do material do .glb pelo material do jogo (ex.: {"madeira": "madeira_azul", "vidro": "vidro_luz"}).
func malha(mesh: Mesh, xf: Transform3D, mapa := {}) -> void:
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var nome: String = m.resource_name if m != null else "cantaria"
		nome = mapa.get(nome, nome)
		var xf2 := xf
		xf2.origin.x -= _eps(nome)                     # cada material uns milímetros para fora da fachada (-X): batente, folha e ferragem sem piscar
		_tool(nome).append_from(mesh, i, xf2)
		var bb: AABB = xf2 * mesh.surface_get_aabb(i) if mesh.has_method("surface_get_aabb") else xf2 * mesh.get_aabb()
		_boxes.append([nome, bb, true])          # malha pronta: a caixa envolvente não é a geometria (fica fora da auditoria de planos)


## Auditoria: caixas que não encostam em nenhuma outra caixa do lote nem nos sólidos dados (flutuando).
## Devolve descrições "material em (x,y,z)". `tol` = folga em metros.
func floating(solids: Array, tol := 0.04) -> Array[String]:
	var out: Array[String] = []
	for i in _boxes.size():
		var a: AABB = (_boxes[i][1] as AABB).grow(tol)
		var touches := false
		for sd in solids:
			if a.intersects(sd as AABB):
				touches = true
				break
		if not touches:
			for j in _boxes.size():
				if i != j and a.intersects(_boxes[j][1] as AABB):
					touches = true
					break
		if not touches:
			var c: Vector3 = (_boxes[i][1] as AABB).get_center()
			out.append("%s em (%.2f, %.2f, %.2f)" % [_boxes[i][0], c.x, c.y, c.z])
	return out
