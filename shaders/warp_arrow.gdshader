shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float distortion_strength : hint_range(0.0, 0.12, 0.001) = 0.032;
uniform float radius : hint_range(0.2, 1.8, 0.01) = 1.12;
uniform float stretch : hint_range(0.5, 4.0, 0.01) = 2.05;
uniform float forward_pull : hint_range(0.0, 1.5, 0.01) = 0.62;
uniform float radial_strength : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float directional_pull_strength : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float tangential_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float pulse_amount : hint_range(0.0, 0.3, 0.01) = 0.04;
uniform float pulse_speed : hint_range(0.0, 12.0, 0.1) = 4.2;
uniform float effect_opacity : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float dist = length(centered);
	float falloff = 1.0 - smoothstep(radius * 0.45, radius, dist);
	falloff = clamp(falloff * effect_opacity, 0.0, 1.0);

	float pulse = 1.0 + sin(TIME * pulse_speed + dist * 10.0) * pulse_amount;
	float center_boost = 1.0 - smoothstep(0.0, radius * 0.72, dist);
	float forward_mask = clamp(0.55 - centered.y * 0.8, 0.0, 1.0);
	float trailing_mask = clamp(0.45 + centered.y * 0.7, 0.0, 1.0);

	vec2 radial = centered;
	float radial_length = length(radial);
	if (radial_length > 0.0001) {
		radial /= radial_length;
	} else {
		radial = vec2(0.0, -1.0);
	}
	vec2 tangent = vec2(-radial.y, radial.x);

	vec2 offset = -radial * distortion_strength * radial_strength * (0.45 + center_boost * 0.55) * falloff * pulse;
	offset += vec2(
		0.0,
		-distortion_strength
			* forward_pull
			* directional_pull_strength
			* (0.25 + forward_mask * stretch)
			* (falloff + center_boost * 0.85)
			* pulse
	);
	offset += tangent * centered.x * distortion_strength * tangential_strength * trailing_mask * falloff;

	vec2 base_uv = clamp(SCREEN_UV, vec2(0.0), vec2(1.0));
	vec2 warped_uv = clamp(base_uv + offset, vec2(0.0), vec2(1.0));
	COLOR = vec4(texture(screen_texture, warped_uv).rgb, 1.0);
}
