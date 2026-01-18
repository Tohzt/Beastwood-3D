extends Node3D

@onready var mirror = $Mirror
@onready var login_menu = $LoginMenu
@onready var pause_menu = $PauseMenu
@onready var color_picker = $ColorPicker
@onready var ThreeOnOnePole = $"ThreeOnOnePole"
@onready var other_respawns = $PauseMenu/PauseContainer/MarginContainer/VBoxContainer/OtherRespawns
@onready var spawn_player = $Spawn_Player
@export var play_3on1pole = false
const Player = preload("res://Player/player.tscn")
const PORT = 8910
@export var Address = "127.0.0.1"
var enet_peer

func _ready():
	ThreeOnOnePole.hide()
	color_picker.hide()
	pause_menu.hide()
	login_menu.show()

func _unhandled_input(_event):
	if Input.is_action_just_pressed("ui_cancel"):
		if login_menu.visible == false and color_picker.visible == false: 
			if pause_menu.visible == false:
				other_respawns.visible = is_multiplayer_authority()
				pause_menu.show()
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				_on_return_button_pressed()

@rpc("any_peer", "call_local")
func set_threeOnOnePole(t_f):
	play_3on1pole = t_f
	ThreeOnOnePole.visible = t_f

func select_player():
	var dart = get_tree().get_first_node_in_group("Darts")
	var players = get_tree().get_nodes_in_group("Players")
	var turn = randi_range(0, players.size()-1)
	players[turn].pick_up(dart, players[turn].multiplayer.get_unique_id())

func _on_host_button_pressed():
	login_menu.hide()
	color_picker.show()
	enet_peer = ENetMultiplayerPeer.new()
	printt(enet_peer, PORT)
	enet_peer.create_server(PORT)
	enet_peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(enet_peer)
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	add_player(multiplayer.get_unique_id())

func _on_join_button_pressed():
	login_menu.hide()
	color_picker.show()
	enet_peer = ENetMultiplayerPeer.new()
	enet_peer.create_client(Address, PORT)
	enet_peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(enet_peer)

func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)
	player.position = spawn_player.position
	add_child(player)

@rpc("any_peer")
func remove_player(id):
	var players = get_tree().get_nodes_in_group("Players")
	for player in players:
		if player.name == str(id):
			player.queue_free()

func _on_return_button_pressed():
	pause_menu.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_respawn_button_pressed():
	var players = get_tree().get_nodes_in_group("Players")
	for player in players:
		if player.is_multiplayer_authority():
			player.position = player.spawn_origin
	pause_menu.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_exit_button_pressed():
	get_tree().quit()
func _on_button_pressed():
	get_tree().quit()

func _on_respawn_pnc_pressed():
	var pncs = get_tree().get_nodes_in_group("PNC")
	for pnc in pncs:
		pnc.respawn.rpc()

func _on_respawn_dartboard_pressed():
	var dartboard = get_tree().get_first_node_in_group("Dartboard")
	dartboard.respawn.rpc()

func _on_respawn_darts_pressed():
	var darts = get_tree().get_nodes_in_group("Darts")
	for dart in darts:
		dart.respawn.rpc()
		
func _on_respawn_all():
	_on_respawn_pnc_pressed()
	_on_respawn_dartboard_pressed()
	_on_respawn_darts_pressed()
	var Others = get_tree().get_nodes_in_group("Other")
	for other in Others:
		other.respawn.rpc()


func _on_red_button_pressed():
	var col = %RedButton.texture_normal.gradient.get_color(0)
	_set_player_color(col)
func _on_green_button_pressed():
	var col = %GreenButton.texture_normal.gradient.get_color(0)
	_set_player_color(col)
func _on_blue_button_pressed():
	var col = %BlueButton.texture_normal.gradient.get_color(0)
	_set_player_color(col)
func _on_yellow_button_pressed():
	var col = %YellowButton.texture_normal.gradient.get_color(0)
	_set_player_color(col)
func _on_pink_button_pressed():
	var col = %PinkButton.texture_normal.gradient.get_color(0)
	_set_player_color(col)
func _on_light_blue_button_pressed():
	var col = %LightBlueButton.texture_normal.gradient.get_color(0)
	_set_player_color(col)
func _on_brown_button_pressed():
	var col = %BrownButton.texture_normal.gradient.get_color(0)
	_set_player_color(col)
func _on_orange_button_pressed():
	var col = %OrangeButton.texture_normal.gradient.get_color(0)
	_set_player_color(col)

func _set_player_color(col):
	var players = get_tree().get_nodes_in_group("Players")
	for player in players:
		if int(str(player.name)) == multiplayer.get_unique_id():
			player.set_color.rpc(col)
	color_picker.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_colors.rpc()

@rpc("any_peer")
func _update_colors():
	var players = get_tree().get_nodes_in_group("Players")
	for player in players:
			player.set_color.rpc(player.color)

func _on_color_button_pressed():
	pause_menu.hide()
	color_picker.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
