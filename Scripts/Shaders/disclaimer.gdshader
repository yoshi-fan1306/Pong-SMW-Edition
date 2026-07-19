shader_type canvas_item;

// Change this to adjust the star size. 
// Lower values = Bigger stars, Higher values = Smaller stars.
uniform float pixel_scale = 3.0; 
uniform float speed = 8.0;

void fragment() {
    // 1. Get the size of the texture in pixels
    vec2 tex_size = vec2(textureSize(TEXTURE, 0));
    
    // 2. Calculate the aspect ratio of a single frame
    // We divide the width by 4 because your sheet has 4 frames
    float frame_width = tex_size.x / 4.0;
    
    // 3. Calculate tiling based on fixed pixel scale
    // This ignores the screen size and uses the original image size
    vec2 uv = FRAGCOORD.xy / (vec2(frame_width, tex_size.y) * pixel_scale);
    
    // 4. Calculate animation frame
    float current_frame = floor(mod(TIME * speed, 4.0));
    
    // 5. Shift the UV to the correct frame
    uv.x = (uv.x + current_frame) / 4.0;

    COLOR = texture(TEXTURE, fract(uv));
}
