extends RigidBody2D

@export var stay_duration: float = 2.5        # how long the pillar stays solid before sinking
@export var sink_distance: float = 64.0       # how far it sinks slowly
@export var sink_duration: float = 0.8        # duration of slow sinking
@export var slam_distance: float = 400.0      # how far it slams down quickly
@export var rise_speed: float = 400.0         # used for slam speed (same as rise)
@export var slam_duration: float = 0.3        # fast slam timing

@onready var shape = $CollisionShape2D
@onready var damage_area = $DamageArea
@onready var damage_shape = $DamageArea/CollisionShape2D

var is_rising: bool = false


func _ready():
	gravity_scale = 0
	freeze = true
	sleeping = false
	damage_area.monitoring = false


# Called by the boss when the rock starts rising
func start_rising():
	is_rising = true
	damage_area.monitoring = true


# Called by the boss when rising stops
func stop_rising():
	is_rising = false
	damage_area.monitoring = false
	# After rising, begin its life cycle (stay → sink → slam)
	await post_rise_sequence()


# ------------------- Rock Lifecycle -------------------

func post_rise_sequence():
	# Step 1: Stay solid for a while
	await get_tree().create_timer(stay_duration).timeout

	# Step 2: Slowly sink
	await slow_sink()

	# Step 3: Slam down quickly and disappear
	await slam_down()
	queue_free()


func slow_sink():
	var tween = create_tween()
	var original_pos = global_position
	tween.tween_property(self, "global_position:y", original_pos.y + sink_distance, sink_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func slam_down():
	var tween = create_tween()
	var original_pos = global_position
	var target_y = original_pos.y + slam_distance
	tween.tween_property(self, "global_position:y", target_y, slam_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished


func _on_area_2d_body_entered(body: Node2D) -> void:
	if is_rising and body.name == "Player":
		PlayerManager.player_hp -= 1
		print("Player damaged by rising rock!")
