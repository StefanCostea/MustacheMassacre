shader_type spatial;
varying vec3 shell;
void vertex() {
	shell = normalize(vec3(VERTEX.x / .205, VERTEX.y / .265, VERTEX.z / .205));
	VERTEX.xz *= 1.0 - .18 * shell.y;
}
void fragment() {
	vec3 cell = floor(shell * 16.);
	float seed = fract(sin(dot(cell, vec3(17.17, 43.61, 91.13))) * 4375.73);
	float freckles = smoothstep(.81, .95, seed) * (1. - smoothstep(.18, .48, length(fract(shell*16.)-.5)));
	vec3 chalk = mix(vec3(.94,.77,.48), vec3(.30,.14,.06), freckles*.80);
	float stripe = 1.-smoothstep(.116,.132,abs(shell.y+.13));
	float lip = 1.-smoothstep(.015,.028,abs(abs(shell.y+.13)-.134));
	float ticks = step(.58,cos(10.*atan(shell.z,shell.x)+shell.y*9.));
	ALBEDO = mix(mix(chalk, mix(vec3(.32,.027,.045),vec3(.91,.15,.15),ticks),stripe),vec3(.64,.36,.09),lip);
	ROUGHNESS = mix(.65,.38,max(stripe,lip));
	METALLIC = .35*lip;
}
