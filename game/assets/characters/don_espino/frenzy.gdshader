shader_type spatial;
render_mode cull_disabled;
varying vec3 local_position;
void vertex() { local_position=VERTEX; }
void fragment() {
	float strand=sin(UV.x*190.0+UV.y*8.0)*0.5+0.5;
	ALBEDO=mix(vec3(.55,.25,.035),vec3(1.0,.67,.17),strand*.35+.65);
	METALLIC=.72;
	ROUGHNESS=.32;
	EMISSION=vec3(1.0,.52,.08)*(.28+.15*sin(TIME*5.0+local_position.x*3.0));
}
