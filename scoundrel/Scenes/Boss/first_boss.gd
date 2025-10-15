extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_player = $AnimationPlayer
@onready var player = get_parent().get_node("Player")
@onready var ground_spawn_point = $RockSpawnPoint

@export var rock_scene: PackedScene
@export var warning_scene: PackedScene
@export var spawn_range: float = 5000.0
@export var rock_count: int = 3
@export var warning_delay: float = 0.8
@export var min_spacing: float = 500.0
@export var rock_rise_height: float = 300.0

var state_machine: AnimationNodeStateMachinePlayback
var hp = 100
var last_spawn_positions: Array = []


func _ready() -> void:
	anim_tree.active = true
	state_machine = anim_tree.get("parameters/playback")


func _process(_delta: float) -> void:
	sprite_direction()
	if Input.is_action_just_pressed("ui_accept"):
		range_attacks()


func sprite_direction():
	sprite.flip_h = player.global_position.x > global_position.x


func decrease_hp(damage):
	hp -= damage


func range_attacks():
	print("Boss starting range attack!")
	state_machine.travel("Range_Attacks")

	last_spawn_positions.clear()

	for i in range(rock_count):
		spawn_random_rock()
		await get_tree().create_timer(0.3).timeout

	print("Boss range attack finished.")
	state_machine.travel("Idle")


func spawn_random_rock():
	if not rock_scene:
		push_error("No rock scene assigned!")
		return

	var spawn_pos = get_valid_spawn_position()

	# Step 1: Warning effect
	var warning
	if warning_scene:
		warning = warning_scene.instantiate()
		get_parent().add_child(warning)
		warning.global_position = spawn_pos
		# Do NOT free it yet — we’ll fade it out later

	await get_tree().create_timer(warning_delay).timeout

	# Step 2: Spawn rock
	var rock = rock_scene.instantiate()
	get_parent().add_child(rock)
	rock.global_position = spawn_pos

	# Step 3: Rising animation
	rock.start_rising()
	var tween = create_tween()
	var target_pos = spawn_pos - Vector2(0, rock_rise_height)
	tween.tween_property(rock, "position", target_pos, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	rock.stop_rising()

	# Step 4: Fade out warning after the rock appears
	if warning:
		var fade_tween = create_tween()
		fade_tween.tween_property(warning, "modulate:a", 0.0, 0.3)
		await fade_tween.finished
		warning.queue_free()

	print("Spawned rock at:", rock.global_position)


func get_valid_spawn_position() -> Vector2:
	var attempts = 0
	while attempts < 10:
		var random_x = global_position.x + randf_range(-spawn_range / 2, spawn_range / 2)
		var spawn_y = ground_spawn_point.global_position.y
		var candidate = Vector2(random_x, spawn_y)

		var too_close = false
		for pos in last_spawn_positions:
			if pos.distance_to(candidate) < min_spacing:
				too_close = true
				break

		if not too_close:
			last_spawn_positions.append(candidate)
			return candidate

		attempts += 1

	return Vector2(global_position.x + randf_range(-spawn_range / 2, spawn_range / 2), ground_spawn_point.global_position.y)
