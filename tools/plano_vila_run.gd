extends SceneTree
## Gera o plano da vila (docs/plano_vila.json) e imprime a prova de cadastro: godot --headless --path . --script res://tools/plano_vila_run.gd
func _init() -> void:
	var vb := VilaBuilder.new()
	vb._setup({})
	var it := Interiores.new()
	var dims := {}
	for sid in Interiores.SALAS_RUA:
		var sl := it.sala_rua(vb, sid)
		var d: Vector3 = sl.get_meta("dim")
		dims[sid] = Vector2(d.x + 0.87, d.z + 0.87)
		sl.free()
	var pl := PlanoVila.new()
	var res := pl.montar(dims)
	print("[plano] itens no cadastro: ", (res["cadastro"] as Array).size(), " | sobreposições: ", res["sobreposicoes"])
	for a in res["avisos"]:
		print("[plano] aviso: ", a)
	var lista := []
	for c in res["cadastro"]:
		var r: Rect2 = c["r"]
		lista.append({"id": c["id"], "tipo": c["tipo"], "x": r.position.x, "z": r.position.y, "w": r.size.x, "h": r.size.y})
	var eixo := pl.eixo(1.0)
	var pts := []
	for p in eixo:
		pts.append([p.x, p.y])
	var f := FileAccess.open("res://docs/plano_vila.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"cadastro": lista, "eixo": pts, "sobreposicoes": res["sobreposicoes"]}))
	f.close()
	quit()
