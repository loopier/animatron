shader_type canvas_item;

uniform vec3 uAddColor = vec3(0, 0, 0);
uniform float uAlpha = 1;
uniform bool uSelected = false;

void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.rgb += uAddColor.rgb;
	COLOR.a *= uAlpha;
	//if (uSelected) {
		//if (COLOR.a < 0.2) COLOR.rgb = vec3(1);
	//}
}
