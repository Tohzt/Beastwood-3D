extends HoldableClass

@export var power = 0
@onready var offset_origin = Vector3(0.1,0.1,.15)

func _ready():
	animation_player = $AnimationPlayer
	animation_player.play("Idle")
	outline = $Outline
	offset = offset_origin
	super._ready()
#
func _process(_delta):
	super._process(_delta)

@rpc("any_peer", "call_local", "unreliable")
func throw(_flip_power):
	animation_player.play("Recoil")
