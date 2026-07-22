extends CharacterBody2D

const SPEED = 500.0

@onready var animated_sprite = $Animations
@onready var camera = $Camera2D

var last_position = Vector2.ZERO
var is_stunned = false
var local_only = false
var target_position = Vector2.ZERO
var has_target = false

func _ready():
	camera.enabled = is_multiplayer_authority()
	$FovOverlay.visible = is_multiplayer_authority()
	collision_layer = 2
	collision_mask = 1

func set_stunned(value: bool):
	is_stunned = value

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		if is_stunned:
			velocity = Vector2.ZERO
		else:
			var direction = Input.get_vector("hunter_left", "hunter_right", "hunter_up", "hunter_down")
			velocity = direction * SPEED
			move_and_slide()
		if not local_only:
			for peer_id in Global.in_game_peers:
				if peer_id != multiplayer.get_unique_id():
					broadcast_position.rpc_id(peer_id, position)
	else:
		if has_target:
			if position.distance_to(target_position) > 500:
				position = target_position
			else:
				position = position.lerp(target_position, 0.4)

	var move_delta = position - last_position
	last_position = position

	if move_delta.length() < 0.5:
		animated_sprite.play("Sec Idle Down")
	elif move_delta.y > 0.5:
		animated_sprite.play("Sec Walk Down")
	elif move_delta.y < -0.5:
		animated_sprite.play("Sec Walk Up")
	elif move_delta.x > 0:
		animated_sprite.play("Sec Walk Right")
	else:
		animated_sprite.play("Sec Walk Left")

@rpc("authority", "call_remote", "unreliable_ordered")
func broadcast_position(pos: Vector2):
	target_position = pos
	has_target = true
