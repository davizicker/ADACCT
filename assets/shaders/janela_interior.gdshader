shader_type spatial;
render_mode cull_disabled;
// VIDRO COM INTERIOR FALSO ("interior mapping"): cada painel de janela é um quadrado que mostra uma sala procedural atrás do vidro
// (paredes, piso de tábuas, teto com vigas, rodapé, porta, armário, quadro, cortinas), vista com perspectiva correta.
// Dados por janela (MultiMesh INSTANCE_CUSTOM): x = semente (muda a sala), y = 1 se a luz está acesa, z = variação de profundidade.
// Acesa: o quarto brilha (luz quente de lampião). Apagada: bem escura, com um pouco de luar azulado. O brilho de reflexo vem do PBR.

uniform float profundidade = 3.6;
uniform float largura_sala = 3.8;
uniform float pe_direito = 3.1;
uniform float peitoril = 0.95;
uniform vec3 cor_luz : source_color = vec3(1.0, 0.70, 0.36);

varying vec3 pos_loc;
varying vec4 dados;
varying vec2 tam;

const vec3 PAL[6] = vec3[6](vec3(0.82, 0.78, 0.66), vec3(0.72, 0.74, 0.62), vec3(0.78, 0.66, 0.56), vec3(0.66, 0.72, 0.78), vec3(0.80, 0.72, 0.52), vec3(0.74, 0.62, 0.60));
const vec3 CORT[4] = vec3[4](vec3(0.85, 0.80, 0.68), vec3(0.62, 0.22, 0.24), vec3(0.28, 0.40, 0.58), vec3(0.78, 0.66, 0.40));

float h1(float n) { return fract(sin(n * 91.3458) * 47453.5453); }
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

// Interseção raio x caixa (método das lajes). Devolve a distância de entrada, ou 1e5 se errar; n = normal da face atingida.
float caixa(vec3 ro, vec3 rd, vec3 bmin, vec3 bmax, out vec3 n) {
	vec3 inv = 1.0 / (rd + vec3(1e-6));
	vec3 t0 = (bmin - ro) * inv;
	vec3 t1 = (bmax - ro) * inv;
	vec3 tmn = min(t0, t1);
	vec3 tmx = max(t0, t1);
	float tn = max(max(tmn.x, tmn.y), tmn.z);
	float tf = min(min(tmx.x, tmx.y), tmx.z);
	n = vec3(0.0);
	if (tf < max(tn, 0.0)) return 1e5;
	if (tn == tmn.x) n = vec3(-sign(rd.x), 0.0, 0.0);
	else if (tn == tmn.y) n = vec3(0.0, -sign(rd.y), 0.0);
	else n = vec3(0.0, 0.0, -sign(rd.z));
	return tn;
}

void vertex() {
	pos_loc = VERTEX;
	dados = INSTANCE_CUSTOM;
	tam = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
}

void fragment() {
	vec3 cam_l = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	vec3 P = vec3(pos_loc.xy * tam, 0.0);
	vec3 C = vec3(cam_l.xy * tam, cam_l.z * length(MODEL_MATRIX[2].xyz));
	vec3 D = normalize(P - C);
	float semente = dados.x;
	bool acesa = dados.y > 0.5;
	float prof = profundidade * (0.8 + 0.5 * dados.z);
	float rw = largura_sala * (0.85 + 0.45 * h1(semente + 3.0));
	float y0 = -tam.y * 0.5 - peitoril;
	float y1 = y0 + pe_direito;
	float tx = 1e5;
	float ty = 1e5;
	float tz = 1e5;
	if (abs(D.x) > 1e-4) tx = ((D.x > 0.0 ? rw * 0.5 : -rw * 0.5) - P.x) / D.x;
	if (abs(D.y) > 1e-4) ty = ((D.y > 0.0 ? y1 : y0) - P.y) / D.y;
	if (D.z < -1e-4) tz = (-prof - P.z) / D.z;
	float t = min(tx, min(ty, tz));
	int eixo = (t == tz) ? 2 : ((t == tx) ? 0 : 1);
	vec3 H = P + D * t;
	vec3 reboco = PAL[int(floor(semente * 6.0)) % 6];
	vec3 col;
	// mobília e moradores: caixas de verdade dentro da sala (mesa, cama, baú, estante) e, às vezes, uma silhueta parada no escuro
	bool mov = false;
	vec3 movcor = vec3(0.0);
	vec3 nn;
	float tm = 1e5;
	int tipo = int(floor(h1(semente + 31.0) * 5.0));
	float madeira = 0.75 + 0.5 * h1(semente + 33.0);
	vec3 wood = vec3(0.30, 0.17, 0.09) * madeira;
	float zc = -prof * (0.45 + 0.25 * h1(semente + 35.0));
	if (tipo == 0) {                                         // mesa com um vaso e cadeira
		float a = caixa(P, D, vec3(-0.55, y0 + 0.70, zc - 0.4), vec3(0.55, y0 + 0.76, zc + 0.4), nn);
		if (a < tm) { tm = a; movcor = wood * (nn.y > 0.5 ? 1.25 : 0.9); }
		a = caixa(P, D, vec3(-0.07, y0, zc - 0.07), vec3(0.07, y0 + 0.70, zc + 0.07), nn);
		if (a < tm) { tm = a; movcor = wood * 0.7; }
		a = caixa(P, D, vec3(-0.12, y0 + 0.76, zc - 0.12), vec3(0.12, y0 + 1.0, zc + 0.12), nn);
		if (a < tm) { tm = a; movcor = vec3(0.45, 0.2, 0.15); }
		a = caixa(P, D, vec3(0.65, y0 + 0.45, zc - 0.25), vec3(1.05, y0 + 0.5, zc + 0.15), nn);
		if (a < tm) { tm = a; movcor = wood * 0.9; }
		a = caixa(P, D, vec3(0.65, y0 + 0.5, zc + 0.12), vec3(1.05, y0 + 1.0, zc + 0.17), nn);
		if (a < tm) { tm = a; movcor = wood * 0.8; }
	} else if (tipo == 1) {                                   // cama de ferro colada numa parede lateral
		float xs = (h1(semente + 37.0) < 0.5) ? 1.0 : -1.0;
		float xa = xs * (rw * 0.5 - 0.5);
		float a = caixa(P, D, vec3(xa - 0.5, y0 + 0.25, -prof * 0.85), vec3(xa + 0.5, y0 + 0.55, -prof * 0.85 + 1.9), nn);
		if (a < tm) { tm = a; movcor = (nn.y > 0.5 ? vec3(0.62, 0.58, 0.5) : vec3(0.35, 0.3, 0.26)); }
		a = caixa(P, D, vec3(xa - 0.4, y0 + 0.55, -prof * 0.85 + 1.5), vec3(xa + 0.4, y0 + 0.65, -prof * 0.85 + 1.85), nn);
		if (a < tm) { tm = a; movcor = vec3(0.8, 0.78, 0.72); }
		a = caixa(P, D, vec3(xa - 0.5, y0 + 0.25, -prof * 0.85 + 1.88), vec3(xa + 0.5, y0 + 1.1, -prof * 0.85 + 1.95), nn);
		if (a < tm) { tm = a; movcor = vec3(0.12, 0.1, 0.09); }
	} else if (tipo == 2) {                                   // estante alta com livros, na parede do fundo
		float a = caixa(P, D, vec3(-0.8, y0, -prof + 0.05), vec3(0.8, y0 + 2.0, -prof + 0.45), nn);
		if (a < tm) {
			tm = a;
			vec3 q = P + D * a;
			float lin = floor((q.y - y0) / 0.4);
			movcor = (nn.z > 0.5) ? mix(wood * 0.6, vec3(0.45 + 0.4 * h1(lin + floor(q.x * 8.0)), 0.18, 0.12), step(0.12, fract((q.y - y0) / 0.4)) * step(0.35, h1(floor(q.x * 8.0) + lin * 7.0))) : wood;
		}
	} else if (tipo == 3) {                                   // baú aos pés e banquinho
		float a = caixa(P, D, vec3(-0.6, y0, zc - 0.3), vec3(0.6, y0 + 0.5, zc + 0.3), nn);
		if (a < tm) { tm = a; movcor = wood * (nn.y > 0.5 ? 1.1 : 0.75); }
		a = caixa(P, D, vec3(0.8, y0, zc - 0.2), vec3(1.15, y0 + 0.42, zc + 0.15), nn);
		if (a < tm) { tm = a; movcor = wood * 0.85; }
	}
	if (acesa && h1(semente + 41.0) < 0.11) {                  // silhueta de alguém em pé, de costas para a janela
		float fx = (h1(semente + 43.0) - 0.5) * rw * 0.5;
		float fz = -prof * 0.68;
		float a = caixa(P, D, vec3(fx - 0.26, y0, fz - 0.14), vec3(fx + 0.26, y0 + 1.45, fz + 0.14), nn);
		if (a < tm) { tm = a; movcor = vec3(0.012); }
		a = caixa(P, D, vec3(fx - 0.14, y0 + 1.45, fz - 0.13), vec3(fx + 0.14, y0 + 1.75, fz + 0.13), nn);
		if (a < tm) { tm = a; movcor = vec3(0.008); }
	}
	if (tm < t) {
		t = tm;
		H = P + D * t;
		mov = true;
	}
	if (mov) {
		col = movcor;
	} else if (eixo == 2) {
		// parede do fundo
		vec2 q = vec2((H.x + rw * 0.5) / rw, (H.y - y0) / pe_direito);
		col = reboco * (0.88 + 0.12 * h2(floor(q * 40.0)));
		if (q.y < 0.1) col *= 0.5;                                          // rodapé escuro
		float sorteio = h1(semente + 7.0);
		if (sorteio < 0.33 && abs(q.x - 0.5) < 0.11 && q.y < 0.68) col = vec3(0.10, 0.06, 0.035);                  // porta ao fundo
		else if (sorteio < 0.66 && q.x > 0.12 && q.x < 0.42 && q.y < 0.6) col = vec3(0.16, 0.09, 0.05) * (0.8 + 0.4 * h2(floor(q * 18.0)));   // armário
		if (q.x > 0.62 && q.x < 0.8 && q.y > 0.5 && q.y < 0.76) col = (q.x > 0.64 && q.x < 0.78 && q.y > 0.52 && q.y < 0.74) ? vec3(0.45, 0.42, 0.3) : vec3(0.25, 0.15, 0.07);   // quadro
	} else if (eixo == 0) {
		// paredes laterais
		vec2 q = vec2(-H.z / prof, (H.y - y0) / pe_direito);
		col = reboco * 0.78 * (0.9 + 0.1 * h2(floor(q * 30.0)));
		if (q.y < 0.1) col *= 0.5;
		if (h1(semente + 11.0) < 0.5 && q.x > 0.35 && q.x < 0.55 && q.y > 0.45 && q.y < 0.72) col = vec3(0.5, 0.38, 0.24);       // quadro na lateral
	} else if (D.y < 0.0) {
		// piso de tábuas
		float tabua = floor(H.x * 4.5);
		float junta = step(0.05, fract(H.x * 4.5));
		col = vec3(0.34, 0.20, 0.11) * (0.65 + 0.5 * h1(tabua + semente * 13.0)) * (0.55 + 0.45 * junta);
		if (h1(semente + 5.0) < 0.5 && abs(H.x) < rw * 0.22 && H.z < -prof * 0.25 && H.z > -prof * 0.8) col = mix(col, vec3(0.42, 0.10, 0.09), 0.85);   // tapete
	} else {
		// teto com vigas
		col = reboco * 0.65;
		if (fract(H.z * 0.8 + semente) < 0.14) col = vec3(0.14, 0.08, 0.05);
	}
	// cortina na janela (fica no plano do vidro): laterais do painel
	vec2 uvp = pos_loc.xy + vec2(0.5);
	float quer_cortina = h1(semente + 17.0);
	if (quer_cortina < 0.45) {
		vec3 cc = CORT[int(floor(h1(semente + 19.0) * 4.0)) % 4];
		float larg = 0.18 + 0.12 * h1(semente + 23.0);
		float dobra = 0.8 + 0.2 * sin(uvp.x * 60.0);
		if (uvp.x < larg || uvp.x > 1.0 - larg) col = cc * dobra;
	}
	// luz do quarto: lâmpada no teto, queda suave com a distância
	vec3 L = vec3(0.0, y1 - 0.25, -prof * 0.5);
	float d = length(H - L);
	float luz = 1.0 / (1.0 + 0.09 * d * d);
	vec3 quente;
	if (acesa) {
		quente = col * cor_luz * (0.55 + 3.2 * luz);
		ALBEDO = vec3(0.01);
		EMISSION = quente * 1.25;
	} else {
		// penumbra: a luz que entra pela própria janela clareia o fundo perto do vidro e some com a profundidade
		float entrada = 0.35 + 0.65 * exp(-0.55 * d * 0.5);
		ALBEDO = col * 0.10;
		EMISSION = col * vec3(0.9, 0.92, 1.0) * 1.8 * entrada;
	}
	ROUGHNESS = 0.05;
	SPECULAR = 0.85;
	METALLIC = 0.0;
}
