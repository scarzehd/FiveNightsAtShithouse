shader_type spatial;
global uniform bool IS_EDITOR;

void fragment() {
	if (!IS_EDITOR) {
		discard; // Do not render in actual game
	}

	ALBEDO = vec3(1.0,0.0,0.0); // Mesh will appear red in the editor
}