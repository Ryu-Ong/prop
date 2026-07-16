extends Node2D

@onready var baton = $Baton
@onready var hitbox = $Baton/CollisionShape2D

var canHit = true
var is_stunned = false

func _ready() -> void:
	baton.visible = false
	baton.monitoring = false
	hitbox.disabled = true

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if get_parent().local_only:
		return
	if is_stunned:
		return
	look_at(get_global_mouse_position())
	for peer_id in Global.in_game_peers:
		if peer_id != multiplayer.get_unique_id():
			broadcast_rotation.rpc_id(peer_id, rotation)
	if Input.is_action_pressed("Baton"):
		fire.rpc()

@rpc("authority", "call_remote", "unreliable_ordered")
func broadcast_rotation(rot: float):
	rotation = rot

@rpc("authority", "call_local", "reliable")
func fire():
	if not canHit:
		return
	canHit = false
	hitbox.disabled = false
	baton.visible = true
	baton.monitoring = true
	var tree = get_tree()
	await tree.physics_frame
	await tree.physics_frame
	if not is_inside_tree():
		return
	if is_multiplayer_authority():
		var hit_hider = false
		for area in baton.get_overlapping_areas():
			var owner_node = area.get_parent()
			if owner_node and owner_node.has_method("die"):
				owner_node.die.rpc()
				hit_hider = true
		if not hit_hider:
			for body in baton.get_overlapping_bodies():
				if body is StaticBody2D or body is TileMapLayer:
					stun.rpc()
					break
	await tree.create_timer(0.5).timeout
	if not is_inside_tree():
		return
	baton.visible = false
	baton.monitoring = false
	hitbox.disabled = true
	canHit = true

@rpc("authority", "call_local", "reliable")
func stun():
	is_stunned = true
	get_parent().set_stunned(true)
	var tree = get_tree()
	await tree.create_timer(3.0).timeout
	if not is_inside_tree():
		return
	is_stunned = false
	get_parent().set_stunned(false)
