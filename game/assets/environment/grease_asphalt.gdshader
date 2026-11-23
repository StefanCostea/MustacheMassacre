shader_type spatial;
varying vec2 street;
void vertex() {street=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
float grit(vec2 p){return fract(sin(dot(p,vec2(19.73,87.43)))*43758.55);}
void fragment(){
	vec2 slab=fract((street+vec2(.7,.9))/3.0);
	float joint=smoothstep(.0,.018,min(min(slab.x,1.-slab.x),min(slab.y,1.-slab.y)));
	float oil=smoothstep(.45,.94,sin(street.y*.43+sin(street.x*.65))*cos(street.x*.6-street.y*.13));
	float fleck=grit(floor(street*37.));
	vec3 stone=mix(vec3(.057,.069,.071),vec3(.135,.14,.132),fleck*.54);
	ALBEDO=mix(vec3(.023,.027,.025),mix(stone,vec3(.028,.035,.031),oil*.76),joint);
	ROUGHNESS=mix(.90,.29,oil);
}
