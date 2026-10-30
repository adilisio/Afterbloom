shader_type spatial;
// Soft glowing mote / spore. Use with GPUParticles3D.transform_align = Z_BILLBOARD.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.7, 0.45, 1.0);
uniform float energy = 3.0;
uniform float fade = 1.0;
uniform float near_fade = 0.6;

varying float v_dist;

void vertex() {
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float core = exp(-d * d * 18.0);
	float halo = exp(-d * d * 4.0) * 0.25;
	float a = (core + halo) * smoothstep(1.0, 0.85, d);
	a *= smoothstep(near_fade * 0.4, near_fade, v_dist) * fade * COLOR.a;
	ALBEDO = tint * COLOR.rgb * energy * a;
}
