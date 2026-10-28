@tool
class_name ZonaLimpa
extends Node3D
## Caixa que apaga os objetos individuais gerados pelo código dentro dela (veja Ajustes). No editor aparece como uma caixa vermelha.

@export var tamanho := Vector3(3.0, 3.0, 3.0):
	set(v):
		tamanho = v
		_desenha()


func _ready() -> void:
	_desenha()


func contem(p: Vector3) -> bool:
	var l := global_transform.affine_inverse() * p
	return absf(l.x) <= tamanho.x * 0.5 and absf(l.y) <= tamanho.y * 0.5 and absf(l.z) <= tamanho.z * 0.5


func _desenha() -> void:
	if not Engine.is_editor_hint():
		return
	var mi := get_node_or_null("Caixa") as MeshInstance3D
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Caixa"
		add_child(mi)
	var bm := BoxMesh.new()
	bm.size = tamanho
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.1, 0.1, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
