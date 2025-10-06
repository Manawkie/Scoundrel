extends CharacterBody2D


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_player = $AnimationPlayer
var state_machine : AnimationNodeStateMachinePlayback



const JUMP_VELOCITY = -1000.0 
const SPEED = 200.0
const GRAVITY = 1800.0
const FAST_FALL_SPEED = 10000.0

var direction: float = 0.0
var current_state = "Idle"
var current_anim_playing = ""



func _ready() -> void:
	
	if anim_tree:
		anim_tree.active = true
	state_machine = anim_tree["parameters/playback"]
	print(state_machine)
	if state_machine == null:
		print("error")
	else:
		state_machine.travel("Idle")
		current_anim_playing = "Idle"

func _physics_process(delta: float) -> void:
	player_movement_x()
	player_movement_y(delta)
	apply_gravity(delta)
	move_and_slide()
	determine_animation_state()
	anim_manager(current_state)
	
	
	
func player_movement_y(delta):
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if Input.is_action_just_pressed("go_down") and not is_on_floor():
		velocity.y = FAST_FALL_SPEED * delta
		
			
func player_movement_x():
	
	direction = Input.get_axis("walk_left", "walk_right")
	velocity.x = direction * SPEED
	if direction != 0:
			sprite.flip_h = direction < 0
	
	
func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if velocity.y > 0:
			velocity.y = 0
			
			
func determine_animation_state():
	if not is_on_floor():
		if velocity.y < 0:
			current_state = "Jump"
		elif velocity.y > 0:
			current_state = "Fall"
		return

	if direction != 0:
		current_state = "Walk"
	else:
		current_state = "Idle"
		

	
	
func anim_manager(state):
	if state == current_anim_playing:
		return
	if state_machine == null:
		return
	
	match state:
		"Idle":
			state_machine.travel("Idle")
		"Walk":
			state_machine.travel("Walk")
		"Jump":
			state_machine.travel("Jump")
		"Fall":
			state_machine.travel("Fall")
	
	current_anim_playing = state
