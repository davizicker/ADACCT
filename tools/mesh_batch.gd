class_name MeshBatch
extends RefCounted
## Funde muitas caixas/quadros pequenos numa única malha com uma superfície por material.
## Serve para detalhes (molduras, janelas, grades, degraus) sem criar milhares de nós:
## uma casa com 60 peças vira 1 nó com ~7 superfícies.

var _st := {}                 # nome do material -> SurfaceTool
var _loader: Callable         # nome -> Material


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


func box(mat: String, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var xf := Transform3D(Basis.from_euler(rot), pos)
	var st := _tool(mat)
	var h := size * 0.5
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


## Quadro plano. Sem rotação ele "olha" para +Z. `yaw` gira em torno de Y.
func quad(mat: String, size: Vector2, pos: Vector3, yaw := 0.0) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos)
	var st := _tool(mat)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var p0 := xf * Vector3(-hx, -hy, 0)
	var p1 := xf * Vector3(hx, -hy, 0)
	var p2 := xf * Vector3(hx, hy, 0)
	var p3 := xf * Vector3(-hx, hy, 0)
	var en := (xf.basis * Vector3.BACK).normalized()
	tri(st, p0, p1, p2, en)
	tri(st, p0, p2, p3, en)


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
	for k in segs:
		var t0 := PI * float(k) / segs
		var t1 := PI * float(k + 1) / segs
		var tm := (t0 + t1) * 0.5
		var chord := 2.0 * r * sin((t1 - t0) * 0.5) + 0.03
		box(mat, Vector3(depth, thick, chord), center + Vector3(0, r * sin(tm), r * cos(tm)), Vector3(-tm - PI / 2.0, 0, 0))


## Meio disco (vidro/folha com topo em arco), no plano Y-Z, voltado para -X. `center` = meio da base.
func half_disc(mat: String, center: Vector3, r: float, segs := 10) -> void:
	var st := _tool(mat)
	for k in segs:
		var t0 := PI * float(k) / segs
		var t1 := PI * float(k + 1) / segs
		tri(st, center, center + Vector3(0, r * sin(t0), r * cos(t0)), center + Vector3(0, r * sin(t1), r * cos(t1)), Vector3(-1, 0, 0))


## Cilindro (eixo Y local; use `rot` para deitar). Serve para barris, rodas, bueiros, colunas.
func cylinder(mat: String, r_bottom: float, r_top: float, h: float, pos: Vector3, rot := Vector3.ZERO, segs := 10) -> void:
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
		(_st[mat_name] as SurfaceTool).commit(mesh)
		if mesh.get_surface_count() > before:
			mesh.surface_set_material(before, _loader.call(mat_name))
	return mesh
