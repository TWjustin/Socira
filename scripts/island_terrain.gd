@tool
extends Node3D

# Fixed prototype dimensions, not a random-island generator.
const HALF_SIZE := 32
const SEA_LEVEL := -0.2
const SHALLOW_WIDTH := 4.0
const BOUNDARY_SEGMENTS := 128

func _ready() -> void:
	_build_ground()
	_build_water()
	_build_deep_water_boundary()

static func shoreline_radius(angle: float) -> float:
	return 22.0 + 1.4 * sin(angle * 3.0) + 0.7 * cos(angle * 5.0)

static func shore_distance(x: float, z: float) -> float:
	return Vector2(x, z).length() - shoreline_radius(atan2(z, x))

static func height_at(x: float, z: float) -> float:
	var coast := shore_distance(x, z)
	var height := SEA_LEVEL * smoothstep(-5.0, 0.0, coast)
	height -= 0.4 * smoothstep(0.0, SHALLOW_WIDTH, coast)
	height -= 0.5 * smoothstep(SHALLOW_WIDTH, 9.0, coast)
	height += _hill(x, z, Vector2(-10, -9), 7.0, 1.8)
	height += _hill(x, z, Vector2(10, 10), 6.0, 1.4)
	height += _hill(x, z, Vector2(-8, 12), 5.0, 0.9)
	return height

static func _hill(x: float, z: float, center: Vector2, radius: float, height: float) -> float:
	var weight := maxf(0.0, 1.0 - Vector2(x, z).distance_squared_to(center) / (radius * radius))
	return weight * weight * height

func _build_ground() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-HALF_SIZE, HALF_SIZE):
		for x in range(-HALF_SIZE, HALF_SIZE):
			var a := Vector2(x, z)
			var b := Vector2(x + 1, z)
			var c := Vector2(x, z + 1)
			var d := Vector2(x + 1, z + 1)
			for point in [a, b, c, b, d, c]:
				var y := height_at(point.x, point.y)
				var dx := height_at(point.x - 0.1, point.y) - height_at(point.x + 0.1, point.y)
				var dz := height_at(point.x, point.y - 0.1) - height_at(point.x, point.y + 0.1)
				surface.set_normal(Vector3(dx, 0.2, dz).normalized())
				var coast := shore_distance(point.x, point.y)
				var grass := Color("527f4c").lerp(Color("7f9c5b"), clampf(y / 2.0, 0, 1))
				var sand := Color("c5b178").lerp(Color("849a88"), smoothstep(-0.5, 4.0, coast))
				surface.set_color(grass.lerp(sand, smoothstep(-5.5, -3.5, coast)))
				surface.add_vertex(Vector3(point.x, y, point.y))
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	add_child(ground)
	var visual := MeshInstance3D.new()
	visual.name = "Surface"
	visual.mesh = mesh
	ground.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	# Derive collision from the rendered triangles to keep both surfaces aligned.
	collision.shape = mesh.create_trimesh_shape()
	ground.add_child(collision)

func _build_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.position.y = SEA_LEVEL
	var plane := PlaneMesh.new()
	plane.size = Vector2(2000, 2000)
	water.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/island_water.gdshader")
	water.material_override = material
	add_child(water)

func _build_deep_water_boundary() -> void:
	var barrier := StaticBody3D.new()
	barrier.name = "DeepWaterBoundary"
	add_child(barrier)
	for index in range(BOUNDARY_SEGMENTS):
		var a := _boundary_point(float(index) * TAU / BOUNDARY_SEGMENTS)
		var b := _boundary_point(float(index + 1) * TAU / BOUNDARY_SEGMENTS)
		var delta := b - a
		var box := BoxShape3D.new()
		box.size = Vector3(delta.length() + 0.25, 4.0, 0.35)
		var collision := CollisionShape3D.new()
		collision.shape = box
		collision.position = (a + b) * 0.5 + Vector3(0, 1.0, 0)
		collision.rotation.y = -atan2(delta.z, delta.x)
		barrier.add_child(collision)

static func _boundary_point(angle: float) -> Vector3:
	var radius := shoreline_radius(angle) + SHALLOW_WIDTH
	return Vector3(cos(angle) * radius, 0, sin(angle) * radius)
