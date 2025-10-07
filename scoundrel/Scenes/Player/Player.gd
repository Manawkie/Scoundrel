extends CharacterBody2D


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_player = $AnimationPlayer
@onready var eye_sprite = $EyeKael
@onready var bomb_scene = preload("res://scoundrel/Scenes/Objects/Bomb.tscn")
@onready var bullet_scene = preload("res://scoundrel/Scenes/Objects/Bullet/Bullet.tscn")
var state_machine : AnimationNodeStateMachinePlayback

enum WeaponState {SCIMITAR, GUN}

# --- WEAPON CONSTANTS ---
const SCIMITAR_COOLDOWN = 0.3 # Cooldown after melee attack finishes
const GUN_COOLDOWN = 0.5 	  # Cooldown after gun attack finishes
const SCIMITAR_ANIM_DURATION = 0.2
const GUN_ANIM_DURATION = 0.3
var current_weapon: WeaponState = WeaponState.SCIMITAR
var is_attacking: bool = false
var attack_timer: float = 0.0


# --- DASH CONSTANTS ---
const DASH_SPEED = 1600.0
const DASH_DURATION = 0.15  # seconds the dash lasts
const DASH_COOLDOWN = 0.5   # seconds until the player can dash again

# --- BOMB CONSTANTS ---
const BOMB_COOLDOWN = 1.0       # seconds until the player can drop another bomb (cooldown)
const BOMB_ANIMATION_DURATION = 0.4 # NEW: seconds the drop animation lasts

# --- MOVEMENT CONSTANTS ---
const JUMP_VELOCITY = -1000.0 
const SPEED = 200.0
const RSPEED = 800.0
const GRAVITY = 1800.0
const FAST_FALL_SPEED = 1800.0


# --- EYE CONSTANTS
const MAX_PUPIL_MOVEMENT = 8.0 # Max distance the eye can shift in pixels
const EYE_SMOOTH_FACTOR = 0.1 # How smoothly the eye tracks the cursor (0.0 to 1.0)

# --- AIR CONTROL CONSTANTS
const AIR_CONTROL_FACTOR = 0.6 # Multiplier for max horizontal speed in the air (e.g., 800 * 0.6 = 480)
const AIR_ACCEL_RATE = 0.15    # The "smoothness" factor for changing direction in the air (0.0 to 1.0)

var direction: float = 0.0
var last_direction: float = 1.0 # Tracks last non-zero direction for dashing
var current_state = "Idle"
var current_anim_playing = ""
var eye_original_position: Vector2 
var run_toggle = false

# --- DASH VARIABLES ---
var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: float = 0.0
var dash_timer: float = 0.0

# --- BOMB VARIABLES ---
var can_drop_bomb: bool = true
var is_dropping_bomb: bool = false # NEW: Flag to hold character during animation
var bomb_timer: float = 0.0 # Used for both animation duration and cooldown



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
		
	if eye_sprite:
		eye_original_position = eye_sprite.position
		
func _process(_delta: float) -> void:
	handle_eye_tracking()

func _physics_process(delta: float) -> void:
	handle_dash(delta)
	handle_bomb_drop(delta)
	handle_weapon_combat(delta)
	if is_dashing or is_dropping_bomb:
		velocity.y = 0
	else:
		player_movement_x()
		player_movement_y()
		apply_gravity(delta)
	move_and_slide()
	determine_animation_state()
	anim_manager(current_state)

func player_movement_y():
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if Input.is_action_pressed("go_down") and not is_on_floor() and not is_dashing:
		velocity.y = FAST_FALL_SPEED
	
	if Input.is_action_just_pressed("toggle_run"):
		if run_toggle == true:
			run_toggle = false
		else:
			run_toggle = true

func player_movement_x():
	direction = Input.get_axis("walk_left", "walk_right")
	
	if is_dashing:
		return 
		
	var target_speed = SPEED
	
	if run_toggle == true:
		target_speed = RSPEED
		
	if is_on_floor():
		
		velocity.x = direction * target_speed
	elif direction != 0:

		var target_vel = direction * target_speed * AIR_CONTROL_FACTOR
		velocity.x = lerp(velocity.x, target_vel, AIR_ACCEL_RATE)
		
	if direction != 0:
			sprite.flip_h = direction < 0
			last_direction = direction

func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if velocity.y > 0:
			velocity.y = 0

func determine_animation_state():
	if is_dashing:
		current_state = "Dash"
		return
		
	if is_dropping_bomb:
		current_state = "Drop_Bomb"
		return
		
	if not is_on_floor():
		if velocity.y < 0:
			current_state = "Jump"
		elif velocity.y > 0:
			current_state = "Fall"
		return

	if direction != 0:
		if run_toggle == true:
			current_state = "Run"
		if run_toggle == false:
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
		"Run":
			state_machine.travel("Run")
		"Dash":
			state_machine.travel("Dash")
		"Drop_Bomb":
			state_machine.travel("Drop_Bomb")
		"Scimitar_Attack":
			state_machine.travel("Scimitar_Attack")
		"Gun_Fire":
			state_machine.travel("Gun_Fire")
	
	current_anim_playing = state

func handle_eye_tracking():
	
	# 1. Get mouse position relative to the eye's world position
	var mouse_world_pos = get_global_mouse_position()
	var eye_world_pos = eye_sprite.global_position
	
	# 2. Calculate the direction and distance from the eye to the mouse
	var direction_to_mouse = (mouse_world_pos - eye_world_pos)
	
	# 3. Limit the length (distance) of the vector to the max shift amount
	var target_shift = direction_to_mouse.limit_length(MAX_PUPIL_MOVEMENT)
	
	# 4. Determine the final target position relative to the character body
	var target_position = eye_original_position + target_shift
	
	# 5. Smoothly interpolate the eye's current position to the target position
	# This creates the smooth "drag" or "lean" effect.
	eye_sprite.position = eye_sprite.position.lerp(target_position, EYE_SMOOTH_FACTOR)

func handle_weapon_combat(delta):
	
	if Input.is_action_just_pressed("select_gun"):
		current_weapon = WeaponState.GUN
		print("gun")
		
	if Input.is_action_just_pressed("select_scimitar"):
		current_weapon = WeaponState.SCIMITAR
		print("scimitar")
	
	if Input.is_action_just_pressed("fire") and not is_attacking:
		start_attack()
		
	if is_attacking:
		attack_timer -= delta
		# End of the animation/attack phase
		if attack_timer <= 0:
			end_attack()
	# Else: the timer acts as a simple cooldown until attack_timer <= 0

func start_attack():
	is_attacking = true
	
	match current_weapon:
		WeaponState.SCIMITAR:
			attack_timer = SCIMITAR_ANIM_DURATION + SCIMITAR_COOLDOWN
			
		WeaponState.GUN:
			attack_timer = GUN_ANIM_DURATION + GUN_COOLDOWN
			# NEW LOGIC: Calculate aim vector
			var mouse_pos = get_global_mouse_position()
			var aim_vector = (mouse_pos - global_position).normalized()
			
			var projectile = bullet_scene.instantiate()
			get_tree().root.add_child(projectile)
			
			projectile.spawner = self
			projectile.global_position = global_position 
			
			# Pass the full aim vector instead of just direction
			if projectile.has_method("set_aim_vector"):
				projectile.set_aim_vector(aim_vector)
	
func end_attack():
	is_attacking = false

func handle_bomb_drop(delta):
	if Input.is_action_just_pressed("drop_bomb") and can_drop_bomb: 
		start_bomb_drop()
	
	if is_dropping_bomb:
		bomb_timer -= delta
		
		# Placeholder for Bomb Instantiation would go here...
		
		if bomb_timer <= 0:
			
			var bomb_instance = bomb_scene.instantiate()
			get_tree().current_scene.add_child(bomb_instance)
			bomb_instance.global_position = global_position + Vector2(0, 10) 
			bomb_instance.apply_initial_impulse(velocity)
			
			
			end_bomb_animation()
			
	# 3. Manage Cooldown (Only runs if not currently in the animation phase)
	if not can_drop_bomb and not is_dropping_bomb:
		bomb_timer -= delta
		if bomb_timer <= 0:
			can_drop_bomb = true
			bomb_timer = 0

func start_bomb_drop(): 
	is_dropping_bomb = true
	can_drop_bomb = false
	bomb_timer = BOMB_ANIMATION_DURATION 
	
func end_bomb_animation(): 
	is_dropping_bomb = false
	bomb_timer = BOMB_COOLDOWN

func handle_dash(delta):
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		start_dash()

	if is_dashing:
		dash_timer -= delta
		
		velocity.x = dash_direction * DASH_SPEED
		if dash_timer <= 0:
			end_dash()


	if not can_dash and not is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			can_dash = true
			dash_timer = 0 

func start_dash():

	is_dashing = true
	can_dash = false
	dash_timer = DASH_DURATION
	
	if direction != 0:
		dash_direction = sign(direction) 
	else:
		dash_direction = sign(last_direction) 
		
func end_dash():
	is_dashing = false
	dash_timer = DASH_COOLDOWN
