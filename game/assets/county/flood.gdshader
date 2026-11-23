shader_type spatial;
render_mode cull_disabled;
varying vec2 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){
	float swell=sin(world.y*3.3+TIME*4.+sin(world.x*1.7)*.8);
	float ripple=sin(world.x*4.1-world.y*2.1+TIME*2.7);
	float crest=smoothstep(.72,1.0,swell*.7+ripple*.3);
	ALBEDO=mix(vec3(.07,.39,.48),vec3(.65,.90,.85),crest);
	ROUGHNESS=.27;METALLIC=.22;ALPHA=.43+.28*crest;
}
