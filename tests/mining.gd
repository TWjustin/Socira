extends SceneTree

const FIXTURE := "user://mining_fixture.cfg"
const MAIN = preload("res://scenes/main.tscn")
const Pickup = preload("res://scripts/items/pickup.gd")
const Storage = preload("res://scripts/inventory/player_storage.gd")
const Crafting = preload("res://scripts/inventory/crafting.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func settle() -> void:
	for index in range(5):
		await physics_frame

func count_stones(storage) -> int:
	return storage.hotbar.count_item(&"test_stone") + storage.backpack.count_item(&"test_stone")

func _run() -> void:
	if "--verify-close" in OS.get_cmdline_user_args():
		var reopened = MAIN.instantiate()
		reopened.save_path = FIXTURE
		root.add_child(reopened)
		reopened.player.set_physics_process(false)
		check(not reopened.on_island, "外島關閉重進回本土")
		check(count_stones(reopened.storage) == 7, "正常關閉後保留 7 石塊")
		check(reopened.storage.hotbar.count_item(&"test_pickaxe") == 1, "測試鎬保存")
		check(reopened.dev_supplies.get_child_count() == 0, "測試鎬不重複發放")
		DirAccess.remove_absolute(FIXTURE)
		print("PASS: mining normal close recovery" if failures == 0 else "FAIL")
		quit(0 if failures == 0 else 1)
		return
	if FileAccess.file_exists(FIXTURE):
		DirAccess.remove_absolute(FIXTURE)
	var scene = MAIN.instantiate()
	scene.save_path = FIXTURE
	root.add_child(scene)
	scene.player.set_physics_process(false)
	await create_timer(0.2).timeout
	scene.player.position = Vector3(3, 0, -2)
	await settle()
	check(scene.storage.hotbar.count_item(&"test_pickaxe") == 1, "碰觸領取一把測試鎬")
	check(scene.dev_supplies.get_child_count() == 0, "鎬領取後移除")
	scene.travel()
	var ore = scene.island.get_node("TestOre")
	var interaction = scene.get_node("Interaction")
	scene.player.position = Vector3(3, 0, -5.2)
	scene.player.camera.look_at(ore.global_position)
	await settle()
	scene.storage.selected = 1
	check(not interaction.use_selected() and ore.hits == 0, "空手不採礦")
	scene.storage.hotbar.add_item(scene.ITEMS[1], 1)
	check(not interaction.use_selected() and ore.hits == 0, "原測試工具不能代替鎬")
	scene.storage.selected = 0
	scene.player.position.z = -4
	scene.player.camera.look_at(ore.global_position)
	await settle()
	check(not interaction.use_selected() and ore.hits == 0, "超過 3m 不採礦")
	scene.player.position.z = -5.2
	scene.player.camera.look_at(ore.global_position)
	scene.get_node("InventoryPanel").set_open(true)
	check(not interaction.use_selected() and ore.hits == 0, "背包開啟不採礦")
	scene.get_node("InventoryPanel").set_open(false)
	var block := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 3, 0.3)
	collision.shape = shape
	block.add_child(collision)
	scene.island.add_child(block)
	block.position = Vector3(3, 1, -6.5)
	await settle()
	check(not interaction.use_selected() and ore.hits == 0, "遮擋不採礦")
	block.queue_free()
	await settle()
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	check(ore.hits == 0, "重捕捉游標不敲礦")
	for index in range(4):
		Input.parse_input_event(click.duplicate())
		Input.flush_buffered_events()
		check(ore.hits == index + 1 and ore.drops_spawned == index + 1, "前四擊每擊 1 個")
	Input.parse_input_event(click.duplicate())
	Input.flush_buffered_events()
	check(ore.hits == 5 and ore.drops_spawned == 7 and ore.is_queued_for_deletion(), "第五擊噴 3 個並爆開")
	check(ore.strike() == 0 and ore.drops_spawned == 7, "爆開後不可重複產出")
	await create_timer(0.5).timeout
	var drops: Array = []
	for child in scene.island.get_children():
		if child is Pickup and child.item.item_id == &"test_stone":
			drops.append(child)
	check(drops.size() == 7, "七個獨立漂浮石塊")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/mining_ui.png")
	# Fill remaining slots: contact must leave the source intact, then retry
	# while still overlapping after space becomes available.
	scene.storage.add_pickup(scene.ITEMS[1], 34)
	var first = drops[0]
	scene.player.position = Vector3(first.position.x, 0, first.position.z)
	await settle()
	check(first.quantity == 1 and count_stones(scene.storage) == 0, "滿包碰觸保留石塊")
	scene.storage.hotbar.remove_item(&"test_tool", 8)
	await settle()
	check(count_stones(scene.storage) >= 1, "空間釋出後仍接觸可拾取")
	for drop in drops:
		if is_instance_valid(drop) and not drop.is_queued_for_deletion():
			scene.player.position = Vector3(drop.position.x, 0, drop.position.z)
			await settle()
	check(count_stones(scene.storage) == 7, "碰觸共收 7 石塊")
	check(scene.storage.hotbar.count_item(&"test_pickaxe") == 1, "鎬無消耗")
	scene.storage.hotbar.remove_item(&"test_tool", 36)
	scene.storage.backpack.remove_item(&"test_tool", 36)
	scene.storage.add_pickup(scene.ITEMS[0], 2)
	check(Crafting.craft(scene.storage).ok and count_stones(scene.storage) == 7, "新增物品不影響原合成")
	scene.travel()
	check(not scene.on_island and count_stones(scene.storage) == 7, "帶回本土")
	scene.travel()
	check(scene.island.get_node("TestOre").hits == 0, "新旅程重建礦石")
	check(scene.save_game() == OK, "新物品存檔")
	var snapshot: Dictionary = scene.storage.snapshot()
	var invalid := ConfigFile.new()
	invalid.load(FIXTURE)
	invalid.set_value("world", "test_pickaxe_remaining", 2)
	invalid.save(FIXTURE)
	scene.load_game()
	check(scene.load_failed and scene.storage.snapshot() == snapshot, "無效鎬餘量不部分套用")
	scene.load_failed = false
	check(scene.save_game() == OK, "恢復有效測試檔")
	print("PASS: mining, seven floating drops, contact/full inventory, crafting and travel" if failures == 0 else "FAIL: %d" % failures)
	if failures > 0:
		quit(1)
		return
	scene._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
