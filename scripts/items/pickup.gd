extends Area3D

const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const Player = preload("res://scripts/player.gd")
@export var item: ItemDefinition
@export_range(1, 9999) var quantity := 1
@export var tint := Color("69b9d4")
var elapsed := 0.0

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is Player and body.controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var world = body.get_parent()
			var accepted := collect(world.storage)
			if accepted > 0:
				world.status.text = "已碰觸拾取 %s × %d" % [item.display_name, accepted]
			if quantity == 0:
				break

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	$Visual.material_override = material
	_update_label()

func _process(delta: float) -> void:
	elapsed += delta
	$Visual.rotation.y += delta
	$Visual.position.y = sin(elapsed * 2.0) * 0.08

func collect(storage) -> int:
	if quantity <= 0 or is_queued_for_deletion():
		return 0
	var remaining: int = storage.add_pickup(item, quantity)
	var accepted := quantity - remaining
	quantity = remaining
	_update_label()
	if quantity == 0:
		queue_free()
	return accepted

func _update_label() -> void:
	$Label.text = "%s × %d" % [item.display_name if item != null else "未設定物品", quantity]
