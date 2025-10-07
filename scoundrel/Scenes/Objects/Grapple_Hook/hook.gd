extends Area2D

# This will be set by the player when the hook is launched
var velocity: Vector2 = Vector2.ZERO
var spawner = null # Renamed from player_node to spawner for consistency
var hit_confirmed: bool = false # Prevents multiple hit callbacks

# The distance the hook has traveled
var traveled_distance: float = 0.0

# --- Setup Function (Called by Player) ---
func set_grapple_mode(aim_vector: Vector2, speed: float, player: CharacterBody2D):
	"""Initializes the hook's movement properties and stores the player reference."""
	velocity = aim_vector * speed
	spawner = player # Storing the player reference as spawner
	
	# Connect the signal for collision detection
	# Assuming you set the hook scene's root node to be an Area2D
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# If a hit is confirmed, the hook should stop moving and wait to be queued_free
	if hit_confirmed:
		return
		
	# 1. Move the hook
	var move_vector = velocity * delta
	global_position += move_vector
	traveled_distance += move_vector.length()
	
	# 2. Max Range Check
	# This is a redundant check (player script also does this) but adds safety
	if traveled_distance > spawner.MAX_HOOK_LENGTH:
		# If the hook reaches max range without hitting, tell the player to retract
		if is_instance_valid(spawner) and spawner.is_grappling:
			spawner.retract_hook()
		queue_free()


# --- Collision Detection ---
func _on_body_entered(body: Node2D):
	# Ignore if we already hit something or if the body is the player itself
	if hit_confirmed or body == spawner:
		return

	# CHECK UPDATED: Now includes TileMapLayer as the valid solid body type for map geometry.
	if body is StaticBody2D or body is CharacterBody2D or body is TileMapLayer:
		hit_confirmed = true
		
		# Stop the hook's movement instantly
		velocity = Vector2.ZERO
		
		# For simplicity, we just use the hook's current position as the hit point:
		var hit_point = global_position
		
		if is_instance_valid(spawner):
			# CRITICAL: Call the player's function to start the swinging state
			spawner.on_hook_hit(hit_point)
			
		queue_free()
