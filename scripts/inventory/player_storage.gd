extends RefCounted

const Inventory = preload("res://scripts/inventory/inventory.gd")
var backpack := Inventory.new()
var hotbar := Inventory.new(9)
var selected := 0

func snapshot() -> Dictionary:
	return {"backpack": backpack.get_slots(), "hotbar": hotbar.get_slots(), "selected": selected}

func restore(value: Variant, catalog: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	var bag := backpack.decode_slots(value.get("backpack"), catalog)
	var bar := hotbar.decode_slots(value.get("hotbar"), catalog)
	var selection: Variant = value.get("selected")
	if bag.size() != 27 or bar.size() != 9 or not selection is int or selection < 0 or selection >= 9:
		return false
	selected = selection
	backpack.restore_slots(bag)
	hotbar.restore_slots(bar)
	return true

func cycle(step: int) -> void:
	selected = posmod(selected + step, 9)

# Preserve all unaccepted quantity for the future world pickup source.
func add_pickup(item, quantity: int) -> int:
	var remaining := hotbar.add_item(item, quantity, false)
	remaining = backpack.add_item(item, remaining, false)
	remaining = hotbar.add_item(item, remaining)
	return backpack.add_item(item, remaining)
