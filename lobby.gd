extends Node

const PORT = 7777
const MAX_PLAYERS = 8

@onready var ip_field = $VBoxContainer/LineEdit
@onready var start_btn = $VBoxContainer/ButtonStart
@onready var player_list = $VBoxContainer/ItemList

# hunter-count screen
@onready var hunter_select = $HunterSelect
@onready var count_label = $HunterSelect/Row/CountLabel
@onready var split_label = $HunterSelect/SplitLabel
@onready var minus_btn = $HunterSelect/Row/MinusBtn
@onready var plus_btn = $HunterSelect/Row/PlusBtn

# The decorative rocks and trees are also children of VBoxContainer, so we hide
# the interactive Controls by name instead of the whole container - otherwise the
# scenery disappears along with the menu.
const LOBBY_CONTROLS := ["Label", "LineEdit", "Button", "Button2", "ButtonStart", "ItemList"]

var connected_peers = []
var hunter_count := 1

func _ready():
	start_btn.visible = false
	hunter_select.visible = false
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

	minus_btn.pressed.connect(func(): _nudge_hunter_count(-1))
	plus_btn.pressed.connect(func(): _nudge_hunter_count(1))
	$HunterSelect/ConfirmBtn.pressed.connect(_on_confirm_pressed)
	$HunterSelect/BackBtn.pressed.connect(func(): _show_hunter_select(false))

func _on_host_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	start_btn.visible = true
	add_player_to_list(multiplayer.get_unique_id())

func _on_join_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip_field.text, PORT)
	multiplayer.multiplayer_peer = peer

func _on_connected_to_server():
	add_player_to_list(multiplayer.get_unique_id())

func _on_peer_connected(id: int):
	connected_peers.append(id)
	add_player_to_list(id)
	_reclamp_hunter_count()

func _on_peer_disconnected(id: int):
	connected_peers.erase(id)
	for i in player_list.item_count:
		if player_list.get_item_text(i) == str(id):
			player_list.remove_item(i)
			break
	_reclamp_hunter_count()

# somebody joined or left while the host was on the picker - the valid range just
# moved, so pull the current choice back inside it and redraw
func _reclamp_hunter_count() -> void:
	hunter_count = clampi(hunter_count, 1, max_hunters())
	if hunter_select and hunter_select.visible:
		_refresh_hunter_select()

func add_player_to_list(id: int):
	player_list.add_item(str(id))

# ---------------------------------------------------------------------------
# HUNTER COUNT SCREEN (host only)
# ---------------------------------------------------------------------------

func player_count() -> int:
	return connected_peers.size() + 1

func max_hunters() -> int:
	# always leave at least one hider; floor of 1 so a solo host can still test
	return maxi(1, player_count() - 1)

func _on_start_pressed():
	if not multiplayer.is_server():
		return
	hunter_count = clampi(hunter_count, 1, max_hunters())
	_show_hunter_select(true)

func _show_hunter_select(show: bool) -> void:
	for control_name in LOBBY_CONTROLS:
		var node = $VBoxContainer.get_node_or_null(control_name)
		if node:
			node.visible = not show
	hunter_select.visible = show
	if show:
		_refresh_hunter_select()

func _nudge_hunter_count(step: int) -> void:
	hunter_count = clampi(hunter_count + step, 1, max_hunters())
	_refresh_hunter_select()

func _refresh_hunter_select() -> void:
	var hiders = player_count() - hunter_count
	count_label.text = str(hunter_count)
	split_label.text = "%d %s vs %d %s" % [
		hunter_count, "hunter" if hunter_count == 1 else "hunters",
		hiders, "hider" if hiders == 1 else "hiders"
	]
	# grey out the arrows at the ends of the range
	minus_btn.disabled = hunter_count <= 1
	plus_btn.disabled = hunter_count >= max_hunters()

func _on_confirm_pressed() -> void:
	_begin_game(clampi(hunter_count, 1, max_hunters()))

# ---------------------------------------------------------------------------

func _begin_game(hunters: int):
	if not multiplayer.is_server():
		return
	Global.in_game_peers.clear()
	Global.dead_hiders.clear()
	var all_peers = [multiplayer.get_unique_id()] + connected_peers
	all_peers.shuffle()   # randomise who draws hunter, not just how many
	var role_map = {}
	for i in all_peers.size():
		role_map[all_peers[i]] = "hunter" if i < hunters else "hider"
	for id in all_peers:
		if id == multiplayer.get_unique_id():
			Global.my_role = role_map[id]
			Global.all_roles = role_map
		else:
			assign_role.rpc_id(id, role_map[id], role_map)
	await get_tree().create_timer(0.3).timeout
	load_game.rpc()

@rpc("authority", "call_remote", "reliable")
func assign_role(role: String, role_map: Dictionary):
	Global.my_role = role
	Global.all_roles = role_map
	print("I am a: ", role)
	print("All roles: ", role_map)

@rpc("authority", "call_local", "reliable")
func load_game():
	get_tree().change_scene_to_file("res://node_2d.tscn")
