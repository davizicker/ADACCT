class_name VelaVotiva
extends Area3D
## Altar de rua: acender uma vela (E). A chama fica acesa, o medo baixa e o Bradador recua um passo (uma vez por altar).

@export var texto_interacao := "Acender uma vela"

var _acesa := false

const FRASES := [
	"Você acende a vela. A chama se firma, e a rua parece respirar.",
	"Uma vela por quem não voltou da mina. O vento se acalma por um instante.",
	"A cera escorre devagar. Lá longe, algo para de andar.",
	"Você reza baixinho. O escuro, por ora, recua.",
]


func _ready() -> void:
	add_to_group("interagivel")
	monitoring = false


func interagir(_player: Player) -> void:
	if _acesa:
		get_tree().call_group("hud", "show_prompt", "A vela já arde. Alguém vai se lembrar de você.", 3.0)
		return
	_acesa = true
	texto_interacao = "Vela acesa"
	var chama := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.09
	chama.mesh = sm
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(1.0, 0.82, 0.45)
	chama.material_override = mt
	chama.position = Vector3(0, 0.0, 0)
	add_child(chama)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.7, 0.35)
	luz.light_energy = 1.4
	luz.omni_range = 6.0
	luz.position = Vector3(0, 0.15, 0)
	add_child(luz)
	get_tree().call_group("audio", "play_clink")
	get_tree().call_group("audio", "acalmar", 0.6)
	var main := get_tree().get_first_node_in_group("jogo")
	var recuou := false
	if main != null:
		var sc: Variant = main.get("screams")
		if sc != null and int(sc.get("stage")) > 0:
			sc.set("stage", int(sc.get("stage")) - 1)
			sc.call("_place_bradador")
			recuou = true
	var f: String = FRASES[int(absf(global_position.x * 7.0 + global_position.z * 3.0)) % FRASES.size()]
	get_tree().call_group("hud", "show_prompt", f + ("  (Ele recuou.)" if recuou else ""), 5.0)
