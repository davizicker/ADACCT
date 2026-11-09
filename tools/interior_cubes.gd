extends SceneTree
## Fotografa de verdade o interior de cada sala (6 direções, a partir do centro) e salva tudo num Texture2DArray:
## assets/texturas/salas_interior.res (84 camadas = 14 salas x 6 faces) + salas_interior_dims.json (largura, altura, profundidade).
## O shader das janelas (assets/shaders/janela_interior.gdshader) usa isso para mostrar a sala real atrás do vidro.
## Rodar DEPOIS do bake: xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/interior_cubes.gd

const TAM := 256
# direção de olhar e "para cima" de cada face (o shader usa exatamente a mesma tabela)
const OLHAR: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
const CIMA: Array[Vector3] = [Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(0, 1, 0)]


func _init() -> void:
	var v: Node = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(v)
	for i in 4:
		await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(TAM, TAM)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.near = 0.05
	cam.far = 60.0
	vp.add_child(cam)
	var imgs: Array[Image] = []
	var dims := []
	for g in v.get_node("Interiores").get_children():
		var dim: Vector3 = g.get_meta("dim", Vector3(7, 3, 6))
		dims.append([dim.x, dim.y, dim.z])
		var centro: Vector3 = (g as Node3D).global_position + Vector3(dim.x * 0.5, dim.y * 0.5, dim.z * 0.5)
		for f in 6:
			cam.global_transform = Transform3D(Basis.looking_at(OLHAR[f], CIMA[f]), centro)
			for k in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var im := vp.get_texture().get_image()
			im.convert(Image.FORMAT_RGB8)
			im.generate_mipmaps()
			imgs.append(im)
		print("[salas] ", g.name, " ", dim)
	var arr := Texture2DArray.new()
	var err := arr.create_from_images(imgs)
	print("[salas] camadas=", imgs.size(), " erro=", err)
	DirAccess.make_dir_recursive_absolute("res://assets/texturas")
	ResourceSaver.save(arr, "res://assets/texturas/salas_interior.res")
	var f := FileAccess.open("res://assets/texturas/salas_interior_dims.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(dims))
	f.close()
	print("[salas] pronto")
	quit()
