extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_player = $AnimationPlayer
@onready var player = get_parent().get_node("Player")
var state_machine : AnimationNodeStateMachinePlayback

enum BossState {FULL_HEALTH, HALF_HEALTH, QUARTER_HEALTH}


# --- BOSS VARIABLES ---
var hp = 100
var melee_range = false
var projectile_range = true


func _ready() -> void:
	anim_tree.active = true
	state_machine = anim_tree.get("parameters/playback")
	
	


func _process(_delta: float) -> void:
	sprite_direction()
	
	


func sprite_direction():
	if player.global_position.x > global_position.x:
		# Player is on the right
		sprite.flip_h = true
	else:
		# Player is on the left
		sprite.flip_h = false


func decrease_hp(damage):
	hp -= damage
	
