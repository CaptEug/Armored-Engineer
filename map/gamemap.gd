class_name GameMap
extends Node2D

const MAP_VERSION := 0
const MAP_CHUNK_SIZE := 32
const MAP_FILE_NAME := "terrain.map"

const DEEP_OCEAN_MAX_ELEVATION := -0.28
const SHALLOW_WATER_MAX_ELEVATION := -0.08
const SAND_GROUND_MAX_ELEVATION := 0.08
const CONTINENT_CENTER_ELEVATION := 0.58
const CONTINENT_EDGE_FALLOFF := 1.05
const ELEVATION_NOISE_STRENGTH := 0.55

const NATURAL_GENERATION_RULES := [
	{
		"block_name": "Hematite",
		"minimum": 0.2,
		"maximum": 0.3,
	},
	{
		"block_name": "Sandstone",
		"minimum": 0.0,
		"maximum": 0.5,
	},
]

@onready var ground: GroundLayer = $GroundLayer
@onready var world_blocks: WorldBlockLayer = $WorldBlockLayer
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var vehicle_root := $VehicleRoot

@export var minimap: MiniMap
var layers: Dictionary[String, TileMapLayer]
var world_seed: String
var world_height := 256
var world_width := 256

var world_bounds: Rect2i:
	get:
		return Rect2i(
			Vector2i(-world_width / 2, -world_height / 2),
			Vector2i(world_width, world_height)
		)


func _ready() -> void:
	layers = {
		"terrain": ground,
		"blocks": world_blocks,
	}
	for validation_error: String in (
		BlockDB.validate_database(world_blocks.tile_set)
	):
		push_error(validation_error)
	for validation_error: String in (
		TerrainDB.validate_database(ground.tile_set)
	):
		push_error(validation_error)
	print("=== 游戏地图初始化完成 ===")


func generate_world() -> void:
	var natural_rules := _resolve_natural_generation_rules(
		NATURAL_GENERATION_RULES
	)
	if natural_rules.size() != NATURAL_GENERATION_RULES.size():
		push_error(
			"World generation stopped because its block rules are invalid."
		)
		return
	for terrain_id: int in [
		TerrainDB.DEEP_OCEAN,
		TerrainDB.SHALLOW_WATER,
		TerrainDB.SAND_GROUND,
		TerrainDB.SANDSTONE_GROUND,
	]:
		if not ground.terrain_tiles.has(terrain_id):
			push_error(
				"World generation terrain has no TileSet visual: %s."
				% TerrainDB.get_terrain_name(terrain_id)
			)
			return

	ground.clear()
	var elevation_noise := FastNoiseLite.new()
	elevation_noise.seed = hash(world_seed)
	elevation_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	elevation_noise.frequency = 0.012
	var resource_noise := FastNoiseLite.new()
	resource_noise.seed = hash(world_seed + ":resources")
	resource_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	resource_noise.frequency = 0.035

	world_blocks.begin_bulk_edit()
	var bounds := world_bounds
	for x in range(bounds.position.x, bounds.end.x):
		for y in range(bounds.position.y, bounds.end.y):
			var cell := Vector2i(x, y)
			var elevation := _get_elevation(cell, elevation_noise)
			var terrain_id := _select_terrain(elevation)
			ground.place_terrain(cell, terrain_id)
			if terrain_id != TerrainDB.SANDSTONE_GROUND:
				continue
			var resource_value := resource_noise.get_noise_2d(x, y)
			var natural_block_id := _select_generation_block(
				resource_value,
				natural_rules
			)
			if natural_block_id != BlockDB.INVALID_BLOCK_ID:
				world_blocks.place_block(natural_block_id, cell)
	world_blocks.end_bulk_edit()

	var structure_result := StructureGenerator.generate_default_structures(
		self
	)
	if not structure_result["ok"]:
		push_warning(structure_result["error"])
	if is_instance_valid(minimap):
		minimap.map_renderer.loadmap()
		minimap.map_renderer.queue_redraw()


func _get_elevation(cell: Vector2i, noise: FastNoiseLite) -> float:
	var half_size := Vector2(world_width, world_height) * 0.5
	var center := Vector2(world_bounds.position) + half_size
	var normalized := (Vector2(cell) + Vector2(0.5, 0.5) - center)
	normalized /= half_size
	var edge_distance := maxf(absf(normalized.x), absf(normalized.y))
	var continent_height := (
		CONTINENT_CENTER_ELEVATION
		- edge_distance * CONTINENT_EDGE_FALLOFF
	)
	return (
		continent_height
		+ noise.get_noise_2d(cell.x, cell.y) * ELEVATION_NOISE_STRENGTH
	)


func _select_terrain(elevation: float) -> int:
	if elevation <= DEEP_OCEAN_MAX_ELEVATION:
		return TerrainDB.DEEP_OCEAN
	if elevation <= SHALLOW_WATER_MAX_ELEVATION:
		return TerrainDB.SHALLOW_WATER
	if elevation <= SAND_GROUND_MAX_ELEVATION:
		return TerrainDB.SAND_GROUND
	return TerrainDB.SANDSTONE_GROUND


func is_cell_in_world(cell: Vector2i) -> bool:
	return world_bounds.has_point(cell)


func get_chunk_world_origin(
	chunk_x: int,
	chunk_y: int,
	chunk_size: int = MAP_CHUNK_SIZE
) -> Vector2i:
	return world_bounds.position + Vector2i(
		chunk_x * chunk_size,
		chunk_y * chunk_size
	)


func _resolve_natural_generation_rules(
	definitions: Array
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition: Dictionary in definitions:
		var block_name := str(definition.get("block_name", ""))
		var block_id := BlockDB.get_id_for_name(block_name)
		var minimum := float(definition.get("minimum", 0.0))
		var maximum := float(definition.get("maximum", 0.0))
		if (
			block_id == BlockDB.INVALID_BLOCK_ID
			or not BlockDB.is_natural(block_id)
			or not BlockDB.can_place_on(block_id, BlockDB.HOST_WORLD)
		):
			push_error(
				"Generation block %s is missing or is not natural."
				% block_name
			)
			return []
		if minimum >= maximum:
			push_error(
				"Invalid generation range for %s: %s to %s."
				% [block_name, minimum, maximum]
			)
			return []
		result.append({
			"block_id": block_id,
			"minimum": minimum,
			"maximum": maximum,
		})
	return result


func _select_generation_block(
	noise_value: float,
	rules: Array[Dictionary]
) -> int:
	for rule: Dictionary in rules:
		if (
			noise_value > float(rule["minimum"])
			and noise_value <= float(rule["maximum"])
		):
			return int(rule["block_id"])
	return BlockDB.INVALID_BLOCK_ID


func save_map(world_folder: String) -> bool:
	assert(world_width % MAP_CHUNK_SIZE == 0)
	assert(world_height % MAP_CHUNK_SIZE == 0)
	var chunks_x := world_width / MAP_CHUNK_SIZE
	var chunks_y := world_height / MAP_CHUNK_SIZE
	var file := FileAccess.open(
		world_folder + MAP_FILE_NAME,
		FileAccess.WRITE
	)
	if file == null:
		push_error("Failed to open world map for saving")
		return false
	file.store_buffer("MAP0".to_ascii_buffer())
	file.store_16(MAP_VERSION)
	file.store_16(world_width)
	file.store_16(world_height)
	file.store_8(MAP_CHUNK_SIZE)
	file.store_16(layers.size())
	for layer_name: String in layers:
		var layer: TileMapLayer = layers[layer_name]
		file.store_8(layer_name.length())
		file.store_buffer(layer_name.to_ascii_buffer())
		file.store_32(chunks_x * chunks_y)
		for chunk_y in range(chunks_y):
			for chunk_x in range(chunks_x):
				var bytes: PackedByteArray = layer.call(
					"save_chunk",
					chunk_x,
					chunk_y,
					world_bounds.position
				)
				file.store_16(chunk_x)
				file.store_16(chunk_y)
				file.store_32(bytes.size())
				file.store_buffer(bytes)
	file.close()
	print("Terrain save complete")
	return true


func load_map(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open world file")
		return false
	var magic := file.get_buffer(4).get_string_from_ascii()
	if magic != "MAP0":
		push_error("Invalid world file")
		file.close()
		return false
	var version := file.get_16()
	if version != MAP_VERSION:
		push_error(
			"Unsupported world file version %d; expected %d."
			% [version, MAP_VERSION]
		)
		file.close()
		return false
	world_width = file.get_16()
	world_height = file.get_16()
	var chunk_size := file.get_8()
	var layer_count := file.get_16()
	ground.clear()
	world_blocks.begin_bulk_edit()
	for _layer_index in range(layer_count):
		var name_length := file.get_8()
		var layer_name := file.get_buffer(
			name_length
		).get_string_from_ascii()
		var chunk_count := file.get_32()
		var layer: TileMapLayer = layers.get(layer_name)
		if layer == null:
			push_warning("Unknown layer: %s" % layer_name)
			_skip_layer_chunks(file, chunk_count)
			continue
		for _chunk_index in range(chunk_count):
			var chunk_x := file.get_16()
			var chunk_y := file.get_16()
			var data_size := file.get_32()
			var bytes := file.get_buffer(data_size)
			layer.call(
				"load_chunk",
				chunk_x,
				chunk_y,
				bytes,
				chunk_size,
				world_bounds.position
			)
	world_blocks.end_bulk_edit()
	file.close()
	if is_instance_valid(minimap):
		minimap.map_renderer.loadmap()
		minimap.map_renderer.queue_redraw()
	return true


func _skip_layer_chunks(file: FileAccess, chunk_count: int) -> void:
	for _chunk_index in range(chunk_count):
		file.get_16()
		file.get_16()
		var data_size := file.get_32()
		file.seek(file.get_position() + data_size)
