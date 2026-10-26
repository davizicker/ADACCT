shader_type sky;
// Céu noturno com nuvens macias, estrelas e LUA (na direção da luz "Lua" da cena).
// Edite as cores/tamanhos no material assets/materials/ceu.tres.

uniform vec3 top_color : source_color = vec3(0.016, 0.034, 0.105);
uniform vec3 horizon_color : source_color = vec3(0.115, 0.165, 0.300);
uniform vec3 cloud_dark : source_color = vec3(0.060, 0.080, 0.150);
uniform vec3 cloud_lit : source_color = vec3(0.300, 0.370, 0.540);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.50;
uniform float cloud_speed = 0.0035;
uniform float star_strength : hint_range(0.0, 2.0) = 1.0;
uniform float moon_size = 0.040;       // raio angular (radianos)
uniform vec3 moon_color : source_color = vec3(0.92, 0.95, 1.0);
uniform float moon_glow : hint_range(0.0, 2.0) = 1.0;

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
	vec3 col = mix(horizon_color, top_color, pow(h, 0.42));
	float cl = 0.0;
	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.28) * 1.25 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.3);
		float c = fbm(uv);
		float lo = 0.60 - cloud_cover * 0.42;
		cl = smoothstep(lo, lo + 0.40, c);                      // borda larga e macia
		cl *= smoothstep(0.0, 0.20, dir.y) * 0.80;              // some perto do horizonte, nunca é opaca
		float edge = clamp((fbm(uv + vec2(0.05, 0.035)) - c) * 5.0 + 0.5, 0.0, 1.0);
		vec3 ccol = mix(cloud_dark, cloud_lit, edge * 0.8);
		col = mix(col, ccol, cl);
		// estrelas (só onde não há nuvem)
		vec2 sp = dir.xz / (dir.y + 0.001) * 18.0;
		vec2 cell = floor(sp);
		float st = step(0.9965, hash(cell));
		float tw = 0.6 + 0.4 * sin(TIME * 2.0 + hash(cell + 7.0) * 30.0);
		col += vec3(0.8, 0.85, 1.0) * st * tw * star_strength * (1.0 - cl) * smoothstep(0.12, 0.4, dir.y);
	} else {
		col = mix(horizon_color * 0.7, vec3(0.02, 0.03, 0.05), clamp(-dir.y * 3.0, 0.0, 1.0));
	}
	// lua: disco com "mares" e halo; as nuvens a cobrem em parte
	if (LIGHT0_ENABLED) {
		vec3 L = normalize(LIGHT0_DIRECTION);
		float ang = acos(clamp(dot(dir, L), -1.0, 1.0));
		vec3 up = abs(L.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
		vec3 tx = normalize(cross(up, L));
		vec3 ty = cross(L, tx);
		vec2 m = vec2(dot(dir, tx), dot(dir, ty)) / moon_size;
		float disc = smoothstep(1.0, 0.93, length(m));
		float maria = fbm(m * 1.8 + 3.0);
		vec3 surf = mix(moon_color, moon_color * vec3(0.55, 0.60, 0.72), smoothstep(0.42, 0.66, maria) * 0.7);
		surf *= 0.8 + 0.25 * (1.0 - length(m) * 0.5);
		float glow = (exp(-pow(ang / (moon_size * 2.6), 2.0)) * 0.55 + exp(-pow(ang / (moon_size * 9.0), 2.0)) * 0.22) * moon_glow;
		float vis = 1.0 - cl * 0.8;
		col += vec3(0.50, 0.60, 0.85) * glow * vis * 0.55;
		col = mix(col, surf * 3.0, disc * vis);
	}
	COLOR = col;
}
