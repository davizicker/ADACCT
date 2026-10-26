class_name Modelos
extends RefCounted
## Troca automática dos modelos simples por modelos 3D reais (.glb) colocados em assets/models/.
## Para ajustar tamanho, giro ou animação de um modelo, edite os dicionários abaixo.
##
## altura  = altura final em metros (o modelo é escalado sozinho)
## yaw     = giro em graus (glTF olha para +Z; o jogo espera -Z, então o padrão é 180)
## anim    = nomes de animação a tentar, em ordem (usa a primeira que existir; senão, a primeira do arquivo)
## esconder = nós do modelo simples que somem quando o modelo real entra

const BRADADOR := {
	"path": "res://assets/models/bradador.glb",
	"altura": 2.7,
	"yaw": 180.0,
	"offset": Vector3.ZERO,
	"anim": ["idle", "Idle", "IDLE", "stand", "Stand"],
	"esconder": ["Manto", "Cabeca", "Braco_Esq", "Braco_Dir"],
}

const MULA := {
	"path": "res://assets/models/mula.glb",
	"altura": 1.9,
	"yaw": 180.0,
	"offset": Vector3.ZERO,
	"anim": ["gallop", "Gallop", "run", "Run", "galope"],
	"esconder": ["Corpo", "Pescoco", "PernaFE", "PernaFD", "PernaTE", "PernaTD"],
}


## Retorna true se um modelo real foi encontrado e colocado em `alvo`.
static func aplicar(alvo: Node3D, cfg: Dictionary) -> bool:
	var path: String = cfg["path"]
	if not ResourceLoader.exists(path):
		return false
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("Modelo inválido: " + path)
		return false
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return false
	var box := _bounds(inst, Transform3D.IDENTITY)
	if box.size.y < 0.001:
		push_warning("Modelo sem malha: " + path)
		inst.free()
		return false
	var k: float = float(cfg["altura"]) / box.size.y
	var wrapper := Node3D.new()
	wrapper.name = "ModeloReal"
	wrapper.rotation_degrees.y = float(cfg["yaw"])
	wrapper.position = cfg["offset"]
	inst.scale = Vector3.ONE * k
	# pés no chão e centrado no eixo
	inst.position = Vector3(-(box.position.x + box.size.x * 0.5) * k, -box.position.y * k, -(box.position.z + box.size.z * 0.5) * k)
	wrapper.add_child(inst)
	alvo.add_child(wrapper)
	for n: String in cfg["esconder"]:
		var c := alvo.get_node_or_null(n) as Node3D
		if c != null:
			c.visible = false
	var ap := _find_player(inst)
	if ap != null:
		var chosen := ""
		for a: String in cfg["anim"]:
			if ap.has_animation(a):
				chosen = a
				break
		if chosen == "" and ap.get_animation_list().size() > 0:
			chosen = ap.get_animation_list()[0]
		if chosen != "":
			var anim := ap.get_animation(chosen)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
			ap.play(chosen)
	return true


static func _bounds(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var local := xf
	if n is Node3D:
		local = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = local * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c in n.get_children():
		var b := _bounds(c, local)
		if b.size == Vector3.ZERO:
			continue
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


static func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_player(c)
		if r != null:
			return r
	return null
