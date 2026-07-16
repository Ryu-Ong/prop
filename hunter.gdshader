shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0) = 0.4;
uniform float softness : hint_range(0.0, 0.5) = 0.05;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	uv.x *= aspect;
	center.x *= aspect;
	float dist = distance(uv, center);
	float alpha = smoothstep(radius, radius + softness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}