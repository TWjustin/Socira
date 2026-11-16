extends SceneTree

const Storage = preload("res://scripts/inventory/player_storage.gd")
const MATERIAL = preload("res://items/testing/test_material.tres")
const TOOL = preload("res://items/testing/test_tool.tres")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data := Storage.new()
	check(data.backpack.capacity == 27 and data.hotbar.capacity == 9, "27+9 獨立容量")
	check(data.add_pickup(MATERIAL, 99 * 10) == 0, "跨區入包")
	check(data.hotbar.count_item(MATERIAL.item_id) == 891 and data.backpack.count_item(MATERIAL.item_id) == 99, "工具欄空格優先")
	var partial := Storage.new()
	partial.backpack.add_item(MATERIAL, 98)
	partial.add_pickup(MATERIAL, 2)
	check(partial.backpack.count_item(MATERIAL.item_id) == 99 and partial.hotbar.count_item(MATERIAL.item_id) == 1, "先補背包既有堆疊再工具欄空格")
	check(data.add_pickup(TOOL, 30) == 4, "36 格滿包餘量")
	partial.hotbar.move_to(0, partial.backpack, 1)
	check(partial.hotbar.get_slots()[0].is_empty() and partial.backpack.get_slots()[1].quantity == 1, "跨區搬移")
	partial.backpack.move_to(1, partial.backpack, 0)
	check(partial.backpack.get_slots()[1].quantity == 1, "滿堆疊不吞物品")
	var merge := Storage.new()
	merge.hotbar.add_item(MATERIAL, 90)
	merge.backpack.add_item(MATERIAL, 20)
	merge.backpack.move_to(0, merge.hotbar, 0)
	check(merge.hotbar.get_slots()[0].quantity == 99 and merge.backpack.get_slots()[0].quantity == 11, "部分合併餘量")
	merge.hotbar.add_item(TOOL, 1)
	merge.hotbar.move_to(1, merge.backpack, 0)
	check(merge.backpack.get_slots()[0].item_id == TOOL.item_id and merge.hotbar.get_slots()[1].quantity == 11, "不同類交換")
	merge.cycle(-1)
	check(merge.selected == 8, "向前循環")
	merge.cycle(1)
	check(merge.selected == 0, "向後循環")
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = "user://hotbar_fixture.cfg"
	root.add_child(scene)
	var ui = scene.get_node("InventoryPanel")
	ui.bind_inventory(scene.inventory, [MATERIAL, TOOL])
	scene.storage.hotbar.add_item(TOOL, 1)
	check(ui.hotbar_labels[0].text.contains("測試工具"), "工具欄資料變動更新介面")
	scene.storage.hotbar.move_to(0, scene.inventory, 5)
	scene.inventory.add_item(MATERIAL, 20)
	ui.set_open(true)
	ui._click_slot(false, 0)
	ui._click_slot(true, 0)
	check(scene.inventory.count_item(MATERIAL.item_id) == 0 and scene.storage.hotbar.count_item(MATERIAL.item_id) == 20, "介面左鍵跨區搬移")
	ui._click_slot(true, 0)
	ui.set_open(false)
	check(scene.storage.hotbar.count_item(MATERIAL.item_id) == 20 and ui.held_inventory == null, "關閉取消拿取不遺失")
	var distance: float = scene.player.distance
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ui._input(wheel)
	scene.player._unhandled_input(wheel)
	check(scene.storage.selected == 1 and is_equal_approx(scene.player.distance, distance), "滾輪換格且不縮放")
	ui.set_open(true)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/hotbar_ui.png")
	scene.queue_free()
	await process_frame
	print("PASS: independent hotbar, pickup order, transfer, merge, swap, cursor cancel, wheel" if failures == 0 else "FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
