extends CharacterBody2D

const SPEED = 500.0

const IDLE_ANIM = "Sec Idle Down"   # the only idle animation in the SpriteFrames

# Draw order. CanvasItems sort by z_index FIRST and only y-sort within the same
# z_index, so lifting the hunter out of the shared band (everything else is 0)
# makes it render above every prop, hider and tile regardless of position.
const HUNTER_Z_INDEX = 100
const SNAP_DISTANCE = 500.0         # teleport instead of sliding if we are this far off
const SMOOTHING = 18.0              # remote follow rate (higher = snappier, lower = smoother)
const MOVE_EPSILON = 20.0           # px/s below which the hunter counts as standing still

@onready var animated_sprite = $Animations
@onready var camera = $Camera2D

var is_stunned = false
var local_only = false

# --- remote-peer interpolation state ---
var target_position = Vector2.ZERO
var remote_velocity = Vector2.ZERO
var has_target = false

var facing = "Down"

func _ready():
	camera.enabled = is_multiplayer_authority()
	$FovOverlay.visible = is_multiplayer_authority()
	collision_layer = Global.LAYER_HUNTER
	collision_mask = Global.LAYER_WORLD | Global.LAYER_HIDER   # blocked by props AND hiders
	z_index = HUNTER_Z_INDEX
	target_position = position

func set_stunned(value: bool):
	is_stunned = value

func _physics_process(delta: float) -> void:
	# The velocity used to pick an animation. On the owning peer that is the real
	# velocity; on every other peer it is the velocity we were told about, NOT the
	# frame-to-frame position delta (which is what used to cause the flicker).
	var anim_velocity: Vector2

	if is_multiplayer_authority():
		if is_stunned:
			velocity = Vector2.ZERO
		else:
			var direction = Input.get_vector("hunter_left", "hunter_right", "hunter_up", "hunter_down")
			velocity = direction * SPEED
		# always move_and_slide, even when stunned, so collisions stay resolved
		move_and_slide()
		anim_velocity = velocity

		if not local_only:
			for peer_id in Global.in_game_peers:
				if peer_id != multiplayer.get_unique_id():
					broadcast_state.rpc_id(peer_id, position, velocity)
	else:
		# never run physics for a puppet - just chase the last known position
		velocity = Vector2.ZERO
		if has_target:
			if position.distance_to(target_position) > SNAP_DISTANCE:
				position = target_position
			else:
				position = position.lerp(target_position, clampf(SMOOTHING * delta, 0.0, 1.0))
		anim_velocity = remote_velocity

	_update_animation(anim_velocity)

func _update_animation(v: Vector2) -> void:
	if v.length() < MOVE_EPSILON:
		_play(IDLE_ANIM)
		return

	# dominant axis wins; ties resolve to vertical so a diagonal never flickers
	if absf(v.y) >= absf(v.x):
		facing = "Down" if v.y > 0.0 else "Up"
	else:
		facing = "Right" if v.x > 0.0 else "Left"

	_play("Sec Walk " + facing)

func _play(anim: String) -> void:
	if animated_sprite.animation == anim and animated_sprite.is_playing():
		return
	if animated_sprite.sprite_frames and not animated_sprite.sprite_frames.has_animation(anim):
		anim = IDLE_ANIM
	animated_sprite.play(anim)

@rpc("authority", "call_remote", "unreliable_ordered")
func broadcast_state(pos: Vector2, vel: Vector2):
	target_position = pos
	remote_velocity = vel
	has_target = true
