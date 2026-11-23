shader_type spatial;
render_mode cull_disabled;

uniform sampler2D hair_atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_metal_atlas : filter_linear_mipmap, repeat_enable;
uniform sampler2D grooves : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float groove_depth = 0.0;
instance uniform float gild = 0.0;
instance uniform float fan = 0.0;

void fragment() {
	float reach = clamp(UV2.x, 0.0, 1.0);
	bool vane = UV2.y > 0.5;
	if (vane && fan < 0.002) {
		discard;
	}
	vec3 chestnut = texture(hair_atlas, UV).rgb;
	float dye = smoothstep(reach * 0.52, reach * 0.52 + 0.36, gild);
	float fibre = vane ? pow(0.5 + 0.5 * cos(6.283 * (UV.y * 15.0 + 0.35 * sin(UV.x * 6.0))), 4.0) : 0.0;
	float tone = vane ? clamp(COLOR.r * 1.16 + 0.15 * fibre, 0.0, 1.0) : clamp(0.16 + 3.3 * chestnut.r, 0.0, 1.0);
	vec3 gold = mix(vec3(0.25, 0.068, 0.008), vec3(1.0, 0.60, 0.14), tone);
	ALBEDO = mix(vane ? COLOR.rgb : chestnut, gold, dye);
	vec2 rough_metal = texture(rough_metal_atlas, UV).gb;
	METALLIC = mix(vane ? 0.0 : rough_metal.y, 0.27, dye);
	ROUGHNESS = mix(vane ? 0.65 : rough_metal.x, 0.43, dye);
	NORMAL_MAP = texture(grooves, UV).rgb;
	NORMAL_MAP_DEPTH = vane ? 0.0 : groove_depth * mix(1.0, 0.3, dye);
	EMISSION = gold * dye * (0.075 + 0.05 * fibre);
}
