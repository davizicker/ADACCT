class_name Quadras
extends RefCounted
## Divide uma lista de instâncias em MultiMesh por QUADRAS de 48 m. Necessário porque o alcance de visibilidade (visibility_range)
## usa o centro da caixa do nó: um MultiMesh gigante que cobre a vila inteira teria o centro no meio da rua e sumiria quando
## o jogador estivesse longe dele. Com quadras, cada pedaço aparece só perto (e some longe, como queremos).

const LADO := 48.0


## xfs: Array[Transform3D]; custom: Array[Color] opcional (dados por instância, MultiMesh.use_custom_data).
static func dividir(nome: String, mesh: Mesh, xfs: Array, fim: float, sombra := false, custom := [], cores := []) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = nome
	var celulas := {}
	for i in xfs.size():
		var o: Vector3 = (xfs[i] as Transform3D).origin
		var k := Vector2i(floori(o.x / LADO), floori(o.z / LADO))
		if not celulas.has(k):
			celulas[k] = []
		(celulas[k] as Array).append(i)
	for k: Vector2i in celulas:
		var idx: Array = celulas[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = custom.size() > 0
		mm.use_colors = cores.size() > 0
		mm.mesh = mesh
		mm.instance_count = idx.size()
		for j in idx.size():
			mm.set_instance_transform(j, xfs[idx[j]])
			if custom.size() > 0:
				mm.set_instance_custom_data(j, custom[idx[j]])
			if cores.size() > 0:
				mm.set_instance_color(j, cores[idx[j]])
		var mi := MultiMeshInstance3D.new()
		mi.name = "%s_%d_%d" % [nome, k.x, k.y]
		mi.multimesh = mm
		mi.visibility_range_end = fim
		mi.visibility_range_end_margin = minf(8.0, fim * 0.15)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
	return raiz
