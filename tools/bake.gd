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
	_materials()
	# camadas de musgo/limo em manchas por cima de telhados, muros de pedra e cantaria
	_sobrepor(MATS + "telha_uv.tres", Color(0.15, 0.25, 0.08), 0.30, 0.5, 0.45, 0.75)
	_sobrepor(MATS + "muro.tres", Color(0.14, 0.26, 0.08), 0.36, 0.42, 0.75, 0.8)
	_sobrepor(MATS + "cantaria.tres", Color(0.42, 0.46, 0.28), 0.22, 0.45, 0.6, 0.5)
	var b := VilaBuilder.new()
	var vila := b.build_vila({})
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
## Material do Poly Haven (CC0) a partir de assets/textures/polyhaven/<pasta>/<pasta>_{diff,nor_gl,rough}_1k.jpg.
func _poly(mat_name: String, folder: String, tint: Color, scale: float, normal_scale := 1.0, rough_mult := 1.0) -> void:
	var dir := TEX + "polyhaven/" + folder + "/" + folder
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(dir + "_diff_1k.jpg") as Texture2D
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(dir + "_nor_gl_1k.jpg") as Texture2D
	m.normal_scale = normal_scale
	m.roughness_texture = load(dir + "_rough_1k.jpg") as Texture2D
	m.roughness = rough_mult
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ResourceSaver.save(m, MATS + mat_name + ".tres")


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
	if ResourceLoader.exists(dir + "Metalness.jpg"):
		m.metallic = 1.0
		m.metallic_texture = load(dir + "Metalness.jpg") as Texture2D
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ResourceSaver.save(m, MATS + mat_name + ".tres")


## Superfície mista (shader superficie_mista): textura A + textura B em manchas, triplanar no mundo.
func _mista(mat_name: String, a: String, b: String, tint: Color, escala: float, mistura := 0.45, sujeira := 0.3, rough := 0.93, normal := 1.0) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/superficie_mista.gdshader")
	m.set_shader_parameter("albedo_a", _tex(a + "_albedo.png"))
	m.set_shader_parameter("normal_a", _tex(a + "_normal.png"))
	m.set_shader_parameter("albedo_b", _tex(b + "_albedo.png"))
	m.set_shader_parameter("normal_b", _tex(b + "_normal.png"))
	m.set_shader_parameter("ruido", _tex("ruido_mistura.png"))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("escala", escala)
	m.set_shader_parameter("mistura", mistura)
	m.set_shader_parameter("sujeira", sujeira)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("normal_forca", normal)
	ResourceSaver.save(m, MATS + mat_name + ".tres")


## Camada de musgo/limo/sujeira por cima de um material (next_pass).
func _sobrepor(mat_path: String, cor: Color, cobertura: float, escala: float, so_topo: float, opacidade: float) -> void:
	var base := load(mat_path) as Material
	var o := ShaderMaterial.new()
	o.shader = load("res://assets/shaders/sobreposicao.gdshader")
	o.set_shader_parameter("ruido", _tex("ruido_mistura.png"))
	o.set_shader_parameter("cor", cor)
	o.set_shader_parameter("cobertura", cobertura)
	o.set_shader_parameter("escala", escala)
	o.set_shader_parameter("so_topo", so_topo)
	o.set_shader_parameter("opacidade", opacidade)
	base.next_pass = o
	ResourceSaver.save(base, mat_path)


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
	var pc := load(MATS + "pedra_chao.tres") as StandardMaterial3D
	pc.vertex_color_use_as_albedo = true      # a rua tem cor por vértice (sujeira, musgo, umidade)
	pc.roughness_texture = _tex("pedra_rough.png")   # pedra polida brilha, junta de terra é fosca
	pc.roughness = 1.0
	ResourceSaver.save(pc, MATS + "pedra_chao.tres")
	_poly("muro", "stone_wall_04", Color(0.95, 0.93, 0.90), 0.34, 1.2)    # muros e arrimos: pedra rústica real (Poly Haven)
	_surf("cantaria", "cantaria", Color(1.0, 1.0, 0.97), 0.5, 0.8, 1.0)
	_mista("reboco_branco", "reboco_velho", "reboco", Color(0.97, 0.95, 0.90), 0.22, 0.5)
	_mista("reboco_branco_novo", "reboco", "reboco_velho", Color(0.98, 0.97, 0.93), 0.22, 0.4)
	_mista("reboco_ocre", "reboco_velho", "reboco", Color(0.90, 0.76, 0.50), 0.22, 0.5)
	_mista("reboco_amarelo", "reboco", "reboco_velho", Color(0.95, 0.86, 0.55), 0.22, 0.4)
	_mista("reboco_azul", "reboco_velho", "reboco", Color(0.58, 0.70, 0.82), 0.22, 0.5)
	_mista("reboco_salmao", "reboco", "reboco_velho", Color(0.86, 0.64, 0.55), 0.22, 0.4)
	_mista("reboco_verde", "reboco_velho", "reboco", Color(0.66, 0.78, 0.64), 0.22, 0.5)
	_mista("reboco_creme", "reboco_velho", "reboco", Color(0.96, 0.88, 0.68), 0.22, 0.5)
	_surf("telha", "telha", Color(1, 1, 1), 0.3, 0.8, 1.2)
	# telhado com UV: as telhas correm no sentido do caimento (usado pelos telhados de MeshBatch.roof)
	var tuv := StandardMaterial3D.new()
	tuv.albedo_texture = _tex("telha_albedo.png")
	tuv.normal_enabled = true
	tuv.normal_texture = _tex("telha_normal.png")
	tuv.normal_scale = 1.3
	tuv.roughness = 0.78
	tuv.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ResourceSaver.save(tuv, MATS + "telha_uv.tres")
	_flat("telha_cumeeira", Color(0.30, 0.12, 0.08), 0.8)
	var vl := StandardMaterial3D.new()
	vl.albedo_texture = _tex("vidro_luz.png")
	vl.emission_enabled = true
	vl.emission_texture = _tex("vidro_luz.png")
	vl.emission_energy_multiplier = 1.15
	vl.roughness = 0.3
	ResourceSaver.save(vl, MATS + "vidro_luz.tres")
	var vn := StandardMaterial3D.new()
	vn.albedo_texture = _tex("vidro_noite.png")
	vn.roughness = 0.1
	vn.metallic_specular = 0.9
	ResourceSaver.save(vn, MATS + "vidro_noite.tres")
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
	var gg := TEX + "ambientcg/Ground037/"      # grama com musgo
	var gc := TEX + "ambientcg/Ground054/"      # barro seco
	for pair in [["plano", gd], ["ingreme", gi], ["grama", gg], ["barro", gc]]:
		var pre: String = pair[0]
		var dd: String = pair[1]
		terreno.set_shader_parameter(pre + "_cor", load(dd + "Color.jpg"))
		terreno.set_shader_parameter(pre + "_normal", load(dd + "NormalGL.jpg"))
		terreno.set_shader_parameter(pre + "_rug", load(dd + "Roughness.jpg"))
	ResourceSaver.save(terreno, MATS + "terreno.tres")
	_real("ferro", "Metal047B", Color(0.28, 0.26, 0.25), 0.9, 1.0, 1.0)            # ferro escuro corroído (grades, braços, ferragens)
	_real("ferro_ferrugem", "Metal053C", Color(0.9, 0.85, 0.8), 0.7, 1.0, 1.0)     # chapa com tinta descascando e ferrugem (calhas, tubos)
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
	_flat("pano", Color(0.62, 0.60, 0.54), 1.0)
	_flat("papel", Color(0.93, 0.86, 0.66), 0.9, 0.0, 0.7)
	var tvm := ShaderMaterial.new()
	tvm.shader = load("res://assets/shaders/tv_estatica.gdshader")
	ResourceSaver.save(tvm, MATS + "tv_tela.tres")
	var htv := StandardMaterial3D.new()
	htv.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	htv.albedo_texture = _tex("ponto_luz.png")
	htv.albedo_color = Color(0.55, 0.75, 1.0, 0.40)
	htv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	htv.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	htv.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	htv.disable_receive_shadows = true
	ResourceSaver.save(htv, MATS + "halo_tv.tres")
	for pl in [["placa_verde", Color(0.09, 0.25, 0.15)], ["placa_vermelha", Color(0.42, 0.09, 0.07)], ["placa_azul", Color(0.09, 0.17, 0.34)],
			["placa_marrom", Color(0.26, 0.15, 0.07)], ["placa_preta", Color(0.05, 0.05, 0.06)]]:
		_flat(pl[0], pl[1], 0.65)
	_flat("ouro_velho", Color(0.72, 0.55, 0.20), 0.38, 0.75)
	_flat("pao", Color(0.62, 0.40, 0.16), 0.85)
	_flat("couro", Color(0.18, 0.10, 0.06), 0.8)
	_flat("gema", Color(0.12, 0.45, 0.30), 0.2, 0.0, 0.6)
	_flat("listra_branca", Color(0.85, 0.83, 0.78), 0.7)
	_flat("listra_vermelha", Color(0.65, 0.10, 0.08), 0.7)
	_flat("listra_azul", Color(0.10, 0.20, 0.50), 0.7)
	_flat("pano_azul", Color(0.35, 0.42, 0.52), 1.0)
	_flat("pano_rosa", Color(0.58, 0.40, 0.40), 1.0)
	_flat("pano_cru", Color(0.60, 0.55, 0.43), 1.0)
	for hl in [["halo_quente", Color(1.0, 0.70, 0.32, 0.55)], ["halo_vela", Color(1.0, 0.52, 0.18, 0.65)]]:
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.albedo_texture = _tex("ponto_luz.png")
		hm.albedo_color = hl[1]
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		hm.billboard_keep_scale = true
		hm.cull_mode = BaseMaterial3D.CULL_DISABLED
		hm.no_depth_test = false
		hm.disable_receive_shadows = true
		ResourceSaver.save(hm, MATS + hl[0] + ".tres")
	var aq := ShaderMaterial.new()
	aq.shader = load("res://assets/shaders/agua_queda.gdshader")
	ResourceSaver.save(aq, MATS + "agua_queda.tres")
	_flat("vidro_oleo", Color(0.50, 0.24, 0.06), 0.12, 0.0, 0.55)
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
	_real("rocha", "Ground028", Color(0.66, 0.66, 0.68), 0.45, 1.3)          # pedras soltas das encostas e da beira da rua
	var poca := StandardMaterial3D.new()
	poca.albedo_color = Color(0.05, 0.065, 0.09, 0.55)
	poca.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	poca.roughness = 0.03
	poca.metallic = 0.0
	poca.metallic_specular = 1.0
	ResourceSaver.save(poca, MATS + "poca.tres")
	var folha := StandardMaterial3D.new()
	folha.albedo_texture = load(TEX + "folha_seca.png") as Texture2D
	folha.vertex_color_use_as_albedo = true
	folha.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	folha.alpha_scissor_threshold = 0.5
	folha.cull_mode = BaseMaterial3D.CULL_DISABLED
	folha.roughness = 0.9
	ResourceSaver.save(folha, MATS + "folha_seca.tres")
	var flor := StandardMaterial3D.new()
	flor.vertex_color_use_as_albedo = true
	flor.roughness = 0.8
	ResourceSaver.save(flor, MATS + "flor_mix.tres")
	_real("palma_tronco", "Bark014", Color(0.62, 0.6, 0.57), 0.9, 1.0)
	_real("terra_quintal", "Ground054", Color(0.95, 0.68, 0.55), 0.3, 1.0)       # barro vermelho de Minas (Ground054 tingido)
	_real("pele_bradador", "Bark014", Color(0.75, 0.72, 0.7), 2.0, 1.5)   # para o modelo do Bradador, se vier sem textura
	_flat("bradador_preto", Color(0, 0, 0), 1.0, 0.0, 0.0, true)
	_flat("bradador_palido", Color(0.78, 0.78, 0.72), 1.0, 0.0, 0.0, true)


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
	# lanterna de querosene na mão (Poly Haven Lantern_01, CC0): a chama e o vidro acendem/apagam com a tecla F
	var lm := PropKit.make("Lantern_01", 0.88)
	lm.name = "LanternaModelo"
	lm.position = Vector3(0.31, -0.42, -0.62)
	lm.rotation_degrees = Vector3(0, -25, 0)
	cam.add_child(lm)
	var chama := MeshInstance3D.new()
	chama.name = "Chama"
	var sph := SphereMesh.new()
	sph.radius = 0.016
	sph.height = 0.05
	chama.mesh = sph
	chama.material_override = load(MATS + "chama.tres")
	chama.position = Vector3(0, 0.10, 0)
	lm.add_child(chama)
	var brilho := MeshInstance3D.new()
	brilho.name = "Halo"
	var hq := QuadMesh.new()
	hq.size = Vector2(0.30, 0.30)
	brilho.mesh = hq
	brilho.material_override = load(MATS + "halo_vela.tres")
	brilho.position = Vector3(0, 0.10, 0)
	lm.add_child(brilho)
	lantern.position = lm.position + Vector3(0, 0.12, 0.02)
	lantern.omni_range = 11.0
	return p


func _bradador(b: VilaBuilder) -> Node3D:
	return Criaturas.bradador(b.mat("bradador_preto"), b.mat("bradador_palido"))


## Mula-sem-cabeça: corpo escuro, quatro pernas que balançam, pescoço cotoco com fogo e luz.
func _mula(b: VilaBuilder) -> Node3D:
	var m := Criaturas.mula(b.mat("mula_corpo"))
	m.set_script(load("res://scripts/mula.gd"))
	var fire := CPUParticles3D.new()
	fire.name = "Fogo"
	fire.position = Vector3(0, 2.2, -1.35)
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
	light.position = Vector3(0, 2.3, -1.4)
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
	var mis := Node.new()
	mis.name = "Missao"
	mis.set_script(load("res://scripts/missao.gd"))
	main.add_child(mis)
	mis.owner = main
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
