shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
// Água de riacho à noite: escura, com ondulação que corre e brilho forte nas luzes.
// Edite as cores no material assets/materials/agua.tres.

uniform vec4 cor : source_color = vec4(0.015, 0.05, 0.07, 0.88);
uniform float velocidade = 0.35;
uniform float ondulacao = 0.35;

varying vec3 wpos;

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

float height(vec2 p) {
	return vnoise(p * 1.7 + vec2(TIME * velocidade, 0.0)) * 0.6 + vnoise(p * 4.1 - vec2(TIME * velocidade * 1.6, 0.0)) * 0.4;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float e = 0.08;
	float h = height(p);
	float dx = height(p + vec2(e, 0.0)) - h;
	float dz = height(p + vec2(0.0, e)) - h;
	vec3 wn = normalize(vec3(-dx / e * ondulacao, 1.0, -dz / e * ondulacao));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ALBEDO = cor.rgb + vec3(h * 0.03);
	ALPHA = cor.a;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	METALLIC = 0.1;
}
