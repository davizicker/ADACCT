shader_type spatial;
// Terreno dos morros com texturas reais (ambientCG, CC0), misturadas por inclinação e por manchas:
//   - plano com mato: grama com musgo (Ground037)        - plano seco: terra com cascalho (Ground108)
//   - íngreme:        chão pedregoso com líquen (Ground028) - manchas: barro vermelho (Ground054, tingido)
// A cor do vértice (tools/vila_builder.gd) dá variação de tom. Edite escalas e limites no material assets/materials/terreno.tres.

uniform sampler2D plano_cor : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D plano_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D plano_rug : hint_roughness_r, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ingreme_cor : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ingreme_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ingreme_rug : hint_roughness_r, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grama_cor : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grama_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grama_rug : hint_roughness_r, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D barro_cor : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D barro_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D barro_rug : hint_roughness_r, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float escala_plano = 0.22;
uniform float escala_ingreme = 0.16;
uniform float escala_grama = 0.20;
uniform float escala_barro = 0.24;
uniform float inclinacao_ini = 0.90;   // normal.y acima disso = 100% plano
uniform float inclinacao_fim = 0.66;   // normal.y abaixo disso = 100% íngreme
uniform float forca_normal = 1.0;
uniform vec3 tom_barro : source_color = vec3(1.0, 0.62, 0.48);   // Minas: terra vermelha
uniform float quanto_mato : hint_range(0.0, 1.0) = 0.65;
uniform float quanto_barro : hint_range(0.0, 1.0) = 0.30;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

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
	float ingreme = smoothstep(inclinacao_ini, inclinacao_fim, wnorm.y);                    // 0 plano, 1 íngreme
	float mato = smoothstep(0.40, 0.62, vnoise(wpos.xz * 0.045) * 0.65 + vnoise(wpos.xz * 0.19) * 0.35) * quanto_mato;
	float barro = smoothstep(0.62, 0.78, vnoise(wpos.xz * 0.11 + 31.0)) * quanto_barro * (1.0 - ingreme);
	vec3 c_plano = tri(plano_cor, wpos, wnorm, escala_plano).rgb;
	vec3 c_grama = tri(grama_cor, wpos, wnorm, escala_grama).rgb;
	vec3 c_barro = tri(barro_cor, wpos, wnorm, escala_barro).rgb * tom_barro;
	vec3 c_ingreme = tri(ingreme_cor, wpos, wnorm, escala_ingreme).rgb;
	vec3 base = mix(c_plano, c_grama, mato);
	base = mix(base, c_barro, barro);
	vec3 alb = mix(base, c_ingreme, ingreme);
	ALBEDO = alb * COLOR.rgb;
	float r_base = mix(tri(plano_rug, wpos, wnorm, escala_plano).r, tri(grama_rug, wpos, wnorm, escala_grama).r, mato);
	r_base = mix(r_base, tri(barro_rug, wpos, wnorm, escala_barro).r, barro);
	ROUGHNESS = mix(r_base, tri(ingreme_rug, wpos, wnorm, escala_ingreme).r, ingreme);
	vec3 n_base = mix(texture(plano_normal, wpos.xz * escala_plano).rgb, texture(grama_normal, wpos.xz * escala_grama).rgb, mato);
	n_base = mix(n_base, texture(barro_normal, wpos.xz * escala_barro).rgb, barro);
	NORMAL_MAP = mix(n_base, texture(ingreme_normal, wpos.xz * escala_ingreme).rgb, ingreme);
	NORMAL_MAP_DEPTH = forca_normal;
}
