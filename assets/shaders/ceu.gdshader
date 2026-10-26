shader_type sky;
// Céu noturno azul com nuvens e estrelas. Edite as cores no material assets/materials/ceu.tres.

uniform vec3 top_color : source_color = vec3(0.020, 0.045, 0.120);
uniform vec3 horizon_color : source_color = vec3(0.140, 0.200, 0.340);
uniform vec3 cloud_dark : source_color = vec3(0.045, 0.060, 0.110);
uniform vec3 cloud_lit : source_color = vec3(0.230, 0.290, 0.440);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_speed = 0.004;
uniform float star_strength : hint_range(0.0, 2.0) = 1.0;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.45));
	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.30) * 1.3 + vec2(TIME * cloud_speed, 0.0);
		float c = fbm(uv);
		float cl = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.22, c);
		float edge = clamp((fbm(uv + vec2(0.06, 0.04)) - c) * 6.0 + 0.5, 0.0, 1.0);
		vec3 ccol = mix(cloud_dark, cloud_lit, edge);
		col = mix(col, ccol, cl * smoothstep(0.0, 0.12, dir.y));
		// estrelas (só onde não há nuvem)
		vec2 sp = dir.xz / (dir.y + 0.001) * 18.0;
		vec2 cell = floor(sp);
		float st = step(0.9965, hash(cell));
		float tw = 0.6 + 0.4 * sin(TIME * 2.0 + hash(cell + 7.0) * 30.0);
		col += vec3(0.8, 0.85, 1.0) * st * tw * star_strength * (1.0 - cl) * smoothstep(0.12, 0.4, dir.y);
	} else {
		col = mix(horizon_color * 0.7, vec3(0.02, 0.03, 0.05), clamp(-dir.y * 3.0, 0.0, 1.0));
	}
	COLOR = col;
}
