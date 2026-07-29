extends Camera2D

# Free-floating spectator camera created for a hider after they die.
# Left click  -> next living hider
# Right click -> previous living hider
# Hunters are never valid spectate targets.

const FOLLOW_SMOOTHING = 12.0

var targets: Array = []      # peer ids of living hiders, excluding ourselves
var index: int = 0
var label: Label = null

func _ready() -> void:
	zoom = Vector2(1.2, 1.2)   # match the hider camera so the world looks the same size
	make_current()
	_build_label()
	_refresh_targets()
	_snap_to_target()

# --- target list -----------------------------------------------------------

func _refresh_targets() -> void:
	var scene := get_tree().current_scene
	var previous = current_target_id()

	targets.clear()
	for pid in Global.all_roles:
		if Global.all_roles[pid] != "hider":
			continue                                   # hunters are not spectatable
		if pid == multiplayer.get_unique_id():
			continue                                   # that's us, we're dead
		if Global.dead_hiders.has(pid):
			continue                                   # already dead
		if scene == null or not scene.has_node(str(pid)):
			continue                                   # node gone (disconnected)
		targets.append(pid)
	targets.sort()

	# try to stay on whoever we were already watching
	if previous != -1 and targets.has(previous):
		index = targets.find(previous)
	elif targets.is_empty():
		index = 0
	else:
		index = index % targets.size()

func current_target_id() -> int:
	if targets.is_empty() or index >= targets.size():
		return -1
	return targets[index]

func current_target_node() -> Node2D:
	var id := current_target_id()
	if id == -1:
		return null
	var scene := get_tree().current_scene
	if scene == null or not scene.has_node(str(id)):
		return null
	return scene.get_node(str(id))

# --- input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_cycle(1)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_cycle(-1)

func _cycle(step: int) -> void:
	_refresh_targets()
	if targets.is_empty():
		_update_label()
		return
	index = wrapi(index + step, 0, targets.size())
	_snap_to_target()
	_update_label()

# --- following -------------------------------------------------------------

func _snap_to_target() -> void:
	var node := current_target_node()
	if node:
		global_position = node.global_position
	_update_label()

func _process(delta: float) -> void:
	var node := current_target_node()

	# our target died or left - move to the next one automatically
	if node == null:
		_refresh_targets()
		node = current_target_node()
		_update_label()
		if node == null:
			return
		global_position = node.global_position
		return

	global_position = global_position.lerp(
		node.global_position,
		clampf(FOLLOW_SMOOTHING * delta, 0.0, 1.0)
	)

# --- on-screen text --------------------------------------------------------

func _build_label() -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_node("UI"):
		return
	label = Label.new()
	label.name = "SpectatorLabel"
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.position = Vector2(-260, -70)
	scene.get_node("UI").add_child(label)
	_update_label()

func _update_label() -> void:
	if label == null or not is_instance_valid(label):
		return
	if targets.is_empty():
		label.text = "You died - no hiders left to spectate"
		label.modulate = Color(1, 0.45, 0.45)
	else:
		label.text = "Spectating hider %d  (%d/%d)   -   Left / Right click to switch" % [
			current_target_id(), index + 1, targets.size()
		]
		label.modulate = Color(0.85, 0.9, 1.0)

func _exit_tree() -> void:
	if label and is_instance_valid(label):
		label.queue_free()
