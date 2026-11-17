extends CharacterBody3D

const SPEED := 6.0
const LIMIT := 31.6
const GRAVITY := 20.0
const JUMP_SPEED := sqrt(2.0 * GRAVITY * 1.2)
var jump_requested := false
var yaw := 0.0
var pitch := -0.45
var distance := 7.0
var controls_enabled := true
@onready var pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

func _ready() -> void:
	# Use the scene's camera placement as the initial view before loading a save.
	pitch = pivot.rotation.x
	yaw = pivot.rotation.y
	distance = camera.position.z
	update_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		jump_requested = true
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw = wrapf(yaw - event.relative.x * 0.003, -PI, PI)
		pitch = clampf(pitch - event.relative.y * 0.003, -1.35, 0.15)
	update_camera()

func update_camera() -> void:
	if pivot == null:
		return
	pivot.rotation = Vector3(pitch, yaw, 0.0)
	# Keep the camera above the flat ground when looking upward.
	var safe_distance := distance
	if sin(pitch) > 0.0:
		safe_distance = minf(distance, 1.1 / sin(pitch))
	camera.position = Vector3(0.0, 0.0, safe_distance)

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0.0, input.y)
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	if is_on_floor() and jump_requested and controls_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		velocity.y = JUMP_SPEED
	elif not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	jump_requested = false
	move_and_slide()
	position.x = clampf(position.x, -LIMIT, LIMIT)
	position.z = clampf(position.z, -LIMIT, LIMIT)
