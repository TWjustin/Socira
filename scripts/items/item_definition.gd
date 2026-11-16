extends Resource

enum Kind { MATERIAL, TOOL }

@export var item_id: StringName
@export var display_name: String
@export var kind: Kind = Kind.MATERIAL

func stack_limit() -> int:
	return 1 if kind == Kind.TOOL else 99
