extends RigidBody2D # CHANGED from Area2D to RigidBody2D for physics control

@export var fuse_time: float = 2.0# seconds before explosion
@onready var _timer: Timer = $Timer
@onready var _explosion: GPUParticles2D = $GPUParticles2D
@onready var _sprite = $AnimatedSprite2D
const INHERIT_VELOCITY_MULTIPLIER = 0.5 


func _ready():
	set_collision_mask_value(4, true)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	# Ensure the bomb won't rotate randomly when hitting the ground
	lock_rotation = true

	_sprite.play("bomb")
	
	_timer.wait_time = fuse_time
	_timer.one_shot = true
	# --- FIX: Explicitly connect the signal in code ---
	_timer.timeout.connect(_on_Timer_timeout)
	# --------------------------------------------------
	_timer.start()
	
	# Safety check: RigidBody2D requires a CollisionShape2D
	if get_node_or_null("CollisionShape2D") == null:
		print("WARNING: Bomb is missing a CollisionShape2D! Physics will not work.")
		

	
func apply_initial_impulse(player_vel: Vector2):
	var _impulse = player_vel * INHERIT_VELOCITY_MULTIPLIER
	apply_central_impulse()
	
func _on_Timer_timeout():
	# This function is now guaranteed to run when the timer finishes
	explode()
	print("sss")

func explode():
	# Hide bomb sprite
	print("went here")
	_sprite.visible = false
	$CollisionShape2D.disabled = true

	# Play explosion particles
	_explosion.emitting = true

	# Wait for particles to finish (optional)
	await get_tree().create_timer(_explosion.lifetime).timeout
	print("end")
	# Remove the bomb after particles finish
	queue_free()
