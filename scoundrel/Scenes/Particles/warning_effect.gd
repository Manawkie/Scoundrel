extends Node2D

@export var duration: float = 0.8
@onready var particles: GPUParticles2D = $GPUParticles2D

func _ready():
	particles.emitting = true  # start emitting immediately
	await get_tree().create_timer(duration).timeout
	queue_free()  # disappear after duration
