shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture;
uniform float grain_amount : hint_range(0.0, 1.0) = 0.05;
uniform float grain_speed : hint_range(0.0, 60.0) = 12.0;

void fragment() {
    // Sample the original screen texture
    vec4 original_color = texture(screen_texture, SCREEN_UV);

    // Use SCREEN_UV and TIME to create flickering, screen-consistent noise
    // The '+ vec2(TIME * ...)' animates the noise
    float noise = fract(sin(dot(SCREEN_UV + vec2(TIME * grain_speed * 0.01), vec2(12.9898, 78.233))) * 43758.5453);
    
    // Convert noise from [0, 1] range to [-0.5, 0.5] range
    float centered_noise = noise - 0.5;

    // Apply to color
    original_color.rgb += centered_noise * grain_amount;

    COLOR = clamp(original_color, 0.0, 1.0);
}