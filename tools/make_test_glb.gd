extends SceneTree
## Gera um .glb de teste (esqueleto simples com garras) só para verificar que a troca de modelo funciona.
## godot --headless --path . --script res://tools/make_test_glb.gd -- <saida.glb>
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var root := Node3D.new()
	root.name = "Teste"
	var body := MeshInstance3D.new()
	body.name = "Corpo"
	var cap := CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 3.0
	body.mesh = cap
	body.position.y = 1.5 + 5.0     # fora do chão de propósito: o código deve colocar os pés em y=0
	root.add_child(body)
	var nose := MeshInstance3D.new()
	nose.name = "Nariz"
	var bx := BoxMesh.new()
	bx.size = Vector3(0.2, 0.2, 0.6)
	nose.mesh = bx
	nose.position = Vector3(0, 7.0, 0.6)    # o "rosto" aponta para +Z (convenção glTF)
	root.add_child(nose)
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_scene(root, st)
	var err := doc.write_to_filesystem(st, out)
	print("[glb] escrito: ", err == OK, " ", out)
	quit()
