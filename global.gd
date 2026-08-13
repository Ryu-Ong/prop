extends Node

# NOTE: spectator.gd is loaded at runtime rather than with preload().
# This script is an autoload, and spectator.gd refers back to `Global`, so a
# preload here would be a cyclic dependency between the two scripts.
const SPECTATOR_SCRIPT_PATH := "res://spectator.gd"

# ---- physics layers ----
# Hider and hunter bodies used to share layer 2, and both masked only layer 1,
# so the hunter passed straight through disguised hiders while real props blocked
# it - an instant tell. They now sit on separate layers so hunter<->hider can
# collide WITHOUT making hider<->hider collide (which would stack them at spawn).
const LAYER_WORLD := 1      # props (StaticBody2D) and the tilemap
const LAYER_HIDER := 2      # hider bodies
const LAYER_COMBAT := 4     # baton area + hider hurtbox area
const LAYER_HUNTER := 8     # hunter body

# ---- map / safe-zone configuration ----
const MAP_SIZE := 4736.0                       # map is 4736 x 4736, centred on the origin
const MAP_MIN := Vector2(-MAP_SIZE * 0.5, -MAP_SIZE * 0.5)
const MAP_MAX := Vector2(MAP_SIZE * 0.5, MAP_SIZE * 0.5)

const TILE_SIZE := 32.0
const ZONE_RADIUS := TILE_SIZE * 5.0           # 5 tiles = 160 px
const ZONE_EDGE_MARGIN := 0.2                  # zone centres stay 20% away from every edge
const ZONE_COUNT := 2                          # zone assigned at 1 min and at 2 min
const ZONE_INTERVAL := 60.0                    # seconds between reveal / deadline steps

# ---- audio ----
# Everything is deliberately NON-directional: we use plain AudioStreamPlayers and
# set volume from distance by hand. AudioStreamPlayer2D would do the falloff for
# free, but it also pans left/right, which would tell the hunter which WAY a
# whistle came from. Distance-only means "something is close" without "over there".
const WHISTLE_MAX_DISTANCE := 2500.0    # whistle is inaudible past this
const FOOTSTEP_MAX_DISTANCE := 700.0    # footsteps are much more intimate
const SILENT_DB := -80.0                # Godot treats this as effectively muted

# Exponent on the distance falloff.
#
# 2.0 (inverse-square, physically realistic) turned out to be bad for gameplay:
# it puts -12 dB at half range and -24 dB at three quarters, so the useful
# listening radius collapsed to roughly half of max_distance - barely past the
# edge of the screen, which told the hunter almost nothing.
#
# 1.0 is straight-line amplitude: -6 dB at half range, -12 dB at three quarters.
# Quieter sounds stay audible much further out, so distance carries real
# information. Realism loses to readability here.
const AUDIO_ATTENUATION := 1.0

# Flat dB offset applied on top of the distance falloff. Lets footsteps sit under
# the whistle without shrinking the range you can hear them from - drop it further
# (-12, -16) if they are still too present.
const FOOTSTEP_TRIM_DB := -9.0

# Where the local player is listening from. Using the active Camera2D covers both
# living players and dead ones (spectator.gd IS a Camera2D), so this keeps working
# while spectating with no extra bookkeeping.
func listener_position() -> Vector2:
	var vp := get_viewport()
	if vp:
		var cam := vp.get_camera_2d()
		if cam:
			return cam.global_position
	return Vector2.ZERO

# Full volume at the source, silent exactly at max_distance, curved in between.
#
# Two separate "logarithmic" things are going on and both matter:
#   1. pow(t, AUDIO_ATTENUATION) shapes the AMPLITUDE falloff so it drops fast
#      near the source and trails off - roughly how sound behaves in air.
#   2. linear_to_db() converts that amplitude to decibels, which is the
#      perceptual scale volume_db expects. Assigning a raw 0-1 value there
#      would sound wrong no matter how good the curve is.
func distance_volume_db(world_pos: Vector2, max_distance: float, trim_db: float = 0.0) -> float:
	var d := listener_position().distance_to(world_pos)
	var t := 1.0 - clampf(d / max_distance, 0.0, 1.0)
	if t <= 0.0:
		return SILENT_DB
	return linear_to_db(pow(t, AUDIO_ATTENUATION)) + trim_db

# Fire-and-forget one shot (the whistle).
func play_oneshot(player: AudioStreamPlayer, world_pos: Vector2, max_distance: float) -> void:
	if player == null or player.stream == null:
		return
	player.volume_db = distance_volume_db(world_pos, max_distance)
	if player.volume_db <= SILENT_DB:
		return          # too far away to bother playing
	player.play()

# Continuous looping sound (footsteps). Call every frame; it starts, stops and
# re-levels itself as the emitter moves and starts/stops.
func update_loop_sound(player: AudioStreamPlayer, world_pos: Vector2, active: bool, max_distance: float, trim_db: float = 0.0) -> void:
	if player == null or player.stream == null:
		return
	if not active:
		if player.playing:
			player.stop()
		return
	var db := distance_volume_db(world_pos, max_distance, trim_db)
	if db <= SILENT_DB:
		if player.playing:
			player.stop()
		return
	player.volume_db = db
	if not player.playing:
		player.play()

# AudioStreamMP3 / AudioStreamOggVorbis both expose `loop`; WAV uses loop_mode.
# Forcing it here means a dropped-in file loops even if the import setting is off.
func force_loop(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	if "loop" in player.stream:
		player.stream.loop = true
	elif "loop_mode" in player.stream:
		player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

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

# Per-match state that every peer must clear for itself when a game scene loads.
# lobby.gd only clears dead_hiders on the SERVER (_on_start_pressed returns early
# for clients), so without this a client kept its dead list from the previous
# match and every hider looked dead in round two.
func reset_match_state() -> void:
	dead_hiders.clear()
	reset_zones()

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
	set_master_volume(master_volume)
	# launch an instance pre-muted with the --mute argument
	if OS.get_cmdline_args().has("--mute"):
		set_audio_muted(true)

# ---- master volume (settings slider) ----
# Lives here rather than on the menu so the choice survives scene changes - the
# menu is freed the moment you enter the lobby.
var master_volume := 1.0   # 0.0 .. 1.0

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	var idx := AudioServer.get_bus_index("Master")
	# linear_to_db(0) is -inf, so floor it at the silence threshold instead
	AudioServer.set_bus_volume_db(idx, SILENT_DB if master_volume <= 0.0 else linear_to_db(master_volume))

# ---- debug mute (press M in any running instance) ----
#
# Running three copies of the game locally means three copies of every footstep.
# Muting the Master bus kills all of it for THAT window only - the other
# instances are separate processes with their own AudioServer, so nothing about
# the game state or the network is affected.
var audio_muted := false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		set_audio_muted(not audio_muted)

func set_audio_muted(muted: bool) -> void:
	audio_muted = muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
	# stamp the window title so you can see at a glance which windows are silent
	var w := get_window()
	if w:
		w.title = "Prop Hunt v1" + (" [MUTED]" if muted else "")

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
			var cam = load(SPECTATOR_SCRIPT_PATH).new()
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
