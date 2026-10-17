shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.2,0.2,0.2,1.0);
uniform vec3 head_world;
uniform vec3 torso_world;
uniform vec3 left_arm_world;
uniform vec3 right_arm_world;
uniform vec3 left_leg_world;
uniform vec3 right_leg_world;
uniform vec3 region_hp = vec3(100.0);
uniform vec3 leg_hp = vec3(100.0);
varying vec3 world_surface;
void vertex() {
	world_surface = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
float region_distance(vec3 pixel, vec3 world, float radius) {
	return length(pixel-world)/radius;
}
vec3 damage_color(float health) {
	if (health >= 80.0) return base_color.rgb;
	if (health >= 60.0) return mix(base_color.rgb,vec3(1.0,0.87,0.06),0.82);
	if (health >= 20.0) return mix(base_color.rgb,vec3(1.0,0.29,0.015),0.90);
	return mix(base_color.rgb,vec3(0.95,0.025,0.01),0.96);
}
void fragment() {
	vec3 p = world_surface;
	float best = region_distance(p,torso_world,0.80);
	float health = region_hp.y;
	float d = region_distance(p,head_world,0.53);
	if (d < best) { best=d; health=region_hp.x; }
	d = region_distance(p,left_arm_world,0.63);
	if (d < best) { best=d; health=region_hp.z; }
	d = region_distance(p,right_arm_world,0.63);
	if (d < best) { best=d; health=leg_hp.x; }
	d = region_distance(p,left_leg_world,0.72);
	if (d < best) { best=d; health=leg_hp.y; }
	d = region_distance(p,right_leg_world,0.72);
	if (d < best) { best=d; health=leg_hp.z; }
	float coverage = 1.0 - smoothstep(0.9,1.22,best);
	ALBEDO = mix(base_color.rgb,damage_color(health),coverage);
	ROUGHNESS = 0.8;
}
