shader_type spatial;
// Terreno dos morros: mistura duas texturas reais (ambientCG, CC0) pela inclinação.
//  - partes planas:    terra com cascalho (Ground108)
//  - partes íngremes:  chão pedregoso com líquen (Ground028)
// A cor do vértice (definida em tools/vila_builder.gd) dá variação de tom entre áreas.
// Edite escalas e limites no material assets/materials/terreno.tres.

uniform sampler2D plano_cor : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D plano_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D plano_rug : hint_roughness_r, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ingreme_cor : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ingreme_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ingreme_rug : hint_roughness_r, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float escala_plano = 0.22;
uniform float escala_ingreme = 0.16;
uniform float inclinacao_ini = 0.88;   // normal.y acima disso = 100% plano
uniform float inclinacao_fim = 0.62;   // normal.y abaixo disso = 100% íngreme
uniform float forca_normal = 1.0;
uniform vec3 tom_verde : source_color = vec3(0.80, 1.0, 0.70);
uniform float verde = 0.35;            // quanto "mato" (tom verde) nas partes planas

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 tri(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(t, p.zy * s) * w.x + texture(t, p.xz * s) * w.y + texture(t, p.xy * s) * w.z;
}

void fragment() {
	float m = smoothstep(inclinacao_ini, inclinacao_fim, wnorm.y);   // 0 plano, 1 íngreme
	vec4 cp = tri(plano_cor, wpos, wnorm, escala_plano);
	vec4 ci = tri(ingreme_cor, wpos, wnorm, escala_ingreme);
	vec3 alb = mix(cp.rgb, ci.rgb, m);
	alb = mix(alb, alb * tom_verde, verde * (1.0 - m));
	ALBEDO = alb * COLOR.rgb;
	float rp = tri(plano_rug, wpos, wnorm, escala_plano).r;
	float ri = tri(ingreme_rug, wpos, wnorm, escala_ingreme).r;
	ROUGHNESS = mix(rp, ri, m);
	// relevo: normal map projetado de cima (usa o tangente gerado do mapeamento por X/Z)
	vec3 np = texture(plano_normal, wpos.xz * escala_plano).rgb;
	vec3 ni = texture(ingreme_normal, wpos.xz * escala_ingreme).rgb;
	NORMAL_MAP = mix(np, ni, m);
	NORMAL_MAP_DEPTH = forca_normal;
}
