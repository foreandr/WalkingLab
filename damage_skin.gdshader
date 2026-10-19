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
	// Continuous transitions: red -> orange -> yellow -> white.
	// Restored HP should visibly remove injury without abrupt color jumps.
	float h = clamp(health,0.0,100.0);
	vec3 red = vec3(0.95,0.025,0.01);
	vec3 orange = vec3(1.0,0.32,0.02);
	vec3 yellow = vec3(1.0,0.86,0.12);
	if (h < 25.0) return mix(red,orange,smoothstep(0.0,25.0,h));
	if (h < 65.0) return mix(orange,yellow,smoothstep(25.0,65.0,h));
	return mix(yellow,base_color.rgb,smoothstep(65.0,100.0,h));
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
