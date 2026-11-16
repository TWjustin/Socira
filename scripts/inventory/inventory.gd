extends RefCounted

const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const CAPACITY := 27

signal changed

# Empty slots are empty dictionaries. Only scalar values are stored here.
var _slots: Array[Dictionary] = []
var capacity: int

func _init(size: int = CAPACITY) -> void:
	capacity = maxi(1, size)
	for index in range(capacity):
		_slots.append({})

func get_slots() -> Array[Dictionary]:
	# Callers cannot mutate inventory data through the returned snapshot.
	return _slots.duplicate(true)

func decode_slots(value: Variant, catalog: Dictionary) -> Array[Dictionary]:
	var decoded: Array[Dictionary] = []
	if not value is Array or value.size() != capacity:
		return decoded
	for slot in value:
		if not slot is Dictionary:
			return []
		if slot.is_empty():
			decoded.append({})
			continue
		var id: Variant = slot.get("item_id")
		var quantity: Variant = slot.get("quantity")
		if not (id is String or id is StringName) or not catalog.has(StringName(id)) or not quantity is int:
			return []
		var limit: int = catalog[StringName(id)].stack_limit()
		if quantity < 1 or quantity > limit:
			return []
		decoded.append({"item_id": StringName(id), "quantity": quantity, "stack_limit": limit})
	return decoded

func restore_slots(decoded: Array[Dictionary]) -> void:
	_slots = decoded.duplicate(true)
	changed.emit()

func count_item(item_id: StringName) -> int:
	var total := 0
	for slot in _slots:
		if slot.get("item_id", &"") == item_id:
			total += slot["quantity"]
	return total

func remove_item(item_id: StringName, quantity: int) -> int:
	var remaining := maxi(0, quantity)
	for index in range(capacity):
		var slot := _slots[index]
		if slot.get("item_id", &"") != item_id:
			continue
		var removed := mini(remaining, int(slot.quantity))
		slot.quantity -= removed
		remaining -= removed
		if slot.quantity == 0:
			_slots[index] = {}
		if remaining == 0:
			break
	if remaining != maxi(0, quantity):
		changed.emit()
	return remaining

# Returns the unaccepted quantity. The pickup source must retain this remainder.
# Invalid requests do not change the inventory; negative quantities return zero.
func add_item(item: ItemDefinition, quantity: int, fill_empty: bool = true) -> int:
	if quantity <= 0:
		return 0
	if item == null or item.item_id == &"" or item.kind not in [ItemDefinition.Kind.MATERIAL, ItemDefinition.Kind.TOOL]:
		return quantity
	var limit := item.stack_limit()
	# Reject conflicting definitions of an existing item ID atomically.
	for slot in _slots:
		if slot.get("item_id", &"") == item.item_id and slot["stack_limit"] != limit:
			return quantity
	var remaining := quantity
	for slot in _slots:
		if slot.get("item_id", &"") == item.item_id:
			var accepted := mini(remaining, limit - int(slot["quantity"]))
			slot["quantity"] += accepted
			remaining -= accepted
			if remaining == 0:
				break
	if remaining > 0 and fill_empty:
		for index in range(capacity):
			if _slots[index].is_empty():
				var accepted := mini(remaining, limit)
				_slots[index] = {"item_id": item.item_id, "quantity": accepted, "stack_limit": limit}
				remaining -= accepted
				if remaining == 0:
					break
	if remaining != quantity:
		changed.emit()
	return remaining

func move_to(index: int, target: RefCounted, target_index: int) -> void:
	if index < 0 or index >= capacity or target_index < 0 or target_index >= target.capacity:
		return
	if self == target and index == target_index:
		return
	var source: Dictionary = _slots[index]
	var destination: Dictionary = target._slots[target_index]
	if source.is_empty():
		return
	if not destination.is_empty() and source.item_id == destination.item_id:
		var amount := mini(int(source.quantity), int(destination.stack_limit) - int(destination.quantity))
		destination.quantity += amount
		source.quantity -= amount
		if source.quantity == 0:
			_slots[index] = {}
	else:
		_slots[index] = destination
		target._slots[target_index] = source
	changed.emit()
	if self != target:
		target.changed.emit()
