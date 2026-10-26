extends SceneTree
## Recria do zero: materiais, plantas, a vila, o jogador, o Bradador e a cena principal.
## ATENÇÃO: sobrescreve scenes/*, assets/materials/*.tres e assets/meshes/*.res.
## Depois que você começar a editar a vila no editor, NÃO rode isto de novo (perderia suas edições).
## Uso (nesta ordem, na raiz do projeto):
##   godot --headless --path . --script res://tools/gen_textures.gd
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/bake.gd
##   godot --headless --path . --import

const TEX := "res://assets/textures/"
const MATS := "res://assets/materials/"
const SCENES := "res://scenes/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/meshes")
	DirAccess.make_dir_recursive_absolute("res://scenes/veg")
	_materials()
	var veg := Veg.build_all()
	print("[bake] plantas: ", veg.size())
	var b := VilaBuilder.new()
	var vila := b.build_vila(veg)
	_save(vila, "vila.scn")
	_save(_player(), "jogador.tscn")
	_save(_bradador(b), "bradador.tscn")
	var casa := b.make_casa(9.0, 2, "reboco_branco", "madeira_azul", 10.0, true, 0.3, false)
	casa.name = "Casa"
	_save(casa, "casa.tscn")
	_save(b.make_poste(), "poste.tscn")
	_main()
	print("[bake] pronto")
	quit()


# ------------------------------------------------------------------ materiais

func _tex(n: String) -> Texture2D:
	return load(TEX + n) as Texture2D


func _surf(mat_name: String, tex: String, tint: Color, scale: float, rough := 0.95, normal := 1.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(tex + "_albedo.png")
	m.normal_enabled = true
	m.normal_texture = _tex(tex + "_normal.png")
	m.normal_scale = normal
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ResourceSaver.save(m, MATS + mat_name + ".tres")


func _flat(mat_name: String, color: Color, rough := 0.9, metal := 0.0, emissive := 0.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ResourceSaver.save(m, MATS + mat_name + ".tres")
	return m


## Folhagem com recorte (alpha scissor). two_sided = cartão único visto dos dois lados.
func _leafy(mat_name: String, tex: String, tint := Color(1, 1, 1), two_sided := false) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(tex + ".png")
	m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED if two_sided else BaseMaterial3D.CULL_BACK
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ResourceSaver.save(m, MATS + mat_name + ".tres")


func _materials() -> void:
	_surf("pedra_chao", "pedra", Color(0.88, 0.85, 0.80), 0.3, 0.58, 1.4)   # rugosidade baixa: brilho de pedra molhada
	_surf("muro", "muro", Color(0.95, 0.93, 0.90), 0.35, 0.95, 1.3)
	_surf("cantaria", "cantaria", Color(1.0, 1.0, 0.97), 0.5, 0.8, 1.0)
	_surf("reboco_branco", "reboco_velho", Color(0.97, 0.95, 0.90), 0.22)
	_surf("reboco_branco_novo", "reboco", Color(0.98, 0.97, 0.93), 0.22)
	_surf("reboco_ocre", "reboco_velho", Color(0.90, 0.76, 0.50), 0.22)
	_surf("reboco_amarelo", "reboco", Color(0.95, 0.86, 0.55), 0.22)
	_surf("reboco_azul", "reboco_velho", Color(0.58, 0.70, 0.82), 0.22)
	_surf("reboco_salmao", "reboco", Color(0.86, 0.64, 0.55), 0.22)
	_surf("reboco_verde", "reboco_velho", Color(0.66, 0.78, 0.64), 0.22)
	_surf("reboco_creme", "reboco_velho", Color(0.96, 0.88, 0.68), 0.22)
	_surf("telha", "telha", Color(1, 1, 1), 0.3, 0.8, 1.2)
	_surf("madeira_azul", "madeira", Color(0.20, 0.38, 0.62), 0.6)
	_surf("madeira_vermelha", "madeira", Color(0.62, 0.14, 0.10), 0.6)
	_surf("madeira_verde", "madeira", Color(0.18, 0.40, 0.28), 0.6)
	_surf("madeira_ocre", "madeira", Color(0.80, 0.58, 0.18), 0.6)
	_surf("madeira_natural", "madeira", Color(0.50, 0.34, 0.20), 0.6)
	_surf("madeira_branca", "madeira", Color(0.92, 0.90, 0.84), 0.6)
	var terreno := StandardMaterial3D.new()
	terreno.albedo_texture = _tex("terra_albedo.png")
	terreno.normal_enabled = true
	terreno.normal_texture = _tex("terra_normal.png")
	terreno.vertex_color_use_as_albedo = true
	terreno.uv1_triplanar = true
	terreno.uv1_world_triplanar = true
	terreno.uv1_scale = Vector3.ONE * 0.12
	terreno.roughness = 1.0
	terreno.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ResourceSaver.save(terreno, MATS + "terreno.tres")
	_flat("ferro", Color(0.05, 0.05, 0.05), 0.55, 0.6)
	_flat("janela_escura", Color(0.015, 0.02, 0.03), 0.15)
	_flat("janela_acesa", Color(1.0, 0.62, 0.25), 0.5, 0.0, 0.9)
	_flat("vidro_lampiao", Color(1.0, 0.75, 0.35), 0.5, 0.0, 2.0)
	_flat("porta_igreja", Color(1.0, 0.72, 0.38), 0.5, 0.0, 0.7)
	var bulbo := _flat("bulbo", Color(1.0, 0.82, 0.5), 0.5, 0.0, 3.0, true)
	bulbo.disable_fog = false
	ResourceSaver.save(bulbo, MATS + "bulbo.tres")
	var luz := StandardMaterial3D.new()
	luz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	luz.albedo_color = Color(1.0, 0.82, 0.5)
	luz.albedo_texture = _tex("ponto_luz.png")
	luz.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	luz.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	luz.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	luz.disable_fog = true
	ResourceSaver.save(luz, MATS + "luz_distante.tres")
	var sky := ShaderMaterial.new()
	sky.shader = load("res://assets/shaders/ceu.gdshader")
	ResourceSaver.save(sky, MATS + "ceu.tres")
	var serra := _flat("serra", Color(0.022, 0.028, 0.048), 1.0, 0.0, 0.0, true)
	serra.disable_fog = true
	ResourceSaver.save(serra, MATS + "serra.tres")
	_flat("casca", Color(0.20, 0.14, 0.10), 1.0)
	_flat("palma_tronco", Color(0.45, 0.42, 0.38), 0.9)
	_flat("bradador_preto", Color(0, 0, 0), 1.0, 0.0, 0.0, true)
	_flat("bradador_palido", Color(0.78, 0.78, 0.72), 1.0, 0.0, 0.0, true)
	_leafy("folhagem", "folhagem", Color(0.85, 0.95, 0.8))
	_leafy("arbusto", "arbusto")
	_leafy("samambaia", "samambaia")
	_leafy("capim", "capim")
	_leafy("bananeira", "bananeira")
	_leafy("hera", "hera", Color(0.9, 1.0, 0.85), true)


# ------------------------------------------------------------------ atores

func _player() -> CharacterBody3D:
	var p := CharacterBody3D.new()
	p.name = "Jogador"
	p.set_script(load("res://scripts/player.gd"))
	var shape := CollisionShape3D.new()
	shape.name = "Colisao"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	p.add_child(shape)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(0, 1.6, 0)
	cam.fov = 75.0
	cam.far = 1500.0
	p.add_child(cam)
	var lantern := OmniLight3D.new()
	lantern.name = "Lampiao"
	lantern.position = Vector3(0.25, -0.35, -0.5)
	lantern.light_color = Color(1.0, 0.72, 0.38)
	lantern.light_energy = 1.7
	lantern.omni_range = 9.0
	lantern.shadow_enabled = false   # ligue no editor (Shadow > Enabled) se seu PC aguentar
	cam.add_child(lantern)
	return p


func _bradador(b: VilaBuilder) -> Node3D:
	var n := Node3D.new()
	n.name = "Bradador"
	var manto := MeshInstance3D.new()
	manto.name = "Manto"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.14
	cone.bottom_radius = 0.55
	cone.height = 2.2
	cone.radial_segments = 10
	manto.mesh = cone
	manto.material_override = b.mat("bradador_preto")
	manto.position.y = 1.15
	n.add_child(manto)
	var cabeca := MeshInstance3D.new()
	cabeca.name = "Cabeca"
	var sph := SphereMesh.new()
	sph.radius = 0.15
	sph.height = 0.46
	cabeca.mesh = sph
	cabeca.material_override = b.mat("bradador_palido")
	cabeca.position.y = 2.45
	n.add_child(cabeca)
	for side: float in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		arm.name = "Braco_%s" % ("Esq" if side < 0.0 else "Dir")
		var ac := CylinderMesh.new()
		ac.top_radius = 0.05
		ac.bottom_radius = 0.03
		ac.height = 1.7
		arm.mesh = ac
		arm.material_override = b.mat("bradador_preto")
		arm.position = Vector3(side * 0.34, 1.45, 0.05)
		arm.rotation_degrees = Vector3(0, 0, side * 6.0)
		n.add_child(arm)
	return n


# ------------------------------------------------------------------ cenas

func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		if c.scene_file_path == "":
			_own(c, owner_node)


func _save(root: Node, file_name: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("falha ao empacotar " + file_name)
		return
	ResourceSaver.save(ps, SCENES + file_name)
	print("[bake] ", file_name)


func _main() -> void:
	var main := Node3D.new()
	main.name = "Main"
	main.set_script(load("res://scripts/main.gd"))
	for part in [["Vila", "vila.scn"], ["Jogador", "jogador.tscn"], ["Bradador", "bradador.tscn"]]:
		var inst := (load(SCENES + part[1]) as PackedScene).instantiate()
		inst.name = part[0]
		main.add_child(inst)
		inst.owner = main
	var start := Route.pos(2.0)
	(main.get_node("Jogador") as Node3D).position = start + Vector3(0, 0.25, 0)
	(main.get_node("Bradador") as Node3D).visible = false
	var gritos := Node.new()
	gritos.name = "Gritos"
	gritos.set_script(load("res://scripts/scream_system.gd"))
	main.add_child(gritos)
	gritos.owner = main
	var aud := Node.new()
	aud.name = "Audio"
	aud.set_script(load("res://scripts/audio_director.gd"))
	main.add_child(aud)
	aud.owner = main
	var ui := CanvasLayer.new()
	ui.name = "Interface"
	ui.set_script(load("res://scripts/hud.gd"))
	main.add_child(ui)
	ui.owner = main
	var ps := PackedScene.new()
	ps.pack(main)
	ResourceSaver.save(ps, SCENES + "main.tscn")
	print("[bake] main.tscn")
