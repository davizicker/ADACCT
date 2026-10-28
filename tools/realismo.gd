class_name Realismo
extends RefCounted
## Elementos de realismo de 1961: postes de madeira com fios e transformador, cogumelos, galhos caídos (modelo real do tronco morto)
## e fumaça de chaminé. (Vaga-lumes e morcegos são scripts em scripts/vagalumes.gd e scripts/morcegos.gd.)

const SW_H := 0.12
var b: VilaBuilder


func construir(builder: VilaBuilder) -> Node3D:
	b = builder
	var root := Node3D.new()
	root.name = "Realismo"
	root.add_child(_postes_e_fios())
	root.add_child(_cogumelos())
	root.add_child(_galhos())
	return root


func _fora(p: Vector3, margem: float) -> bool:
	return Route.dist_to_center(p) >= Route.width(Route.nearest_s(p)) * 0.5 + margem and not b._na_passagem(p.x, p.z, 3.0)


# ------------------------------------------------------------------ postes de energia (1961) e fios

func _postes_e_fios() -> Node3D:
	var root := Node3D.new()
	root.name = "PostesEFios"
	var mb := b._batch()
	var topos: Array[Vector3] = []
	var s := 16.0
	var i := 0
	while s < Route.S_END + 40.0:
		var sigma := 1.0 if i % 2 == 0 else -1.0
		var w := Route.width(s)
		var ponto := Route.pos(s) + Route.right(s) * sigma * (w * 0.5 + 0.35) + Vector3(0, SW_H, 0)
		var ok := b._livre(ponto, 0.7) and not b._na_passagem(ponto.x, ponto.z, 2.5) and w > 3.0
		# fora das bocas de becos e de portas
		for al in VilaBuilder.ALLEYS:
			if absf(float(al[0]) - s) < 5.0 and float(al[1]) == sigma:
				ok = false
		if not ok:
			s += 3.0
			continue
		b._reservar(ponto, 0.7)
		var h := 7.4
		var t := Route.tangent(s)
		var yaw := atan2(-t.z, t.x)
		mb.cylinder("madeira_escura", 0.18, 0.11, h, ponto + Vector3(0, h * 0.5, 0), Vector3.ZERO, 8)
		# cruzeta e isoladores de porcelana
		mb.box("madeira_escura", Vector3(0.1, 0.12, 1.5), ponto + Vector3(0, h - 0.35, 0), Vector3(0, yaw, 0))
		var lat := Route.right(s)
		for ox: float in [-0.65, 0.0, 0.65]:
			var ip := ponto + Vector3(0, h - 0.18, 0) + lat * ox
			mb.cylinder("cantaria", 0.035, 0.05, 0.14, ip, Vector3.ZERO, 6)
			topos.append(ip + Vector3(0, 0.08, 0))
		# transformador a cada ~5 postes
		if i % 5 == 2:
			mb.cylinder("ferro", 0.24, 0.24, 0.7, ponto + Vector3(0, h - 1.2, 0) + lat * 0.45, Vector3.ZERO, 10)
			mb.box("ferro", Vector3(0.1, 0.1, 0.1), ponto + Vector3(0, h - 0.8, 0) + lat * 0.45)
		var col := b._prop_collision_node(ponto, 0.34, 2.2)
		root.add_child(col)
		i += 1
		s += b._rng.randf_range(34.0, 42.0)
	# fios: 3 condutores entre postes consecutivos, com catenária
	var n := topos.size() / 3
	for k in range(n - 1):
		for c in 3:
			var a := topos[k * 3 + c]
			var d := topos[(k + 1) * 3 + c]
			var prev := a
			var seg_n := 14
			for q in range(1, seg_n + 1):
				var tt := float(q) / seg_n
				var pt := a.lerp(d, tt)
				pt.y -= sin(tt * PI) * 0.55 * (a.distance_to(d) / 38.0)
				var sg := pt - prev
				mb.box("ferro", Vector3(sg.length() + 0.02, 0.014, 0.014), (prev + pt) * 0.5, Vector3(0, atan2(-sg.z, sg.x), atan2(sg.y, Vector2(sg.x, sg.z).length())))
				prev = pt
	b._mesh_node(root, "Malha", mb.commit())
	return root


# ------------------------------------------------------------------ cogumelos

func _malha_cogumelo() -> Mesh:
	var mb := b._batch()
	mb.cylinder("pano_cru", 0.012, 0.016, 0.07, Vector3(0, 0.035, 0), Vector3.ZERO, 6)
	mb.sphere("madeira_ocre", 0.045, Vector3(0, 0.075, 0), 8, 4)
	mb.cylinder("pano_cru", 0.008, 0.01, 0.045, Vector3(0.05, 0.022, 0.02), Vector3.ZERO, 5)
	mb.sphere("madeira_ocre", 0.028, Vector3(0.05, 0.05, 0.02), 7, 3)
	return mb.commit()


func _cogumelos() -> Node3D:
	var root := Node3D.new()
	root.name = "Cogumelos"
	var mesh := _malha_cogumelo()
	var xf: Array[Transform3D] = []
	var tries := 0
	while xf.size() < 700 and tries < 6000:
		tries += 1
		var s := b._rng.randf_range(4.0, Route.length() - 10.0)
		var sig := -1.0 if b._rng.randf() < 0.5 else 1.0
		var w := Route.width(s)
		var p := Vector3.ZERO
		if b._rng.randf() < 0.45:       # pé das paredes
			var q := Route.pos(s) + Route.right(s) * sig * (w * 0.5 + 0.7 - b._rng.randf_range(0.05, 0.3))
			p = Vector3(q.x, Route.height(s) + SW_H - 0.02, q.z)
			if not b._livre(p, 0.25):
				continue
		else:                           # encostas e quintais, perto de árvores
			var d := b._rng.randf_range(w * 0.5 + 12.0, 55.0)
			var q := Route.pos(s) + Route.right(s) * sig * d
			p = Vector3(q.x, b.terrain_h(q.x, q.z) - 0.02, q.z)
			if not _fora(p, 10.0):
				continue
		var sc := b._rng.randf_range(0.8, 1.7)
		for k in b._rng.randi_range(1, 3):       # tufinhos de 1 a 3
			var off := Vector3(b._rng.randf_range(-0.1, 0.1), 0, b._rng.randf_range(-0.1, 0.1))
			xf.append(Transform3D(Basis(Vector3.UP, b._rng.randf() * TAU).scaled(Vector3.ONE * sc * b._rng.randf_range(0.7, 1.2)), p + off))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Cogumelos"
	mi.multimesh = mm
	mi.visibility_range_end = 40.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root


# ------------------------------------------------------------------ galhos caídos (o tronco morto do Poly Haven, em escala pequena)

func _galhos() -> Node3D:
	var root := Node3D.new()
	root.name = "GalhosCaidos"
	var mesh := PropKit.kit_mesh("plantas_lod", "tronco_L1")
	var bb := mesh.get_aabb()
	var c := bb.get_center()
	var xf: Array[Transform3D] = []
	var tries := 0
	while xf.size() < 220 and tries < 3000:
		tries += 1
		var s := b._rng.randf_range(4.0, Route.length() - 10.0)
		var sig := -1.0 if b._rng.randf() < 0.5 else 1.0
		var w := Route.width(s)
		var d := b._rng.randf_range(w * 0.5 + 10.0, 50.0)
		var q := Route.pos(s) + Route.right(s) * sig * d
		var p := Vector3(q.x, b.terrain_h(q.x, q.z) + 0.02, q.z)
		if not _fora(p, 9.0):
			continue
		var k := b._rng.randf_range(0.12, 0.34)
		var bas := Basis.from_euler(Vector3(b._rng.randf_range(-0.12, 0.12), b._rng.randf() * TAU, b._rng.randf_range(-0.12, 0.12))).scaled(Vector3.ONE * k)
		xf.append(Transform3D(bas, p) * Transform3D(Basis(), Vector3(-c.x, -bb.position.y, -c.z)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Galhos"
	mi.multimesh = mm
	mi.visibility_range_end = 70.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root


# ------------------------------------------------------------------ fumaça de chaminé

static func fumaca(pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Fumaca"
	p.position = pos
	p.amount = 12
	p.lifetime = 7.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 14, 12))
	p.visibility_range_end = 70.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.25, 1, 0.1)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.12, 0.08, 0.0)       # sobe e é levada pelo vento
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.35))
	curva.add_point(Vector2(1, 2.4))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(0.55, 0.55, 0.58, 0.0))
	grad.add_point(0.15, Color(0.55, 0.55, 0.58, 0.32))
	grad.set_color(1, Color(0.4, 0.4, 0.45, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var tex := GradientTexture2D.new()
	var g2 := Gradient.new()
	g2.set_color(0, Color(1, 1, 1, 1))
	g2.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g2
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	m.albedo_texture = tex
	q.material = m
	p.draw_pass_1 = q
	return p
