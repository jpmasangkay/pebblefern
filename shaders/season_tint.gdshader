shader_type canvas_item;

// Lightweight seasonal foliage tinting for Pebblefern (Bloom=0, Sun=1, Harvest=2, Frost=3).
// Selectively shifts natural foliage greens while preserving water, wood, stone, and soil colors.

uniform int season_index : hint_range(0, 3) = 0;

void fragment() {
	// In Godot 4 canvas_item shaders, COLOR is already texture(TEXTURE, UV) * vertex_color.
	// Using COLOR directly preserves exact 1:1 tileset RGB fidelity (no accidental RGB squaring!).
	vec4 tex = COLOR;
	if (tex.a < 0.01) {
		COLOR = tex;
	} else {
		float green_dom = smoothstep(0.02, 0.14, tex.g - max(tex.r, tex.b));
		vec3 shifted = tex.rgb;
		if (season_index == 1) {
			// Sun: warm sun-drenched golden meadow lift
			shifted = vec3(
				clamp(tex.r * 1.15 + 0.03, 0.0, 1.0),
				clamp(tex.g * 1.03, 0.0, 1.0),
				clamp(tex.b * 0.84, 0.0, 1.0)
			);
		} else if (season_index == 2) {
			// Harvest: cozy autumn amber & warm ochre foliage
			shifted = vec3(
				clamp(tex.g * 1.06 + 0.04, 0.0, 1.0),
				clamp(tex.g * 0.68 + tex.r * 0.18, 0.0, 1.0),
				clamp(tex.b * 0.58, 0.0, 1.0)
			);
		} else if (season_index == 3) {
			// Frost: crisp snow-frosted sage & pale ice highlight
			float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
			vec3 frosted = vec3(
				clamp(lum * 0.96 + 0.24, 0.0, 1.0),
				clamp(lum * 1.02 + 0.26, 0.0, 1.0),
				clamp(lum * 1.12 + 0.30, 0.0, 1.0)
			);
			shifted = mix(tex.rgb, frosted, 0.72);
		}
		COLOR = vec4(mix(tex.rgb, shifted, green_dom), tex.a);
	}
}
