shader_type spatial;
render_mode cull_disabled;
varying vec3 skin;
void vertex() { skin = VERTEX; }
void fragment() {
	float ribs = .5+.5*cos(9.*atan(skin.y,skin.x)+skin.z*.34);
	float plant = smoothstep(.10,.43,COLOR.g-COLOR.r+.13);
	ALBEDO = COLOR.rgb * mix(1., .83+.20*ribs, plant);
	ROUGHNESS = mix(.56,.41,ribs*plant);
	SPECULAR = .35;
}
