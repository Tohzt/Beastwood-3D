extends CharacterBody3D

const SPEED = 4.0
const JUMP_VELOCITY = 3.3  # Initial upward velocity (applied on press)
const JUMP_HOLD_GRAVITY_SCALE = 0.28  # While holding jump and moving up, gravity is reduced (Mario-style variable height)
const TRAMPOLINE_JUMP_MULTIPLIER = 2.0
const TRAMPOLINE_BOUNCE_BASE = 2.5
const TRAMPOLINE_BOUNCE_DAMPING = 0.6
const TRAMPOLINE_JUMP_BOOST = 1.5
const LANDING_DEATH_SPEED = 25.0  # Fall speed (m/s) above which we play death animation on land
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var previous_velocity_y = 0.0
var flip_power = 0
@onready var flip_power_label = $MarginContainer/FlipPowerLabel
@onready var its_garbage = $MarginContainer/ItsGarbage
@onready var camera = $TwistPivot/PitchPivot/SpringArm3D/Camera3D
#@onready var material = $CollisionShape3D/MeshInstance3D
@onready var material = $"3DGodotRobot"
@onready var swing_arm = $TwistPivot/PitchPivot/SpringArm3D
@onready var interact = $TwistPivot/PitchPivot/Interact
@onready var hand = $TwistPivot/PitchPivot/Hand
@onready var twist_pivot := $TwistPivot
@onready var pitch_pivot := $TwistPivot/PitchPivot
@export var first_person: bool = false
@export var color = Color(0,0,0,1)
var item_in_hand
var mouse_sensativity := 0.001
var twist_input := 0.0
var pitch_input := 0.0
#@onready var animation_player = $"3DGodotRobot/AnimationPlayer"
@onready var animation_player = $"3DGodotRobot/Thing/AnimationPlayer"

var spawn_origin: Vector3
var hand_origin: Vector3

var is_sprinting: bool = false
var was_in_air: bool = false  # Used for jump land animation
var in_death_pose: bool = false  # Holding death last frame until player moves

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	animation_player.play("CharacterArmature|Idle")
	animation_player.animation_finished.connect(_on_animation_finished)
	if not is_multiplayer_authority(): return
	get_parent().mirror.MainCamPath = camera.get_path()
	toggle_first_person(first_person)
	spawn_origin = position
	hand_origin = hand.position
	camera.current = true

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "CharacterArmature|Jump":
		# Jump plays once; go to Jump_Idle for the rest of the air time
		if !is_on_floor():
			animation_player.play("CharacterArmature|Jump_Idle")
	elif anim_name == "CharacterArmature|Jump_Land":
		# Transition to Idle/Run after landing animation
		if velocity != Vector3.ZERO:
			animation_player.play("CharacterArmature|Run")
		else:
			animation_player.play("CharacterArmature|Idle")
	elif anim_name == "CharacterArmature|Death":
		# Play Death_Idle until the player moves
		animation_player.play("CharacterArmature|Death_Idle")

func _process(delta):
	if !is_multiplayer_authority(): return
	
	## TODO: Weird Garbage pre-garbage
	var selected_item = interact.get_collider()
	if selected_item:
		if selected_item.name == "Garbage" and Input.is_action_just_pressed("interact"):
			if !its_garbage.visible:
				its_garbage.show()
				await get_tree().create_timer(2).timeout
				its_garbage.hide()
		if selected_item.name == "ColorPickerBlock" and Input.is_action_just_pressed("interact"):
			selected_item.open_colorpicker()
	
	flip_power_label.visible = false
	if item_in_hand:
		hand.position = hand_origin + item_in_hand.offset
		if item_in_hand.name == "PNC":
			flip_power_label.text = "Flicka Da Wrist: " + str(flip_power)
			if flip_power == 100:
				flip_power_label.text = "Dat Wrist!"
			flip_power_label.visible = true
	
	if animation_player.current_animation == "T-pose":
		var flip_rotation = deg_to_rad(lerp(0,360,animation_player.current_animation_position/animation_player.current_animation_length))
		if first_person:
			pitch_pivot.rotation.x = flip_rotation
		material.rotation.x = flip_rotation
	
	if is_on_floor():
		# Check if we're standing on a trampoline (don't play Idle/Run on trampoline)
		var floor_collision = get_last_slide_collision()
		var on_trampoline_now = false
		if floor_collision:
			var col = floor_collision.get_collider()
			if col and col.is_in_group("Trampoline"):
				on_trampoline_now = true
		if Input.is_action_just_pressed("jump"):
			var base_jump = JUMP_VELOCITY
			if on_trampoline_now:
				velocity.y = base_jump * TRAMPOLINE_JUMP_MULTIPLIER
			else:
				velocity.y = base_jump
			animation_player.play("CharacterArmature|Jump")
		
		# Only play Idle/Run on solid ground; don't override Jump/Jump_Land. Death holds last frame until player moves.
		var move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var getting_up = in_death_pose and move_input != Vector2.ZERO
		if getting_up:
			in_death_pose = false
		if !on_trampoline_now\
		and !Input.is_action_just_pressed("jump")\
		and animation_player.current_animation != "Crouch"\
		and animation_player.current_animation != "T-pose"\
		and animation_player.current_animation != "CharacterArmature|Jump_Land"\
		and animation_player.current_animation != "CharacterArmature|Jump"\
		and !in_death_pose:
			if velocity != Vector3.ZERO or getting_up:
				animation_player.play("CharacterArmature|Run")
			else:
				animation_player.play("CharacterArmature|Idle")
		if Input.is_action_pressed("crouch"):
			animation_player.play("CharacterArmature|Wave")
		
		is_sprinting = false
		if Input.is_action_pressed("shift"):
			is_sprinting = true
	if !is_on_floor():
		# Jump_Idle when falling, Jump when rising
		if velocity.y < 0:
			animation_player.play("CharacterArmature|Jump_Idle")
		# Variable height: holding jump reduces gravity while moving up (Mario-style)
		if Input.is_action_pressed("jump") and velocity.y > 0:
			velocity.y -= gravity * JUMP_HOLD_GRAVITY_SCALE * delta
		else:
			velocity.y -= gravity * delta
	_input_direction()
	if is_sprinting:
		velocity *= Vector3(1.5,1,1.5)
	
	# Track previous velocity for bounce detection
	var was_falling = previous_velocity_y < 0
	previous_velocity_y = velocity.y
	
	move_and_slide()
	
	# Check for trampoline bounce or play land animation when landing
	if is_on_floor() and was_falling:
		var collision = get_last_slide_collision()
		var on_trampoline = false
		if collision:
			var collider = collision.get_collider()
			if collider and collider.is_in_group("Trampoline"):
				on_trampoline = true
				# Calculate bounce based on fall velocity (with damping)
				var fall_velocity = abs(previous_velocity_y)
				var bounce_velocity = TRAMPOLINE_BOUNCE_BASE + (fall_velocity * TRAMPOLINE_BOUNCE_DAMPING)
				# If jump is pressed while landing, boost the bounce
				if Input.is_action_pressed("jump"):
					bounce_velocity *= TRAMPOLINE_JUMP_BOOST
				velocity.y = bounce_velocity
				animation_player.play("CharacterArmature|Jump")
		if !on_trampoline and was_in_air:
			# Hard landing: play death; otherwise play land
			if abs(previous_velocity_y) >= LANDING_DEATH_SPEED:
				animation_player.play("CharacterArmature|Death")
				in_death_pose = true
			else:
				animation_player.play("CharacterArmature|Jump_Land")
	
	was_in_air = !is_on_floor()

func _unhandled_input(event: InputEvent) -> void:
	if!is_multiplayer_authority(): return
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_camera_rotation(event)
	
	if Input.is_action_just_pressed("tab"):
		toggle_first_person(!first_person)
		
	pick_up_item()

func _camera_rotation(event):
	twist_input = - event.relative.x * mouse_sensativity
	pitch_input = - event.relative.y * mouse_sensativity
	# Set rotation directly instead of using rotate methods for better sync detection
	twist_pivot.rotation.y += twist_input
	material.rotation.y += twist_input
	pitch_pivot.rotation.x += pitch_input
	pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, -1.5, 1)
	twist_input = 0.0
	pitch_input = 0.0

func _input_direction():
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = (twist_pivot.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

func toggle_first_person(t_or_f):
	first_person = t_or_f
	swing_arm.spring_length = 0 if t_or_f else 2
	swing_arm.position.y = 0
	swing_arm.position.z = 0
	self.visible  = !t_or_f

func pick_up_item():
	if item_in_hand:
		if Input.is_action_just_released("left_click"):
			item_in_hand.throw.rpc(flip_power)
		if Input.is_action_just_pressed("right_click"):
			item_in_hand.drop.rpc()
		return
	else:
		var collider = interact.get_collider()
		if collider != null and collider is RigidBody3D and !collider.is_held:
			if Input.is_action_just_pressed("interact"):
				pick_up(collider)

func pick_up(item: HoldableClass, id = multiplayer.get_unique_id()):
	if multiplayer.get_unique_id() == id: 
		interact.collide_with_bodies = false
		item.linear_velocity = Vector3.ZERO
		item.angular_velocity = Vector3.ZERO
		item_in_hand = item
		item.hold.rpc(id)

@rpc("any_peer", "call_remote")
func set_color(col):
	# Allow any peer to call, but verify it's the correct player
	# call_remote: runs on all remote peers (server and other clients)
	var player_id = int(str(name))
	var sender_id = multiplayer.get_remote_sender_id()

	# Validate sender: allow if:
	# - sender_id == 0: local call (authority calling directly)
	# - sender_id == player_id: RPC from the player who owns this character
	# - sender_id == 1: server relaying color to clients
	var is_valid = (sender_id == 0) or (sender_id == player_id) or (sender_id == 1)
	if not is_valid:
		print("[WARNING] set_color RPC received for wrong player! Player ID: %d, Sender ID: %d" % [player_id, sender_id])
		return

	print("[PLAYER %s] Setting color to %s (is_server: %s, sender: %d)" % [name, col, multiplayer.is_server(), sender_id])
	color = col

	# SERVER RELAY: If we're the server and received this from a client, relay to all other clients
	# This is needed because in ENet, client RPCs only go to server, not other clients
	if multiplayer.is_server() and sender_id != 0 and sender_id != 1:
		set_color.rpc(col)
	var robot_multi_mesh = [$"3DGodotRobot/RobotArmature/Skeleton3D/Bottom",$"3DGodotRobot/RobotArmature/Skeleton3D/Chest",$"3DGodotRobot/RobotArmature/Skeleton3D/Face",$"3DGodotRobot/RobotArmature/Skeleton3D/Llimbs and head", $"3DGodotRobot/Thing/RootNode/CharacterArmature/Skeleton3D/FinnTheFrog"]
	
	# Handle the frog mesh separately (it uses get_active_material instead of surface_override)
	var frog_mesh = $"3DGodotRobot/Thing/RootNode/CharacterArmature/Skeleton3D/FinnTheFrog"
	if frog_mesh:
		var frog_mat: StandardMaterial3D = frog_mesh.get_active_material(0)
		if frog_mat is StandardMaterial3D:
			var new_mat = frog_mat.duplicate()
			new_mat.albedo_color = col
			frog_mesh.set_surface_override_material(0, new_mat)
	
	# Handle all other meshes
	for mesh: MeshInstance3D in robot_multi_mesh:
		if mesh == frog_mesh:
			continue  # Already handled above
		var mat = mesh.get_surface_override_material(0)
		if mat != null:
			# Duplicate material to avoid sharing between player instances
			var new_mat = mat.duplicate()
			new_mat.albedo_color = col
			mesh.set_surface_override_material(0, new_mat)

#func ascend_stairs(delta):
#	var collision = move_and_collide(velocity * delta, true)
#	if is_on_floor() and collision: 
#		if collision.get_collider().name == "StaticBody3D":
#			var test_velocity = velocity
#			test_velocity.y = 50
#			var test_move = move_and_collide(test_velocity * delta, true)
#			if !test_move:
##				velocity.y = move_toward(0, 3, SPEED)
#				move_and_collide(test_velocity * delta)
