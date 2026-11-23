shader_type spatial;
render_mode cull_disabled;
varying vec2 county;
void vertex(){ county=(MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
float hash(vec2 p){return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453);}
float grain(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
float district(vec2 p,vec2 center){return 1.-smoothstep(11.,17.,length((p-center)*vec2(.9,1.)));}
void fragment(){
 vec2 p=county;
 float dust=grain(p*.53)*.10+grain(p*5.)*.035;
 vec3 base=vec3(.37,.215,.11)+dust;
 float road=1.-smoothstep(2.1,3.8,min(min(abs(p.y-8.),abs(p.y+26.)),min(abs(p.x+30.),abs(p.x-27.))));
 base=mix(base,vec3(.52,.359,.205)+dust*.55,road*.88);
 float city=district(p,vec2(26.,5.)), park=district(p,vec2(-22.,-26.)), palace=district(p,vec2(23.,-29.));
 float oil=smoothstep(.51,.94,sin(p.y*.43+sin(p.x*.65))*cos(p.x*.60-p.y*.13));
 vec2 slab=fract((p+vec2(.7,.9))/3.);
 float seam=smoothstep(0.,.019,min(min(slab.x,1.-slab.x),min(slab.y,1.-slab.y)));
 vec3 asphalt=mix(vec3(.091,.115,.12),vec3(.117,.151,.157)+dust*.42,seam);
 base=mix(base,asphalt+vec3(.04,.011,.05)*oil,city);
 vec2 brick=p*vec2(.8,1.3);brick.x+=.5*mod(floor(brick.y),2.);float joint=min(fract(brick.x),fract(brick.y));
 base=mix(base,mix(vec3(.18,.087,.105),vec3(.39,.18,.185)+dust*.6,smoothstep(.01,.07,joint)),park);
 vec2 tile=floor(p*.65);float checker=mod(tile.x+tile.y,2.);
 base=mix(base,mix(vec3(.50,.48,.53),vec3(.72,.66,.57),checker)+sin(p.y*5.+grain(p*.8)*7.)*.022,palace);
 ALBEDO=base;ROUGHNESS=.92-city*(.36+.4*oil)-palace*.4;
}
