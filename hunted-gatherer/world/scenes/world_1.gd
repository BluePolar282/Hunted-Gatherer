extends Node2D

@export var map_width: int = 80
@export var map_height: int = 60
@export var noise_scale: float = 0.04
@export var island_falloff: float = 2.5

@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var map_overlay = $CanvasLayer/MapOverlay
@onready var map_display = $CanvasLayer/MapOverlay/MapDisplay

const TERRAIN_SET = 0   # the terrain set both terrains live in
const TERRAIN_GRASS = 0 # terrain index for grass
const TERRAIN_WATER = 1 # terrain index for water

var grass_cells: Array[Vector2i] = []
var map_texture: ImageTexture = null
var water_cells: Array[Vector2i] = []
var spawn_tile: Vector2i = Vector2i.ZERO

const LAND_THRESHOLD = 0.0  # noise values above this = grass, below = water

func _ready() -> void:
	map_overlay.visible = false
	generate()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		tilemap.clear()
		generate()

	# Hold to peek at map
	if event.is_action_pressed("map"):
		show_map()
	if event.is_action_released("map"):
		map_overlay.visible = false

func generate() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = randi()
	noise.frequency = noise_scale

	var cx := map_width  / 2.0
	var cy := map_height / 2.0

	# Instead of placing tiles one by one, we collect all positions
	# for each terrain into two lists, then place them all at once.
	# This is what lets set_cells_terrain_connect work —
	# it needs to see the whole group to figure out which edges to use.
	grass_cells = []
	water_cells = []

	for x in map_width:
		for y in map_height:
			var n: float = noise.get_noise_2d(x, y)

			var dx := (x - cx) / cx
			var dy := (y - cy) / cy
			var dist := sqrt(dx * dx + dy * dy)
			var falloff := pow(dist, 2.5) * island_falloff
			n -= falloff

			# Sort each tile position into the right list
			if n > LAND_THRESHOLD:
				grass_cells.append(Vector2i(x, y))
			else:
				water_cells.append(Vector2i(x, y))

	grass_cells = smooth(grass_cells, 6)

	# Rebuild water_cells from whatever isn't grass anymore
	var grass_set := {}
	for c in grass_cells:
		grass_set[c] = true
	water_cells = []
	for x in map_width:
		for y in map_height:
			if not grass_set.has(Vector2i(x, y)):
				water_cells.append(Vector2i(x, y))

	tilemap.set_cells_terrain_connect(grass_cells, TERRAIN_SET, TERRAIN_GRASS, true)
	tilemap.set_cells_terrain_connect(water_cells, TERRAIN_SET, TERRAIN_WATER, true)
	
	spawn_player()
	map_texture = draw_map()
	
func spawn_player() -> void:
	var cx := map_width  / 2.0
	var cy := map_height / 2.0

	var sorted := grass_cells.duplicate()
	sorted.sort_custom(func(a, b):
		var da := Vector2(a).distance_to(Vector2(cx, cy))
		var db := Vector2(b).distance_to(Vector2(cx, cy))
		return da < db
	)

	var candidates := sorted.slice(0, min(10, sorted.size()))
	var chosen: Vector2i = candidates[randi() % candidates.size()]
	spawn_tile = chosen	# save it for the map

	var world_pos := tilemap.to_global(tilemap.map_to_local(chosen))
	$caveman.global_position = world_pos
	$caveman.tilemap = tilemap
	
func smooth(cells: Array[Vector2i], passes: int = 3) -> Array[Vector2i]:
	# Puts all current land cells into a Set for fast lookup
	var cell_set := {}
	for c in cells:
		cell_set[c] = true

	for _p in passes:
		var to_add: Array[Vector2i] = []
		var to_remove: Array[Vector2i] = []

		for c in cell_set.keys():
			var neighbors := [
				Vector2i(c.x + 1, c.y),
				Vector2i(c.x - 1, c.y),
				Vector2i(c.x, c.y + 1),
				Vector2i(c.x, c.y - 1),
			]

			var land_neighbors := 0
			for n in neighbors:
				if cell_set.has(n):
					land_neighbors += 1

			# A land tile with fewer than 2 land neighbors is isolated — remove it
			if land_neighbors < 2:
				to_remove.append(c)

		# Also fill water tiles that are surrounded by land on 3+ sides
		for x in map_width:
			for y in map_height:
				var c := Vector2i(x, y)
				if cell_set.has(c):
					continue
				var neighbors := [
					Vector2i(x + 1, y),
					Vector2i(x - 1, y),
					Vector2i(x, y + 1),
					Vector2i(x, y - 1),
				]
				var land_neighbors := 0
				for n in neighbors:
					if cell_set.has(n):
						land_neighbors += 1
				if land_neighbors >= 3:
					to_add.append(c)

		for c in to_remove:
			cell_set.erase(c)
		for c in to_add:
			cell_set[c] = true

	# Convert back to array
	var result: Array[Vector2i] = []
	for c in cell_set.keys():
		result.append(c)
	return result

#------------------------------------------------

func show_map() -> void:
	map_display.texture = map_texture
	map_overlay.visible = true

func draw_map() -> ImageTexture:
	var img := Image.create(map_width, map_height, false, Image.FORMAT_RGBA8)

	var grass_set := {}
	for c in grass_cells:
		grass_set[c] = true

	var color_land  := Color(0.85, 0.80, 0.60)
	var color_water := Color(0.15, 0.20, 0.30)
	var color_shore := Color(0.65, 0.60, 0.40)

	for x in map_width:
		for y in map_height:
			var pos := Vector2i(x, y)
			if grass_set.has(pos):
				var is_shore := false
				for neighbor in [
					Vector2i(x+1, y), Vector2i(x-1, y),
					Vector2i(x, y+1), Vector2i(x, y-1)
				]:
					if not grass_set.has(neighbor):
						is_shore = true
						break
				if is_shore:
					img.set_pixel(x, y, color_shore)
				else:
					img.set_pixel(x, y, color_land)
			else:
				img.set_pixel(x, y, color_water)
				
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var px := spawn_tile.x + dx
			var py := spawn_tile.y + dy
			if px >= 0 and px < map_width and py >= 0 and py < map_height:
				img.set_pixel(px, py, Color(0.448, 0.617, 0.352, 1.0))

	return ImageTexture.create_from_image(img)
