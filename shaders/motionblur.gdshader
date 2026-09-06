shader_type canvas_item;


uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

uniform vec2 blur_direction = vec2(0.0, 0.0);

uniform int samples : hint_range(4, 32) = 32;

void fragment() {
    vec4 color = vec4(0.0);
    float total_weight = 0.0;

    for (int i = 0; i < samples; i++) {
        // Offset samples along the direction of movement
        float offset = float(i) / float(samples - 1) - 0.5;
        vec2 uv_offset = blur_direction * offset;
        color += texture(screen_texture, SCREEN_UV + uv_offset);
        total_weight += 1.0;
    }

    COLOR = color / total_weight;
}
