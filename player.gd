extends CharacterBody3D

# Movement
@export var speed: float = 6.0
@export var jump_velocity: float = 7.0    # increase this for higher/faster jumps
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var air_control: float = 0.25

# Mouse look
@export var mouse_sensitivity_x: float = 0.0035   # horizontal
@export var mouse_sensitivity_y: float = 0.0035   # vertical
@export var min_pitch_deg: float = -75.0
@export var max_pitch_deg: float = -10.0

# internal
var cam: Camera3D
var spring_arm: SpringArm3D
var ray: RayCast3D
var on_slippery: bool = false
var pitch_rad: float = 0.0   # camera pitch in radians

# jump helper
var just_jumped: bool = false

func _ready():
	cam = $SpringArm3D/Camera3D
	spring_arm = $SpringArm3D
	ray = $RayCast3D
	if ray:
		ray.enabled = true
		# avoid ray hitting the player itself
		ray.add_exception(self)
	# start captured so mouse controls camera
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# initialize pitch from current spring arm rotation
	pitch_rad = spring_arm.rotation.x

func _unhandled_input(event):
	# mouse look only when mouse is captured
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_update_mouse_look(event.relative)

func _process(_delta):
	# toggle mouse capture with Escape via action
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_mouse_look(relative: Vector2):
	# yaw: rotate player horizontally
	var yaw_delta = -relative.x * mouse_sensitivity_x
	rotate_y(yaw_delta)

	# pitch: change spring arm rotation.x, clamp
	var pitch_delta = -relative.y * mouse_sensitivity_y
	pitch_rad = clamp(pitch_rad + pitch_delta, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	var r = spring_arm.rotation
	r.x = pitch_rad
	spring_arm.rotation = r

func _physics_process(delta):
	_process_movement(delta)
	_apply_gravity(delta)
	move_and_slide()  # Godot 4: uses CharacterBody3D.velocity internally

func _process_movement(_delta):
	var in_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var in_z = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var input_dir = Vector3(in_x, 0.0, in_z)

	if input_dir.length() > 0.01:
		input_dir = input_dir.normalized()
		# player-relative movement (forward is player's forward)
		var player_basis = global_transform.basis
		var forward = -player_basis.z
		var right = player_basis.x
		var dir_world = (right * input_dir.x + forward * input_dir.z)
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
			velocity.x = lerp(velocity.x, 0.0, 0.18)
			velocity.z = lerp(velocity.z, 0.0, 0.18)
		else:
			velocity.x = lerp(velocity.x, 0.0, 0.02)
			velocity.z = lerp(velocity.z, 0.0, 0.02)

	# Jump using RayCast ground check
	if Input.is_action_just_pressed("jump") and _is_grounded():
		velocity.y = jump_velocity
		just_jumped = true

	# Slippery tweak
	if on_slippery and _is_grounded():
		velocity.x = lerp(velocity.x, velocity.x, 0.995)
		velocity.z = lerp(velocity.z, velocity.z, 0.995)

func _apply_gravity(delta):
	# If in the air, apply gravity
	if not _is_grounded():
		velocity.y -= gravity * delta
	else:
		# If we just jumped, allow upward velocity for this frame; clear flag afterwards
		if just_jumped:
			just_jumped = false
		else:
			if velocity.y < 0.0:
				velocity.y = 0.0

func _is_grounded() -> bool:
	if ray and ray.is_enabled():
		return ray.is_colliding()
	return is_on_floor()

# Called by WindZone to nudge player
func apply_wind(vec: Vector3):
	velocity += vec
