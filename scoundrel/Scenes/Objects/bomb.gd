extends Area2D

@export var fuse_time: float = 2.0   # seconds before explosion
@onready var _timer: Timer = $Timer
@onready var _explosion: GPUParticles2D = $GPUParticles2D
@onready var _sprite = $AnimatedSprite2D

func _ready():
	_sprite.play("bomb")
	_timer.wait_time = fuse_time
	_timer.one_shot = true
	_timer.start()
	_explosion.emitting = false  # keep off until boom

func _on_Timer_timeout():
	explode()

func explode():
	# Hide bomb sprite
	_sprite.visible = false

	# Play explosion particles
	_explosion.emitting = true

	# Wait for particles to finish (optional)
	await get_tree().create_timer(_explosion.lifetime).timeout

	# Remove the bomb after particles finish
	queue_free()
