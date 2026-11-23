shader_type spatial;
uniform sampler2D painted : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 object_point;
varying vec3 object_normal;

float hash(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
void vertex() {
	object_point = VERTEX;
	object_normal = NORMAL;
}
void fragment() {
	vec3 color = texture(painted, UV).rgb;
	float straw = smoothstep(1.1,1.8,color.r/max(.008,color.g));
	float lengthwise = mix(object_point.x, object_point.z, smoothstep(.52,.87,abs(object_normal.x)));
	float across = mix(object_point.z,object_point.y,smoothstep(.48,.85,max(abs(object_normal.x),object_normal.y)));
	vec2 stem = vec2(lengthwise*7.0,across*68.+2.2*sin(lengthwise*4.+across));
	float offset = hash(vec2(0.,floor(stem.y)));
	stem.x += offset;
	float ink = hash(floor(stem));
	float stroke = smoothstep(.08,.30,fract(stem.x))*(1.-smoothstep(.66,1.,fract(stem.x)));
	float groove = (1.-smoothstep(.10,.45,abs(fract(stem.y)-.5))) * stroke * ink;
	float filtered = 1.-smoothstep(.42,1.5,fwidth(stem.y));
	vec3 grain = vec3(.78,1.14,1.32)*(1.+(.54*groove-.12)*filtered);
	ALBEDO = color * mix(vec3(.78,.82,.80),grain,straw) + straw*vec3(.009,.012,.013);
	ROUGHNESS = .94;
}
