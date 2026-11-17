@tool
extends "res://scripts/island_terrain.gd"

const BLOCK_HEIGHT := 1.0
var cells: Dictionary = {}

static func base_height(cell: Vector2i) -> float:
	var x := float(cell.x) + 0.5
	var z := float(cell.y) + 0.5
	var coast := shore_distance(x, z)
	if coast >= SHALLOW_WIDTH:
		return -2.0
	if coast >= 0.0:
		return -1.0
	var hills := _hill(x, z, Vector2(-10, -9), 7.0, 3.6)
	hills += _hill(x, z, Vector2(10, 10), 6.0, 2.8)
	hills += _hill(x, z, Vector2(-8, 12), 5.0, 1.8)
	return roundf(hills / BLOCK_HEIGHT) * BLOCK_HEIGHT

func _build_ground() -> void:
	cells.clear()
	for z in range(-HALF_SIZE, HALF_SIZE):
		for x in range(-HALF_SIZE, HALF_SIZE):
			var cell := Vector2i(x, z)
			var level := base_height(cell)
			var ramp := Vector2i.ZERO
			# Fixed ramp corridors; other terrace edges remain vertical steps.
			if z in [-9, -8, 9, 10, 12, 13, -1, 0] or x in [-1, 0]:
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if base_height(cell + direction) == level + BLOCK_HEIGHT and base_height(cell - direction) == level:
						ramp = direction
						break
			cells[cell] = {"height": level, "ramp": ramp}
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in cells:
		var points := _top(cell)
		var coast := shore_distance(float(cell.x) + 0.5, float(cell.y) + 0.5)
		var tint := Color("59854f") if coast < -4.0 else Color("c5b178")
		tint = tint.lerp(Color.WHITE, float(posmod(cell.x + cell.y, 2)) * 0.025)
		_triangle(surface, points[0], points[1], points[2], tint)
		_triangle(surface, points[1], points[3], points[2], tint)
		var sides := [
			[0, 1, Vector2i.UP, 2, 3],
			[1, 3, Vector2i.RIGHT, 0, 2],
			[3, 2, Vector2i.DOWN, 1, 0],
			[2, 0, Vector2i.LEFT, 3, 1]]
		for side in sides:
			var a: Vector3 = points[side[0]]
			var b: Vector3 = points[side[1]]
			var neighbor := cell + Vector2i(side[2])
			var bottom_a := a
			var bottom_b := b
			bottom_a.y = -3.0
			bottom_b.y = -3.0
			if cells.has(neighbor):
				var next := _top(neighbor)
				bottom_a.y = minf(a.y, next[side[3]].y)
				bottom_b.y = minf(b.y, next[side[4]].y)
			var soil := Color("90704e") if coast < -4.0 else Color("b49d6b")
			_triangle(surface, a, bottom_a, b, soil)
			_triangle(surface, b, bottom_a, bottom_b, soil)
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
	collision.shape = mesh.create_trimesh_shape()
	ground.add_child(collision)

func _top(cell: Vector2i) -> PackedVector3Array:
	var info: Dictionary = cells[cell]
	var points := PackedVector3Array()
	for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var rise := 0.0
		match info.ramp:
			Vector2i.RIGHT: rise = float(corner.x)
			Vector2i.LEFT: rise = 1.0 - float(corner.x)
			Vector2i.DOWN: rise = float(corner.y)
			Vector2i.UP: rise = 1.0 - float(corner.y)
		points.append(Vector3(cell.x + corner.x, float(info.height) + rise * BLOCK_HEIGHT, cell.y + corner.y))
	return points

func surface_height(x: float, z: float) -> float:
	var cell := Vector2i(floori(x), floori(z))
	if not cells.has(cell):
		return -3.0
	var points := _top(cell)
	return points[0].y + (points[1].y - points[0].y) * (x - cell.x) + (points[2].y - points[0].y) * (z - cell.y)

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	var normal := (c - a).cross(b - a)
	if normal.length_squared() < 0.000001:
		return
	surface.set_normal(normal.normalized())
	surface.set_color(tint)
	for point in [a, b, c]:
		surface.add_vertex(point)
