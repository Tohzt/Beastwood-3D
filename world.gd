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
var is_dedicated_server := false
var admin_peer_id := -1  # First player to connect becomes admin

func _ready():
	ThreeOnOnePole.hide()
	color_picker.hide()
	pause_menu.hide()

	# Check for dedicated server mode via command line
	var args = OS.get_cmdline_args()
	if "--server" in args:
		_start_dedicated_server()
	else:
		login_menu.show()

func _start_dedicated_server():
	is_dedicated_server = true
	login_menu.hide()
	print("[SERVER] Starting dedicated server on port %d..." % PORT)

	enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_server(PORT)
	if error != OK:
		print("[SERVER] Failed to create server: %s" % error_string(error))
		get_tree().quit(1)
		return

	enet_peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(enet_peer)
	multiplayer.peer_connected.connect(_on_peer_connected_dedicated)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected_dedicated)
	print("[SERVER] Server started successfully. Waiting for players...")

func _on_peer_connected_dedicated(peer_id):
	print("[SERVER] Player connected: %d" % peer_id)
	# First player becomes admin
	if admin_peer_id == -1:
		admin_peer_id = peer_id
		print("[SERVER] Player %d is now the admin" % peer_id)
		_sync_admin_id.rpc(peer_id)
	add_player(peer_id)
	# Sync existing player colors to the new peer after a short delay
	# (wait for the new player's node to be ready)
	_sync_colors_to_peer.call_deferred(peer_id)

func _on_peer_disconnected_dedicated(peer_id):
	print("[SERVER] Player disconnected: %d" % peer_id)
	remove_player(peer_id)
	# If admin disconnects, promote the next player
	if peer_id == admin_peer_id:
		var players = get_tree().get_nodes_in_group("Players")
		if players.size() > 0:
			admin_peer_id = int(str(players[0].name))
			print("[SERVER] New admin: %d" % admin_peer_id)
			_sync_admin_id.rpc(admin_peer_id)
		else:
			admin_peer_id = -1
			print("[SERVER] No players remaining, no admin")

func is_admin() -> bool:
	if is_dedicated_server:
		return false  # Server itself is never "admin" in gameplay sense
	# On client: check if we are the admin
	return multiplayer.get_unique_id() == admin_peer_id or multiplayer.is_server()

@rpc("authority", "call_remote", "reliable")
func _sync_admin_id(peer_id):
	admin_peer_id = peer_id

func _unhandled_input(_event):
	if Input.is_action_just_pressed("ui_cancel"):
		if login_menu.visible == false and color_picker.visible == false: 
			if pause_menu.visible == false:
				other_respawns.visible = is_admin()
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
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

func _on_connected_to_server():
	print("[CLIENT] Connected to server, waiting for player spawn...")

func add_player(peer_id):
	# Only server should spawn players
	if not multiplayer.is_server():
		print("[CLIENT] Ignoring add_player call - not server")
		return
		
	print("[SERVER] Spawning player for peer: %d at position: %s" % [peer_id, spawn_player.position])
	var player = Player.instantiate()
	player.name = str(peer_id)
	# Set position after adding to ensure it's set correctly
	add_child(player, true)  # force_readable_name = true for multiplayer
	# Wait a frame for the node to be fully in the tree, then set position
	await get_tree().process_frame
	player.position = spawn_player.position
	print("[SERVER] Player %d spawned at: %s" % [peer_id, player.position])

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
	var my_id = multiplayer.get_unique_id()
	for player in players:
		var player_id = int(str(player.name))
		if player_id == my_id:
			print("[CLIENT] Setting color for player %d (me)" % player_id)
			# Call directly on local player (runs immediately)
			player.set_color(col)
			# Then RPC to sync to server and other clients
			player.set_color.rpc(col)
			break  # Found our player, no need to continue
	color_picker.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

@rpc("any_peer")
func _update_colors():
	var players = get_tree().get_nodes_in_group("Players")
	for player in players:
			player.set_color.rpc(player.color)

func _sync_colors_to_peer(peer_id):
	# Server-only: send all existing player colors to a newly connected peer
	if not multiplayer.is_server():
		return
	# Wait a couple frames for the new peer's nodes to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	print("[SERVER] Syncing existing player colors to peer %d" % peer_id)
	var players = get_tree().get_nodes_in_group("Players")
	for player in players:
		var player_color = player.color
		# Only sync if player has a non-default color (not black)
		if player_color != Color(0, 0, 0, 1):
			print("[SERVER] Sending color %s for player %s to peer %d" % [player_color, player.name, peer_id])
			player.set_color.rpc_id(peer_id, player_color)

func _on_color_button_pressed():
	pause_menu.hide()
	color_picker.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
