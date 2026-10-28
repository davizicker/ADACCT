shader_type spatial;
// SUPERFÍCIE MISTA: mistura duas texturas PBR reais (A e B) em manchas orgânicas, em coordenadas do MUNDO (triplanar),
// com manchas escuras de umidade (escorridos verticais) e variação de cor por parede. Para paredes, pisos e tetos.
// Mapas de normal triplanares (método "whiteout"). Ruído: assets/textures/ruido_mistura.png (sem emenda).

uniform sampler2D albedo_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D albedo_b : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float escala = 0.22;
uniform float escala_ruido = 0.09;
uniform float mistura : hint_range(0.0, 1.0) = 0.45;
uniform float contraste = 5.0;
uniform float sujeira : hint_range(0.0, 1.0) = 0.3;
uniform float normal_forca = 1.0;
uniform float rough = 0.93;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 pesos(vec3 n) {
	vec3 w = pow(abs(n), vec3(6.0));
	return w / (w.x + w.y + w.z + 1e-5);
}

#define TRI(T, P, W, S) (texture(T, (P).zy * (S)) * (W).x + texture(T, (P).xz * (S)) * (W).y + texture(T, (P).xy * (S)) * (W).z)

// mapa de normal triplanar (método "whiteout"): recebe as 3 amostras já lidas
vec3 normal_tri(vec3 tx, vec3 ty, vec3 tz, vec3 n, vec3 w, float forca) {
	tx = tx * 2.0 - 1.0;
	ty = ty * 2.0 - 1.0;
	tz = tz * 2.0 - 1.0;
	tx.xy *= forca;
	ty.xy *= forca;
	tz.xy *= forca;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 w = pesos(n);
	float m = TRI(ruido, wpos, w, escala_ruido).r;
	float k = clamp((m - (1.0 - mistura)) * contraste + 0.5, 0.0, 1.0);
	vec3 aa = TRI(albedo_a, wpos, w, escala).rgb;
	vec3 bb = TRI(albedo_b, wpos, w, escala * 1.07).rgb;
	vec3 alb = mix(aa, bb, k) * tint;
	// manchas de umidade: ruído esticado na vertical (escorridos)
	float s2 = TRI(ruido, wpos * vec3(0.7, 0.18, 0.7) + vec3(3.1, 0.0, 7.7), w, escala_ruido * 2.3).r;
	alb *= 1.0 - sujeira * smoothstep(0.52, 0.85, s2);
	// variação macro: cada parede sai um pouco diferente da vizinha
	float v = TRI(ruido, wpos + vec3(11.0, 3.0, 5.0), w, escala_ruido * 0.35).r;
	alb *= 0.9 + 0.2 * v;
	ALBEDO = alb;
	ROUGHNESS = rough;
	float sb = escala * 1.07;
	vec3 na = normal_tri(texture(normal_a, wpos.zy * escala).xyz, texture(normal_a, wpos.xz * escala).xyz, texture(normal_a, wpos.xy * escala).xyz, n, w, normal_forca);
	vec3 nb = normal_tri(texture(normal_b, wpos.zy * sb).xyz, texture(normal_b, wpos.xz * sb).xyz, texture(normal_b, wpos.xy * sb).xyz, n, w, normal_forca);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mix(na, nb, k)), 0.0)).xyz);
}
