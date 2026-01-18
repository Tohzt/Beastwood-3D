extends RigidBody3D
class_name HoldableClass

@export var offset: Vector3 = Vector3.ZERO
var outline
var holder: CharacterBody3D
var animation_player: AnimationPlayer
@export var is_held = false
@export var spawn_position: Vector3
@export var spawn_orientation: Vector3
var reset = false

func _ready():
	set_spawn.rpc()

func _process(_delta):
	if holder:
		var a = global_transform.origin
		var b = holder.hand.global_transform.origin
		linear_velocity = ((b-a) * 50)
		angular_velocity = Vector3.ZERO
		position = holder.hand.global_transform.origin
		if name != "Dartboard":
			rotation = holder.pitch_pivot.rotation
		rotation.y = holder.twist_pivot.rotation.y
	
	if position.y < -500: reset = true
	if reset:
		reset = false
		respawn.rpc()
	pass

	freeze_if_vertical()

	var players = get_tree().get_nodes_in_group("Players")
	for player in players:
		if outline and player.is_multiplayer_authority():
			var result = player.interact.get_collider()
			if !is_held and result and result == self:
				outline.visible = true
			else:
				outline.visible = false


func _unhandled_input(event):
	if is_held and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			match self.name:
				"PNC":
					holder.flip_power += 1
				"Dartboard":
					offset.z = clamp(offset.z - .05, -0.75, 0)
				"Gun":
					flip_gun.rpc("forward")
				"Basketball":
					holder.flip_power += 1
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			match self.name:
				"PNC":
					holder.flip_power -= 1
				"Dartboard":
					offset.z = clamp(offset.z + .05, -0.75, 0) 
				"Gun":
					flip_gun.rpc("backward")
				"Basketball":
					holder.flip_power -= 1
		holder.flip_power = clamp(holder.flip_power, 0, 100)

@rpc("any_peer", "call_local")
func flip_gun(dir):
	if (dir == "forward"):
		animation_player.play("Flip_Forward")
	if (dir == "backward"):
		animation_player.play("Flip_Backward")

func freeze_if_vertical():
	pass

@rpc("any_peer", "call_local")
func set_spawn():
	spawn_position = position
	spawn_orientation = rotation

@rpc("any_peer", "call_local")
func respawn():
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	rotation = spawn_orientation
	position = spawn_position

@rpc("any_peer", "call_local")
func set_frozen(t_f):
	freeze = t_f

@rpc("any_peer", "call_local")
func hold(player_id):
	var players = get_tree().get_nodes_in_group("Players")
	for player in players:
		if player.name == str(player_id):
			holder = player
			is_held = true
			set_frozen.rpc(false)
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO

@rpc("any_peer", "call_local", "unreliable")
func throw(flip_power):
	if is_held:
		var facing_dir = holder.twist_pivot.duplicate()
		facing_dir.rotation.y += deg_to_rad(-90)
		var flip_dir = facing_dir.basis.z.normalized()
		apply_impulse(Vector3(0,1,0) * 5)
		apply_torque(flip_dir * flip_power)
		is_held = false
		holder.interact.collide_with_bodies = true
		holder.item_in_hand = null
		holder = null

@rpc("any_peer", "call_local")
func drop():
	holder.interact.collide_with_bodies = true
	holder.item_in_hand = null
	holder = null
	is_held = false
