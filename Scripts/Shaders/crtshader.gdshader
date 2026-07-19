shader_type canvas_item;

// Automatically grabs whatever is rendering behind this node
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

group_uniforms CRT_Tweaks;
uniform float curvature : hint_range(0.0, 0.5) = 0.08;
uniform float scanline_count : hint_range(100.0, 1080.0) = 400.0;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.25;
uniform float vignette_opacity : hint_range(0.0, 2.0) = 0.2;

// Bends the UV coordinates to create a curved CRT tube look
vec2 distort(vec2 uv) {
	vec2 cc = uv - 0.5;
	float dist = dot(cc, cc);
	return uv + cc * dist * curvature;
}

void fragment() {
	vec2 distorted_uv = distort(SCREEN_UV);
	
	// Cut off pixels that warp outside screen boundaries (creates black tube corners)
	if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0 || distorted_uv.y < 0.0 || distorted_uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Sample the game screen using the warped coordinates
		vec4 text_color = texture(SCREEN_TEXTURE, distorted_uv);
		
		// Generate horizontal scanlines using a sine wave
		float scanline = sin(distorted_uv.y * scanline_count * PI * 2.0);
		scanline = (scanline + 1.0) / 2.0; // Map from [-1, 1] to [0, 1]
		scanline = mix(1.0, scanline, scanline_opacity);
		text_color.rgb *= scanline;
		
		// Generate vignette (dark edges around the borders)
		vec2 vig_uv = distorted_uv * (1.0 - distorted_uv.yx);
		float vignette = vig_uv.x * vig_uv.y * 15.0;
		vignette = pow(vignette, vignette_opacity);
		text_color.rgb *= vignette;
		
		COLOR = text_color;
	}
}
