extends Node

var my_role = "hider"
var all_roles = {}  # {peer_id: "hunter" or "hider"}
var in_game_peers = []  # server-side: peers whose game scene is loaded

func _ready():
	multiplayer.peer_disconnected.connect(func(id): in_game_peers.erase(id))

# called by node_2d.gd when the game scene loads on any peer
func enter_game():
	if multiplayer.is_server():
		_register(multiplayer.get_unique_id())
	else:
		_register_rpc.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _register_rpc():
	_register(multiplayer.get_remote_sender_id())

# server only: handles a peer arriving in the game scene
func _register(id: int):
	if not multiplayer.is_server():
		return
	if in_game_peers.has(id):
		return
	# cross-spawn: existing peers spawn the newcomer, newcomer spawns existing peers
	for peer_id in in_game_peers:
		_spawn_on(peer_id, id)
		_spawn_on(id, peer_id)
	in_game_peers.append(id)
	# newcomer spawns themselves
	_spawn_on(id, id)

# spawn `spawn_id`'s player on `target_peer`'s machine
func _spawn_on(target_peer: int, spawn_id: int):
	if target_peer == multiplayer.get_unique_id():
		_do_spawn(spawn_id)
	else:
		_do_spawn_rpc.rpc_id(target_peer, spawn_id)

@rpc("authority", "call_remote", "reliable")
func _do_spawn_rpc(spawn_id: int):
	_do_spawn(spawn_id)

func _do_spawn(spawn_id: int):
	var scene_root = get_tree().current_scene
	if scene_root and scene_root.has_method("spawn_player"):
		scene_root.spawn_player(spawn_id)
