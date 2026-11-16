extends SceneTree

const Storage = preload("res://scripts/inventory/player_storage.gd")
const Crafting = preload("res://scripts/inventory/crafting.gd")
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
	data.hotbar.add_item(MATERIAL, 1)
	data.backpack.add_item(MATERIAL, 1)
	var original := data.snapshot()
	check(Crafting.plan(data).ok and data.snapshot() == original, "預檢不更動物品")
	check(Crafting.craft(data).ok and Crafting.material_count(data) == 0, "跨兩區扣材料")
	check(data.hotbar.count_item(TOOL.item_id) == 1, "產物優先工具欄")
	var after := data.snapshot()
	check(not Crafting.craft(data).ok and data.snapshot() == after, "材料不足不扣物品")
	var full := Storage.new()
	full.hotbar.add_item(MATERIAL, 98)
	full.hotbar.add_item(TOOL, 8)
	full.backpack.add_item(TOOL, 27)
	var full_before := full.snapshot()
	check(not Crafting.craft(full).ok and full.snapshot() == full_before, "空間不足原子拒絕")
	var exact := Storage.new()
	exact.hotbar.add_item(MATERIAL, 2)
	exact.hotbar.add_item(TOOL, 8)
	exact.backpack.add_item(TOOL, 27)
	check(Crafting.craft(exact).ok and exact.hotbar.count_item(TOOL.item_id) == 9, "可用耗盡材料釋出的格子")
	var bulk := Storage.new()
	bulk.add_pickup(MATERIAL, 10)
	check(Crafting.craftable_count(bulk) == 5 and Crafting.material_count(bulk) == 10, "可合成數預估不修改")
	for i in range(5):
		check(Crafting.craft(bulk).ok, "連續合成")
	check(bulk.hotbar.count_item(TOOL.item_id) == 5 and not Crafting.craft(bulk).ok, "重複點擊不重複收益")
	var main = load("res://scenes/main.tscn")
	var scene = main.instantiate()
	scene.save_path = "user://crafting_fixture.cfg"
	root.add_child(scene)
	scene.storage.add_pickup(MATERIAL, 6)
	var ui = scene.get_node("InventoryPanel")
	ui.set_open(true)
	ui.show_crafting(true)
	check(ui.craft_panel.visible and not ui.grid.visible and not ui.craft_button.disabled, "合成分頁與可用按鈕")
	ui.craft_button.pressed.emit()
	check(Crafting.material_count(scene.storage) == 4 and scene.storage.hotbar.count_item(TOOL.item_id) == 1, "介面按鈕合成")
	check(scene.save_game() == OK, "合成後存檔")
	var restored = main.instantiate()
	restored.save_path = scene.save_path
	root.add_child(restored)
	check(restored.storage.snapshot() == scene.storage.snapshot(), "新場景恢復合成數量")
	restored.queue_free()
	ui.show_crafting(false)
	ui._click_slot(true, 0)
	ui.show_crafting(true)
	var held_before: Dictionary = scene.storage.snapshot()
	ui._craft_one()
	check(ui.craft_button.disabled and scene.storage.snapshot() == held_before, "拿取中不合成避免游標來源衝突")
	ui.set_open(false)
	ui.set_open(true)
	ui.show_crafting(true)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/crafting_ui.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.save_path))
	scene.queue_free()
	await process_frame
	print("PASS: crafting combined inputs, capacity, rollback, UI, save/load" if failures == 0 else "FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
