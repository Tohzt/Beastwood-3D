extends HoldableClass

@export var power = 0
@export var throw_direction =  Vector3.ZERO
@onready var offset_origin = Vector3(0,0.25,0)
var release

func _ready():
	outline = $Outline
	offset = offset_origin
	super._ready()
#
func _process(_delta):
	super._process(_delta)
	
	if holder != null:
		if Input.is_action_pressed("left_click"):
			_set_power.rpc()
	elif offset != offset_origin:
		offset = offset_origin

@rpc("any_peer", "call_local")
func _set_power():
	offset.z = min(0.2, offset.z + .01)
	power = lerp(0, 10, inverse_lerp(0, 0.2, offset.z))

@rpc("any_peer", "call_local", "unreliable")
func throw(_flip_power):
	if is_held:
		throw_direction = self.global_transform.basis.z.normalized()
		apply_impulse(throw_direction * -power)
		is_held = false
		holder.interact.collide_with_bodies = true
		holder.item_in_hand = null
		holder = null
