extends Node2D

@export var hunter_scene : PackedScene
@export var hider_scene : PackedScene

@onready var timer = $UI/Control/VBoxContainer/Timer/Label
@onready var leveltimer = $LevelTimer

func _ready():
	print("READY - my id: ", multiplayer.get_unique_id(), " is server: ", multiplayer.is_server())
	print("My role: ", Global.my_role)
	timer.text = str(int(leveltimer.time_left))

	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(remove_player)
		spawn_player(multiplayer.get_unique_id())
		if Global.my_role == "hider":
			show_role_label()
			start_hider_countdown()
	else:
		notify_server_ready.rpc_id(1)
		if Global.my_role == "hider":
			show_role_label()
			start_hider_countdown()

func show_role_label():
	var label = Label.new()
	label.text = "You are the HIDER!"
	label.modulate = Color(0.3, 1, 0.3)
	label.add_theme_font_size_override("font_size", 32)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(-200, 20)
	$UI.add_child(label)
	await get_tree().create_timer(3.0).timeout
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	await tween.finished
	label.queue_free()

func start_hider_countdown():
	var label = Label.new()
	label.name = "HunterCountdown"
	label.add_theme_font_size_override("font_size", 24)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(-200, 60)
	label.modulate = Color(1, 0.5, 0.5)
	$UI.add_child(label)
	for i in range(30, 0, -1):
		label.text = "Hunter spawns in: " + str(i)
		await get_tree().create_timer(1.0).timeout
	label.text = "Hunter has spawned! Hide!"
	await get_tree().create_timer(2.0).timeout
	label.queue_free()

@rpc("any_peer", "call_remote", "reliable")
func notify_server_ready():
	var id = multiplayer.get_remote_sender_id()
	spawn_player(id)
	spawn_player_rpc.rpc(id)
	spawn_player_rpc.rpc_id(id, id)
	for child in get_children():
		if not child is CharacterBody2D:
			continue
		var existing_id = int(child.name)
		if existing_id != id:
			spawn_player_rpc.rpc_id(id, existing_id)

@rpc("any_peer", "call_remote", "reliable")
func spawn_player_rpc(id: int):
	spawn_player(id)

func spawn_player(id: int):
	if has_node(str(id)):
		return
	var role = Global.all_roles.get(id, "hider")
	var scene = hider_scene if role == "hider" else hunter_scene
	var player = scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	add_child(player)
	player.position = Vector2(0, 0)

func remove_player(id: int):
	if has_node(str(id)):
		get_node(str(id)).queue_free()

func _process(delta):
	timer.text = str(int(leveltimer.time_left))

func hider_win():
	get_tree().change_scene_to_file("res://hiders_win.tscn")

var first_timeout = true
func _on_level_timer_timeout() -> void:
	if first_timeout:
		first_timeout = false
		$LevelTimer.wait_time = 180.0
		$LevelTimer.start()
	else:
		hider_win()
