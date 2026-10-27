class_name Kit
extends RefCounted
## Módulos de fachada modelados no Blender (tools/blender/kit_colonial.py), em res://assets/models/kit/.
## Convenção do módulo: frente +Z, parede em z=0, origem no centro-base. Em casas do jogo a fachada fica no plano x=0 e a rua
## em -x, então os módulos entram girados em -90° (Kit.fachada(...)).

const DIR := "res://assets/models/kit/"
static var _cache := {}


static func mesh(nome: String) -> Mesh:
	if not _cache.has(nome):
		var ps := load(DIR + nome + ".glb") as PackedScene
		var inst := ps.instantiate()
		var m: Mesh = null
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			m = (mi as MeshInstance3D).mesh
			break
		# um glb com vários objetos (um por material) vira vários MeshInstance3D: junta tudo numa malha só
		var am := ArrayMesh.new()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var mm := (mi as MeshInstance3D).mesh
			for i in mm.get_surface_count():
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mm.surface_get_arrays(i))
				var mt := mm.surface_get_material(i)
				if mt != null:
					mt = mt.duplicate()
					mt.resource_name = (mi as MeshInstance3D).name.get_slice("_", 0) if mt.resource_name == "" else mt.resource_name
				am.surface_set_material(am.get_surface_count() - 1, mt)
		inst.free()
		_cache[nome] = am
	return _cache[nome]


## Transformação de um módulo na fachada: `pos` = (x=0 no plano da parede, y altura, z posição ao longo da fachada).
static func fachada(pos: Vector3, escala := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, -PI / 2.0).scaled_local(escala), pos)
