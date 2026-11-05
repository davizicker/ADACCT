extends SceneTree
## Procura móveis/objetos flutuando, enterrados ou se atravessando (rua e interiores):
## godot --headless --path . --script res://tools/auditoria_moveis.gd
## 1) FLUTUANDO: nada sólido a menos de 4 cm abaixo da base do objeto;  2) SEM APOIO: nada sólido até 60 cm abaixo;
## 3) ATRAVESSANDO: a caixa do objeto (encolhida) invade uma parede ou outro móvel com colisão.

func _init() -> void:
	var v: Node3D = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(v)
	for i in 4:
		await physics_frame
	var space := v.get_world_3d().direct_space_state
	var flut := []
	var sem_apoio := []
	var atrav := []
	var total := 0
	var coletaveis := 0
	for n in v.find_children("*", "Node3D", true, false):
		var nd := n as Node3D
		var eh_prop := nd.has_meta("bb")
		var eh_col := nd is Coletavel
		if not eh_prop and not eh_col:
			continue
		var pos := nd.global_position
		var interior := pos.x > 1500.0
		total += 1
		if eh_col:
			coletaveis += 1
		# base do objeto: o ponto de origem (props têm os pés em y = 0; coletáveis têm a base ~5 cm abaixo)
		var base := pos + Vector3(0, -0.05 if eh_col else 0.0, 0)
		var q := PhysicsRayQueryParameters3D.create(base + Vector3(0, 0.06, 0), base + Vector3(0, -0.6, 0))
		q.collide_with_areas = false
		var h := space.intersect_ray(q)
		var nome := str(nd.get_path()).replace("/root/Vila/", "")
		if h.is_empty():
			if not (nd.name.begins_with("arvore") or nd.name.begins_with("palm")):
				sem_apoio.append("%s @%s" % [nome, snapped(pos, Vector3(0.1, 0.1, 0.1))])
		else:
			var gap: float = base.y - float(h["position"].y)
			if gap > 0.04:
				flut.append("%s flutua %.0f cm @%s sobre %s" % [nome, gap * 100.0, snapped(pos, Vector3(0.1, 0.1, 0.1)), str((h["collider"] as Node).get_parent().name)])
		# atravessando: só móveis com bb (não coletáveis pequenos)
		if eh_prop and interior:
			var bb: AABB = nd.get_meta("bb")
			if bb.size.x < 0.25 or bb.size.y < 0.25:
				continue
			var sh := BoxShape3D.new()
			sh.size = Vector3(bb.size.x * 0.8, maxf(bb.size.y * 0.7, 0.1), bb.size.z * 0.8)
			var qs := PhysicsShapeQueryParameters3D.new()
			qs.shape = sh
			qs.transform = Transform3D(nd.global_transform.basis, nd.global_transform * (bb.get_center() + Vector3(0, 0.12, 0)))
			qs.collide_with_areas = false
			var hits := space.intersect_shape(qs, 8)
			var nomes := []
			for hh in hits:
				var c := hh["collider"] as Node
				var cn: String = str(c.get_parent().name)
				if cn == "Piso" or cn == "Teto" or c.get_parent() == nd or cn.begins_with(str(nd.name).split("_")[0]):
					continue
				nomes.append(cn)
			if not nomes.is_empty():
				atrav.append("%s invade %s" % [nome, ", ".join(nomes)])
	print("[moveis] objetos=%d (coletáveis=%d) | flutuando=%d | sem apoio=%d | atravessando=%d" % [total, coletaveis, flut.size(), sem_apoio.size(), atrav.size()])
	for x in flut.slice(0, 60):
		print("[moveis] FLUTUA  ", x)
	for x in sem_apoio.filter(func(t: String) -> bool: return t.contains("Oleo") or t.contains("Interiores")).slice(0, 60):
		print("[moveis] SEM APOIO  ", x)
	for x in atrav.slice(0, 40):
		print("[moveis] ATRAVESSA  ", x)
	quit()
