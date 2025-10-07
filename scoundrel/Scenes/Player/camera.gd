extends Camera2D

# --- Configuration Variables ---

# How far the camera can move toward the cursor, in pixels.
const MAX_CURSOR_OFFSET = 150.0 

# How much influence the mouse has over the camera (0.0 = none, 1.0 = full focus on mouse).
# 0.2 means the camera moves 20% toward the mouse direction.
const MOUSE_INFLUENCE_WEIGHT = 0.3

# The smoothing factor (Lerp T value). Lower values are smoother/slower.
const SMOOTH_FACTOR = 0.1 

# --- Runtime Variables ---

# This will store the smooth offset we are aiming for
var current_offset_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Set the process mode to make the camera movement independent of physics framerate.
	set_process(true)
	# Ensure camera has default smoothing enabled for character movement
	# (Though we are using offset, this is good practice)
	# self.process_mode = Node.PROCESS_MODE_PHYSICS_INTERNAL # Use this if attached to CharacterBody2D script
	pass

func _process(_delta: float) -> void:
	# 1. Get the mouse position relative to the center of the screen/viewport.
	#    This gives us a vector pointing from the screen center to the cursor.
	var mouse_pos_relative_to_center = get_viewport().get_mouse_position() - get_viewport_rect().size / 2
	
	# 2. Apply a maximum distance (clamp) so the camera doesn't fly off too far
	var clamped_mouse_offset = mouse_pos_relative_to_center.limit_length(MAX_CURSOR_OFFSET)
	
	# 3. Calculate the final target offset by applying the influence weight.
	var desired_offset = clamped_mouse_offset * MOUSE_INFLUENCE_WEIGHT

	# 4. Smoothly interpolate the camera's current offset toward the desired target.
	#    This creates the "drag" or "peek" effect.
	current_offset_target = current_offset_target.lerp(desired_offset, SMOOTH_FACTOR)
	
	# 5. Apply the smooth offset to the Camera2D node.
	# Since the Camera2D is a child of the Player, changing its 'offset' moves the camera's viewport.
	offset = current_offset_target
