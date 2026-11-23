shader_type spatial;
render_mode diffuse_burley;

uniform vec4 sand_color : source_color = vec4(0.45,0.255,0.11,1.0);
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float broad=noise(world.xz*0.34)*0.6+noise(world.xz*1.7)*0.25+noise(world.xz*9.0)*0.15;
	float fleck=step(0.86,noise(world.xz*53.0));
	float tracks=(1.0-smoothstep(0.07,0.18,abs(abs(world.x+0.22*sin(world.z*0.5))-2.8)))*0.07;
	ALBEDO=sand_color.rgb*(0.72+broad*0.55-tracks)+fleck*0.025;
	ROUGHNESS=0.96;
	float grain=noise(world.xz*70.0);
	NORMAL_MAP=normalize(vec3(dFdx(grain)*0.15,dFdy(grain)*0.15,1.0))*0.5+0.5;
}
