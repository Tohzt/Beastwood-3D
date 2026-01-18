extends StaticBody3D
@onready var outline: MeshInstance3D = $Outline
var UI_ColorPicker: CanvasLayer

func _ready():
	outline = $Outline
	UI_ColorPicker = get_tree().get_first_node_in_group("ColorPicker")

func open_colorpicker() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	UI_ColorPicker.show()
