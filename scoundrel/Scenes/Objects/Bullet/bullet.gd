extends Area2D


@onready var after_hit_particle = $GPUParticles2D
@export var speed = 4000.0 # High speed for a gun bullet
var aim_vector: Vector2 = Vector2.RIGHT # The normalized vector pointing where the bullet should travel
var spawner: Node2D # Reference to the node that spawned this projectile (the player)


func set_aim_vector(new_vector: Vector2): # NEW function to receive the aim
	aim_vector = new_vector
	
	# Optional: Rotate the sprite to face the aim direction
	# rotation = aim_vector.angle() 

func _ready():
	self.name = "Bullet"
	# Connect signal to handle what happens when the bullet hits something
	body_entered.connect(_on_body_entered) 
	
	# Setting the collision mask here ensures it ignores the player layer (Layer 2)
	set_collision_mask_value(2, false) # Ignores player layer
	set_collision_layer_value(4, true)  # Sets projectile to its own layer

func _physics_process(delta):
	# Move the projectile using the aim vector
	position += aim_vector * speed * delta

func _on_body_entered(body):
	# 1. Check to see if the body hit is the player who fired this projectile.
	if body == spawner:
		print("player")
		return
	
	if body.has_method("decrease_hp"):
		print("I entered")
		body.decrease_hp(10)
	# NEW LOGIC: Check if the projectile hit a bomb and trigger an early explosion.
	# We use has_method("explode") as a safe way to check if the body is a bomb.
	if body.has_method("explode"):
		print("from bullet")
		body.explode() # Trigger the bomb's explosion immediately
		
	if body.has_method("boss_hit"):
		body.boss_hit()
	# 2. Destroy the projectile upon hitting any other solid object (ground, wall, enemy, or bomb)
	
	var bullet_pos = global_position
	after_hit_particle.global_position = bullet_pos
	after_hit_particle.emitting = true
	$AnimatedSprite2D.visible = false
	if after_hit_particle.emitting == false:
		queue_free()
	
	
	
	
