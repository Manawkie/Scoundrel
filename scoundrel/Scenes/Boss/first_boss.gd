extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_player = $AnimationPlayer
@onready var player = get_parent().get_node("Player")
@onready var ground_spawn_point = $RockSpawnPoint

@export var rock_scene: PackedScene
@export var spawn_range: float = 600.0  # ← horizontal range for random spawn
@export var rock_count: int = 3         # ← number of rocks to spawn per attack

enum BossState {FULL_HEALTH, HALF_HEALTH, QUARTER_HEALTH}
enum AnimState {MELEE_ATTACK, RANGE_ATTACK}

var state_machine: AnimationNodeStateMachinePlayback

# --- BOSS VARIABLES ---
var hp = 100
var melee_range = false
var projectile_range = true

func _ready() -> void:
	anim_tree.active = true
	state_machine = anim_tree.get("parameters/playback")


func _process(_delta: float) -> void:
	sprite_direction()

	if Input.is_action_just_pressed("ui_accept"):
		range_attacks()


func sprite_direction():
	if player.global_position.x > global_position.x:
		sprite.flip_h = true
	else:
		sprite.flip_h = false


func decrease_hp(damage):
	hp -= damage


func _on_melee_range_entered(_body: Node2D) -> void:
	print("inside")


func _on_melee_range_exited(_body: Node2D) -> void:
	print("outside")


func range_attacks():
	print("Boss starting range attack!")
	state_machine.travel("Range_Attacks")  # Trigger punch animation

	# Wait for impact frame (example delay to match animation)
	#await get_tree().create_timer(0.5).timeout

	# Spawn several random rocks
	for i in range(rock_count):
		spawn_random_rock()
		await get_tree().create_timer(0.3).timeout  # short delay between spawns

	print("Boss range attack finished.")
	state_machine.travel("Idle")


func spawn_random_rock():
	if not rock_scene:
		push_error("No rock scene assigned!")
		return

	var rock = rock_scene.instantiate()
	get_parent().add_child(rock)

	# Random X around the boss position (using spawn_range)
	var random_x = global_position.x + randf_range(-spawn_range / 2, spawn_range / 2)
	var spawn_y = ground_spawn_point.global_position.y

	rock.global_position = Vector2(random_x, spawn_y)

	print("Spawned rock at: ", rock.global_position)
