extends Node2D

@export var player_scene : PackedScene
@export var Hider_scene : PackedScene
@onready var timer = $UI/Control/VBoxContainer/Timer/Label
@onready var leveltimer = $LevelTimer

func _ready():
	print("READY - my id: ", multiplayer.get_unique_id(), " is server: ", multiplayer.is_server())
	spawn_player(multiplayer.get_unique_id())
	timer.text = str(int(leveltimer.time_left))
	
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(remove_player)
	else:
		notify_server_ready.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func notify_server_ready():
	var id = multiplayer.get_remote_sender_id()
	spawn_player(id)
	spawn_player_rpc.rpc(id)
	for child in get_children():
		if not child is CharacterBody2D:
			continue
		var existing_id = int(child.name)
		if existing_id != id:
			spawn_player_rpc.rpc_id(id, existing_id)

@rpc("any_peer", "call_remote", "reliable")
func spawn_player_rpc(id: int):
	print("spawn_player_rpc called for: ", id, " on peer: ", multiplayer.get_unique_id())
	spawn_player(id)

func spawn_player(id: int):
	print("spawn_player called for: ", id, " exists already: ", has_node(str(id)))
	if has_node(str(id)):
		return
	var player = player_scene.instantiate()
	var Hider = Hider_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	add_child(player)
	player.position = Vector2(0, 0)
	Hider.name = str(id)
	Hider.set_multiplayer_authority(id)
	add_child(Hider)
	Hider.position = Vector2(0, 0)
# player.position = Vector2(200 + randi() % 200, 200 + randi() % 200)

func remove_player(id: int):
	if has_node(str(id)):
		get_node(str(id)).queue_free()
		
func _process(delta):
	timer.text = str(int(leveltimer.time_left))

func game_over():
	get_tree().change_scene_to_file("res://asset/Main_menu.tscn")

func _on_level_timer_timeout() -> void:
	game_over()
	pass # Replace with function body.
