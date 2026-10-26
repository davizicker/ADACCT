class_name Veg
extends RefCounted
## Vegetação feita de "cartões" com textura transparente (técnica padrão em jogos).
## Gera as malhas em assets/meshes/ e as cenas em scenes/veg/ (usadas pela vila).
## Cada planta é UM nó com 1–2 superfícies (tronco + folhas) para poupar desempenho.
## Materiais: res://assets/materials/<nome>.tres (criados em tools/bake.gd).

const MATS := "res://assets/materials/"
const MESHES := "res://assets/meshes/"
const SCENES := "res://scenes/veg/"


static func _quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, half_w: float, half_h: float, normal: Vector3) -> void:
	# duas faces (frente e verso) com a mesma normal: iluminação igual dos dois lados
	var a := center - u * half_w - v * half_h
	var b := center + u * half_w - v * half_h
	var c := center + u * half_w + v * half_h
	var d := center - u * half_w + v * half_h
	var uvs := {a: Vector2(0, 1), b: Vector2(1, 1), c: Vector2(1, 0), d: Vector2(0, 0)}
	for tri_pts in [[a, b, c], [a, c, d], [a, c, b], [a, d, c]]:
		for p: Vector3 in tri_pts:
			st.set_normal(normal)
			st.set_uv(uvs[p])
			st.add_vertex(p)


## Aglomerado esférico de cartões (copa de árvore ou moita).
static func cluster_into(st: SurfaceTool, count: int, radius: float, size: float, seed_: int, squash: float, offset: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	for i in count:
		var p := Vector3.ZERO
		while true:
			p = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			if p.length() <= 1.0:
				break
		var center := p * radius
		center.y *= squash
		var normal := (center + Vector3(0, radius * 0.25, 0)).normalized()
		if normal.length() < 0.1:
			normal = Vector3.UP
		var facing := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.6), rng.randf_range(-1, 1)).normalized()
		var u := facing.cross(Vector3.UP).normalized()
		var v := facing.cross(u).normalized()
		var s := size * rng.randf_range(0.8, 1.2)
		_quad(st, center + offset, u, v, s * 0.5, s * 0.5, normal)


## n cartões verticais girando em torno de Y (visto de cima, uma "estrela").
static func crossed_into(st: SurfaceTool, n: int, w: float, h: float, offset := Vector3.ZERO) -> void:
	for i in n:
		var a := PI * float(i) / n
		var u := Vector3(cos(a), 0, sin(a))
		_quad(st, offset + Vector3(0, h * 0.5, 0), u, Vector3.UP, w * 0.5, h * 0.5, Vector3.UP)


## n cartões saindo da base em leque, inclinados para fora (samambaia, bananeira, copa de palmeira).
static func radial_into(st: SurfaceTool, n: int, w: float, h: float, tilt_deg: float, offset := Vector3.ZERO, phase := 0.0) -> void:
	var tilt := deg_to_rad(tilt_deg)
	for i in n:
		var a := TAU * float(i) / n + phase
		var out := Vector3(cos(a), 0, sin(a))
		var u := Vector3.UP.cross(out).normalized()
		var v := (Vector3.UP * cos(tilt) + out * sin(tilt)).normalized()
		var normal := (Vector3.UP * 0.7 + out * 0.5).normalized()
		_quad(st, offset + v * (h * 0.5), u, v, w * 0.5, h * 0.5, normal)


static func _material(mat_name: String) -> Material:
	return load(MATS + mat_name + ".tres") as Material


static func _save_mesh(mesh: Mesh, mesh_name: String) -> Mesh:
	var path := MESHES + mesh_name + ".res"
	ResourceSaver.save(mesh, path)
	return load(path) as Mesh


## Malha de planta: superfície 0 = tronco (opcional), superfície seguinte = folhas.
## `leaves` recebe o SurfaceTool onde desenhar os cartões.
static func plant_mesh(mesh_name: String, trunk: Dictionary, leaf_mat: String, leaves: Callable) -> Mesh:
	var mesh := ArrayMesh.new()
	if not trunk.is_empty():
		var cyl := CylinderMesh.new()
		cyl.bottom_radius = trunk["rb"]
		cyl.top_radius = trunk["rt"]
		cyl.height = trunk["h"]
		cyl.radial_segments = 8
		cyl.rings = 1
		var st0 := SurfaceTool.new()
		st0.begin(Mesh.PRIMITIVE_TRIANGLES)
		st0.append_from(cyl, 0, Transform3D(Basis(), Vector3(0, float(trunk["h"]) * 0.5, 0)))
		st0.commit(mesh)
		mesh.surface_set_material(0, _material(trunk["mat"]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	leaves.call(st)
	var idx := mesh.get_surface_count()
	st.commit(mesh)
	mesh.surface_set_material(idx, _material(leaf_mat))
	return _save_mesh(mesh, mesh_name)


static func _scene(node_name: String, mesh: Mesh) -> PackedScene:
	var root := Node3D.new()
	root.name = node_name
	var mi := MeshInstance3D.new()
	mi.name = "Malha"
	mi.mesh = mesh
	mi.visibility_range_end = 260.0
	mi.visibility_range_end_margin = 30.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	root.add_child(mi)
	mi.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	var path := SCENES + node_name.to_lower() + ".tscn"
	ResourceSaver.save(ps, path)
	root.free()
	return load(path) as PackedScene


## Cria todas as cenas de plantas. Retorna {nome: PackedScene}.
static func build_all() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(SCENES)
	var out := {}

	# árvores de copa larga (mangueira/jaqueira), 3 variações
	for i in 3:
		var h := 4.2 + i * 0.6
		var m := plant_mesh("arvore_%d" % i, {"h": h, "rb": 0.34, "rt": 0.16, "mat": "casca"}, "folhagem",
			func(st: SurfaceTool) -> void:
				cluster_into(st, 26, 2.7, 2.6, 200 + i, 0.85, Vector3(0, h + 1.3, 0))
				cluster_into(st, 14, 1.6, 2.2, 230 + i, 0.8, Vector3(1.7, h * 0.85, 0.9)))
		out["arvore_%d" % i] = _scene("Arvore_%d" % i, m)

	# árvore pequena de quintal (jabuticabeira/limoeiro)
	var small := plant_mesh("arvore_pequena", {"h": 1.7, "rb": 0.16, "rt": 0.09, "mat": "casca"}, "folhagem",
		func(st: SurfaceTool) -> void: cluster_into(st, 16, 1.5, 1.7, 210, 0.85, Vector3(0, 2.5, 0)))
	out["arvore_pequena"] = _scene("ArvorePequena", small)

	# palmeira-imperial: tronco alto e fino, copa de folhas arqueadas
	var palma := plant_mesh("palmeira", {"h": 12.0, "rb": 0.30, "rt": 0.20, "mat": "palma_tronco"}, "samambaia",
		func(st: SurfaceTool) -> void:
			radial_into(st, 9, 3.8, 4.4, 62.0, Vector3(0, 12.0, 0))
			radial_into(st, 5, 2.8, 3.4, 26.0, Vector3(0, 12.1, 0), 0.3))
	out["palmeira"] = _scene("Palmeira", palma)

	# bananeira (touceira)
	var banana := plant_mesh("bananeira", {}, "bananeira",
		func(st: SurfaceTool) -> void:
			radial_into(st, 6, 2.8, 3.2, 34.0)
			radial_into(st, 5, 2.4, 2.8, 20.0, Vector3.ZERO, 0.5))
	out["bananeira"] = _scene("Bananeira", banana)

	var arbusto := plant_mesh("arbusto", {}, "arbusto",
		func(st: SurfaceTool) -> void: cluster_into(st, 11, 0.55, 1.0, 220, 0.8, Vector3(0, 0.6, 0)))
	out["arbusto"] = _scene("Arbusto", arbusto)

	var felce := plant_mesh("samambaia", {}, "samambaia",
		func(st: SurfaceTool) -> void: radial_into(st, 6, 1.3, 1.1, 48.0))
	out["samambaia"] = _scene("Samambaia", felce)

	var capim := plant_mesh("capim", {}, "capim",
		func(st: SurfaceTool) -> void: crossed_into(st, 3, 0.9, 0.7))
	out["capim"] = _scene("Capim", capim)
	return out
