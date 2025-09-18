extends CharacterBody3D

@export var speed: float = 6.0
@export var jump_velocity: float = 5.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var air_control: float = 0.25

# NOTE: don't redeclare `velocity` — CharacterBody3D already provides it.
var cam: Camera3D
var ray: RayCast3D
var on_slippery: bool = false

func _ready():
	cam = $SpringArm3D/Camera3D
	ray = $RayCast3D
	if ray:
		ray.enabled = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	_process_movement(delta)
	_apply_gravity(delta)
	# Godot 4: CharacterBody3D.move_and_slide() uses the built-in `velocity`.
	move_and_slide()

func _process_movement(delta):
	var in_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var in_z = Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	var input_dir = Vector3(in_x, 0.0, in_z)

	if input_dir.length() > 0.01:
		input_dir = input_dir.normalized()
		var cam_basis = cam.global_transform.basis
		var dir_world = (cam_basis.x * input_dir.x + cam_basis.z * input_dir.z)
		dir_world.y = 0.0
		dir_world = dir_world.normalized()
		var desired = dir_world * speed

		if _is_grounded():
			velocity.x = desired.x
			velocity.z = desired.z
		else:
			velocity.x = lerp(velocity.x, desired.x, air_control)
			velocity.z = lerp(velocity.z, desired.z, air_control)
	else:
		if _is_grounded():
			velocity.x = lerp(velocity.x, 0.0, 0.18)   # <- changed 0 -> 0.0
			velocity.z = lerp(velocity.z, 0.0, 0.18)   # <- changed 0 -> 0.0
		else:
			velocity.x = lerp(velocity.x, 0.0, 0.02)   # <- changed 0 -> 0.0
			velocity.z = lerp(velocity.z, 0.0, 0.02)   # <- changed 0 -> 0.0

	if Input.is_action_just_pressed("jump") and _is_grounded():
		velocity.y = jump_velocity

	if on_slippery and _is_grounded():
		velocity.x = lerp(velocity.x, velocity.x, 0.995)
		velocity.z = lerp(velocity.z, velocity.z, 0.995)

func _apply_gravity(delta):
	if not _is_grounded():
		velocity.y -= gravity * delta
	else:
		velocity.y = min(velocity.y, 0.0)

func _is_grounded() -> bool:
	if ray and ray.is_enabled():
		return ray.is_colliding()
	return is_on_floor()

# Called externally by WindZone to nudge the player
func apply_wind(vec: Vector3):
	velocity += vec
