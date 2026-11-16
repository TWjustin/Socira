extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.save_path = "user://pickup_fixture.cfg"
	# Grounded ItemDrop retains aimed/right-click behavior.
	for child in scene.get_node("TestPickups").get_children():
		scene.get_node("TestPickups").remove_child(child)
		child.free()
	for index in range(2):
		var drop = load("res://scenes/items/item_drop.tscn").instantiate()
		drop.name = "TestMaterial" if index == 0 else "TestTool"
		drop.position = Vector3(-1 if index == 0 else 1, 0, -2)
		drop.item = scene.ITEMS[index]
		drop.quantity = 120 if index == 0 else 2
		scene.get_node("TestPickups").add_child(drop)
	root.add_child(scene)
	scene.player.set_physics_process(false)
	scene.player.set_process_unhandled_input(false)
	scene.player.position = Vector3.ZERO
	var target = scene.get_node("TestPickups/TestMaterial")
	var tool = scene.get_node("TestPickups/TestTool")
	var interaction = scene.get_node("Interaction")
	await create_timer(0.2).timeout
	scene.player.camera.look_at(target.global_position)
	await physics_frame
	await physics_frame
	check(interaction.find_target() == target, "中央瞄準、角色中心 3m 內")
	scene.player.position = Vector3(-1, 0, -2)
	await create_timer(0.1).timeout
	check(target.quantity == 120, "ItemDrop 碰觸不自動拾取")
	scene.player.position = Vector3.ZERO
	scene.player.camera.look_at(target.global_position)
	scene.get_node("InventoryPanel").set_open(true)
	check(interaction.interact() == 0, "背包開啟不拾取")
	scene.get_node("InventoryPanel").set_open(false)
	var obstacle := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 2, 0.3)
	collision.shape = box
	obstacle.add_child(collision)
	scene.add_child(obstacle)
	obstacle.position = Vector3(-0.5, 0.9, -1)
	await physics_frame
	await physics_frame
	check(interaction.find_target() == null, "角色到物品遮擋拒絕")
	obstacle.queue_free()
	await physics_frame
	await physics_frame
	target.position = Vector3(-1, 0, -4)
	scene.player.camera.look_at(target.global_position)
	await physics_frame
	await physics_frame
	check(interaction.find_target() == null, "超過 3m 拒絕")
	target.position = Vector3(-1, 0, -2)
	scene.player.camera.look_at(target.global_position)
	await physics_frame
	await physics_frame
	var right := InputEventMouseButton.new()
	right.pressed = true
	right.button_index = MOUSE_BUTTON_RIGHT
	interaction._unhandled_input(right)
	check(target.is_queued_for_deletion(), "全數拾取移除世界物件")
	check(scene.storage.hotbar.count_item(&"test_material") == 120, "120 材料進工具欄並分格")
	await process_frame
	scene.storage.add_pickup(tool.item, 34)
	check(tool.collect(scene.storage) == 0 and tool.quantity == 2, "36 格全滿保留世界物品")
	var Storage = load("res://scripts/inventory/player_storage.gd")
	var partial = Storage.new()
	partial.hotbar.add_item(tool.item, 9)
	partial.backpack.add_item(tool.item, 26)
	check(tool.collect(partial) == 1 and tool.quantity == 1 and not tool.is_queued_for_deletion(), "部分拾取保留餘量")
	scene.player.camera.look_at(tool.global_position)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/pickup_ui.png")
	# Floating Pickup ignores right click and collects only on contact.
	scene.storage.restore(Storage.new().snapshot(), scene._catalog())
	var floating = load("res://scenes/items/pickup.tscn").instantiate()
	floating.item = scene.ITEMS[3]
	floating.quantity = 3
	floating.position = Vector3(8, 0.9, 8)
	scene.add_child(floating)
	scene.player.position = Vector3(8, 0, 10)
	scene.player.camera.look_at(floating.global_position)
	await create_timer(0.1).timeout
	check(interaction.interact() == 0 and floating.quantity == 3, "漂浮 Pickup 不右鍵遠距拾取")
	scene.player.position = Vector3(8, 0, 8)
	scene.get_node("InventoryPanel").set_open(true)
	await create_timer(0.1).timeout
	check(floating.quantity == 3, "背包開啟不自動拾取")
	scene.get_node("InventoryPanel").set_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await create_timer(0.1).timeout
	check(floating.quantity == 3, "游標釋放不自動拾取")
	scene.storage.add_pickup(scene.ITEMS[3], 98)
	scene.storage.add_pickup(scene.ITEMS[1], 35)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await create_timer(0.1).timeout
	check(floating.quantity == 2 and scene.storage.hotbar.count_item(&"test_stone") == 99, "碰觸部分補堆疊，餘量保留")
	scene.storage.hotbar.remove_item(&"test_tool", 1)
	await create_timer(0.1).timeout
	check(not is_instance_valid(floating) and scene.storage.hotbar.count_item(&"test_stone") == 101, "保持碰觸，釋出格位後拾取餘量")
	scene.queue_free()
	await process_frame
	print("PASS: grounded right-click ItemDrop and floating contact Pickup, full/partial retention, UI isolation" if failures == 0 else "FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
