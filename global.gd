extends Node

const SpectatorCamera = preload("res://spectator.gd")

# ---- map / safe-zone configuration ----
const MAP_SIZE := 4736.0                       # map is 4736 x 4736, centred on the origin
const MAP_MIN := Vector2(-MAP_SIZE * 0.5, -MAP_SIZE * 0.5)
const MAP_MAX := Vector2(MAP_SIZE * 0.5, MAP_SIZE * 0.5)

const TILE_SIZE := 32.0
const ZONE_RADIUS := TILE_SIZE * 5.0           # 5 tiles = 160 px
const ZONE_EDGE_MARGIN := 0.2                  # zone centres stay 20% away from every edge
const ZONE_COUNT := 2                          # zone assigned at 1 min and at 2 min
const ZONE_INTERVAL := 60.0                    # seconds between reveal / deadline steps

var my_role = "hider"
var all_roles = {}
var in_game_peers = []
var dead_hiders = []

# ---- safe-zone state (server generates, mirrored to every peer) ----
var zones := {}              # { peer_id: [Vector2 zone_1, Vector2 zone_2] }
var active_zone_index := -1  # -1 = no zone active yet

func reset_zones() -> void:
	zones.clear()
	active_zone_index = -1

# Rect the zone CENTRE may fall inside, so the whole circle stays clear of the edges.
func zone_center_bounds() -> Rect2:
	var inset := Vector2.ONE * (MAP_SIZE * ZONE_EDGE_MARGIN)
	var lo := MAP_MIN + inset
	var hi := MAP_MAX - inset
	return Rect2(lo, hi - lo)

func random_zone_center(rng: RandomNumberGenerator) -> Vector2:
	var b := zone_center_bounds()
	return Vector2(
		rng.randf_range(b.position.x, b.end.x),
		rng.randf_range(b.position.y, b.end.y)
	)

# The local player's currently-active zone centre, or null if none.
func my_zone():
	return zone_for(multiplayer.get_unique_id())

func zone_for(peer_id: int):
	if active_zone_index < 0:
		return null
	var list = zones.get(peer_id, [])
	if active_zone_index >= list.size():
		return null
	return list[active_zone_index]

func is_inside_zone(peer_id: int, pos: Vector2) -> bool:
	var z = zone_for(peer_id)
	if z == null:
		return true   # no active zone -> nothing to fail
	return pos.distance_to(z) <= ZONE_RADIUS

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
		# if it's MY player that died, hand over to a spectator camera that can
		# cycle between the remaining living hiders
		if id == multiplayer.get_unique_id() and not scene.has_node("Spectator"):
			var cam = SpectatorCamera.new()
			cam.name = "Spectator"
			cam.position = node.global_position
			scene.add_child(cam)
		node.queue_free()

	# hunters win when every hider is dead
	var total_hiders = 0
	for pid in all_roles:
		if all_roles[pid] == "hider":
			total_hiders += 1
	if dead_hiders.size() >= total_hiders:
		await get_tree().create_timer(1).timeout
		get_tree().change_scene_to_file("res://hunters_win.tscn")
