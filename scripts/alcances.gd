class_name Alcances
extends RefCounted
## Última passada do bake: todo objeto sem alcance de visibilidade ganha um (antes ~1500 peças eram desenhadas da vila inteira,
## inclusive o interior da igreja a 400 m e as salas de casas do outro lado do mapa). Marcos da paisagem continuam sem limite.

const SEM_LIMITE := ["Terreno", "Rua", "Serra", "Ceu", "Lua", "Ambiente", "FundoDaRua", "LuzesDistantes"]
const MARCOS := ["Adro/Igreja", "Morros/Capela"]      # torres da igreja e capela do morro: vistas de longe pela rua


static func aplicar(vila: Node) -> Dictionary:
	var rel := {"interior": 0, "pequeno": 0, "casa": 0, "detalhe_casa": 0, "resto": 0, "mantidos": 0}
	for gi in vila.find_children("*", "GeometryInstance3D", true, false):
		var g := gi as GeometryInstance3D
		if g.visibility_range_end > 0.0:
			continue
		var caminho := String(vila.get_path_to(g))
		var partes := caminho.split("/")
		var topo := partes[0]
		if topo in SEM_LIMITE:
			rel["mantidos"] += 1
			continue
		var marco := false
		for m in MARCOS:
			if caminho.begins_with(m):
				marco = true
		if marco:
			rel["mantidos"] += 1
			continue
		var bb := g.get_aabb()
		var tam := (g.global_transform.basis * bb.size).abs().length() if g.is_inside_tree() else bb.size.length()
		if tam > 60.0:                      # peça gigante (chão do adro, muralha): fica
			rel["mantidos"] += 1
			continue
		var fim := 160.0
		var k := "resto"
		if topo == "Interiores":
			fim = 80.0 if (partes.size() > 1 and partes[1].begins_with("igreja")) else 45.0
			k = "interior"
		elif topo == "Casas":
			if caminho.contains("/Detalhes") or caminho.contains("/Fundos") or caminho.contains("/Lateral") or caminho.contains("VidrosEPlantas"):
				fim = 120.0
				k = "detalhe_casa"
			elif tam < 2.0:
				fim = 70.0
				k = "pequeno"
			else:
				fim = 260.0
				k = "casa"
		elif tam < 2.0:
			fim = 70.0
			k = "pequeno"
		g.visibility_range_end = fim
		g.visibility_range_end_margin = minf(8.0, fim * 0.1)
		rel[k] += 1
	return rel
