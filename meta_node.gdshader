shader_type canvas_item;

uniform vec3 uAddColor = vec3(0, 0, 0);
uniform bool uSelected = false;

void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.rgb += uAddColor;
	if (uSelected) {
		if (COLOR.a < 1.0) COLOR.rgb = vec3(1);
	}
}
