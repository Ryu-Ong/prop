extends Node2D

@export var hunter_scene : PackedScene

func _ready():
	var role = $CanvasLayer/role_label
	role.text = "You are the HUNTER!"
	role.modulate = Color(1, 0.3, 0.3)
	role.add_theme_font_size_override("font_size", 32)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.anchor_left = 0.5
	role.anchor_right = 0.5
	role.anchor_top = 0.1
	role.anchor_bottom = 0.1
	role.offset_left = -200
	role.offset_right = 200

	var countdown = $CanvasLayer/countdown_label
	countdown.add_theme_font_size_override("font_size", 64)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.anchor_left = 0.5
	countdown.anchor_right = 0.5
	countdown.anchor_top = 0.5
	countdown.anchor_bottom = 0.5
	countdown.offset_left = -200
	countdown.offset_right = 200
	countdown.offset_top = -50
	countdown.offset_bottom = 50

	var player = hunter_scene.instantiate()
	player.name = "waiting_hunter"
	player.set_multiplayer_authority(multiplayer.get_unique_id())
	add_child(player)
	player.position = Vector2(0, 0)

	fade_role_label()
	start_countdown()

func fade_role_label():
	await get_tree().create_timer(5.0).timeout
	var tween = create_tween()
	tween.tween_property($CanvasLayer/role_label, "modulate:a", 0.0, 1.0)
	await tween.finished
	$CanvasLayer/role_label.queue_free()

func start_countdown():
	for i in range(30, 0, -1):
		$CanvasLayer/countdown_label.text = "Spawning in: " + str(i)
		await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://node_2d.tscn")
