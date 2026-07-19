shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.5) = 0.0;
uniform vec2 aspect_ratio = vec2(1.0, 1.0);

void fragment() {
    vec2 uv = UV - 0.5;
    uv.x *= aspect_ratio.x / aspect_ratio.y;
    float dist = length(uv);
    if (dist > radius) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0);
    }
}
