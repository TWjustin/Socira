extends StaticBody3D

const PICKUP_SCENE = preload("res://scenes/items/pickup.tscn")
const STONE = preload("res://items/testing/test_stone.tres")
var hits := 0
var drops_spawned := 0

func strike() -> int:
	if hits >= 5 or is_queued_for_deletion():
		return 0
	hits += 1
	var count := 3 if hits == 5 else 1
	for index in range(count):
		var drop = PICKUP_SCENE.instantiate()
		drop.name = "StonePickup%d" % drops_spawned
		drop.item = STONE
		drop.quantity = 1
		drop.tint = Color("9ca6b4")
		var angle := float(drops_spawned) * TAU / 7.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		drop.position = position + direction * 0.95 + Vector3(0, 0.3, 0)
		get_parent().add_child(drop)
		var end := Vector3(position.x, 0.9, position.z) + direction * 1.7
		var tween := drop.create_tween()
		tween.tween_property(drop, "position", drop.position + Vector3(0, 0.5, 0), 0.12)
		tween.tween_property(drop, "position", end, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		drops_spawned += 1
	$Label.text = "測試礦石 %d／5｜測試鎬左鍵" % hits
	if hits == 5:
		_burst()
		queue_free()
	return count

func _burst() -> void:
	for index in range(6):
		var fragment := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * 0.2
		mesh.material = $Visual.mesh.material
		fragment.mesh = mesh
		fragment.position = position
		get_parent().add_child(fragment)
		var angle := float(index) * TAU / 6.0
		var tween := fragment.create_tween().set_parallel()
		tween.tween_property(fragment, "position", position + Vector3(cos(angle), 0.6, sin(angle)) * 1.4, 0.35)
		tween.tween_property(fragment, "scale", Vector3.ZERO, 0.35)
		tween.chain().tween_callback(fragment.queue_free)
