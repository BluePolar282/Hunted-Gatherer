extends Node2D

# --- Settings (tweakable in Inspector) ---
@export var map_width:      int   = 80
@export var map_height:     int   = 60
@export var noise_scale:    float = 0.025
@export var island_falloff: float = 2.0
@export var foliage_sheet:  Texture2D
@export var tile_size:      int   = 16

# --- Node refs ---
@onready var tilemap    := $TileMapLayer
@onready var foliage    := $Foliage
@onready var player     := $caveman
@onready var map_overlay := $CanvasLayer/MapOverlay
@onready var map_display := $CanvasLayer/MapOverlay/MapDisplay

# --- Terrain indices (match your TileSet setup) ---
const TERRAIN_SET  = 0
const TERRAIN_GRASS = 0

# --- Shared state ---
var grass_cells: Array[Vector2i] = []
var spawn_tile:  Vector2i        = Vector2i.ZERO
var map_texture: ImageTexture    = null

# --- Foliage definitions ---
# atlas_col, atlas_row: top-left tile on spritesheet
# width, height: size in tiles
# density: spawn chance per grass tile (0.0-1.0)
# avoid_shore: skip edge tiles
# offset_y: vertical nudge in pixels
var foliage_types := [
	{ "name":"tree_small",  "atlas_col":15,  "atlas_row":0, "width":5, "height":5, "density":0.04, "avoid_shore":true,  "offset_y":-24.0 },
	{ "name":"tree_medium", "atlas_col":10, "atlas_row":0, "width":5, "height":5, "density":0.03, "avoid_shore":true,  "offset_y":-24.0 },
	{ "name":"grass_tuft",  "atlas_col":5,  "atlas_row":2, "width":1, "height":1, "density":0.1, "avoid_shore":false, "offset_y":0.0   },
	{ "name":"rock",        "atlas_col":8,  "atlas_row":4, "width":2, "height":1, "density":0.02, "avoid_shore":false, "offset_y":0.0   },
]

# ================================================
func _ready() -> void:
	map_overlay.visible = false
	generate()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		generate()
	if event.is_action_pressed("map"):
		map_display.texture = map_texture
		map_display.size = Vector2(400, 400)
		map_display.position = get_viewport().get_visible_rect().size / 2.0 - map_display.size / 2.0
		map_overlay.visible = true
	if event.is_action_released("map"):
		map_overlay.visible = false

# ================================================
func generate() -> void:
	tilemap.clear()
	grass_cells.clear()
	for child in foliage.get_children():
		child.queue_free()

	# --- Noise ---
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = randi()
	noise.frequency = noise_scale

	var cx := float(map_width)  / 2.0
	var cy := float(map_height) / 2.0

	# --- Build grass cell list ---
	for x in map_width:
		for y in map_height:
			var n: float = noise.get_noise_2d(x, y)
			var dx: float = (float(x) - cx) / cx
			var dy: float = (float(y) - cy) / cy
			var dist: float = sqrt(dx * dx + dy * dy)
			n -= pow(dist, 2.5) * island_falloff
			if n > 0.0:
				grass_cells.append(Vector2i(x, y))

	# --- Smooth ---
	grass_cells = _smooth(grass_cells, 6)

	# --- Place terrain ---
	tilemap.set_cells_terrain_connect(grass_cells, TERRAIN_SET, TERRAIN_GRASS, true)

	# --- Rest ---
	_spawn_player()
	_scatter_foliage()
	map_texture = _draw_map()

# ================================================
func _smooth(cells: Array[Vector2i], passes: int) -> Array[Vector2i]:
	var cell_set: Dictionary = {}
	for c in cells:
		cell_set[c] = true

	for _p in passes:
		var to_add:    Array[Vector2i] = []
		var to_remove: Array[Vector2i] = []

		for c in cell_set.keys():
			var count := 0
			for nb in [Vector2i(c.x+1,c.y), Vector2i(c.x-1,c.y), Vector2i(c.x,c.y+1), Vector2i(c.x,c.y-1)]:
				if cell_set.has(nb):
					count += 1
			if count < 2:
				to_remove.append(c)

		for x in map_width:
			for y in map_height:
				var c := Vector2i(x, y)
				if cell_set.has(c):
					continue
				var count := 0
				for nb in [Vector2i(x+1,y), Vector2i(x-1,y), Vector2i(x,y+1), Vector2i(x,y-1)]:
					if cell_set.has(nb):
						count += 1
				if count >= 3:
					to_add.append(c)

		for c in to_remove:
			cell_set.erase(c)
		for c in to_add:
			cell_set[c] = true

	var result: Array[Vector2i] = []
	for c in cell_set.keys():
		result.append(c)
	return result

# ================================================
func _spawn_player() -> void:
	var cx := float(map_width)  / 2.0
	var cy := float(map_height) / 2.0

	var sorted: Array[Vector2i] = grass_cells.duplicate()
	sorted.sort_custom(func(a, b):
		return Vector2(a).distance_to(Vector2(cx, cy)) < Vector2(b).distance_to(Vector2(cx, cy))
	)

	var candidates: Array[Vector2i] = sorted.slice(0, min(10, sorted.size()))
	spawn_tile = candidates[randi() % candidates.size()]

	player.global_position = tilemap.to_global(tilemap.map_to_local(spawn_tile))
	player.tilemap = tilemap

# ================================================
func _scatter_foliage() -> void:
	var grass_set: Dictionary = {}
	for c in grass_cells:
		grass_set[c] = true

	for c in grass_cells:
		var is_shore := false
		for nb in [Vector2i(c.x+1,c.y), Vector2i(c.x-1,c.y), Vector2i(c.x,c.y+1), Vector2i(c.x,c.y-1)]:
			if not grass_set.has(nb):
				is_shore = true
				break

		for obj in foliage_types:
			if obj["avoid_shore"] and is_shore:
				continue
			if randf() < obj["density"]:
				var sprite := Sprite2D.new()
				sprite.texture = foliage_sheet
				sprite.region_enabled = true
				sprite.region_rect = Rect2(
					obj["atlas_col"] * tile_size,
					obj["atlas_row"] * tile_size,
					obj["width"]     * tile_size,
					obj["height"]    * tile_size
				)
				var h: int = obj["height"]
				var base_offset := float(-h * tile_size) / 2.0 + float(tile_size) / 2.0 + float(obj["offset_y"])
				var world_pos : Vector2 = tilemap.to_global(tilemap.map_to_local(c)) + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
				# Keep offset at zero — move the visual shift into position instead
				# This means the sprite origin stays at the base, which y-sort uses
				sprite.position = world_pos + Vector2(0.0, base_offset)
				sprite.position = tilemap.to_global(tilemap.map_to_local(c)) + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
				sprite.name = obj["name"]
				foliage.add_child(sprite)
				break

# ================================================
func _draw_map() -> ImageTexture:
	var img := Image.create(map_width, map_height, false, Image.FORMAT_RGBA8)
	var grass_set: Dictionary = {}
	for c in grass_cells:
		grass_set[c] = true

	for x in map_width:
		for y in map_height:
			var pos := Vector2i(x, y)
			if grass_set.has(pos):
				var shore := false
				for nb in [Vector2i(x+1,y), Vector2i(x-1,y), Vector2i(x,y+1), Vector2i(x,y-1)]:
					if not grass_set.has(nb):
						shore = true
						break
				img.set_pixel(x, y, Color(0.65, 0.60, 0.40) if shore else Color(0.85, 0.80, 0.60))
			else:
				img.set_pixel(x, y, Color(0.15, 0.20, 0.30))

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var px := spawn_tile.x + dx
			var py := spawn_tile.y + dy
			if px >= 0 and px < map_width and py >= 0 and py < map_height:
				img.set_pixel(px, py, Color(1, 0.2, 0.2))

	return ImageTexture.create_from_image(img)
