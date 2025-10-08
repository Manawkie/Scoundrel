extends CharacterBody2D


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_player = $AnimationPlayer
@onready var eye_sprite = $EyeKael
@onready var bomb_scene = preload("res://scoundrel/Scenes/Objects/Bomb/Bomb.tscn")
@onready var bullet_scene = preload("res://scoundrel/Scenes/Objects/Bullet/Bullet.tscn")
@onready var grapple_hook_scene = preload("res://scoundrel/Scenes/Objects/Grapple_Hook/Hook.tscn")
var state_machine : AnimationNodeStateMachinePlayback

enum WeaponState {SCIMITAR, GUN, GRAPPLE_HOOK}

# --- WEAPON CONSTANTS ---
const SCIMITAR_COOLDOWN = 0.3 # Cooldown after melee attack finishes
const GUN_COOLDOWN = 0.5 	  # Cooldown after gun attack finishes
const SCIMITAR_ANIM_DURATION = 0.2
const GUN_ANIM_DURATION = 0.3

# --- GRAPPLE HOOK CONSTANTS ---
const HOOK_SPEED = 2000.0       # Speed the hook travels
const MAX_HOOK_LENGTH = 1500.0   # Max distance the hook can reach
const GRAPPLE_PULL_ACCEL = 4000.0 # Acceleration when pulling towards the hook point
const GRAPPLE_COOLDOWN = 0.5    # Cooldown after hook retraction

# --- DASH CONSTANTS ---
const DASH_SPEED = 1600.0
const DASH_DURATION = 0.15  # seconds the dash lasts
const DASH_COOLDOWN = 0.5   # seconds until the player can dash again

# --- BOMB CONSTANTS ---
const BOMB_COOLDOWN = 1.0       # seconds until the player can drop another bomb (cooldown)
const BOMB_ANIMATION_DURATION = 0.4 # NEW: seconds the drop animation lasts
const BOMB_DROP_OFFSET_X = 20.0 # How far it is going to spawn in fornt of the player

# --- MOVEMENT CONSTANTS ---
const JUMP_VELOCITY = -1000.0 
const SPEED = 200.0
const RSPEED = 800.0
const GRAVITY = 1800.0
const FAST_FALL_SPEED = 1200.0

# --- EYE CONSTANTS
const MAX_PUPIL_MOVEMENT = 8.0 # Max distance the eye can shift in pixels
const EYE_SMOOTH_FACTOR = 0.1 # How smoothly the eye tracks the cursor (0.0 to 1.0)

# --- AIR CONTROL CONSTANTS
const AIR_CONTROL_FACTOR = 0.6 # Multiplier for max horizontal speed in the air (e.g., 800 * 0.6 = 480)
const AIR_ACCEL_RATE = 0.15    # The "smoothness" factor for changing direction in the air (0.0 to 1.0)

# --- MOVEMENT  VARIABLE ---
var direction: float = 0.0
var last_direction: float = 1.0 # Tracks last non-zero direction for dashing
var current_state = "Idle"
var current_anim_playing = ""
var eye_original_position: Vector2 
var run_toggle = false

# --- WEAPON VARIABLES ---
var current_weapon: WeaponState = WeaponState.SCIMITAR
var is_attacking: bool = false
var attack_timer: float = 0.0

# --- GRAPPLE HOOK VARIABLES ---
var is_grappling: bool = false # True if launched or hooked
var is_hooked: bool = false    # True if attached to a wall
var hook_point: Vector2 = Vector2.ZERO # World coordinates of the attachment point
var hook_vector: Vector2 = Vector2.ZERO # Direction the hook is traveling
var current_rope_length: float = 0.0
var initial_rope_length: float = 0.0 # NEW: Stores the max possible length for the current swing
var current_hook_instance: Area2D = null

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
	var is_grounded_and_hooked = is_hooked and is_on_floor()
	handle_dash(delta)
	handle_bomb_drop(delta)
	handle_weapon_combat(delta)
	handle_hook_launch(delta)
	if is_hooked:
		handle_rope_control(delta)
	if is_dashing or is_dropping_bomb:
		velocity.y = 0
	elif is_grappling and not is_hooked:
		velocity.y = 0
		velocity.x = lerp(velocity.x, 0.0, 0.02)
	elif is_hooked and not is_grounded_and_hooked:
		handle_swing_physics(delta)
	else:
		player_movement_x(delta)
		player_movement_y()
		apply_gravity(delta)
	update_sprite_flip()
	move_and_slide()
	determine_animation_state()
	anim_manager(current_state)

func player_movement_y():
	
	if is_grappling and not is_on_floor(): 
		return
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if Input.is_action_pressed("go_down") and not is_on_floor() and not is_dashing:
		velocity.y = FAST_FALL_SPEED
	
	if Input.is_action_just_pressed("toggle_run"):
		if run_toggle == true:
			run_toggle = false
		else:
			run_toggle = true

func player_movement_x(delta: float):
	direction = Input.get_axis("walk_left", "walk_right")
	
	if is_dashing: 
		return
		
	var target_speed = SPEED
	
	if run_toggle == true:
		target_speed = RSPEED
		
	var target_vel_x = direction * target_speed
	
	if is_on_floor():
		
		if is_hooked:
			# Logic to prevent running past the maximum rope length
			if direction != 0:
				
				# 1. Predict the position based on the desired velocity
				var proposed_pos_x = global_position.x + target_vel_x * delta
				var proposed_pos = Vector2(proposed_pos_x, global_position.y) 
				
				var distance_to_hook = proposed_pos.distance_to(hook_point)
				
				if distance_to_hook > current_rope_length:
					# Player is trying to move outside the allowed radius
					
					var hook_dir_x = sign(hook_point.x - global_position.x)
					var move_direction_is_away = sign(direction) != hook_dir_x

					# Only restrict velocity if the input is actively pulling away
					if move_direction_is_away:
						velocity.x = 0
					else:
						# Allow movement towards the hook point, even if currently at max length
						velocity.x = target_vel_x
				else:
					# Within the rope limit, allow full movement
					velocity.x = target_vel_x
			else:
				# Idle on floor, hooked: stop horizontal movement
				velocity.x = 0
		else:
			# Standard grounded movement (no hook)
			velocity.x = target_vel_x
			
	elif direction != 0:
		# Air control logic
		var target_max_speed = target_speed * AIR_CONTROL_FACTOR
		var desired_target_vel = direction * target_max_speed
		var input_matches_momentum = sign(direction) == sign(velocity.x)
		var is_overspeeding = abs(velocity.x) > target_max_speed
		
		if is_overspeeding and input_matches_momentum:
			pass
		else:
			velocity.x = lerp(velocity.x, desired_target_vel, AIR_ACCEL_RATE)

	if direction != 0:
			last_direction = direction

func update_sprite_flip():
	var face_direction = 0.0

	# Priority 1: Dashing (Sprite faces the direction of the dash)
	if is_dashing:
		face_direction = dash_direction
	
	# Priority 2: Swinging or Airborne (Sprite faces direction of movement/momentum)
	elif is_hooked or not is_on_floor():
		# When swinging or airborne, base direction on horizontal velocity (momentum).
		# Use a small threshold (e.g., 5.0) to avoid jitter when velocity is near zero.
		if abs(velocity.x) > 5.0:
			face_direction = sign(velocity.x)
	
	# Priority 3: Normal Grounded Movement (Sprite faces direction of input)
	elif direction != 0:
		# When on floor (and not swinging), base direction on input.
		face_direction = direction
	
	# Priority 4: Idle (Sprite faces the last direction of movement)
	else:
		face_direction = last_direction

	# Apply the flip and update last_direction only if a distinct direction is found
	if face_direction != 0:
		sprite.flip_h = face_direction < 0
		# last_direction is only updated by player_movement_x, not here, 
		# unless we are dashing, where last_direction should be updated in start_dash().
		# Keeping original last_direction update for robustness:
		if direction != 0:
			last_direction = direction

func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		if velocity.y > 0:
			velocity.y = 0

func determine_animation_state():
	if is_attacking:
		match current_weapon:
			WeaponState.SCIMITAR:
				current_state = "Scimitar_Attack"
			WeaponState.GUN:
				current_state = "Gun_Fire"
		return
	
	if is_dashing:
		current_state = "Dash"
		return
		
	if is_dropping_bomb:
		current_state = "Drop_Bomb"
		return
	if is_grappling and not is_hooked:
		current_state = "Grapple_Launch"
		return
		
	if is_hooked and not is_on_floor():
		current_state = "Grapple_Swing"
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
		"Grapple_Launch":
			state_machine.travel("Grapple_Launch")
		"Grapple_Swing":
			state_machine.travel("Grapple_Swing")
	
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
	
	if Input.is_action_just_pressed("select_grapple"):
		if is_hooked:
			pass
		else:
			current_weapon = WeaponState.GRAPPLE_HOOK
			print("grapple hook")
	
	if Input.is_action_just_pressed("fire"):
		if current_weapon == WeaponState.GRAPPLE_HOOK and not is_grappling:
			start_grapple()
		elif not is_grappling and not is_attacking:
			start_attack()
	
	if is_grappling and not is_on_floor() and Input.is_action_just_pressed("jump"): 
		retract_hook(is_hooked)
		
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

func start_grapple():
	is_grappling = true
	is_hooked = false 
	velocity.y = 0 
	velocity.x = 0
	
	var mouse_pos = get_global_mouse_position()
	hook_vector = (mouse_pos - global_position).normalized()

	current_hook_instance = grapple_hook_scene.instantiate() 
	get_tree().root.add_child(current_hook_instance)

	if current_hook_instance.has_method("set_grapple_mode"):
		# Assuming the projectile script has a function to set its mode and speed
		current_hook_instance.set_grapple_mode(hook_vector, HOOK_SPEED, self)

	# NEW CONNECTION: Tell the hook instance who the player is, so the Line2D can track.
	if current_hook_instance.has_method("set_player"):
		current_hook_instance.set_player(self)

	current_hook_instance.spawner = self 
	current_hook_instance.global_position = global_position

func handle_hook_launch(_delta):
	# Runs while the hook is launched but not yet hooked
	if is_grappling and not is_hooked and is_instance_valid(current_hook_instance):
		# Check max distance (if hook script fails to return the hook)
		if global_position.distance_to(current_hook_instance.global_position) > MAX_HOOK_LENGTH:
			retract_hook()
			return

func on_hook_hit(hit_point: Vector2):
	# CRITICAL: This is called by the hook projectile when it hits a solid object.
	if not is_grappling or is_hooked:
		return
	
	is_hooked = true
	hook_point = hit_point
	
	var initial_distance = global_position.distance_to(hook_point)
	initial_rope_length = initial_distance
	current_rope_length = initial_distance
	
	# Ensure the player starts with a velocity suitable for swinging
	if velocity.length() < 100: # Give a minimum outward swing speed if stationary
		velocity = hook_vector * 500

func handle_swing_physics(delta):
	if not is_hooked:
		return
		
	# Rope length is now managed by handle_rope_control, which runs regardless of grounded status.
	
	var rope_dir = (hook_point - global_position).normalized()
	
	velocity.y += GRAVITY * delta
	
	var max_length = current_rope_length
	
	var delta_to_hook = hook_point - global_position
	var separation = delta_to_hook.length() - max_length
	
	# Resolve constraint by adjusting velocity tangentially
	if separation > 0:
		var tangent_vector = Vector2(-rope_dir.y, rope_dir.x)
		var tangential_velocity = velocity.dot(tangent_vector) * tangent_vector
		velocity = tangential_velocity
		
		# Teleport slightly back to the rope for stability
		global_position += rope_dir * separation * 0.1
		
	# Apply tangential acceleration from player input while swinging
	var input_direction = Input.get_axis("walk_left", "walk_right")
	if input_direction != 0:
		var tangent_vector = Vector2(-rope_dir.y, rope_dir.x) * input_direction
		velocity += tangent_vector * 100.0 * delta

func handle_rope_control(delta):
	# This function runs every frame if the hook is active (is_hooked = true)
	if not is_hooked:
		return

	if Input.is_action_pressed("fire"):
		var rope_dir = (hook_point - global_position).normalized()
		
		# 1. Shorten the rope length (pulling)
		current_rope_length = max(current_rope_length - GRAPPLE_PULL_ACCEL * delta * 0.075, 50.0)
		var pull_vector = rope_dir * GRAPPLE_PULL_ACCEL * delta * 0.5
		velocity += pull_vector
	else:
		# If fire is not pressed, the rope snaps back to its initial length.
		current_rope_length = initial_rope_length

func retract_hook(apply_jump=false):
	# Allow momentum to continue but reset grapple state
	is_grappling = false
	is_hooked = false
	hook_point = Vector2.ZERO
	
	# Reset vertical velocity to prevent instant drop/snap to ground on release.
	velocity.y = 0
	
	if apply_jump:
		# Apply upward jump velocity if the release was triggered by the 'jump' action while hooked.
		velocity.y = JUMP_VELOCITY
	
	if is_instance_valid(current_hook_instance):
		current_hook_instance.queue_free()
		current_hook_instance = null
		
	# Give the player a short cooldown before re-grappling
	# You might want to repurpose the attack_timer for this, or add a dedicated cooldown
	
	# If not on floor, start falling normally
	if not is_on_floor():
		apply_gravity(0.0)

func handle_bomb_drop(delta):
	if Input.is_action_just_pressed("drop_bomb") and can_drop_bomb: 
		start_bomb_drop()
	
	if is_dropping_bomb:
		bomb_timer -= delta
		
		if bomb_timer <= 0:
			
			var bomb_instance = bomb_scene.instantiate()
			get_tree().root.add_child(bomb_instance) 
			
			var drop_offset = Vector2(BOMB_DROP_OFFSET_X * last_direction, 10)
			bomb_instance.global_position = global_position + drop_offset
			
			# Ensure the bomb inherits the velocity
			if bomb_instance.has_method("apply_initial_impulse"):
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
	# --- NEW LOGIC: Cancel Grapple if Dashing Out of a Swing ---
	if is_hooked:
		# Cancel the grapple first, passing false to prevent an extra upward jump velocity.
		retract_hook(false)

	is_dashing = true
	can_dash = false
	dash_timer = DASH_DURATION
	
	# Determine dash direction:
	# Priority 1: Current horizontal input (A/D)
	if direction != 0:
		dash_direction = direction
	# Priority 2: Momentum (if no input, dash in the direction the player is moving)
	elif abs(velocity.x) > 5.0:
		dash_direction = sign(velocity.x)
	# Priority 3: Last facing direction (default fall-back)
	else:
		dash_direction = last_direction
		
	# Ensure last_direction tracks the dash direction
	last_direction = dash_direction

func end_dash():
	is_dashing = false
	dash_timer = DASH_COOLDOWN
