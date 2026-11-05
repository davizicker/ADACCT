extends SceneTree
## Procura problemas de textura e peso: godot --headless --path . --script res://tools/auditoria_texturas.gd
## 1) texturas sem mipmap (tremem de longe), 2) normal map sem a opção de normal, 3) texturas grandes sem compressão,
## 4) materiais que apontam para arquivo que não existe, 5) superfícies da vila sem material (ficariam brancas).

func _varre(dir: String, ext: String, saida: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			saida.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_varre(dir.path_join(d), ext, saida)


func _init() -> void:
	var imports: Array = []
	_varre("res://assets", ".import", imports)
	var sem_mip := []
	var normal_errado := []
	var grande_sem_compressao := []
	var total_px := 0
	var n_tex := 0
	for imp: String in imports:
		var cf := ConfigFile.new()
		if cf.load(imp) != OK:
			continue
		if str(cf.get_value("remap", "importer", "")) != "texture":
			continue
		var src: String = imp.trim_suffix(".import")
		var mip: bool = bool(cf.get_value("params", "mipmaps/generate", false))
		var modo: int = int(cf.get_value("params", "compress/mode", 0))
		var is_normal: bool = src.to_lower().contains("normal") or src.to_lower().contains("nor_gl") or src.to_lower().contains("normalgl")
		var nm: int = int(cf.get_value("params", "compress/normal_map", 0))
		var tex := load(src) as Texture2D
		if tex == null:
			continue
		var tam := tex.get_size()
		n_tex += 1
		total_px += int(tam.x * tam.y)
		if not mip and tam.x >= 128 and not src.contains("/ui/") and not src.to_lower().contains("ponto_luz") and not src.contains("silhueta"):
			sem_mip.append("%s (%dx%d)" % [src.get_file(), tam.x, tam.y])
		if is_normal and nm == 0:
			normal_errado.append("%s (compress/normal_map=%d)" % [src.get_file(), nm])
		if modo == 0 and tam.x * tam.y >= 1024 * 1024 and not src.contains("/ui/"):
			grande_sem_compressao.append("%s (%dx%d, lossless)" % [src.get_file(), tam.x, tam.y])
	print("[tex] texturas=%d | megapixels=%.1f" % [n_tex, total_px / 1.0e6])
	print("[tex] SEM MIPMAP (tremem de longe): %d" % sem_mip.size())
	for x in sem_mip.slice(0, 25):
		print("[tex]   ", x)
	print("[tex] NORMAL MAP sem a opção de normal: %d" % normal_errado.size())
	for x in normal_errado.slice(0, 15):
		print("[tex]   ", x)
	print("[tex] GRANDES (>=1MP) em lossless: %d" % grande_sem_compressao.size())
	for x in grande_sem_compressao.slice(0, 15):
		print("[tex]   ", x)
	# materiais com dependência faltando
	var tres: Array = []
	_varre("res://assets/materials", ".tres", tres)
	var faltando := 0
	for t: String in tres:
		var r := load(t)
		if r == null:
			print("[tex] MATERIAL NÃO CARREGA: ", t)
			faltando += 1
	print("[tex] materiais=%d, que não carregam=%d" % [tres.size(), faltando])
	# vila: superfícies sem material
	var v: Node3D = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(v)
	await physics_frame
	var sem_mat := 0
	var tris := 0
	var superficies := 0
	var exemplos: Array = []
	for n in v.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.get_path().get_concatenated_names().contains("Serra"):
			continue
		for i in mi.mesh.get_surface_count():
			superficies += 1
			var m := mi.get_active_material(i)
			if m == null:
				sem_mat += 1
				if exemplos.size() < 8:
					exemplos.append(str(mi.get_path()).replace("/root/", ""))
	print("[tex] superfícies=%d, SEM material (branco): %d" % [superficies, sem_mat])
	for x in exemplos:
		print("[tex]   ", x)
	quit()
