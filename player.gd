extends CharacterBody3D

# Movement
@export var speed: float = 10.0
@export var jump_velocity: float = 7.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var air_control: float = 0.25

# Mouse look
@export var mouse_sensitivity_x: float = 0.0035
@export var mouse_sensitivity_y: float = 0.0035
@export var min_pitch_deg: float = -75.0
@export var max_pitch_deg: float = -10.0

# Animation names (can override in the Inspector)
@export var anim_idle_name: String = "idle"
@export var anim_run_name: String = "run"
@export var anim_jump_name: String = "jump"
@export var anim_speed_threshold: float = 0.2

# internal nodes
var cam: Camera3D
var spring_arm: SpringArm3D
var ray: RayCast3D

# internal state
var pitch_rad: float = 0.0
var just_jumped: bool = false

# animation
var anim_player: AnimationPlayer = null
var anim_tree: AnimationTree = null

func _ready():
	# Cache node references (adjust paths if your nodes are named differently)
	cam = $SpringArm3D/Camera3D
	spring_arm = $SpringArm3D
	ray = $RayCast3D

	if ray:
		ray.enabled = true
		# prevent ray colliding with player
		ray.add_exception(self)

	# capture mouse for mouselook
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	pitch_rad = spring_arm.rotation.x

	# find animation nodes (AnimationPlayer or AnimationTree) under this Player
	_find_and_setup_animation_player(self)
	_autodetect_animation_names()

func _unhandled_input(event):
	# mouse look only when mouse is captured
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_update_mouse_look(event.relative)

func _process(_delta):
	# toggle mouse capture with Escape (ui_cancel)
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_mouse_look(relative: Vector2) -> void:
	# yaw (player)
	var yaw_delta = -relative.x * mouse_sensitivity_x
	rotate_y(yaw_delta)

	# pitch (spring arm)
	var pitch_delta = -relative.y * mouse_sensitivity_y
	pitch_rad = clamp(pitch_rad + pitch_delta, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	var r = spring_arm.rotation
	r.x = pitch_rad
	spring_arm.rotation = r

func _physics_process(delta):
	_process_movement(delta)
	_apply_gravity(delta)
	move_and_slide() # CharacterBody3D uses internal velocity
	_update_animation_state()

func _process_movement(_delta):
	# Use explicit strengths so forward/back is always correct
	var forward_strength = 0.0
	var back_strength = 0.0
	var left_strength = 0.0
	var right_strength = 0.0

	# prefer custom move_* actions, else fall back to ui_*
	if InputMap.has_action("move_forward"):
		forward_strength = Input.get_action_strength("move_forward")
		back_strength = Input.get_action_strength("move_back")
		left_strength = Input.get_action_strength("move_left")
		right_strength = Input.get_action_strength("move_right")
	else:
		forward_strength = Input.get_action_strength("ui_up")
		back_strength = Input.get_action_strength("ui_down")
		left_strength = Input.get_action_strength("ui_left")
		right_strength = Input.get_action_strength("ui_right")

	var in_x = right_strength - left_strength
	var in_z = forward_strength - back_strength
	var input_dir = Vector3(in_x, 0.0, in_z)

	if input_dir.length() > 0.01:
		input_dir = input_dir.normalized()
		# movement relative to player yaw
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

	# Jump
	if Input.is_action_just_pressed("jump") and _is_grounded():
		velocity.y = jump_velocity
		just_jumped = true

func _apply_gravity(delta):
	if not _is_grounded():
		velocity.y -= gravity * delta
	else:
		# keep upward velocity for the frame after a jump
		if just_jumped:
			just_jumped = false
		else:
			if velocity.y < 0.0:
				velocity.y = 0.0

func _is_grounded() -> bool:
	# prefer ray-based grounding (more stable on slopes); fallback to is_on_floor()
	if ray and ray.is_enabled():
		if ray.is_colliding():
			return true
	return is_on_floor()

# ---------------- Animation support ----------------
func _find_and_setup_animation_player(node: Node) -> void:
	for child in node.get_children():
		if child is AnimationPlayer:
			anim_player = child
			return
		elif child is AnimationTree:
			anim_tree = child
			return
		else:
			_find_and_setup_animation_player(child)

func _autodetect_animation_names() -> void:
	# if there is an AnimationPlayer and the exported names aren't valid, try to pick reasonable defaults
	if not anim_player:
		return
	var names := anim_player.get_animation_list()
	if names.size() == 0:
		return
	# normalize case for matching
	var lower_names := []
	for n in names:
		lower_names.append(String(n).to_lower())
	# Find run/walk first
	if not anim_player.has_animation(anim_run_name):
		for i in range(lower_names.size()):
			if lower_names[i].find("run") != -1 or lower_names[i].find("walk") != -1:
				anim_run_name = names[i]
				break
	# Find idle
	if not anim_player.has_animation(anim_idle_name):
		for i in range(lower_names.size()):
			if lower_names[i].find("idle") != -1 or lower_names[i].find("stand") != -1:
				anim_idle_name = names[i]
				break
	# Find jump
	if not anim_player.has_animation(anim_jump_name):
		for i in range(lower_names.size()):
			if lower_names[i].find("jump") != -1 or lower_names[i].find("leap") != -1:
				anim_jump_name = names[i]
				break
	# If still missing run or idle, fallback to first/second entries
	if not anim_player.has_animation(anim_idle_name) and names.size() > 0:
		anim_idle_name = names[0]
	if not anim_player.has_animation(anim_run_name):
		for n in names:
			if n != anim_idle_name:
				anim_run_name = n
				break

func _update_animation_state() -> void:
	if anim_player:
		# jumping/falling
		if not _is_grounded():
			if anim_player.has_animation(anim_jump_name):
				if anim_player.current_animation != anim_jump_name:
					anim_player.play(anim_jump_name)
			return

		# on ground: idle vs run
		var horiz_speed = Vector2(velocity.x, velocity.z).length()
		if horiz_speed > anim_speed_threshold and anim_player.has_animation(anim_run_name):
			if anim_player.current_animation != anim_run_name:
				anim_player.play(anim_run_name)
		else:
			if anim_player.has_animation(anim_idle_name):
				if anim_player.current_animation != anim_idle_name:
					anim_player.play(anim_idle_name)
		return

	# if AnimationTree present, activate it (detailed control depends on your tree setup)
	if anim_tree:
		anim_tree.active = true
		return

# Called by external systems (WindZone etc.) to nudge player
func apply_wind(vec: Vector3) -> void:
	velocity += vec
