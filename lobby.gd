extends Node

const PORT = 7777
const MAX_PLAYERS = 8

@onready var ip_field = $VBoxContainer/LineEdit
@onready var start_btn = $VBoxContainer/ButtonStart
@onready var player_list = $VBoxContainer/ItemList

var connected_peers = []

func _ready():
	start_btn.visible = false
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	start_btn.visible = true
	add_player_to_list(multiplayer.get_unique_id())

func _on_join_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip_field.text, PORT)
	multiplayer.multiplayer_peer = peer

func _on_connected_to_server():
	add_player_to_list(multiplayer.get_unique_id())

func _on_peer_connected(id: int):
	connected_peers.append(id)
	add_player_to_list(id)

func _on_peer_disconnected(id: int):
	connected_peers.erase(id)
	for i in player_list.item_count:
		if player_list.get_item_text(i) == str(id):
			player_list.remove_item(i)
			break

func add_player_to_list(id: int):
	player_list.add_item(str(id))

func _on_start_pressed():
	if not multiplayer.is_server():
		return
	Global.in_game_peers.clear()
	Global.dead_hiders.clear()
	var all_peers = [multiplayer.get_unique_id()] + connected_peers
	var hunter_id = all_peers[randi() % all_peers.size()]
	var role_map = {}
	for id in all_peers:
		role_map[id] = "hunter" if id == hunter_id else "hider"
	for id in all_peers:
		if id == multiplayer.get_unique_id():
			Global.my_role = role_map[id]
			Global.all_roles = role_map
		else:
			assign_role.rpc_id(id, role_map[id], role_map)
	await get_tree().create_timer(0.3).timeout
	load_game.rpc()

@rpc("authority", "call_remote", "reliable")
func assign_role(role: String, role_map: Dictionary):
	Global.my_role = role
	Global.all_roles = role_map
	print("I am a: ", role)
	print("All roles: ", role_map)

@rpc("authority", "call_local", "reliable")
func load_game():
	get_tree().change_scene_to_file("res://node_2d.tscn")
