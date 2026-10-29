extends SceneTree
## Varre a rua inteira com uma cápsula do tamanho do jogador, em várias faixas laterais, e lista o que bloqueia o caminho.
## godot --headless --path . --script res://tools/auditoria_caminho.gd
func _init() -> void:
	var v: Node3D = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(v)
	for i in 4:
		await physics_frame
	var sp := v.get_world_3d().direct_space_state
	var achados := {}
	var s := 1.0
	while s < Route.length() - 1.0:
		var w := Route.width(s)
		for lat: float in [-1.3, -0.65, 0.0, 0.65, 1.3]:      # corredor central de 2,6 m: tem de estar sempre livre
			if absf(lat) > w * 0.5:
				continue
			var p := Route.pos(s) + Route.right(s) * lat
			var sh := CapsuleShape3D.new()
			sh.radius = 0.35
			sh.height = 1.7
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = sh
			q.transform = Transform3D(Basis(), Vector3(p.x, Route.height(s) + 0.25 + 0.85, p.z))
			for h in sp.intersect_shape(q, 8):
				var nome := str((h["collider"] as Node).get_path()).replace("/root/Vila/", "")
				if nome.begins_with("Rua/") or nome.contains("Terreno"):
					continue
				if not achados.has(nome):
					achados[nome] = [s, lat]
		s += 0.4
	for k in achados:
		print("[caminho] bloqueia: ", k, "  primeiro em s=", snappedf(achados[k][0], 0.1), " lateral=", snappedf(achados[k][1], 0.1))
	print("[caminho] obstaculos distintos na faixa de passagem: ", achados.size())
	quit()
