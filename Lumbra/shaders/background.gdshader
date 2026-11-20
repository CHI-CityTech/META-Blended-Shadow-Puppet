shader_type canvas_item;
// Full-screen backdrop (scenes/fx/background.tscn): warm light drifting in from the top-left,
// violet shadow from the bottom-right, soft light rays and slow floating motes. Kept dark so the board pops.

uniform vec3 base_color : source_color = vec3(0.03, 0.026, 0.05);
uniform vec3 light_color : source_color = vec3(0.62, 0.44, 0.16);
uniform vec3 shadow_color : source_color = vec3(0.26, 0.12, 0.48);
uniform float drift_speed = 0.035;
uniform float ray_strength = 0.18;
uniform float mote_strength = 0.7;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = vec2(UV.x * aspect, UV.y);
	float t = TIME * drift_speed;

	float clouds_l = fbm(p * 2.2 + vec2(t, -t * 0.6));
	float clouds_s = fbm(p * 2.6 - vec2(t * 0.8, t * 0.4) + 7.3);
	float light_mask = 1.0 - smoothstep(0.0, 1.25, length(UV - vec2(0.0, 0.0)));
	float shadow_mask = 1.0 - smoothstep(0.0, 1.25, length(UV - vec2(1.0, 1.0)));

	vec3 col = base_color;
	col += light_color * light_mask * clouds_l * clouds_l * 1.3;
	col += shadow_color * shadow_mask * clouds_s * 1.0;

	// soft diagonal rays falling from the light corner
	float rays = pow(max(0.0, sin((UV.x * 0.8 - UV.y * 0.45) * 22.0 + clouds_l * 4.0 + TIME * 0.12)), 18.0);
	col += light_color * rays * light_mask * ray_strength;

	// slow floating motes that twinkle
	vec2 g = p * 26.0 + vec2(TIME * 0.05, -TIME * 0.18);
	vec2 id = floor(g);
	float h = hash(id);
	if (h > 0.93) {
		vec2 c = vec2(hash(id + 3.1), hash(id + 7.7)) * 0.6 + 0.2;
		float d = length(fract(g) - c);
		float twinkle = 0.5 + 0.5 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
		vec3 mote_col = mix(shadow_color * 2.2, light_color * 1.8, step(0.965, h));
		col += mote_col * smoothstep(0.08, 0.0, d) * twinkle * mote_strength;
	}
	COLOR = vec4(col, 1.0);
}
