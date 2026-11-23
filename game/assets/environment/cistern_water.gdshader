shader_type spatial;
render_mode diffuse_burley;

void fragment() {
	vec2 p = (UV-vec2(.08,.52))*vec2(2.2,.69);
	float distance_from_drip = length(p);
	float crests = sin(distance_from_drip*55.-TIME*3.1);
	float glint = smoothstep(.89,.99,crests)*exp(-distance_from_drip*2.7);
	float edge = min(min(UV.x*2.5, (1.-UV.x)*2.5),min(UV.y,1.-UV.y));
	vec3 lagoon = mix(vec3(.030,.14,.135),vec3(.065,.235,.203),smoothstep(0.,.20,edge));
	ALBEDO = lagoon + glint * vec3(.12,.17,.13);
	ROUGHNESS = .27;
	METALLIC = .18;
}
