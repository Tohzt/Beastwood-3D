extends HoldableClass

@export var power = 0
@onready var offset_origin = Vector3(0,0,0)

func _ready():
	outline = $Outline
	offset = offset_origin
	super._ready()
#
func _process(_delta):
	super._process(_delta)
