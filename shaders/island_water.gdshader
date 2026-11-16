shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float angle = atan(p.y, p.x);
	float coast = length(p) - (22.0 + 1.4 * sin(angle * 3.0) + 0.7 * cos(angle * 5.0));
	float deep = smoothstep(2.5, 8.0, coast);
	float ripple = sin(p.x * 0.8 + TIME * 1.3) * sin(p.y * 0.55 - TIME * 0.8);
	vec3 water = mix(vec3(0.22, 0.69, 0.70), vec3(0.06, 0.27, 0.43), deep);
	float foam = (1.0 - smoothstep(0.0, 0.55, abs(coast - 0.18 * sin(TIME)))) * 0.4;
	ALBEDO = mix(water + ripple * 0.012, vec3(0.84, 0.94, 0.87), foam);
	ROUGHNESS = 0.32;
	SPECULAR = 0.35;
	ALPHA = mix(0.54, 1.0, deep);
}
