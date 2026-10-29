shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
// RIO: água que corre ao longo do eixo X das UVs (metros ao longo da faixa); UV.y = distância ao eixo. Três camadas de ondas em velocidades diferentes, faixas de espuma que
// descem a correnteza, borda espumosa junto às margens, cor que clareia nas bordas (rasa) e escurece no meio (funda) e reflexo
// do céu/lua por fresnel. Não depende de textura de tela nem de profundidade: funciona igual em qualquer renderizador.
// Edite as cores no material assets/materials/agua.tres.

uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform vec3 cor_rasa : source_color = vec3(0.10, 0.20, 0.18);
uniform vec3 cor_funda : source_color = vec3(0.025, 0.07, 0.10);
uniform vec3 cor_ceu : source_color = vec3(0.16, 0.24, 0.40);
uniform vec3 cor_espuma : source_color = vec3(0.62, 0.68, 0.70);
uniform float velocidade = 0.9;
uniform float ondulacao = 0.5;
uniform float meia_largura = 3.7;

varying vec2 pl;     // posição no plano (metros): X = sentido da correnteza, Y = através do rio

void vertex() {
	pl = UV;
}

float ond(vec2 p, float t) {
	float a = texture(ruido, p * 0.11 + vec2(t * 0.35, 0.0)).r;
	float b = texture(ruido, p * 0.27 + vec2(t * 0.8, t * 0.1) + 3.7).r;
	float c = texture(ruido, p * 0.6 + vec2(t * 1.5, -t * 0.2) + 8.1).r;
	return a * 0.6 + b * 0.3 + c * 0.1;
}

void fragment() {
	float t = TIME * velocidade;
	vec2 p = pl * vec2(1.0, 1.6);
	float e = 0.08;
	float h = ond(p, t);
	float dx = ond(p + vec2(e, 0.0), t) - h;
	float dz = ond(p + vec2(0.0, e), t) - h;
	vec3 wn = normalize(vec3(-dx / e * ondulacao * 0.3, 1.0, -dz / e * ondulacao * 0.3));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	float lateral = abs(pl.y) / meia_largura;                  // 0 no meio, 1 na margem
	float rasa = smoothstep(0.35, 1.0, lateral);
	vec3 col = mix(cor_funda, cor_rasa, rasa);
	col += vec3(0.02, 0.035, 0.03) * h;

	// espuma: margem + faixas que descem a correnteza + riscos finos
	float faixa = texture(ruido, p * vec2(0.42, 0.9) + vec2(t * 0.9, 0.0)).r;
	float fino = texture(ruido, p * vec2(0.9, 1.6) + vec2(t * 1.6, 3.0)).r;
	float borda = smoothstep(0.72, 1.0, lateral) * (0.5 + 0.9 * faixa);
	float riscos = smoothstep(0.80, 0.97, faixa) * smoothstep(0.55, 0.85, fino) * (0.4 + 0.6 * rasa);
	float espuma = clamp(borda + riscos * 0.7, 0.0, 1.0);
	col = mix(col, cor_espuma * (0.55 + 0.45 * fino), espuma);

	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = col;
	EMISSION = (cor_ceu * (0.85 + 2.2 * fres) + col * 0.5) * (1.0 - espuma * 0.6);
	ALPHA = clamp(0.93 + espuma * 0.07, 0.0, 1.0);
	ROUGHNESS = mix(0.10, 0.6, espuma);
	SPECULAR = 0.8;
	METALLIC = 0.0;
}
