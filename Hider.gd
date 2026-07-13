extends CharacterBody2D

const SPEED = 400.0

@onready var camera = $Camera2D

func _ready():
	camera.enabled = is_multiplayer_authority()
	collision_layer = 2
	collision_mask = 1

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var direction = Input.get_vector("hider_left", "hider_right", "hider_up", "hider_down")
		velocity = direction * SPEED
		move_and_slide()
		broadcast_position.rpc(position)

@rpc("authority", "call_remote", "unreliable_ordered")
func broadcast_position(pos: Vector2):
	position = pos

func _on_area_2d_area_entered(area: Area2D) -> void:
	# only the hider's own machine decides if they got hit
	if not is_multiplayer_authority():
		return
	if area.name == "Baton":
		die.rpc()

@rpc("authority", "call_local", "reliable")
func die():
	get_tree().change_scene_to_file("res://hunters_win.tscn")
