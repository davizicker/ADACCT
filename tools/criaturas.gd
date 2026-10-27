class_name Criaturas
extends RefCounted
## Modelos procedurais do Bradador e da Mula-sem-cabeça (placeholders bem melhores que primitivas).
## Para usar os modelos reais, coloque assets/models/bradador.glb e mula.glb (ver scripts/modelos.gd).
## Os nós mantêm os nomes que o jogo espera (Manto, Cabeca, Braco_*, Corpo, Pescoco, Perna*).

static var _ruido := _novo_ruido()


static func _novo_ruido() -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.0
	n.seed = 61
	return n


## Tubo que segue `pts` com raio `rad[i]` em cada ponto (secção elíptica: achatamento lateral `ex`).
static func tubo(pts: Array[Vector3], rad: Array[float], segs := 10, ex := 1.0, tampa_fim := true, tampa_ini := true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	var aneis: Array = []
	for i in n:
		var t: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.UP if absf(t.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
		var a := t.cross(ref).normalized()
		var b := t.cross(a).normalized()
		var ring: Array[Vector3] = []
		for k in segs:
			var ang := TAU * float(k) / segs
			ring.append(pts[i] + a * cos(ang) * rad[i] * ex + b * sin(ang) * rad[i])
		aneis.append(ring)
	for i in n - 1:
		for k in segs:
			var k2 := (k + 1) % segs
			var p00: Vector3 = aneis[i][k]
			var p01: Vector3 = aneis[i][k2]
			var p10: Vector3 = aneis[i + 1][k]
			var p11: Vector3 = aneis[i + 1][k2]
			var fora: Vector3 = ((p00 + p01 + p10 + p11) * 0.25 - (pts[i] + pts[i + 1]) * 0.5)
			MeshBatch.tri(st, p00, p10, p11, fora)
			MeshBatch.tri(st, p00, p11, p01, fora)
	if tampa_fim:
		for k in segs:
			MeshBatch.tri(st, pts[n - 1], aneis[n - 1][k], aneis[n - 1][(k + 1) % segs], pts[n - 1] - pts[n - 2])
	if tampa_ini:
		for k in segs:
			MeshBatch.tri(st, pts[0], aneis[0][k], aneis[0][(k + 1) % segs], pts[0] - pts[1])
	st.generate_normals()
	return st.commit()


## Sólido de revolução (perfil = [raio, altura]) com a barra esfarrapada: `rasgo` = profundidade dos farrapos.
static func manto(perfil: Array[Vector2], segs: int, rasgo: float, semente: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var linhas: Array = []
	for pi in perfil.size():
		var linha: Array[Vector3] = []
		for k in segs:
			var ang := TAU * float(k) / segs
			var r := perfil[pi].x
			var y := perfil[pi].y
			var ru := _ruido.get_noise_2d(cos(ang) * 1.4 + semente, sin(ang) * 1.4 + float(pi) * 0.9) * 0.5 + 0.5
			if pi == 0:                                   # barra: farrapos de alturas diferentes
				y += pow(ru, 1.6) * rasgo
				r *= 0.92 + ru * 0.25
			elif pi == 1:
				r *= 0.94 + ru * 0.12
			linha.append(Vector3(cos(ang) * r, y, sin(ang) * r))
		linhas.append(linha)
	for i in linhas.size() - 1:
		for k in segs:
			var k2 := (k + 1) % segs
			var p00: Vector3 = linhas[i][k]
			var p01: Vector3 = linhas[i][k2]
			var p10: Vector3 = linhas[i + 1][k]
			var p11: Vector3 = linhas[i + 1][k2]
			var c := (p00 + p01 + p10 + p11) * 0.25
			var fora := Vector3(c.x, 0, c.z)
			MeshBatch.tri(st, p00, p10, p11, fora)
			MeshBatch.tri(st, p00, p11, p01, fora)
			# duas faces: o manto rasgado é visto por dentro nos farrapos
			MeshBatch.tri(st, p00, p10, p11, -fora)
			MeshBatch.tri(st, p00, p11, p01, -fora)
	st.generate_normals()
	return st.commit()


static func _esfera(pai: Node3D, nome: String, pos: Vector3, escala: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 14
	sm.rings = 8
	mi.mesh = sm
	mi.scale = escala
	mi.position = pos
	mi.material_override = mat
	pai.add_child(mi)
	return mi


static func _malha(pai: Node3D, nome: String, mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	pai.add_child(mi)
	return mi


static func _emissivo(cor: Color, energia: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = energia
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


# ------------------------------------------------------------------ BRADADOR
## Figura alta e magra de manto esfarrapado, ombros curvados, braços longos até os joelhos e rosto pálido gritando.
## Olha para -Z. Altura ~2,7 m.
static func bradador(preto: Material, palido: Material) -> Node3D:
	var n := Node3D.new()
	n.name = "Bradador"
	var perfil: Array[Vector2] = [
		Vector2(0.62, 0.0), Vector2(0.55, 0.35), Vector2(0.38, 0.85), Vector2(0.26, 1.30),
		Vector2(0.30, 1.75), Vector2(0.33, 2.02), Vector2(0.22, 2.20), Vector2(0.11, 2.30),
	]
	var m := _malha(n, "Manto", manto(perfil, 22, 0.42, 3.0), preto)
	m.rotation_degrees.x = 4.0                       # corcunda leve: o corpo inclina para a frente (-Z)
	# capuz: casca escura em volta da cabeça, aberta na frente
	var capuz := _esfera(n, "Capuz", Vector3(0, 2.46, 0.10), Vector3(0.48, 0.64, 0.44), preto)
	capuz.rotation_degrees.x = -8.0
	var cab := Node3D.new()
	cab.name = "Cabeca"
	cab.position = Vector3(0, 2.42, -0.17)
	n.add_child(cab)
	_esfera(cab, "Rosto", Vector3.ZERO, Vector3(0.26, 0.46, 0.26), palido)
	# boca escancarada (gritando) e olhos fundos
	var vazio := StandardMaterial3D.new()
	vazio.albedo_color = Color(0.01, 0.005, 0.005)
	vazio.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_esfera(cab, "Boca", Vector3(0, -0.15, -0.115), Vector3(0.13, 0.2, 0.07), vazio)
	for lado: float in [-1.0, 1.0]:
		_esfera(cab, "Olho", Vector3(lado * 0.06, 0.06, -0.105), Vector3(0.06, 0.08, 0.05), vazio)
	# braços: ombro -> cotovelo -> mão perto do joelho, com dedos longos
	for lado: float in [-1.0, 1.0]:
		var braco := Node3D.new()
		braco.name = "Braco_Esq" if lado < 0.0 else "Braco_Dir"
		n.add_child(braco)
		var pts: Array[Vector3] = [
			Vector3(lado * 0.32, 1.98, 0.0), Vector3(lado * 0.42, 1.55, -0.08),
			Vector3(lado * 0.46, 1.10, -0.20), Vector3(lado * 0.44, 0.78, -0.30),
		]
		var rad: Array[float] = [0.075, 0.055, 0.045, 0.035]
		_malha(braco, "Membro", tubo(pts, rad, 8), palido)
		var mao: Vector3 = pts[3]
		for d in 5:
			var fp: Array[Vector3] = [mao + Vector3(0, 0, 0), mao + Vector3((d - 2) * 0.018 * lado, -0.14, -0.04 - absf(d - 2) * 0.01), mao + Vector3((d - 2) * 0.03 * lado, -0.30 - (0.05 if d in [1, 2, 3] else 0.0), -0.08)]
			var fr: Array[float] = [0.014, 0.011, 0.006]
			_malha(braco, "Dedo", tubo(fp, fr, 5), palido)
	return n


# ------------------------------------------------------------------ MULA
## Mula-sem-cabeça: corpo de besta com peito e anca, pescoço terminando em toco em brasa, 4 pernas articuladas e cauda em farrapos.
## Olha para -Z. Altura do dorso ~1,5 m. Pernas: pivôs PernaFE/FD/TE/TD (o jogo as balança).
static func mula(corpo_mat: Material) -> Node3D:
	var m := Node3D.new()
	m.name = "Mula"
	var brasa := _emissivo(Color(1.0, 0.35, 0.08), 2.2)
	# tronco: do quadril (+Z) ao peito (-Z)
	var tp: Array[Vector3] = [Vector3(0, 1.28, 0.95), Vector3(0, 1.38, 0.55), Vector3(0, 1.36, 0.0), Vector3(0, 1.38, -0.55), Vector3(0, 1.45, -0.88)]
	var tr: Array[float] = [0.26, 0.37, 0.34, 0.37, 0.30]
	_malha(m, "Corpo", tubo(tp, tr, 14, 0.92), corpo_mat)
	# pescoço grosso subindo à frente e acabando num toco queimado
	var np: Array[Vector3] = [Vector3(0, 1.48, -0.72), Vector3(0, 1.72, -1.02), Vector3(0, 2.02, -1.26), Vector3(0, 2.14, -1.34)]
	var nr: Array[float] = [0.30, 0.22, 0.16, 0.13]
	_malha(m, "Pescoco", tubo(np, nr, 12, 0.85, false, false), corpo_mat)
	_esfera(m, "Toco", Vector3(0, 2.15, -1.35), Vector3(0.28, 0.12, 0.28), brasa)
	# crina em tiras, como se estivesse queimando
	for i in 5:
		var f := float(i) / 4.0
		var cp: Array[Vector3] = [Vector3(0, 1.62 + f * 0.45, -0.95 - f * 0.28), Vector3(0, 1.62 + f * 0.45 + 0.14, -0.95 - f * 0.28 + 0.30), Vector3(0, 1.62 + f * 0.45 + 0.02, -0.95 - f * 0.28 + 0.52)]
		var cr: Array[float] = [0.045, 0.03, 0.006]
		_malha(m, "Crina", tubo(cp, cr, 5), corpo_mat)
	# ancas (volume do quadril)
	_esfera(m, "AncaE", Vector3(-0.2, 1.32, 0.78), Vector3(0.34, 0.5, 0.52), corpo_mat)
	_esfera(m, "AncaD", Vector3(0.2, 1.32, 0.78), Vector3(0.34, 0.5, 0.52), corpo_mat)
	# cauda: tiras longas em farrapos
	for i in 4:
		var o := (i - 1.5) * 0.045
		var cp: Array[Vector3] = [Vector3(o, 1.42, 1.18), Vector3(o * 2.0, 1.20, 1.55), Vector3(o * 3.0, 0.78, 1.80), Vector3(o * 3.5, 0.34 + i * 0.08, 1.88)]
		var cr: Array[float] = [0.05, 0.04, 0.028, 0.008]
		_malha(m, "Cauda", tubo(cp, cr, 5), corpo_mat)
	# pernas: coxa -> articulação -> canela fina -> casco. Pivô no quadril/ombro.
	var pernas := [["PernaFE", -0.20, -0.62, 1.0], ["PernaFD", 0.20, -0.62, 1.0], ["PernaTE", -0.21, 0.80, -1.0], ["PernaTD", 0.21, 0.80, -1.0]]
	for l in pernas:
		var pivo := Node3D.new()
		pivo.name = l[0]
		pivo.position = Vector3(l[1], 1.15, l[2])
		var dir: float = l[3]            # +1 pernas da frente (joelho para frente), -1 traseiras (curva do jarrete)
		var lp: Array[Vector3] = [Vector3(0, 0.0, 0), Vector3(0, -0.40, -0.04 * dir), Vector3(0, -0.62, 0.05 * dir), Vector3(0, -1.0, -0.02 * dir)]
		var lr: Array[float] = [0.12, 0.075, 0.048, 0.036]
		_malha(pivo, "Perna", tubo(lp, lr, 8), corpo_mat)
		_malha(pivo, "Casco", tubo([Vector3(0, -1.0, -0.02 * dir), Vector3(0, -1.12, -0.03 * dir)] as Array[Vector3], [0.05, 0.062] as Array[float], 8), _emissivo(Color(0.03, 0.025, 0.02), 0.0))
		m.add_child(pivo)
	return m
