shader_type spatial;
// Rain streak. Used with GPUParticles3D.transform_align = Z_BILLBOARD_Y_TO_VELOCITY on a thin QuadMesh.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 rain_color : source_color = vec3(0.7, 0.75, 0.8);
uniform float opacity = 0.3;

varying float v_dist;

void vertex() {
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float a = (1.0 - x * x) * smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.55, UV.y);
	a *= smoothstep(0.5, 2.5, v_dist) * opacity * COLOR.a;
	ALBEDO = rain_color;
	ALPHA = clamp(a, 0.0, 1.0);
}
