extends HoldableClass

@export var power = 0
@export var dart_direction =  Vector3.ZERO
@onready var offset_origin = Vector3(0,0.25,0)
var release
#@onready var red_dart = preload("res://Assets/Objects/Dart/dart_red.png")
#@onready var blue_dart = preload("res://Assets/Objects/Dart/dart_blue.png")
func _ready():
	outline = $DartMesh3D/Outline
	offset = offset_origin
	super._ready()
#	var colors = [red_dart, blue_dart]
#	var rand_dart = colors[randi() % colors.size()]
#	$DartMesh3D.get_active_material(0).set("albedo_texture", rand_dart)
#
func _process(_delta):
	super._process(_delta)
	
	if holder == null and !freeze:
		if get_contact_count():
			freeze = true
			offset = offset_origin
	if holder != null:
		if Input.is_action_pressed("left_click"):
			_set_power.rpc()

@rpc("any_peer", "call_local")
func _set_power():
	offset.z = min(0.2, offset.z + .01)
	power = lerp(0, 10, inverse_lerp(0, 0.2, offset.z))

@rpc("any_peer", "call_local", "unreliable")
func throw(_flip_power):
	if is_held:
		dart_direction = self.global_transform.basis.z.normalized()
		apply_impulse(dart_direction * -power)
		is_held = false
		holder.interact.collide_with_bodies = true
		holder.item_in_hand = null
		holder = null
