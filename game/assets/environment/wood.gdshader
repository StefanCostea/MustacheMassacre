shader_type spatial;
uniform vec4 tint : source_color = vec4(.35,.20,.09,1);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
	float drift=noise(UV*vec2(6,2));
	float grain=noise(vec2(UV.x*80.0+drift*6.0,UV.y*2.5));
	float streak=pow(abs(sin(UV.x*145.0+drift*5.0)),24.0);
	float nick=step(.92,noise(UV*vec2(190,25)));
	ALBEDO=tint.rgb*(.76+grain*.42-streak*.10)+nick*.022;
	ROUGHNESS=.83;
}
