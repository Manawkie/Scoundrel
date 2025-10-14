extends RigidBody2D

@export var rise_speed: float = 400.0
@export var rise_duration: float = 0.3
@export var shake_strength: float = 4.0
@export var shake_count: int = 6
@export var sink_distance: float = 32.0
@export var sink_duration: float = 0.8
@export var stay_duration: float = 2.5  # 🧱 how long the pillar stays solid before shaking

@onready var shape = $CollisionShape2D

func _ready():
	gravity_scale = 0
	sleeping = false
	freeze = false

	# Disable collisions briefly to avoid pushing on tilemaps or other objects
	shape.disabled = true
	position.y += 8  # start slightly below floor for better emergence

	# Rise up fast
	apply_central_impulse(Vector2(0, -rise_speed))
	
	# Enable collision after short delay (once it's already rising)
	await get_tree().create_timer(0.15).timeout
	shape.disabled = false

	# Wait for rise to complete
	await get_tree().create_timer(rise_duration).timeout

	# --- PLATFORM STAY TIME ---
	await get_tree().create_timer(stay_duration).timeout

	# --- SHAKE AND SINK WHILE STILL SOLID ---
	await shake_and_sink()

	# Disable collision before removing to avoid trapping player
	shape.disabled = true
	queue_free()


func shake_and_sink():
	var tween = create_tween()
	var original_pos = global_position
	
	for i in range(shake_count):
		var offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		tween.tween_property(self, "global_position", original_pos + offset, sink_duration / (shake_count * 2))
		tween.tween_property(self, "global_position", original_pos, sink_duration / (shake_count * 2))
	
	# Slowly sink while shaking
	tween.tween_property(self, "global_position:y", original_pos.y + sink_distance, sink_duration)
	await tween.finished
