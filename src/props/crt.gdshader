shader_type spatial;
render_mode unshaded, cull_back;
// CRT screen: barrel curvature, scanlines, aperture mask, bloom-ish glow, noise, roll, power on/off.

uniform sampler2D screen : source_color, filter_linear;
uniform float power = 1.0;
uniform float noise_amt = 0.04;
uniform float aged = 0.0;
uniform float brightness = 1.25;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	uv = 0.5 + c * (1.0 + 0.12 * r2);
	// power-on: picture expands from a horizontal line
	float p = clamp(power, 0.0, 1.0);
	float sy = mix(0.004, 1.0, smoothstep(0.0, 0.6, p));
	float sx = mix(0.05, 1.0, smoothstep(0.0, 0.25, p));
	vec2 puv = 0.5 + (uv - 0.5) / vec2(sx, sy);
	vec3 col = vec3(0.0);
	if (puv.x > 0.0 && puv.x < 1.0 && puv.y > 0.0 && puv.y < 1.0) {
		float roll = sin(TIME * 0.7) * 0.0015;
		vec2 suv = puv + vec2(roll * sin(puv.y * 40.0 + TIME * 6.0), 0.0);
		col.r = texture(screen, suv + vec2(0.0015, 0.0)).r;
		col.g = texture(screen, suv).g;
		col.b = texture(screen, suv - vec2(0.0015, 0.0)).b;
		// warm, slightly desaturated 1967 colour
		float l = dot(col, vec3(0.3, 0.59, 0.11));
		col = mix(vec3(l), col, 0.75) * vec3(1.05, 1.0, 0.92);
		float scan = 0.82 + 0.18 * sin(puv.y * 480.0 * 3.14159);
		float mask = 0.9 + 0.1 * sin(FRAGCOORD.x * 2.1);
		col *= scan * mask;
		float n = hash(puv * 640.0 + fract(TIME) * 100.0);
		col = mix(col, vec3(n), noise_amt + aged * 0.25);
		col *= 1.0 - smoothstep(0.18, 0.32, r2) * 0.6;
		col *= brightness * p;
	}
	// glass reflection sheen
	float sheen = smoothstep(0.35, 0.0, distance(UV, vec2(0.3, 0.25))) * 0.06;
	ALBEDO = col + vec3(sheen);
	if (p < 0.02) {
		ALBEDO = vec3(0.025, 0.028, 0.03) + vec3(sheen * 1.5);
	}
}
