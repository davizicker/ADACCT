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
	_save(_mula(b), "mula.tscn")
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


## Material com texturas PBR reais (ambientCG, CC0) de assets/textures/ambientcg/<pasta>/.
func _real(mat_name: String, folder: String, tint: Color, scale: float, normal_scale := 1.0, rough_mult := 1.0) -> void:
	var dir := TEX + "ambientcg/" + folder + "/"
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(dir + "Color.jpg") as Texture2D
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(dir + "NormalGL.jpg") as Texture2D
	m.normal_scale = normal_scale
	m.roughness_texture = load(dir + "Roughness.jpg") as Texture2D
	m.roughness = rough_mult
	if ResourceLoader.exists(dir + "AmbientOcclusion.jpg"):
		m.ao_enabled = true
		m.ao_texture = load(dir + "AmbientOcclusion.jpg") as Texture2D
		m.ao_light_affect = 0.6
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
	_real("madeira_natural", "Wood035", Color(1.0, 0.95, 0.9), 0.8)
	_surf("madeira_branca", "madeira", Color(0.92, 0.90, 0.84), 0.6)
	var terreno := ShaderMaterial.new()
	terreno.shader = load("res://assets/shaders/terreno.gdshader")
	var gd := TEX + "ambientcg/Ground108/"
	var gi := TEX + "ambientcg/Ground028/"
	terreno.set_shader_parameter("plano_cor", load(gd + "Color.jpg"))
	terreno.set_shader_parameter("plano_normal", load(gd + "NormalGL.jpg"))
	terreno.set_shader_parameter("plano_rug", load(gd + "Roughness.jpg"))
	terreno.set_shader_parameter("ingreme_cor", load(gi + "Color.jpg"))
	terreno.set_shader_parameter("ingreme_normal", load(gi + "NormalGL.jpg"))
	terreno.set_shader_parameter("ingreme_rug", load(gi + "Roughness.jpg"))
	ResourceSaver.save(terreno, MATS + "terreno.tres")
	_flat("ferro", Color(0.05, 0.05, 0.05), 0.55, 0.6)
	_real("madeira_escura", "Wood028", Color(1, 1, 1), 0.7)
	_flat("vaso", Color(0.55, 0.26, 0.16), 0.9)
	_flat("verde_vaso", Color(0.10, 0.28, 0.09), 1.0)
	_flat("flor_vermelha", Color(0.75, 0.08, 0.08), 0.8)
	_flat("flor_rosa", Color(0.85, 0.35, 0.5), 0.8)
	_flat("flor_amarela", Color(0.9, 0.75, 0.15), 0.8)
	_flat("vela", Color(0.9, 0.85, 0.7), 0.9)
	_flat("chama", Color(1.0, 0.7, 0.3), 0.5, 0.0, 3.5, true)
	_flat("bandeira_a", Color(0.8, 0.15, 0.12), 1.0)
	_flat("bandeira_b", Color(0.95, 0.75, 0.15), 1.0)
	_flat("bandeira_c", Color(0.15, 0.4, 0.75), 1.0)
	_flat("bandeira_d", Color(0.2, 0.55, 0.28), 1.0)
	_flat("pano", Color(0.78, 0.76, 0.7), 1.0)
	_flat("papel", Color(0.93, 0.86, 0.66), 0.9, 0.0, 0.7)
	_flat("vidro_oleo", Color(0.95, 0.55, 0.15), 0.2, 0.0, 1.4)
	_flat("mula_corpo", Color(0.045, 0.035, 0.035), 0.9)
	var vulto := StandardMaterial3D.new()
	vulto.albedo_texture = _tex("silhueta.png")
	vulto.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vulto.albedo_color = Color(0, 0, 0)
	vulto.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	vulto.alpha_scissor_threshold = 0.4
	vulto.cull_mode = BaseMaterial3D.CULL_DISABLED
	ResourceSaver.save(vulto, MATS + "vulto.tres")
	var fogo := StandardMaterial3D.new()
	fogo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fogo.albedo_texture = _tex("ponto_luz.png")
	fogo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fogo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fogo.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fogo.vertex_color_use_as_albedo = true
	fogo.disable_fog = true
	ResourceSaver.save(fogo, MATS + "fogo.tres")
	var agua := ShaderMaterial.new()
	agua.shader = load("res://assets/shaders/agua.gdshader")
	ResourceSaver.save(agua, MATS + "agua.tres")
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
	_real("casca", "Bark014", Color(0.9, 0.88, 0.85), 1.0, 1.3)
	_real("palma_tronco", "Bark014", Color(0.62, 0.6, 0.57), 0.9, 1.0)
	_real("terra_quintal", "Ground108", Color(0.85, 0.9, 0.8), 0.22, 1.1)
	_real("pele_bradador", "Bark014", Color(0.75, 0.72, 0.7), 2.0, 1.5)   # para o modelo do Bradador, se vier sem textura
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


## Mula-sem-cabeça: corpo escuro, quatro pernas que balançam, pescoço cotoco com fogo e luz.
func _mula(b: VilaBuilder) -> Node3D:
	var m := Node3D.new()
	m.name = "Mula"
	m.set_script(load("res://scripts/mula.gd"))
	var mat := b.mat("mula_corpo")
	var body := MeshInstance3D.new()
	body.name = "Corpo"
	var cap := CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.9
	body.mesh = cap
	body.material_override = mat
	body.rotation_degrees.x = 90.0
	body.position = Vector3(0, 1.2, 0)
	m.add_child(body)
	var neck := MeshInstance3D.new()
	neck.name = "Pescoco"
	var nc := CylinderMesh.new()
	nc.top_radius = 0.13
	nc.bottom_radius = 0.2
	nc.height = 0.9
	neck.mesh = nc
	neck.material_override = mat
	neck.rotation_degrees.x = -38.0
	neck.position = Vector3(0, 1.62, -0.95)
	m.add_child(neck)
	var legs := [["PernaFE", -0.2, -0.65], ["PernaFD", 0.2, -0.65], ["PernaTE", -0.2, 0.65], ["PernaTD", 0.2, 0.65]]
	for l in legs:
		var pivot := Node3D.new()
		pivot.name = l[0]
		pivot.position = Vector3(l[1], 0.95, l[2])
		var leg := MeshInstance3D.new()
		leg.name = "Perna"
		var lc := CylinderMesh.new()
		lc.top_radius = 0.07
		lc.bottom_radius = 0.045
		lc.height = 0.95
		leg.mesh = lc
		leg.material_override = mat
		leg.position = Vector3(0, -0.47, 0)
		pivot.add_child(leg)
		m.add_child(pivot)
	var fire := CPUParticles3D.new()
	fire.name = "Fogo"
	fire.position = Vector3(0, 2.02, -1.25)
	fire.amount = 36
	fire.lifetime = 0.75
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.14
	fire.direction = Vector3(0, 1, 0)
	fire.spread = 22.0
	fire.initial_velocity_min = 1.0
	fire.initial_velocity_max = 2.3
	fire.gravity = Vector3(0, 0.6, 0)
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.1
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	q.material = load(MATS + "fogo.tres")
	fire.mesh = q
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.9, 0.5, 0.95), Color(1.0, 0.4, 0.1, 0.8), Color(0.4, 0.05, 0.0, 0.0)])
	fire.color_ramp = grad
	m.add_child(fire)
	var light := OmniLight3D.new()
	light.name = "ChamaLuz"
	light.position = Vector3(0, 2.1, -1.3)
	light.light_color = Color(1.0, 0.45, 0.15)
	light.light_energy = 3.4
	light.omni_range = 16.0
	light.set_script(load("res://scripts/luz_tremula.gd"))
	light.set("forca", 0.3)
	light.set("velocidade", 11.0)
	m.add_child(light)
	return m


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
	for part in [["Vila", "vila.scn"], ["Jogador", "jogador.tscn"], ["Bradador", "bradador.tscn"], ["Mula", "mula.tscn"]]:
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
	var ev := Node.new()
	ev.name = "Eventos"
	ev.set_script(load("res://scripts/event_director.gd"))
	main.add_child(ev)
	ev.owner = main
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
