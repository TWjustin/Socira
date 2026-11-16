extends Node3D

const SAVE_PATH := "user://save.cfg"
const Inventory = preload("res://scripts/inventory/inventory.gd")
const PlayerStorage = preload("res://scripts/inventory/player_storage.gd")
var storage := PlayerStorage.new()
var inventory = storage.backpack
var save_path := SAVE_PATH
@onready var player = $Player
var status: Label
var load_failed := false
var pickup_templates: Dictionary = {}
const GATE_SCENE = preload("res://scenes/travel_gate.tscn")
const LAND_SCENE = preload("res://scenes/land.tscn")
const ORE_SCENE = preload("res://scenes/items/test_ore.tscn")
const RETURN_POSITION := Vector3(8, 0, -3)
var on_island := false
var island: Node3D
var home_nodes: Array[Node] = []
@onready var home_pickups: Node3D = $TestPickups
const PICKUP_SCENE = preload("res://scenes/items/pickup.tscn")
const ITEMS = [preload("res://items/testing/test_material.tres"), preload("res://items/testing/test_tool.tres"), preload("res://items/testing/test_pickaxe.tres"), preload("res://items/testing/test_stone.tres")]
var dev_supplies: Node3D

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_build_lighting()
	_build_interface()
	dev_supplies = Node3D.new()
	dev_supplies.name = "DevSupplies"
	add_child(dev_supplies)
	_restore_pickaxe(1)
	for pickup in $TestPickups.get_children():
		pickup_templates[str(pickup.name)] = {"position": pickup.position, "item": pickup.item, "quantity": pickup.quantity, "tint": pickup.tint}
	$InventoryPanel.storage = storage
	$InventoryPanel.bind_inventory(inventory, ITEMS)
	$InventoryPanel.open_changed.connect(_on_inventory_open_changed)
	load_game()
	var gate = GATE_SCENE.instantiate()
	gate.name = "TravelGate"
	gate.position = Vector3(8, 0.9, -5)
	add_child(gate)
	home_nodes = [$Land, $TestPickups, $UseTestTarget, gate, dev_supplies]
	var timer := Timer.new()
	timer.wait_time = 60.0
	timer.timeout.connect(save_game)
	add_child(timer)
	timer.start()

func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("a9c6dc")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.55
	environment.environment = settings
	add_child(environment)

func _on_inventory_open_changed(is_open: bool) -> void:
	player.controls_enabled = not is_open
	if is_open:
		player.velocity.x = 0.0
		player.velocity.z = 0.0

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var help := Label.new()
	help.position = Vector2(20, 16)
	help.text = "Socira  |  64 × 64 m\nWASD 移動 · 滑鼠轉向 · E 背包\n左鍵使用 · 漂浮物碰觸拾取 · 右鍵互動／地上物\n測試鎬在 (3, -2) · 出入口在 (8, -5)"
	help.add_theme_color_override("font_shadow_color", Color.BLACK)
	help.add_theme_constant_override("shadow_offset_x", 1)
	help.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(help)
	status = Label.new()
	status.position = Vector2(20, 128)
	status.text = "每 60 秒自動儲存，關閉視窗時儲存"
	layer.add_child(status)

func save_game() -> Error:
	if load_failed:
		status.text = "存檔讀取失敗，保留原檔；請先修復或移開原存檔"
		return ERR_FILE_CORRUPT
	var data := ConfigFile.new()
	data.set_value("save", "version", 2)
	data.set_value("storage", "contents", storage.snapshot())
	var pickups: Dictionary = {}
	for id in pickup_templates:
		var pickup = home_pickups.get_node_or_null(NodePath(id))
		pickups[id] = pickup.quantity if pickup != null and not pickup.is_queued_for_deletion() else 0
	data.set_value("world", "pickups", pickups)
	var pickaxe = dev_supplies.get_node_or_null("TestPickaxe")
	data.set_value("world", "test_pickaxe_remaining", pickaxe.quantity if pickaxe != null and not pickaxe.is_queued_for_deletion() else 0)
	data.set_value("player", "position", RETURN_POSITION if on_island else player.position)
	data.set_value("camera", "yaw", player.yaw)
	data.set_value("camera", "pitch", player.pitch)
	data.set_value("camera", "distance", player.distance)
	var error := data.save(save_path)
	status.text = "已儲存 " + Time.get_time_string_from_system() if error == OK else "儲存失敗，請檢查本機存檔權限"
	return error

func load_game() -> void:
	var data := ConfigFile.new()
	var error := data.load(save_path)
	if error == ERR_FILE_NOT_FOUND:
		return
	var version: Variant = data.get_value("save", "version", 0)
	if error != OK or not version is int or version not in [1, 2]:
		load_failed = true
		status.text = "存檔無法讀取，保留原檔並停止自動覆寫"
		return
	if version == 2:
		var pickups: Variant = data.get_value("world", "pickups")
		var pickaxe_remaining: Variant = data.get_value("world", "test_pickaxe_remaining", 1)
		if not pickaxe_remaining is int or pickaxe_remaining not in [0, 1] or not _valid_pickups(pickups) or not storage.restore(data.get_value("storage", "contents"), _catalog()):
			load_failed = true
			status.text = "物品存檔資料無效，保留原檔並停止自動覆寫"
			return
		$InventoryPanel.set_open(false)
		if on_island:
			_return_home()
		_restore_pickups(pickups)
		_restore_pickaxe(pickaxe_remaining)
	load_failed = false
	var saved_position: Variant = data.get_value("player", "position", Vector3.ZERO)
	if saved_position is Vector3 and saved_position.is_finite():
		player.position = Vector3(clampf(saved_position.x, -31.6, 31.6), 0.0, clampf(saved_position.z, -31.6, 31.6))
	player.yaw = _number(data.get_value("camera", "yaw", 0.0), 0.0, -PI, PI)
	player.pitch = _number(data.get_value("camera", "pitch", -0.45), -0.45, -1.35, 0.15)
	player.distance = _number(data.get_value("camera", "distance", 7.0), 7.0, 2.0, 16.0)
	player.update_camera()
	$InventoryPanel.refresh()
	status.text = "已恢復位置、鏡頭與物品" if version == 2 else "已載入舊版位置存檔，物品從空背包開始"

func _catalog() -> Dictionary:
	var catalog := {}
	for item in ITEMS:
		catalog[item.item_id] = item
	return catalog

func _valid_pickups(value: Variant) -> bool:
	if not value is Dictionary or value.size() != pickup_templates.size():
		return false
	for id in pickup_templates:
		var quantity: Variant = value.get(id)
		if not quantity is int or quantity < 0 or quantity > int(pickup_templates[id].quantity):
			return false
	return true

func _restore_pickups(quantities: Dictionary) -> void:
	for child in $TestPickups.get_children():
		$TestPickups.remove_child(child)
		child.queue_free()
	for id in pickup_templates:
		if quantities[id] == 0:
			continue
		var template: Dictionary = pickup_templates[id]
		var pickup = PICKUP_SCENE.instantiate()
		pickup.name = id
		pickup.position = template.position
		pickup.item = template.item
		pickup.quantity = quantities[id]
		pickup.tint = template.tint
		$TestPickups.add_child(pickup)

func _number(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), minimum, maximum)
	return fallback

func _restore_pickaxe(quantity: int) -> void:
	for child in dev_supplies.get_children():
		dev_supplies.remove_child(child)
		child.queue_free()
	if quantity == 0:
		return
	var pickup = PICKUP_SCENE.instantiate()
	pickup.name = "TestPickaxe"
	pickup.position = Vector3(3, 0.9, -2)
	pickup.item = ITEMS[2]
	pickup.quantity = 1
	pickup.tint = Color("e8bb59")
	dev_supplies.add_child(pickup)

func travel() -> void:
	if not player.controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if on_island:
		_return_home()
	else:
		for node in home_nodes:
			remove_child(node)
		island = Node3D.new()
		island.name = "TestIsland"
		add_child(island)
		island.add_child(LAND_SCENE.instantiate())
		var gate = GATE_SCENE.instantiate()
		gate.position = Vector3(8, 0.9, -5)
		gate.destination_label = "返回自家土地"
		island.add_child(gate)
		var pickup = PICKUP_SCENE.instantiate()
		pickup.name = "IslandMaterial"
		pickup.position = Vector3(5, 0.9, -5)
		pickup.item = ITEMS[0]
		pickup.quantity = 120
		island.add_child(pickup)
		var ore = ORE_SCENE.instantiate()
		ore.position = Vector3(3, 0.8, -8)
		island.add_child(ore)
		on_island = true
		_arrive()
		status.text = "測試外島 · 64×64 m · 測試材料 120 個"

func _arrive() -> void:
	player.position = RETURN_POSITION
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.pitch = -0.15
	player.update_camera()

func _return_home() -> void:
	remove_child(island)
	island.queue_free()
	island = null
	for node in home_nodes:
		add_child(node)
	on_island = false
	_arrive()
	status.text = "已返回自家土地，外島旅程結束"

func _exit_tree() -> void:
	# Detached home nodes remain alive during travel and need explicit cleanup.
	if on_island:
		for node in home_nodes:
			node.free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if save_game() == OK:
			get_tree().quit()
