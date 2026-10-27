extends SceneTree
## Tira várias fotos da vila de uma vez (auditoria visual). Precisa de display (use xvfb).
## godot --path . --rendering-driver opengl3 --audio-driver Dummy --script res://tools/foto_tour.gd -- <pasta> <lista>
## <lista> = "rua" (ao longo da rua), "alvos" (pontos especiais) ou "tudo".
## Cada foto: s (m ao longo da rua), yaw (graus relativo ao sentido da subida), pitch, deslocamento lateral (m), altura extra (m).

const RUA := [
	[6, 0, 3, 0, 0], [6, 180, 3, 0, 0], [30, 0, 3, 0, 0], [30, 180, 3, 0, 0], [55, 0, 3, 0, 0], [55, 180, 3, 0, 0],
	[80, 0, 3, 0, 0], [80, 180, 3, 0, 0], [105, 0, 3, 0, 0], [105, 180, 3, 0, 0], [130, 0, 3, 0, 0], [130, 180, 3, 0, 0],
	[150, 0, 3, 0, 0], [150, 180, 3, 0, 0], [175, 0, 3, 0, 0], [175, 180, 3, 0, 0], [200, 0, 3, 0, 0], [200, 180, 3, 0, 0],
	[225, 0, 3, 0, 0], [225, 180, 3, 0, 0], [250, 0, 3, 0, 0], [250, 180, 3, 0, 0], [275, 0, 3, 0, 0], [275, 180, 3, 0, 0],
	[335, 0, 3, 0, 0], [335, 180, 3, 0, 0], [366, 0, 6, 0, 0], [366, 180, 3, 0, 0],
]
const ALVOS := [
	[118, 90, -10, 0, 0], [118, -90, -10, 0, 0], [112, 0, -10, 0, 0], [124, 180, -10, 0, 0],       # ponte e riacho
	[160, 90, 2, 0, 0], [160, -90, 2, 0, 0], [152, 0, 3, 0, 0],                                       # largo e chafariz
	[88, -90, 5, 0, 0], [188, 90, 5, 0, 0], [262, -90, 5, 0, 0],                                      # becos
	[380, 0, 14, 0, 0], [385, 180, 3, 0, 0], [340, 0, 25, 0, 0],                                      # igreja e adro
	[60, 0, -35, 0, 70], [200, 0, -35, 0, 70], [300, 20, -30, 0, 80],                                 # vista aérea
	[40, 0, 50, 0, 0], [140, 0, 50, 0, 0], [240, 0, 50, 0, 0],                                        # céu
]


const PROPS := [
	# (yaw positivo = olhar para a ESQUERDA da subida; negativo = DIREITA)
	[142, 41, -5, 0, 0], [145, 58, -6, -2.6, 0],            # TV do bar, barril e banquinhos (esquerda, s=148)
	[147, 24, 1, -1, 0], [157, -38, 3, 0, 0],               # carro coberto (esquerda); chafariz, balde e bola (direita)
	[311, 48, 8, 0, 0], [326, -28, 6, 3, 0],                # estátua no adro (esquerda); carro do adro (direita)
	[27, -34, 6, 0, 0], [61, -34, 6, 0, 0],                 # banquinho e balde junto às portas (direita)
	[3, -26, 30, 0, 0], [38, -90, 12, 0.6, 0.8],            # diário (bilhete); portão do beco com a porta real
	[93, 38, 6, 0, 0], [138, 30, 4, -1, 0],                 # lanterna esquecida no banquinho; aros de roda
	[60, 0, -28, 0, 45],                                    # vista de cima: tora e arbustos nas encostas
]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp"
	var which: String = args[1] if args.size() > 1 else "rua"
	var day := args.size() > 2 and args[2] == "dia"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 8:
		await process_frame
	var menu := main.get("menu") as Node
	if menu != null:
		menu.call("close")
	var p := main.get_node("Jogador") as Player
	p.set_physics_process(false)
	(main.get_node("Gritos") as Node).set("enabled", false)
	if day:
		var env := (main.get_node("Vila/Ambiente") as WorldEnvironment).environment
		env.ambient_light_energy = 2.2
		env.ambient_light_color = Color(0.8, 0.85, 1.0)
		env.fog_density = 0.003
		(main.get_node("Vila/Lua") as DirectionalLight3D).light_energy = 1.4
	var list: Array = []
	if which == "rua" or which == "tudo":
		list += RUA
	if which == "alvos" or which == "tudo":
		list += ALVOS
	if which == "props":
		list += PROPS
	var n := 0
	for it in list:
		var s: float = it[0]
		var t := Route.tangent(s)
		var r := Route.right(s)
		p.global_position = Route.pos(s) + r * float(it[3]) + Vector3(0, 0.1 + float(it[4]), 0)
		p.rotation.y = atan2(-t.x, -t.z) + deg_to_rad(float(it[1]))
		p.cam.rotation.x = deg_to_rad(float(it[2]))
		for i in 4:
			await process_frame
		var name := "%s_%03d_%s%d_%d" % [which, int(s), "y", int(it[1]), n]
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
		n += 1
	print("[tour] %d fotos em %s" % [n, out])
	quit()
