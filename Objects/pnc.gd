extends HoldableClass

@export var debug = false
@onready var debug_container = $DebugContainer
@onready var offset_label = $DebugContainer/VBoxContainer/Offset_Label
@onready var holder_label = $DebugContainer/VBoxContainer/Holder_Label
@onready var held_label = $DebugContainer/VBoxContainer/Held_Label
@onready var l_vel_label = $DebugContainer/VBoxContainer/LVel_Label
@onready var a_vel_label = $DebugContainer/VBoxContainer/AVel_Label
@onready var freeze_label = $DebugContainer/VBoxContainer/Freeze_Label

func _ready():
	outline = $Foam/Outline
	super._ready()

func _process(_delta):
	super._process(_delta)
	debug_container.visible = debug
	if debug: 
		offset_label.text = "Offset: " + str(offset)
		holder_label.text = "Holder: " + str(holder)
		held_label.text = "Is Held: " + str(is_held)
		l_vel_label.text = "Linear: " + str(linear_velocity)
		a_vel_label.text = "Angular: " + str(angular_velocity)
		freeze_label.text = "Freeze: " + str(freeze)

func freeze_if_vertical():
	var epsilon = 0.005 
	if get_contact_count():
		for body in get_colliding_bodies():
			if body.get_class() == "StaticBody3D":
				if abs(linear_velocity.length()) < .01 and abs(rotation.x) < epsilon:
					freeze = true
