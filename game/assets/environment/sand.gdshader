shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D hardpan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_paint : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec2 street;

void vertex() {
	street = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

vec2 mirror_tile(vec2 p) {
	return 1.0 - abs(fract(p * 0.5) * 2.0 - 1.0);
}

void fragment() {
	vec2 uv = street / vec2(21.6, 14.4) + vec2(.41,.25);
	vec3 clay = texture(hardpan, mirror_tile(uv)).rgb;
	float detail = texture(hardpan, mirror_tile(street.yx * .27 + vec2(.34,.67))).g;
	// Two wagon routes share the north approach and diverge at the saloon.
	float west_route = street.x + 3.1 + street.y * .30 + sin(street.y*.33)*.58;
	float east_route = street.x - 5.4 - street.y * .57 - sin(street.y*.22)*1.18;
	float shoulder = min(abs(west_route),abs(east_route));
	float road = 1.0-smoothstep(1.0,3.1,shoulder + .38*(detail-.4));
	float rut = min(abs(abs(west_route)-.74),abs(abs(east_route)-.72));
	float wheel = (1.0 - smoothstep(.025,.12,rut)) * smoothstep(.12,.48,detail);
	float luma = dot(clay,vec3(.28,.57,.15));
	vec3 mineral = mix(vec3(luma),clay,.72) * vec3(.57,.49,.46);
	vec3 dust = mineral * vec3(1.25,1.28,1.20) + vec3(.019,.015,.010);
	ALBEDO = mix(mineral,dust,road*.78) * (.93 + .14*detail) * (1.0-.26*wheel);
	vec2 layout = street / vec2(39.0,29.0) + .5;
	vec2 edge = min(layout, 1.-layout);
	float within = smoothstep(-.02,.10,min(edge.x,edge.y));
	vec3 paint = texture(road_paint,clamp(layout,vec2(.001),vec2(.999))).rgb;
	float value = dot(paint, vec3(.28,.57,.15));
	paint = mix(vec3(value),paint,.71) * vec3(.84,.80,.78);
	ALBEDO = mix(ALBEDO,paint*(.82+.63*luma), .77*within);
	ROUGHNESS = .93;
}
