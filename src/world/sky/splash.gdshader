shader_type spatial;
// Rain splash ring on the ground (sub-emitter at collision). Flat quad facing +Y.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 rain_color : source_color = vec3(0.7, 0.75, 0.8);
uniform float opacity = 0.35;

varying float v_life;

void vertex() {
	v_life = INSTANCE_CUSTOM.y;
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float rad = 0.15 + v_life * 0.85;
	float ring = smoothstep(0.14, 0.0, abs(r - rad));
	ALBEDO = rain_color;
	ALPHA = ring * (1.0 - v_life) * opacity * COLOR.a;
}
