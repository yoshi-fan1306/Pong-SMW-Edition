shader_type canvas_item;

uniform vec2 tile_amount = vec2(4.5, 1.0); 
uniform float speed = 8.0;               

void fragment() {

	vec2 tiled_uv = fract(UV * tile_amount);

	float current_frame = floor(mod(TIME * speed, 4.0));

	tiled_uv.x = (tiled_uv.x + current_frame) / 4.0;

	COLOR = texture(TEXTURE, tiled_uv);
}
