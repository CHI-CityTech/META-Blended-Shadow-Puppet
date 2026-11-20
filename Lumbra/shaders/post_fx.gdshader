shader_type canvas_item;
// Full-screen overlay (scenes/fx/post_fx.tscn): darkens the edges and adds a faint moving film grain.

uniform float vignette_strength = 0.55;
uniform float vignette_inner = 0.45;   // 0 = centre, 1 = screen corner
uniform float vignette_outer = 1.05;
uniform float grain_amount = 0.05;
uniform float grain_fps = 24.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float r = length((UV - 0.5) * 2.0) * 0.7071;
	float vig = smoothstep(vignette_inner, vignette_outer, r) * vignette_strength;
	float n = hash(floor(FRAGCOORD.xy) + floor(TIME * grain_fps) * 17.31) - 0.5;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(vig + n * grain_amount, 0.0, 1.0));
}
