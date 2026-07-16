extends Node

var my_role = "hider"
var all_roles = {}
var in_game_peers = []
var dead_hiders = []

func _ready():
	multiplayer.peer_disconnected.connect(func(id): in_game_peers.erase(id))

func enter_game():
	if multiplayer.is_server():
		_register(multiplayer.get_unique_id())
	else:
		_register_rpc.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _register_rpc():
	_register(multiplayer.get_remote_sender_id())

func _register(id: int):
	if not multiplayer.is_server():
		return
	if in_game_peers.has(id):
		return
	for peer_id in in_game_peers:
		_spawn_on(peer_id, id)
		_spawn_on(id, peer_id)
	in_game_peers.append(id)
	_spawn_on(id, id)
	_update_peer_list.rpc(in_game_peers)

@rpc("authority", "call_remote", "reliable")
func _update_peer_list(peers: Array):
	in_game_peers = peers

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

# ---- death handling ----

func report_death(id: int):
	if dead_hiders.has(id):
		return
	dead_hiders.append(id)

	var scene = get_tree().current_scene
	if scene and scene.has_node(str(id)):
		var node = scene.get_node(str(id))
		# if it's MY player that died, set up a spectator view first
		if id == multiplayer.get_unique_id():
			var cam = Camera2D.new()
			cam.position = node.position
			scene.add_child(cam)
			cam.make_current()
			var label = Label.new()
			label.text = "You died! Spectating..."
			label.modulate = Color(1, 0.3, 0.3)
			label.add_theme_font_size_override("font_size", 32)
			label.set_anchors_preset(Control.PRESET_CENTER_TOP)
			label.position = Vector2(-150, 20)
			if scene.has_node("UI"):
				scene.get_node("UI").add_child(label)
		node.queue_free()

	# hunters win when every hider is dead
	var total_hiders = 0
	for pid in all_roles:
		if all_roles[pid] == "hider":
			total_hiders += 1
	if dead_hiders.size() >= total_hiders:
		get_tree().change_scene_to_file("res://hunters_win.tscn")
