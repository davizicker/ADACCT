extends SceneTree
## PLANTA DO JOGO: lê a vila pronta (scenes/vila.scn) e escreve docs/planta/planta.json com
##  - catálogo dos módulos do kit (tamanho padrão medido do modelo: largura x altura x saliência),
##  - ficha de cada casa (número, s na rua, lado, largura, fundo, andares, altura, porta, vãos, módulos com posição exata),
##  - cadastro de TODOS os objetos de cena (grupo, nome, posição x/y/z, tamanho da caixa, rotação),
##  - conferência dos módulos (fora da parede, cobrindo janela/porta, um em cima do outro, sacada sem porta-balcão).
## Uso: xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/planta_jogo.gd   (depois: python3 tools/planta_jogo.py)
const GRUPOS_OBJ := ["Adornos", "Props", "Coletaveis", "Iluminacao", "Nichos", "PropsEncosta", "MurosDasCurvas", "Adro", "Ponte", "Ratos", "Becos", "MurosEQuintais", "Interiores"]
const VAO_TIPOS := ["janela_guilhotina", "janela_colonial", "porta_balcao", "porta_dupla", "porta_bandeira", "grade_janela", "veneziana", "veneziana_e"]
const PAREDE_TIPOS := ["cunhal_1m", "embasamento_1m", "cornija_1m", "cachorro_beiral"]
var problemas: Array = []


func _init() -> void:
	var v: Node3D = (load("res://scenes/vila.scn") as PackedScene).instantiate()
	root.add_child(v)
	await process_frame
	var out := {"modulos": _catalogo(), "casas": [], "objetos": [], "rua": [], "problemas": []}
	for s in range(0, int(Route.length()) + 1, 2):
		var p := Route.pos(float(s))
		out["rua"].append([snappedf(p.x, 0.01), snappedf(p.z, 0.01), snappedf(Route.width(float(s)), 0.01), snappedf(p.y, 0.01)])
	for c in v.get_node("Casas").get_children():
		out["casas"].append(_ficha(c as Node3D, out["modulos"]))
	for gn in GRUPOS_OBJ:
		var g := v.get_node_or_null(gn)
		if g == null:
			continue
		for n in g.get_children():
			if n is Node3D:
				var o := _obj(n as Node3D, gn)
				if not o.is_empty():
					out["objetos"].append(o)
	out["problemas"] = problemas
	var f := FileAccess.open("res://docs/planta/planta.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("[planta] casas=%d objetos=%d modulos=%d problemas=%d" % [out["casas"].size(), out["objetos"].size(), out["modulos"].size(), problemas.size()])
	for pr in problemas.slice(0, 60):
		print("[planta] PROBLEMA ", pr)
	quit()


func _catalogo() -> Dictionary:
	var cat := {}
	var d := DirAccess.open("res://assets/models/kit/")
	for fn in d.get_files():
		if not fn.ends_with(".glb"):
			continue
		var nome := fn.get_basename()
		var ab := Kit.mesh(nome).get_aabb()
		# convenção do módulo: frente +Z, parede z=0 -> largura = x, altura = y, saliência = z
		cat[nome] = {"largura": snappedf(ab.size.x, 0.001), "altura": snappedf(ab.size.y, 0.001), "saliencia": snappedf(ab.end.z, 0.001), "fundo_na_parede": snappedf(-ab.position.z, 0.001), "base_y": snappedf(ab.position.y, 0.001)}
	return cat


func _ficha(c: Node3D, cat: Dictionary) -> Dictionary:
	var xf := c.global_transform
	var w := float(c.get_meta("largura", 0.0))
	var dep := float(c.get_meta("fundo", 0.0))
	var alt := float(c.get_meta("altura", 0.0))
	var dz := float(c.get_meta("door_z", 0.0))
	var porta := xf * Vector3(-0.3, 0.0, dz)
	var s := Route.nearest_s(porta)
	var lado := -1 if Route.right(s).dot(porta - Route.pos(s)) < 0.0 else 1
	var num := c.get_node_or_null("Numero") as Label3D
	var cantos: Array = []
	for q in [Vector3(0, 0, -w / 2.0), Vector3(dep, 0, -w / 2.0), Vector3(dep, 0, w / 2.0), Vector3(0, 0, w / 2.0)]:
		var p: Vector3 = xf * q
		cantos.append([snappedf(p.x, 0.01), snappedf(p.z, 0.01)])
	var mods: Array = []
	var caixas: Array = []          # [nome, AABB local (casa)]
	for m in c.get_meta("modulos", []):
		var nome: String = m[0]
		var mx: Transform3D = m[1]
		var ab: AABB = mx * Kit.mesh(nome).get_aabb()
		caixas.append([nome, ab])
		mods.append({"modulo": nome, "z": snappedf(mx.origin.z, 0.01), "y": snappedf(mx.origin.y, 0.01), "x": snappedf(mx.origin.x, 0.01),
			"largura": snappedf(ab.size.z, 0.01), "altura": snappedf(ab.size.y, 0.01)})
	var vaos: Array = c.get_meta("vaos", [])
	var id := "%s nº%s" % [c.name, num.text if num else "-"]
	# ---- conferência dos módulos
	for e in caixas:
		var nome: String = e[0]
		var ab: AABB = e[1]
		if nome in ["chamine", "beiral_telhas"]:
			continue
		if ab.position.z < -w / 2.0 - 0.08 or ab.end.z > w / 2.0 + 0.08:
			problemas.append("%s: %s sai da largura da parede (z %.2f..%.2f, parede ±%.2f)" % [id, nome, ab.position.z, ab.end.z, w / 2.0])
		if ab.end.y > alt + 0.9 or ab.position.y < -0.4:
			problemas.append("%s: %s fora da altura da casa (y %.2f..%.2f, casa %.2f)" % [id, nome, ab.position.y, ab.end.y, alt])
		if nome in PAREDE_TIPOS:
			for vv in vaos:
				var vz0 := float(vv["z"]) - float(vv["w"]) * 0.5
				var vz1 := float(vv["z"]) + float(vv["w"]) * 0.5
				var vy0 := float(vv["peitoril"])
				var vy1 := float(vv["topo"])
				if ab.end.z > vz0 + 0.03 and ab.position.z < vz1 - 0.03 and ab.end.y > vy0 + 0.03 and ab.position.y < vy1 - 0.03:
					problemas.append("%s: %s cobre %s em z=%.2f y=%.2f" % [id, nome, "porta" if bool(vv["porta"]) else "janela", float(vv["z"]), (vy0 + vy1) * 0.5])
	for i in caixas.size():
		for j in range(i + 1, caixas.size()):
			var a: String = caixas[i][0]
			var b: String = caixas[j][0]
			if a == b or (a in VAO_TIPOS and b in VAO_TIPOS) or a in ["chamine", "beiral_telhas", "cornija_1m", "cachorro_beiral"] or b in ["chamine", "beiral_telhas", "cornija_1m", "cachorro_beiral"]:
				continue
			if (a in ["sacada_ferro", "sacada_1m"] and b in VAO_TIPOS) or (b in ["sacada_ferro", "sacada_1m"] and a in VAO_TIPOS):       # porta-balcão de pé atrás do parapeito: as caixas se sobrepõem de propósito
				continue
			var ia := (caixas[i][1] as AABB).grow(-0.03)
			if ia.intersects((caixas[j][1] as AABB).grow(-0.03)):
				problemas.append("%s: %s atravessa %s" % [id, a, b])
	for e in caixas:
		if e[0] == "sacada_ferro":
			var ab: AABB = e[1]
			var tem := false
			for vv in vaos:                         # vão de porta (com ou sem peça do kit: a porta em arco é feita à mão) logo atrás da sacada
				if bool(vv["porta"]) and absf(float(vv["z"]) - ab.get_center().z) < 0.4 and absf(float(vv["peitoril"]) - (ab.position.y + 0.59)) < 0.45:
					tem = true
			if not tem:
				problemas.append("%s: sacada de ferro sem porta-balcão atrás (z=%.2f)" % [id, ab.get_center().z])
	var contagem := {}
	for m in mods:
		contagem[m["modulo"]] = int(contagem.get(m["modulo"], 0)) + 1
	return {"casa": String(c.name), "numero": num.text if num else "", "s": snappedf(s, 0.1), "lado": lado, "visitavel": c.has_meta("sala_id"),
		"sala": String(c.get_meta("sala_id", "")), "largura": snappedf(w, 0.01), "fundo": snappedf(dep, 0.01), "andares": int(c.get_meta("andares", 1)),
		"altura": snappedf(alt, 0.01), "porta_z": snappedf(dz, 0.01), "porta_xyz": [snappedf(porta.x, 0.01), snappedf(porta.y, 0.01), snappedf(porta.z, 0.01)],
		"cantos": cantos, "vaos": vaos.size(), "modulos_contagem": contagem, "modulos": mods}


func _obj(n: Node3D, grupo: String) -> Dictionary:
	var ab := AABB()
	var ok := false
	for vi in n.find_children("*", "VisualInstance3D", true, false):
		if vi is Light3D or vi is Decal or vi is GPUParticles3D or vi is Label3D or String(vi.name).begins_with("Halo"):
			continue
		var bb := (vi as VisualInstance3D).global_transform * (vi as VisualInstance3D).get_aabb()
		ab = bb if not ok else ab.merge(bb)
		ok = true
	if n is VisualInstance3D and not ok:
		ab = (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
		ok = true
	if not ok:
		ab = AABB(n.global_position, Vector3.ZERO)
	var p := n.global_position
	return {"grupo": grupo, "nome": String(n.name), "x": snappedf(p.x, 0.01), "y": snappedf(p.y, 0.01), "z": snappedf(p.z, 0.01),
		"rot_y": snappedf(rad_to_deg(n.global_rotation.y), 0.1), "tam": [snappedf(ab.size.x, 0.01), snappedf(ab.size.y, 0.01), snappedf(ab.size.z, 0.01)],
		"caixa_xz": [snappedf(ab.position.x, 0.01), snappedf(ab.position.z, 0.01), snappedf(ab.end.x, 0.01), snappedf(ab.end.z, 0.01)],
		"s": snappedf(Route.nearest_s(p), 0.1)}
