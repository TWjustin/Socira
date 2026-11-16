@tool
extends StaticBody3D

func _ready() -> void:
	# Generate the same meter grid in the editor and at runtime.
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-32, 33):
		lines.surface_add_vertex(Vector3(i, 0.005, -32))
		lines.surface_add_vertex(Vector3(i, 0.005, 32))
		lines.surface_add_vertex(Vector3(-32, 0.005, i))
		lines.surface_add_vertex(Vector3(32, 0.005, i))
	lines.surface_end()
	$Grid.mesh = lines
