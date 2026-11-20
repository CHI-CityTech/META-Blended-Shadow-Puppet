shader_type canvas_item;
render_mode blend_add;
// Beam quads from BeamLayer: UV.x = distance from the source in cells, UV.y = 0..1 across the beam.
// Pulses travel away from the source; each one swells the core and halo so it reads even on lit tiles.

uniform float core_width = 0.2;      // set from Look.BEAM_WIDTH / Look.BEAM_GLOW_WIDTH
uniform float halo_strength = 0.45;
uniform float flow_speed = 1.6;      // cells per second, away from the source
uniform float pulse_spacing = 1.2;   // cells between pulses
uniform float pulse_swell = 1.0;     // how much a pulse widens the core

void fragment() {
	float v = abs(UV.y - 0.5) * 2.0;                       // 0 at the centre line, 1 at the edge
	float phase = fract((UV.x - TIME * flow_speed) / pulse_spacing);
	float pulse = pow(sin(phase * PI), 12.0);              // 0..1, a short bright band
	float cw = core_width * (1.0 + pulse_swell * pulse);
	float core = 1.0 - smoothstep(cw * 0.5, cw, v);
	float halo = pow(1.0 - v, 2.5) * halo_strength * (0.5 + 1.5 * pulse);
	float i = core * (0.75 + 0.6 * pulse) + halo;
	COLOR = vec4(COLOR.rgb * i, COLOR.a * clamp(i, 0.0, 1.0));
}
