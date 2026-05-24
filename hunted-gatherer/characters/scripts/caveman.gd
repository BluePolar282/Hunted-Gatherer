extends CharacterBody2D

const BASE_SPEED := 400.0
const SPRINT_SPEED := 650.0
const WATER_SPEED := 200.0

@onready var CURRENT_DIR = "front"
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

const TERRAIN_SET   = 0
const TERRAIN_WATER = 1

var in_water := false
var tilemap: TileMapLayer = null

func _physics_process(delta: float) -> void:
	if tilemap == null:
		return
	# --- Water detection ---
	var feet_offset := Vector2(0, 8)
	var feet_pos := tilemap.to_local(global_position + feet_offset)
	var tile_pos := tilemap.local_to_map(feet_pos)

	var td := tilemap.get_cell_tile_data(tile_pos)
	if td != null:
		in_water = (td.get_terrain() == TERRAIN_WATER)
	else:
		in_water = true
	# --- Speed ---
	var speed: float
	if in_water:
		speed = WATER_SPEED
	elif Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = BASE_SPEED

	# --- Movement ---
	var direction := Input.get_vector("left", "right", "up", "down")
	var target_velocity := direction * speed
	velocity = velocity.lerp(target_velocity, 0.2)
	move_and_slide()

	# --- Animation ---
	if in_water:
		anim.play("swim")
	elif direction != Vector2.ZERO:
		anim.play("run")
	else:
		anim.play("default")

	if velocity.x != 0:
		anim.flip_h = velocity.x < 0

	if velocity.x != 0:
		anim.flip_h = velocity.x < 0
	
func is_water_tile(pos: Vector2i) -> bool:
	var td := tilemap.get_cell_tile_data(pos)
	if td == null:
		return true
	return td.get_terrain() == TERRAIN_WATER
