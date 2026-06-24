extends Node2D

@export var player_scene : PackedScene

func _ready():
	# everyone spawns their own player
	spawn_player(multiplayer.get_unique_id())
	
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(remove_player)
	else:
		# tell server we're ready so it spawns us on its end
		notify_server_ready.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func notify_server_ready():
	var id = multiplayer.get_remote_sender_id()
	# spawn this client on the server
	spawn_player(id)
	# tell all other clients to spawn this player too
	spawn_player_rpc.rpc(id)

@rpc("any_peer", "call_local", "reliable")
func spawn_player_rpc(id: int):
	spawn_player(id)

func spawn_player(id: int):
	if has_node(str(id)):
		return
	var player = player_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	add_child(player)
	player.position = Vector2(200 + randi() % 200, 200 + randi() % 200)
	print("SPAWNED: ", id, " auth: ", player.get_multiplayer_authority())

func remove_player(id: int):
	if has_node(str(id)):
		get_node(str(id)).queue_free()
