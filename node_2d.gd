extends Node2D

@export var hunter_scene : PackedScene
@export var hider_scene : PackedScene

@onready var timer = $UI/Control/VBoxContainer/Timer/Label
@onready var leveltimer = $LevelTimer

const WAITING_POS = Vector2(15000, 15000)
const MAIN_SPAWN = Vector2(0, 0)

func _ready():
	print("READY - my id: ", multiplayer.get_unique_id(), " is server: ", multiplayer.is_server())
	print("My role: ", Global.my_role)

	Global.reset_zones()

	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(remove_player)

	Global.enter_game()

	if Global.my_role == "hider":
		show_role_label("You are the HIDER!", Color(0.3, 1, 0.3))
		leveltimer.stop()
		for i in range(30, 0, -1):
			timer.text = str(i)
			await get_tree().create_timer(1.0).timeout
		leveltimer.wait_time = 180.0
		leveltimer.start()
	else:
		show_role_label("You are the HUNTER!", Color(1, 0.3, 0.3))
		leveltimer.stop()
		for i in range(30, 0, -1):
			timer.text = str(i)
			await get_tree().create_timer(1.0).timeout
		var me = get_node_or_null(str(multiplayer.get_unique_id()))
		if me:
			me.position = MAIN_SPAWN
		leveltimer.wait_time = 180.0
		leveltimer.start()

	timer.text = str(int(leveltimer.time_left))

	# the server drives the safe-zone timeline for everybody
	if multiplayer.is_server():
		_run_zone_timeline()

# ---------------------------------------------------------------------------
# SAFE ZONES
#
#   t = 60s   zone 1 revealed
#   t = 120s  zone 1 deadline enforced (outside -> dead), zone 2 revealed
#   t = 180s  zone 2 deadline enforced, game ends.
#             any hider still alive and inside their zone -> hiders win,
#             otherwise hunters win.
# ---------------------------------------------------------------------------

func _run_zone_timeline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# one independent, randomised zone per hider, per phase
	var assignments := {}
	for pid in Global.all_roles:
		if Global.all_roles[pid] != "hider":
			continue
		var list := []
		for _i in Global.ZONE_COUNT:
			list.append(Global.random_zone_center(rng))
		assignments[pid] = list
	sync_zones.rpc(assignments)

	for i in Global.ZONE_COUNT:
		await get_tree().create_timer(Global.ZONE_INTERVAL).timeout
		if not is_inside_tree():
			return
		if i > 0:
			_enforce_zone(i - 1)   # previous zone's deadline is now up
		set_active_zone.rpc(i)

	# final minute
	await get_tree().create_timer(Global.ZONE_INTERVAL).timeout
	if not is_inside_tree():
		return
	var survivors := _enforce_zone(Global.ZONE_COUNT - 1)
	if survivors > 0:
		end_game_hiders_win.rpc()
	else:
		end_game_hunters_win.rpc()

# Kills every living hider outside their assigned zone. Returns survivor count.
func _enforce_zone(index: int) -> int:
	var survivors := 0
	for pid in Global.zones.keys():
		if Global.dead_hiders.has(pid):
			continue
		var node = get_node_or_null(str(pid))
		if node == null:
			continue
		var list = Global.zones[pid]
		if index >= list.size():
			continue
		if node.global_position.distance_to(list[index]) <= Global.ZONE_RADIUS:
			survivors += 1
		else:
			if node.has_method("die"):
				node.die.rpc()
	return survivors

@rpc("authority", "call_local", "reliable")
func sync_zones(assignments: Dictionary) -> void:
	Global.zones = assignments
	Global.active_zone_index = -1

@rpc("authority", "call_local", "reliable")
func set_active_zone(index: int) -> void:
	Global.active_zone_index = index

func show_role_label(text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 32)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(-200, 20)
	$UI.add_child(label)
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	await tween.finished
	if not is_inside_tree():
		return
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
	player.position = MAIN_SPAWN if role == "hider" else WAITING_POS

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

@rpc("any_peer", "call_local", "reliable")
func end_game_hunters_win():
	get_tree().change_scene_to_file("res://hunters_win.tscn")

func _on_level_timer_timeout() -> void:
	# Intentionally empty: the end of the match is decided by the server in
	# _run_zone_timeline(), which checks the final safe zone before choosing
	# a winner. The LevelTimer is only used to drive the on-screen countdown.
	pass
