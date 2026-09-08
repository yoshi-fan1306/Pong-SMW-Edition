shader_type canvas_item;

uniform float amplitude : hint_range(0.0, 50.0) = 8.0;
uniform float frequency : hint_range(0.0, 0.1) = 0.1;

void vertex() {
   
    float particle_center_y = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y;
    
    
    VERTEX.x += sin(particle_center_y * frequency) * amplitude;
}
