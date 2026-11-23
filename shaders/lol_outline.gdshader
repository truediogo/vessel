shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

// League of Legends-style crisp inverted-hull outer silhouette ink contour
uniform vec4 outline_color : source_color = vec4(0.07, 0.06, 0.10, 1.0);
uniform float outline_width : hint_range(0.0, 0.01) = 0.0022;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
