extends CharacterBody2D

@onready var PLAYER := preload("res://characters/scenes/caveman.tscn").instantiate()
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var SPEED := 250
var chasing := false
var last_direction := Vector2.ZERO

func _physics_process(delta: float) -> void:
	chase_player()
	move_and_slide()
	# Flip sprite
	if last_direction.x < 0:
		sprite.flip_h = true
	elif last_direction.x > 0:
		sprite.flip_h = false

func chase_player():
	if chasing and PLAYER:
		var direction = (PLAYER.position - position).normalized()
		last_direction = direction
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
		
# Sight area signals
func _on_sight_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		chasing = true

func _on_sight_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		chasing = false
