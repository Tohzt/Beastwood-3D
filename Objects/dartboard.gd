extends HoldableClass

func _ready():
	outline = $DartboardMesh3D/Outline
	super._ready()

func _process(_delta):
	super._process(_delta)
	if freeze:
		var pnc = get_tree().get_nodes_in_group("PNC")[0]
		if !pnc.freeze:
			set_frozen.rpc(false)
			get_parent().set_threeOnOnePole.rpc(false)

func freeze_if_vertical():
	var epsilon = 0.005 
	if get_contact_count() and !is_held:
		for body in get_colliding_bodies():
			if body.name == "PNC":
				if abs(linear_velocity.length()) < .01 and abs(rotation.x) < epsilon:
					set_frozen.rpc(true)
					get_parent().set_threeOnOnePole.rpc(true)

@rpc("any_peer", "call_local")
func hold(player_id):
	if freeze:
		get_parent().set_threeOnOnePole.rpc(false)
	super.hold(player_id)
