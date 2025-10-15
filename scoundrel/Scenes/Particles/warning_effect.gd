# WarningEffect.gd
extends Node2D

@export var duration: float = 0.8
@onready var particles: GPUParticles2D = $GPUParticles2D

func _ready():
	# Start particles immediately (if they are set to not one_shot)
	if particles:
		particles.emitting = true

	# optional: play a tiny tween/flicker on a Sprite child here

	# Auto-free after duration
	await get_tree().create_timer(duration).timeout
	queue_free()
