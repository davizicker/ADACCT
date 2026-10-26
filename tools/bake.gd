extends SceneTree
## Recria materiais e cenas (vila, jogador, Bradador, casa, poste, main) do zero.
## ATENÇÃO: sobrescreve scenes/*.tscn e assets/materials/*.tres. Depois que você
## começar a editar a vila no editor, NÃO rode isto de novo (perderia suas edições).
## Uso:
##   godot --headless --path . --script res://tools/gen_textures.gd
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/bake.gd

const TEX := "res://assets/textures/"
const MATS := "res://assets/materials/"
const SCENES := "res://scenes/"


func _init() -> void:
	_materials()
	var b := VilaBuilder.new()
	_save(b.build_vila(), "vila")
	var player := b.build_player()
	player.set_script(load("res://scripts/player.gd"))
	_save(player, "jogador")
	_save(b.build_bradador(), "bradador")
	_save(b.make_casa(12.0, 7.5, "reboco_branco", -1.0, true), "casa")
	_save(b.make_poste(), "poste")
	_main()
	print("[bake] pronto")
	quit()


func _tex_mat(mat_name: String, tex: String, tint: Color, scale: float, rough := 0.95, normal := 1.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + tex + "_albedo.png")
	m.normal_enabled = true
	m.normal_texture = load(TEX + tex + "_normal.png")
	m.normal_scale = normal
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ResourceSaver.save(m, MATS + mat_name + ".tres")


func _flat_mat(mat_name: String, color: Color, rough := 0.9, metal := 0.0, emissive := 0.0, unshaded := false) -> void:
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


func _materials() -> void:
	_tex_mat("pedra_chao", "pedra", Color(0.80, 0.78, 0.74), 0.3, 0.9, 1.4)
	_tex_mat("pedra_clara", "pedra", Color(1.0, 0.98, 0.92), 0.4, 0.9, 1.2)
	_tex_mat("reboco_branco", "reboco", Color(0.95, 0.93, 0.88), 0.25)
	_tex_mat("reboco_ocre", "reboco", Color(0.95, 0.72, 0.40), 0.25)
	_tex_mat("reboco_azul", "reboco", Color(0.55, 0.68, 0.82), 0.25)
	_tex_mat("reboco_terracota", "reboco", Color(0.85, 0.52, 0.40), 0.25)
	_tex_mat("moldura", "reboco", Color(0.92, 0.90, 0.84), 0.5)
	_tex_mat("telha", "telha", Color(1, 1, 1), 0.3, 0.8)
	_tex_mat("madeira", "madeira", Color(1, 1, 1), 0.5)
	_flat_mat("ferro", Color(0.05, 0.05, 0.05), 0.55, 0.6)
	_flat_mat("janela_escura", Color(0.02, 0.025, 0.035), 0.2)
	_flat_mat("janela_acesa", Color(1.0, 0.62, 0.25), 0.5, 0.0, 0.8)
	_flat_mat("vidro_lampiao", Color(1.0, 0.75, 0.35), 0.5, 0.0, 2.2)
	_flat_mat("porta_igreja", Color(1.0, 0.72, 0.38), 0.5, 0.0, 0.9)
	_flat_mat("bradador_preto", Color(0, 0, 0), 1.0, 0.0, 0.0, true)
	_flat_mat("bradador_palido", Color(0.78, 0.78, 0.72), 1.0, 0.0, 0.0, true)


func _own(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		if c.scene_file_path == "":
			_own(c, owner_node)


func _save(root: Node, scene_name: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("falha ao empacotar " + scene_name)
		return
	ResourceSaver.save(ps, SCENES + scene_name + ".tscn")
	print("[bake] ", scene_name)


func _main() -> void:
	var main := Node3D.new()
	main.name = "Main"
	main.set_script(load("res://scripts/main.gd"))
	var parts := [
		["Vila", "vila"], ["Jogador", "jogador"], ["Bradador", "bradador"],
	]
	for p in parts:
		var inst := (load(SCENES + p[1] + ".tscn") as PackedScene).instantiate()
		inst.name = p[0]
		main.add_child(inst)
		inst.owner = main
	(main.get_node("Jogador") as Node3D).position = Vector3(0, World.ground_y(-2.0) + 0.2, -2.0)
	(main.get_node("Bradador") as Node3D).visible = false
	var gritos := Node.new()
	gritos.name = "Gritos"
	gritos.set_script(load("res://scripts/scream_system.gd"))
	main.add_child(gritos)
	gritos.owner = main
	var ui := CanvasLayer.new()
	ui.name = "Interface"
	ui.set_script(load("res://scripts/hud.gd"))
	main.add_child(ui)
	ui.owner = main
	var ps := PackedScene.new()
	ps.pack(main)
	ResourceSaver.save(ps, SCENES + "main.tscn")
	print("[bake] main")
