extends SceneTree
## Conta os nós da vila por tipo (diagnóstico de desempenho). Uso: godot --headless --script res://tools/contar_nos.gd
func _init() -> void:
	var v: Node = (load(OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "res://scenes/vila.scn") as PackedScene).instantiate()
	var cont := {}
	var luzes := 0
	var sombras := 0
	var tris := 0
	var por_pai := {}
	var pilha: Array[Node] = [v]
	while pilha.size() > 0:
		var n: Node = pilha.pop_back()
		cont[n.get_class()] = int(cont.get(n.get_class(), 0)) + 1
		if n is Light3D:
			luzes += 1
			if (n as Light3D).shadow_enabled:
				sombras += 1
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var m := (n as MeshInstance3D).mesh
			var k := 0
			for si in m.get_surface_count():
				var arr := m.surface_get_arrays(si)
				var idx = arr[Mesh.ARRAY_INDEX]
				k += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			tris += k
			var top := n
			while top.get_parent() != v and top.get_parent() != null:
				top = top.get_parent()
			por_pai[top.name] = int(por_pai.get(top.name, 0)) + k
		for c in n.get_children():
			pilha.append(c)
	var ks := cont.keys()
	ks.sort_custom(func(a, b): return cont[a] > cont[b])
	for k in ks.slice(0, 14):
		print("[nos] ", k, " ", cont[k])
	print("[nos] luzes=", luzes, " com sombra=", sombras, " triangulos=", tris)
	var ps := por_pai.keys()
	ps.sort_custom(func(a, b): return por_pai[a] > por_pai[b])
	for k in ps.slice(0, 12):
		print("[tris] ", k, " ", por_pai[k])
	quit()
