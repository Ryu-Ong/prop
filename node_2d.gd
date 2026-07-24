extends Node2D

@export var hunter_scene : PackedScene
@export var hider_scene : PackedScene

@onready var timer = $UI/Control/VBoxContainer/Timer/Label
@onready var leveltimer = $LevelTimer

func _ready():
	print("READY - my id: ", multiplayer.get_unique_id(), " is server: ", multiplayer.is_server())
	print("My role: ", Global.my_role)

	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(remove_player)

	Global.enter_game()

	if Global.my_role == "hider":
		show_role_label()
		leveltimer.stop()
		# 30s hiding phase with visible countdown
		for i in range(30, 0, -1):
			timer.text = str(i)
			await get_tree().create_timer(1.0).timeout
		leveltimer.wait_time = 180.0
		leveltimer.start()
	else:
		# hunter arrives after their 31s waiting room, match is starting now
		leveltimer.stop()
		leveltimer.wait_time = 180.0
		leveltimer.start()

	timer.text = str(int(leveltimer.time_left))

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
	if not leveltimer.is_stopped():
		timer.text = str(int(leveltimer.time_left))

func hider_win():
	end_game_hiders_win.rpc()

@rpc("any_peer", "call_local", "reliable")
func end_game_hiders_win():
	get_tree().change_scene_to_file("res://hiders_win.tscn")

var first_timeout = true
func _on_level_timer_timeout() -> void:
	hider_win()
