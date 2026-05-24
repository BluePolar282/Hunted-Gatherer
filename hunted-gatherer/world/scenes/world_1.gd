extends Node2D

@export var map_width: int = 80
@export var map_height: int = 60
@export var noise_scale: float = 0.04
@export var island_falloff: float = 2.5

@onready var tilemap: TileMapLayer = $TileMapLayer

const TERRAIN_SET = 0   # the terrain set both terrains live in
const TERRAIN_GRASS = 0 # terrain index for grass
const TERRAIN_WATER = 1 # terrain index for water

const LAND_THRESHOLD = 0.0  # noise values above this = grass, below = water

func _ready() -> void:
	generate()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		tilemap.clear()
		generate()

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
	var grass_cells: Array[Vector2i] = []
	var water_cells: Array[Vector2i] = []

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
