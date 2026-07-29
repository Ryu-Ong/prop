extends CharacterBody2D

const SPEED = 350.0
const MAP_MIN = Vector2(-2400, -2400)
const MAP_MAX = Vector2(2400, 2400)

@onready var camera = $Camera2D
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var minimap_dot = $MinimapLayer/MinimapBackground/PlayerDot
@onready var minimap_bg = $MinimapLayer/MinimapBackground

var is_hidden = false
var original_texture
var original_scale
var original_shape

func _ready():
	camera.enabled = is_multiplayer_authority()
	collision_layer = 2
	collision_mask = 1
	# capture default look ONCE - untransform can never hit nulls now
	original_texture = sprite.texture
	original_scale = sprite.scale
	original_shape = collision.shape
	$MinimapLayer.visible = is_multiplayer_authority()

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var direction = Input.get_vector("hider_left", "hider_right", "hider_up", "hider_down")
		velocity = direction * SPEED
		move_and_slide()
		for peer_id in Global.in_game_peers:
			if peer_id != multiplayer.get_unique_id():
				broadcast_position.rpc_id(peer_id, position)
		update_minimap()

func update_minimap():
	var map_size = MAP_MAX - MAP_MIN
	var normalized = (position - MAP_MIN) / map_size  # 0.0 to 1.0
	normalized = normalized.clamp(Vector2(0, 0), Vector2(1, 1))
	var minimap_size = minimap_bg.size
	minimap_dot.position = normalized * minimap_size - minimap_dot.size / 2

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

func untransform():
	if original_scale != null:
		sprite.texture = original_texture
		sprite.scale = original_scale
		collision.shape = original_shape
	is_hidden = false

func _on_area_2d_area_entered(area: Area2D) -> void:
	if not is_multiplayer_authority():
		return
	if area.name == "Baton":
		die.rpc()

@rpc("any_peer", "call_local", "reliable")
func die():
	Global.report_death(int(str(name)))
