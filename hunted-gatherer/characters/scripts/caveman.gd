extends CharacterBody2D
var SPEED = 400
const ACCEL = 500
const FRICTION = 500
@onready var CURRENT_DIR = "front"




func _ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()
	
	
#MOVEMENT/ANIMATIONS
func get_input():
	var DIRECTION = Input.get_vector("left", "right", "up", "down")
	var target_velocity = DIRECTION * SPEED
	velocity = velocity.lerp(target_velocity, 0.2)
	
	
	
	if velocity.x:
		$AnimatedSprite2D.flip_h = velocity.x < 0
		
	if Input.is_action_just_pressed("sprint"):
		SPEED = 650
	if Input.is_action_just_released("sprint"):
		SPEED = 400
		
#ANIMATIONS

	#UP/DOWN
	if velocity.y < 0:
		$AnimatedSprite2D.play("run")
	if velocity.y > 0:
		$AnimatedSprite2D.play("run")
	elif velocity.y == 0:
		CURRENT_DIR = "none"
	#LEFT/RIGHT
	if velocity.x < 0:
		$AnimatedSprite2D.play("run")
	if velocity.x > 0:
		$AnimatedSprite2D.play("run")
	#STILL
	if velocity == Vector2.ZERO:
		$AnimatedSprite2D.play("idle")
	
