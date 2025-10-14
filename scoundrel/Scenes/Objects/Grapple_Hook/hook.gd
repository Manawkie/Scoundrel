extends Area2D

var velocity: Vector2 = Vector2.ZERO
var spawner = null
var hit_confirmed: bool = false
var traveled_distance: float = 0.0

@onready var line: Line2D = $GrappleLine

# --- Wiggle constants (for launching) ---
const NUM_SEGMENTS = 20      # Total segments for the rope (21 points)
const WIGGLE_STRENGTH = 50.0 # Huge arc during launch
const WIGGLE_SPEED = 15.0    # Slower, deliberate whipping motion
const WIGGLE_FREQUENCY = 4.0 

# --- Bounce constants (for when hooked) ---
const BOUNCE_STRENGTH = 5.0  # Subtle bounce amplitude (maximum offset from straight line)
const BOUNCE_SPEED = 5.0     # Slow, natural sway speed
# ------------------------------------------

var time_elapsed: float = 0.0
# ------------------------------------

func set_grapple_mode(aim_vector: Vector2, speed: float, player: CharacterBody2D):
	velocity = aim_vector * speed
	spawner = player

	# Set up the line visually
	line.width = 10.0
	line.default_color = Color(0.9, 0.9, 0.9)# light gray rope
	line.clear_points()
	
	# Initialize with enough points for the whip effect (NUM_SEGMENTS + 1 points)
	for i in range(NUM_SEGMENTS + 1):
		line.add_point(Vector2.ZERO) 

	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Update time for wiggle effect
	time_elapsed += delta 
	
	if hit_confirmed:
		# If hit is confirmed, the hook is anchored. Update with bounce effect.
		_update_rope_line_hooked()
		return

	# Move the hook
	var move_vector = velocity * delta
	global_position += move_vector
	traveled_distance += move_vector.length()

	# Update line with whip effect (while launching)
	_update_rope_line_launching()

	# Check max range
	if traveled_distance > spawner.MAX_HOOK_LENGTH:
		if is_instance_valid(spawner) and spawner.is_grappling:
			spawner.retract_hook()
		queue_free()

# Function to update the line while launching (with whip effect)
func _update_rope_line_launching():
	if not is_instance_valid(spawner):
		return
		
	# Point 0: Player's global position converted to hook's local space
	var start_local = to_local(spawner.global_position)
	# Last Point: Hook's position is its own origin (0, 0) in local space
	var end_local = Vector2.ZERO
	
	# Calculate the vector perpendicular to the straight line
	var perpendicular_vec = (end_local - start_local).normalized().rotated(PI / 2.0)
	
	# Iterate through all points
	for i in range(NUM_SEGMENTS + 1):
		var t = float(i) / NUM_SEGMENTS # t goes from 0.0 (player) to 1.0 (hook)
		
		# 1. Linear position along the straight rope
		var straight_pos = start_local.lerp(end_local, t)
		
		# 2. Calculate the sine wave offset for this point
		# The wave is driven by time and its position (t) along the rope.
		var wave_pos = t * WIGGLE_FREQUENCY * 2.0 * PI
		var wiggle_offset = sin(time_elapsed * WIGGLE_SPEED + wave_pos) * WIGGLE_STRENGTH
		
		# 3. Dampen the wiggle at the ends (zero at t=0 and t=1, strongest at t=0.5)
		var dampening = t * (1.0 - t) * 4.0 # Multiply by 4.0 to bring peak back up to 1.0
		
		# 4. Apply the offset
		var curved_pos = straight_pos + perpendicular_vec * wiggle_offset * dampening
		
		line.set_point_position(i, curved_pos)

# Function to update the line when hooked (with bounce effect)
func _update_rope_line_hooked():
	if not is_instance_valid(spawner):
		return
		
	# Point 0 (Player) in local coordinates
	var start_local = to_local(spawner.global_position)
	# Point 1 (Hook anchor) in local coordinates
	var end_local = Vector2.ZERO 
	
	# Ensure the line has the correct number of points for the curve
	if line.get_point_count() != NUM_SEGMENTS + 1:
		line.clear_points()
		for i in range(NUM_SEGMENTS + 1):
			line.add_point(Vector2.ZERO)
	
	# Calculate the vector perpendicular to the straight line
	var perpendicular_vec = (end_local - start_local).normalized().rotated(PI / 2.0)
	
	# Iterate through all points
	for i in range(NUM_SEGMENTS + 1):
		var t = float(i) / NUM_SEGMENTS # t goes from 0.0 (player) to 1.0 (hook)
		
		# 1. Linear position along the straight rope
		var straight_pos = start_local.lerp(end_local, t)
		
		# 2. Calculate the bounce offset (slow, subtle sine wave)
		# The bounce is driven by time and position along the rope.
		var bounce_offset = sin(time_elapsed * BOUNCE_SPEED + t * PI) * BOUNCE_STRENGTH
		
		# 3. Dampen the bounce at the ends (zero at t=0 and t=1, strongest at t=0.5)
		var dampening = t * (1.0 - t) * 4.0 
		
		# 4. Apply the offset
		var curved_pos = straight_pos + perpendicular_vec * bounce_offset * dampening
		
		line.set_point_position(i, curved_pos)

func _on_body_entered(body: Node2D):
	if hit_confirmed or body == spawner:
		return

	if body is StaticBody2D or body is CharacterBody2D or body is TileMapLayer:
		hit_confirmed = true
		velocity = Vector2.ZERO

		var hit_point = global_position

		if is_instance_valid(spawner):
			spawner.on_hook_hit(hit_point)

		# The hook instance MUST NOT be destroyed here. The player is now responsible for destroying it.
