class_name Detalhes
extends RefCounted
## Detalhes de natureza e de chão espalhados por MultiMesh (baratos): pedras, seixos, flores, folhas secas e poças.
## Chamado por VilaBuilder.build_vila(). Cada função registra quantas instâncias criou em `contagem`
## (o bake imprime isso e docs/14 lista o resultado).

const SW := Route.SIDEWALK
const SW_H := 0.12

var b: VilaBuilder
var contagem := {}


func construir(builder: VilaBuilder) -> Node3D:
	b = builder
	var root := Node3D.new()
	root.name = "Detalhes"
	root.add_child(_pedras_encosta())
	root.add_child(_seixos())
	root.add_child(_flores())
	root.add_child(_folhas())
	root.add_child(_pocas())
	return root


# ------------------------------------------------------------------ geometria procedural

## Pedra facetada: esfera deformada por ruído e achatada.
func _malha_pedra(semente: int, achatar: float) -> Mesh:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 1.3
	n.seed = semente
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 9
	var rings := 6
	var pts: Array = []
	for r in rings + 1:
		var row: Array[Vector3] = []
		var phi := PI * float(r) / rings
		for k in segs:
			var th := TAU * float(k) / segs
			var dir := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var rad := 1.0 + n.get_noise_3dv(dir * 1.6) * 0.38
			row.append(Vector3(dir.x * rad, dir.y * rad * achatar, dir.z * rad))
		pts.append(row)
	for r in rings:
		for k in segs:
			var k2 := (k + 1) % segs
			var a: Vector3 = pts[r][k]
			var bb: Vector3 = pts[r][k2]
			var c: Vector3 = pts[r + 1][k]
			var d: Vector3 = pts[r + 1][k2]
			var out := (a + bb + c + d) * 0.25
			MeshBatch.tri(st, a, c, d, out)
			MeshBatch.tri(st, a, d, bb, out)
	var m := st.commit()
	m.surface_set_material(0, b.mat("rocha"))
	return m


func _esfera_cor(st: SurfaceTool, c: Vector3, r: float, cor: Color) -> void:
	var segs := 5
	var rings := 3
	for ri in rings:
		for k in segs:
			var p00 := _sp(c, r, ri, k, segs, rings)
			var p01 := _sp(c, r, ri, k + 1, segs, rings)
			var p10 := _sp(c, r, ri + 1, k, segs, rings)
			var p11 := _sp(c, r, ri + 1, k + 1, segs, rings)
			for tri in [[p00, p10, p11], [p00, p11, p01]]:
				var n: Vector3 = ((tri[0] + tri[1] + tri[2]) / 3.0 - c).normalized()
				var nn: Vector3 = -(tri[1] - tri[0]).cross(tri[2] - tri[0])
				var order: Array = tri if nn.dot(n) >= 0.0 else [tri[0], tri[2], tri[1]]
				for v: Vector3 in order:
					st.set_color(cor)
					st.set_normal(n)
					st.add_vertex(v)


func _sp(c: Vector3, r: float, ri: int, k: int, segs: int, rings: int) -> Vector3:
	var phi := PI * float(ri) / rings
	var th := TAU * float(k) / segs
	return c + Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)) * r


## Tufo de flores: talos finos verdes e cabeças coloridas (cores por vértice). Um MultiMesh espalha dezenas.
func _malha_flores() -> Mesh:
	var cores := [Color(0.82, 0.10, 0.10), Color(0.9, 0.4, 0.55), Color(0.95, 0.8, 0.15), Color(0.93, 0.92, 0.85), Color(0.55, 0.3, 0.75), Color(0.95, 0.5, 0.12)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var talos: Array[Mesh] = []
	var heads := SurfaceTool.new()
	heads.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalk := SurfaceTool.new()
	stalk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cor: Color = cores[rng.randi() % cores.size()]
	for i in 6:
		var base := Vector3(rng.randf_range(-0.14, 0.14), 0.0, rng.randf_range(-0.14, 0.14))
		var h := rng.randf_range(0.22, 0.45)
		var top := base + Vector3(rng.randf_range(-0.07, 0.07), h, rng.randf_range(-0.07, 0.07))
		var pts: Array[Vector3] = [base, (base + top) * 0.5 + Vector3(0.02, 0, 0), top]
		var rad: Array[float] = [0.006, 0.005, 0.004]
		stalk.append_from(Criaturas.tubo(pts, rad, 4, 1.0, false, false), 0, Transform3D.IDENTITY)
		if i % 3 == 0:
			cor = cores[rng.randi() % cores.size()]
		_esfera_cor(heads, top, rng.randf_range(0.03, 0.05), cor)
	var mesh := ArrayMesh.new()
	var ha := heads.commit()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ha.surface_get_arrays(0))
	mesh.surface_set_material(0, b.mat("flor_mix"))
	var sa := stalk.commit()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sa.surface_get_arrays(0))
	mesh.surface_set_material(1, b.mat("verde_vaso"))
	return mesh


func _mmi(nome: String, mesh: Mesh, xf: Array[Transform3D], cores := [], fim := 90.0) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = cores.size() > 0
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		if cores.size() > 0:
			mm.set_instance_color(i, cores[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = nome
	mi.multimesh = mm
	mi.visibility_range_end = fim
	mi.visibility_range_end_margin = 10.0
	contagem[nome] = xf.size()
	return mi


## Ponto na rua/calçada: s, lado (-1/+1) e distância ao eixo; y sobre o piso.
func _ponto(s: float, lateral: float, sobe := 0.0) -> Vector3:
	var p := Route.pos(s) + Route.right(s) * lateral
	return Vector3(p.x, Route.height(s) + sobe, p.z)


# ------------------------------------------------------------------ pedras, seixos, flores, folhas, poças

func _pedras_encosta() -> Node3D:
	var g := Node3D.new()
	g.name = "Pedras"
	for v in 3:
		var mesh := _malha_pedra(10 + v * 7, 0.55 + v * 0.1)
		var xf: Array[Transform3D] = []
		var tries := 0
		while xf.size() < 260 and tries < 2000:
			tries += 1
			var s := b._rng.randf_range(0.0, Route.length())
			var sig := -1.0 if b._rng.randf() < 0.5 else 1.0
			var d := b._rng.randf_range(Route.width(s) * 0.5 + 9.0, 85.0)
			var p := Route.pos(s) + Route.right(s) * sig * d
			var tam := b._rng.randf_range(0.35, 1.9) * (1.0 + v * 0.25)
			var bas := Basis.from_euler(Vector3(b._rng.randf_range(-0.2, 0.2), b._rng.randf() * TAU, b._rng.randf_range(-0.2, 0.2))).scaled(Vector3(tam, tam, tam * b._rng.randf_range(0.8, 1.3)))
			xf.append(Transform3D(bas, Vector3(p.x, b.terrain_h(p.x, p.z) + tam * 0.12, p.z)))
		g.add_child(_mmi("Rochas_%d" % v, mesh, xf, [], 180.0))
	return g


func _seixos() -> Node3D:
	var g := Node3D.new()
	g.name = "Seixos"
	var mesh := _malha_pedra(77, 0.6)
	var xf: Array[Transform3D] = []
	var s := 1.0
	while s < Route.length() - 1.0:
		for k in 3:
			var sig := -1.0 if b._rng.randf() < 0.5 else 1.0
			var w := Route.width(s)
			var lat := sig * (w * 0.5 + b._rng.randf_range(-0.7, SW + 0.1))
			var y := Route.height(s) + (SW_H if absf(lat) > w * 0.5 + 0.05 else 0.03)
			var t := b._rng.randf_range(0.03, 0.10)
			var p := _ponto(s + b._rng.randf_range(-0.6, 0.6), lat, y - Route.height(s))
			xf.append(Transform3D(Basis.from_euler(Vector3(0, b._rng.randf() * TAU, 0)).scaled(Vector3(t, t, t)), p))
		s += 0.8
	g.add_child(_mmi("Seixos", mesh, xf, [], 55.0))
	return g


func _flores() -> Node3D:
	var g := Node3D.new()
	g.name = "Flores"
	var mesh := _malha_flores()
	var xf: Array[Transform3D] = []
	# pé das casas (calçada), em tufos
	var s := 3.0
	while s < Route.length() - 8.0:
		for sig: float in [-1.0, 1.0]:
			if b._rng.randf() < 0.22:
				var w := Route.width(s)
				var p := _ponto(s, sig * (w * 0.5 + SW - 0.14), SW_H - 0.02)
				if b._livre(p, 0.4):
					xf.append(Transform3D(Basis(Vector3.UP, b._rng.randf() * TAU).scaled(Vector3.ONE * b._rng.randf_range(0.8, 1.5)), p))
		s += 1.7
	# morros: campo de flores entre o capim
	var tries := 0
	var n := 0
	while n < 420 and tries < 3000:
		tries += 1
		var ss := b._rng.randf_range(0.0, Route.length())
		var sig := -1.0 if b._rng.randf() < 0.5 else 1.0
		var d := b._rng.randf_range(Route.width(ss) * 0.5 + 12.0, 60.0)
		var p := Route.pos(ss) + Route.right(ss) * sig * d
		xf.append(Transform3D(Basis(Vector3.UP, b._rng.randf() * TAU).scaled(Vector3.ONE * b._rng.randf_range(1.0, 2.4)), Vector3(p.x, b.terrain_h(p.x, p.z) - 0.03, p.z)))
		n += 1
	g.add_child(_mmi("Flores", mesh, xf, [], 100.0))
	return g


func _folhas() -> Node3D:
	var g := Node3D.new()
	g.name = "Folhas"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := 0.07
	var hz := 0.045
	var p00 := Vector3(-hx, 0, -hz)
	var p10 := Vector3(hx, 0, -hz)
	var p11 := Vector3(hx, 0, hz)
	var p01 := Vector3(-hx, 0, hz)
	for tri in [[p00, p01, p11, Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)], [p00, p11, p10, Vector2(0, 0), Vector2(1, 1), Vector2(1, 0)]]:
		MeshBatch.tri_uv(st, tri[0], tri[1], tri[2], tri[3], tri[4], tri[5], Vector3.UP)
	var mesh := st.commit()
	mesh.surface_set_material(0, b.mat("folha_seca"))
	var xf: Array[Transform3D] = []
	var cores: Array = []
	var s := 0.5
	while s < Route.length() - 0.5:
		for k in 14:
			var w := Route.width(s)
			var lat := b._rng.randf_range(-w * 0.5 - SW + 0.2, w * 0.5 + SW - 0.1)
			var no_calcada := absf(lat) > w * 0.5 + 0.05
			var y := (SW_H + 0.012) if no_calcada else 0.04
			var sc := b._rng.randf_range(0.7, 1.5)
			var bas := Basis(Vector3.UP, b._rng.randf() * TAU).scaled(Vector3(sc, 1.0, sc))
			xf.append(Transform3D(bas, _ponto(s + b._rng.randf_range(-0.6, 0.6), lat, y)))
			var t := b._rng.randf()
			cores.append(Color(0.75, 0.55, 0.35).lerp(Color(1.0, 0.85, 0.55), t) if b._rng.randf() < 0.8 else Color(0.5, 0.55, 0.25))
		s += 1.0
	g.add_child(_mmi("Folhas", mesh, xf, cores, 45.0))
	return g


func _pocas() -> Node3D:
	var g := Node3D.new()
	g.name = "Pocas"
	var n := 0
	var s := 6.0
	var passo := 11.0
	while s < Route.length() - 10.0:
		s += b._rng.randf_range(passo * 0.6, passo * 1.4)
		if absf(s - Route.BRIDGE_S) < 6.0:
			continue
		var w := Route.width(s)
		var sig := -1.0 if b._rng.randf() < 0.5 else 1.0
		var lat := sig * (w * 0.5 - b._rng.randf_range(0.45, 1.1))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var nz := FastNoiseLite.new()
		nz.seed = int(s * 13.0)
		nz.frequency = 1.2
		var rx := b._rng.randf_range(0.4, 1.1)
		var rz := b._rng.randf_range(0.3, 0.7)
		var segs := 18
		var centro := Vector3.ZERO
		var ring: Array[Vector3] = []
		for k in segs:
			var a := TAU * float(k) / segs
			var rr := 1.0 + nz.get_noise_1d(float(k) * 0.7) * 0.28
			ring.append(Vector3(cos(a) * rx * rr, 0, sin(a) * rz * rr))
		for k in segs:
			MeshBatch.tri(st, centro, ring[k], ring[(k + 1) % segs], Vector3.UP)
		var mi := MeshInstance3D.new()
		mi.name = "Poca_%02d" % n
		var m := st.commit()
		m.surface_set_material(0, b.mat("poca"))
		mi.mesh = m
		var t := Route.tangent(s)
		var base := Basis(Vector3.UP, atan2(-t.z, t.x))
		mi.transform = Transform3D(base, _ponto(s, lat, 0.045))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 90.0
		g.add_child(mi)
		n += 1
	contagem["Pocas"] = n
	return g
