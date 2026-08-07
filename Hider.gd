extends CharacterBody2D

const SPEED = 350.0
# map bounds come from Global (4736 x 4736, centred on the origin)
@onready var MAP_MIN: Vector2 = Global.MAP_MIN
@onready var MAP_MAX: Vector2 = Global.MAP_MAX

const SafeZoneVisual = preload("res://safe_zone_visual.gd")
const SAFE_COLOR = Color(0.25, 1.0, 0.42)
const UNSAFE_COLOR = Color(1.0, 0.78, 0.18)
const MIN_MARKER_PX = 12.0   # keep the minimap zone readable even though it is tiny to scale

@onready var camera = $Camera2D
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var minimap_dot = $MinimapLayer/MinimapBackground/PlayerDot
@onready var minimap_bg = $MinimapLayer/MinimapBackground

var is_hidden = false
var original_texture
var original_scale
var original_shape
var original_sprite_offset := Vector2.ZERO
var original_collision_offset := Vector2.ZERO

# ---- safe zone ----
var zone_visual: Node2D = null
var zone_marker: Panel = null
var zone_marker_style: StyleBoxFlat = null
var zone_label: Label = null
var is_in_safe_zone := false
var _shown_zone_index := -99

func _ready():
	camera.enabled = is_multiplayer_authority()
	collision_layer = Global.LAYER_HIDER
	# World only - deliberately NOT the hunter.
	#
	# move_and_slide() performs depenetration recovery: if this body starts a
	# frame overlapping something in its mask, it shoves ITSELF out, even at zero
	# velocity. So while the hunter walked into a disguised hider, the hider's own
	# move_and_slide pushed it clear and broadcast the new position - the "prop"
	# visibly slid. Real props are StaticBody2D, never run move_and_slide, and so
	# can never be pushed; that mismatch was the tell.
	#
	# Collision is resolved by the MOVING body's mask, so the hunter masking
	# LAYER_HIDER is enough to be blocked by hiders. Leaving the hunter out of the
	# hider's mask means the hider never reacts, and cannot be shoved.
	collision_mask = Global.LAYER_WORLD
	# capture default look ONCE - untransform can never hit nulls now
	original_texture = sprite.texture
	original_scale = sprite.scale
	original_shape = collision.shape
	original_sprite_offset = sprite.position
	original_collision_offset = collision.position
	$MinimapLayer.visible = is_multiplayer_authority()
	if is_multiplayer_authority():
		_build_zone_ui()

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var direction = Input.get_vector("hider_left", "hider_right", "hider_up", "hider_down")
		velocity = direction * SPEED
		move_and_slide()
		for peer_id in Global.in_game_peers:
			if peer_id != multiplayer.get_unique_id():
				broadcast_position.rpc_id(peer_id, position)
		update_minimap()
		update_safe_zone()

func update_minimap():
	minimap_dot.position = _to_minimap(position) - minimap_dot.size / 2

func _to_minimap(world_pos: Vector2) -> Vector2:
	var map_size = MAP_MAX - MAP_MIN
	var normalized = (world_pos - MAP_MIN) / map_size  # 0.0 to 1.0
	normalized = normalized.clamp(Vector2(0, 0), Vector2(1, 1))
	return normalized * minimap_bg.size

# ---------------------------------------------------------------------------
# SAFE ZONE - world circle, minimap marker, and "you are safe" feedback
# ---------------------------------------------------------------------------

func _build_zone_ui():
	# circular minimap marker (a Panel with fully rounded corners)
	zone_marker_style = StyleBoxFlat.new()
	zone_marker_style.bg_color = Color(UNSAFE_COLOR.r, UNSAFE_COLOR.g, UNSAFE_COLOR.b, 0.35)
	zone_marker_style.border_color = UNSAFE_COLOR
	zone_marker_style.set_border_width_all(2)
	zone_marker_style.set_corner_radius_all(64)

	zone_marker = Panel.new()
	zone_marker.name = "ZoneMarker"
	zone_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_marker.add_theme_stylebox_override("panel", zone_marker_style)
	zone_marker.visible = false
	minimap_bg.add_child(zone_marker)
	minimap_bg.move_child(zone_marker, 0)   # draw beneath the player dot

	# status text under the minimap
	zone_label = Label.new()
	zone_label.name = "ZoneLabel"
	zone_label.add_theme_font_size_override("font_size", 16)
	zone_label.add_theme_constant_override("outline_size", 4)
	zone_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	zone_label.position = Vector2(minimap_bg.offset_left, minimap_bg.offset_bottom + 8)
	zone_label.visible = false
	$MinimapLayer.add_child(zone_label)

func update_safe_zone():
	if zone_marker == null or zone_label == null:
		return   # UI not built (non-authority peer) - nothing to draw

	var zone = Global.my_zone()

	if zone == null:
		if zone_visual and is_instance_valid(zone_visual):
			zone_visual.visible = false
		if zone_marker:
			zone_marker.visible = false
		if zone_label:
			zone_label.visible = false
		is_in_safe_zone = false
		_shown_zone_index = -99
		return

	# spawn the world visual on first use
	if zone_visual == null or not is_instance_valid(zone_visual):
		var scene := get_tree().current_scene
		if scene == null:
			return   # mid scene-change, try again next frame
		zone_visual = SafeZoneVisual.new()
		zone_visual.radius = Global.ZONE_RADIUS
		scene.add_child(zone_visual)

	zone_visual.visible = true
	zone_visual.global_position = zone

	var dist = global_position.distance_to(zone)
	var now_safe = dist <= Global.ZONE_RADIUS

	# a brand-new zone was just assigned -> announce it
	var fresh_zone := _shown_zone_index != Global.active_zone_index
	if fresh_zone:
		_shown_zone_index = Global.active_zone_index
		is_in_safe_zone = now_safe
		_announce("NEW ZONE ASSIGNED - get inside within 60s!", UNSAFE_COLOR)
	elif now_safe != is_in_safe_zone:
		is_in_safe_zone = now_safe
		if now_safe:
			_announce("SAFE ZONE REACHED", SAFE_COLOR)
		else:
			_announce("YOU LEFT YOUR ZONE!", UNSAFE_COLOR)

	var col = SAFE_COLOR if now_safe else UNSAFE_COLOR
	zone_visual.color = col

	# minimap marker
	var marker_d = max(Global.ZONE_RADIUS * 2.0 / Global.MAP_SIZE * minimap_bg.size.x, MIN_MARKER_PX)
	zone_marker.size = Vector2(marker_d, marker_d)
	zone_marker.position = _to_minimap(zone) - Vector2(marker_d, marker_d) / 2.0
	zone_marker.visible = true
	zone_marker_style.bg_color = Color(col.r, col.g, col.b, 0.35)
	zone_marker_style.border_color = col
	zone_marker_style.set_corner_radius_all(int(marker_d / 2.0))

	# status text
	zone_label.visible = true
	zone_label.add_theme_color_override("font_color", col)
	if now_safe:
		zone_label.text = "SAFE - stay inside"
	else:
		zone_label.text = "MOVE TO ZONE - %d px" % int(dist)

func _announce(text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position = Vector2(-220, 90)
	$MinimapLayer.add_child(label)
	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(label):
		return
	var tween = label.create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	await tween.finished
	if is_instance_valid(label):
		label.queue_free()

@rpc("authority", "call_remote", "unreliable_ordered")
func broadcast_position(pos: Vector2):
	position = pos

func _input(event):
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_hidden:
			untransform_all.rpc()
		else:
			var clicked_prop = get_clicked_prop()
			if clicked_prop:
				transform_all.rpc(String(clicked_prop.name))

func get_clicked_prop():
	var space_state = get_world_2d().direct_space_state
	var params = PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_bodies = true
	params.collision_mask = 0xFFFFFFFF
	var results = space_state.intersect_point(params)
	for result in results:
		var collider = result.collider
		if collider.is_in_group("props"):
			return collider
	return null

@rpc("authority", "call_local", "reliable")
func transform_all(prop_name: String):
	# find the prop by name anywhere in the current scene - works on every peer
	var prop = get_tree().current_scene.find_child(prop_name, true, false)
	if prop == null:
		return
	is_hidden = true
	transform(prop)

@rpc("authority", "call_local", "reliable")
func untransform_all():
	untransform()

func find_child_of_type(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.get_class() == type_name:
			return child
		var found = find_child_of_type(child, type_name)
		if found:
			return found
	return null

func transform(prop: Node):
	var prop_sprite = find_child_of_type(prop, "Sprite2D")
	var prop_collision = find_child_of_type(prop, "CollisionShape2D")
	if prop_sprite == null or prop_collision == null or prop_collision.shape == null:
		return
	sprite.texture = prop_sprite.texture
	sprite.scale = prop_sprite.scale
	collision.shape = prop_collision.shape.duplicate()
	# Copy the prop's local offsets too. Without these the disguise sits a few
	# pixels off from a real prop of the same type - the sprite renders at the
	# wrong height and the hitbox does not line up with the art, both of which
	# are visible tells once a hunter knows to look for them.
	sprite.position = prop_sprite.position
	collision.position = prop_collision.position

func untransform():
	sprite.texture = original_texture
	sprite.scale = original_scale
	collision.shape = original_shape
	sprite.position = original_sprite_offset
	collision.position = original_collision_offset
	is_hidden = false

func _on_area_2d_area_entered(area: Area2D) -> void:
	if not is_multiplayer_authority():
		return
	if area.name == "Baton":
		die.rpc()

@rpc("any_peer", "call_local", "reliable")
func die():
	if zone_visual and is_instance_valid(zone_visual):
		zone_visual.queue_free()
		zone_visual = null
	Global.report_death(int(str(name)))

func _exit_tree() -> void:
	if zone_visual and is_instance_valid(zone_visual):
		zone_visual.queue_free()
		zone_visual = null
