extends Node

const ItemDrop = preload("res://scripts/items/item_drop.gd")
const UseTestTarget = preload("res://scripts/items/use_test_target.gd")
const TestOre = preload("res://scripts/items/test_ore.gd")
const TravelGate = preload("res://scripts/travel_gate.gd")
@onready var world = get_parent()
var prompt: Label
var crosshair: Label

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -5
	crosshair.offset_top = -12
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(crosshair)
	prompt = Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.offset_left = -150
	prompt.offset_right = 150
	prompt.offset_top = 24
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(prompt)

func find_target():
	if not world.player.controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return null
	var camera: Camera3D = world.player.camera
	var center := camera.get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(center)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(center) * 50.0)
	query.exclude = [world.player.get_rid()]
	query.collision_mask = 3 # Floating Pickup never blocks aimed interactions.
	query.collide_with_areas = true
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty() or not (hit.collider is ItemDrop or hit.collider is TravelGate):
		return null
	var target = hit.collider
	var player_center: Vector3 = world.player.global_position + Vector3(0, 0.9, 0)
	if player_center.distance_to(target.global_position) > 3.0:
		return null
	# A separate character-to-item ray prevents collecting around obstacles.
	var sight := PhysicsRayQueryParameters3D.create(player_center, target.global_position)
	sight.exclude = [world.player.get_rid()]
	sight.collision_mask = 3
	sight.collide_with_areas = true
	var obstacle: Dictionary = space.intersect_ray(sight)
	if not obstacle.is_empty() and obstacle.collider != target:
		return null
	return target

func _physics_process(_delta: float) -> void:
	crosshair.visible = world.player.controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var target = find_target()
	if target is TravelGate:
		prompt.text = "右鍵：" + target.destination_label
		return
	prompt.text = "右鍵拾取：%s × %d" % [target.item.display_name, target.quantity] if target != null else ""

func interact() -> int:
	var target = find_target()
	if target == null:
		return 0
	if target is TravelGate:
		world.call_deferred("travel")
		return 0
	var accepted: int = target.collect(world.storage)
	world.status.text = "已拾取 %d 個" % accepted if accepted > 0 else "背包與工具欄已滿"
	return accepted

func use_selected() -> bool:
	if not world.player.controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	var slot: Dictionary = world.storage.hotbar.get_slots()[world.storage.selected]
	if slot.is_empty():
		world.status.text = "空手：請先選取測試工具"
		return false
	if slot.item_id not in [&"test_tool", &"test_pickaxe"]:
		world.status.text = "這個物品不能敲擊測試方塊，請選取測試工具"
		return false
	var camera: Camera3D = world.player.camera
	var center := camera.get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(center)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(center) * 50.0)
	query.exclude = [world.player.get_rid()]
	query.collision_mask = 3
	query.collide_with_areas = true
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty() or not (hit.collider is UseTestTarget or hit.collider is TestOre):
		world.status.text = "未瞄準可用目標，或視線被遮擋"
		return false
	var target = hit.collider
	if target is TestOre and slot.item_id != &"test_pickaxe":
		world.status.text = "礦石需要測試鎬，這個物品不能敲擊"
		return false
	if target is UseTestTarget and slot.item_id != &"test_tool":
		world.status.text = "測試方塊需要原本的測試工具"
		return false
	var player_center: Vector3 = world.player.global_position + Vector3(0, 0.9, 0)
	if player_center.distance_to(target.global_position) > 3.0:
		world.status.text = "距離太遠：請靠近至 3 公尺內"
		return false
	var sight := PhysicsRayQueryParameters3D.create(player_center, target.global_position)
	sight.exclude = [world.player.get_rid()]
	sight.collision_mask = 3
	sight.collide_with_areas = true
	var obstruction: Dictionary = space.intersect_ray(sight)
	if not obstruction.is_empty() and obstruction.collider != target:
		world.status.text = "目標被遮擋，無法使用工具"
		return false
	if target is TestOre:
		var count: int = target.strike()
		world.status.text = "礦石爆開！噴出 3 個石塊" if target.hits == 5 else "敲擊 %d／5 · 掉出 %d 個石塊" % [target.hits, count]
	else:
		target.receive_test_hit()
		world.status.text = "命中測試方塊"
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not world.player.controls_enabled:
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			use_selected()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		interact()
