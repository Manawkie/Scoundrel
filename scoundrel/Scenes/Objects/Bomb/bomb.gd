extends RigidBody2D # CHANGED from Area2D to RigidBody2D for physics control

@export var fuse_time: float = 2.0# seconds before explosion
@onready var _timer: Timer = $Timer
@onready var _explosion: GPUParticles2D = $GPUParticles2D
@onready var _sprite = $AnimatedSprite2D
const INHERIT_VELOCITY_MULTIPLIER = 1.0

# --- NEW: Flag to prevent multiple explosions ---
var has_exploded: bool = false
# -----------------------------------------------

func _ready():
	set_collision_mask_value(2, true)
	
	# Ensure the bomb won't rotate randomly when hitting the ground
	lock_rotation = true

	_sprite.play("bomb")
	
	_timer.wait_time = fuse_time
	_timer.one_shot = true
	# --- FIX: Explicitly connect the signal in code ---
	_timer.timeout.connect(_on_Timer_timeout)
	# --- NEW: Connect collision signal for immediate explosion ---
	# RigidBody2D uses 'body_entered'
	body_entered.connect(_on_body_entered)
	# --------------------------------------------------
	_timer.start()
	
	# Safety check: RigidBody2D requires a CollisionShape2D
	if get_node_or_null("CollisionShape2D") == null:
		print("WARNING: Bomb is missing a CollisionShape2D! Physics will not work.")
	
func apply_initial_impulse(player_vel: Vector2):
	var _impulse = player_vel * INHERIT_VELOCITY_MULTIPLIER
	# FIX: apply_central_impulse now correctly receives the impulse vector
	apply_central_impulse(_impulse) 
	
func _on_Timer_timeout():
	# This function is now guaranteed to run when the timer finishes
	explode()

func _on_body_entered(body: Node2D):
	# Collision trigger for immediate explosion (e.g., hitting the enemy/wall)
	# You might want to filter this based on the body type
	if not body.is_in_group("player"):
		explode()

func explode():
	# 1. CRITICAL CHECK: Prevent double explosion (solves soft error)
	if has_exploded:
		return
	has_exploded = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	
	print("Explosion logic running.")
	_sprite.visible = false
	# Hide bomb sprite
	
	
	# Disable collision safely, which was the source of the soft error
	var collision_shape = $CollisionShape2D
	if collision_shape and is_instance_valid(collision_shape):
		# FIX: Use set_deferred() to avoid modifying the physics state during a physics frame
		collision_shape.set_deferred("disabled", true)
	
	# Play explosion particles
	_explosion.emitting = true

	# Wait for particles to finish
	await get_tree().create_timer(_explosion.lifetime).timeout
	print("Explosion effects finished. Bomb removing itself.")
	
	# Remove the bomb after particles finish
	queue_free()
