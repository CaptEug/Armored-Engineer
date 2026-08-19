class_name GroundLayer
extends TileMapLayer

@onready var gamemap: GameMap = get_parent()
var terrain_tiles: Dictionary = {}


func _ready() -> void:
	build_terrain_cache()


func build_terrain_cache() -> void:
	terrain_tiles.clear()
	if tile_set == null:
		return
	for source_index in tile_set.get_source_count():
		var source_id := tile_set.get_source_id(source_index)
		var source := tile_set.get_source(
			source_id
		) as TileSetAtlasSource
		if source == null:
			continue
		for tile_index in source.get_tiles_count():
			var coordinates := source.get_tile_id(tile_index)
			var data := source.get_tile_data(coordinates, 0)
			if data == null:
				continue
			var terrain_id := int(
				data.get_custom_data("terrain_id")
			)
			if not TerrainDB.has_terrain(terrain_id):
				continue
			if not terrain_tiles.has(terrain_id):
				terrain_tiles[terrain_id] = []
			terrain_tiles[terrain_id].append({
				"source": source_id,
				"coordinates": coordinates,
			})


func place_terrain(cell: Vector2i, terrain_id: int) -> bool:
	if not TerrainDB.has_terrain(terrain_id):
		return false
	if not terrain_tiles.has(terrain_id):
		push_error(
			"No terrain variants for terrain ID %d." % terrain_id
		)
		return false
	var variants: Array = terrain_tiles[terrain_id]
	var choice: Dictionary = variants[
		_get_variant(cell, variants.size())
	]
	set_cell(
		cell,
		int(choice["source"]),
		choice["coordinates"]
	)
	return true


func _get_variant(cell: Vector2i, variant_count: int) -> int:
	return posmod(
		hash(Vector3i(cell.x, cell.y, hash(gamemap.world_seed))),
		variant_count
	)


func get_terrain_id_at(cell: Vector2i) -> int:
	var data := get_cell_tile_data(cell)
	if data == null:
		return TerrainDB.INVALID_TERRAIN_ID
	var terrain_id := int(data.get_custom_data("terrain_id"))
	return (
		terrain_id
		if TerrainDB.has_terrain(terrain_id)
		else TerrainDB.INVALID_TERRAIN_ID
	)


func get_terrain_data_at(cell: Vector2i) -> Dictionary:
	return TerrainDB.get_terrain(get_terrain_id_at(cell))


func is_buildable(cell: Vector2i) -> bool:
	return TerrainDB.is_buildable(get_terrain_id_at(cell))


func save_chunk(
	chunk_x: int,
	chunk_y: int,
	world_origin: Vector2i = Vector2i.ZERO
) -> PackedByteArray:
	const CHUNK_SIZE := GameMap.MAP_CHUNK_SIZE
	var bytes := PackedByteArray()
	bytes.resize(CHUNK_SIZE * CHUNK_SIZE * 2)
	var index := 0
	for local_y in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var cell := Vector2i(
				world_origin.x + chunk_x * CHUNK_SIZE + local_x,
				world_origin.y + chunk_y * CHUNK_SIZE + local_y
			)
			var terrain_id := get_terrain_id_at(cell)
			bytes.encode_u16(
				index,
				0
				if terrain_id == TerrainDB.INVALID_TERRAIN_ID
				else terrain_id
			)
			index += 2
	return bytes


func load_chunk(
	chunk_x: int,
	chunk_y: int,
	bytes: PackedByteArray,
	chunk_size: int,
	world_origin: Vector2i = Vector2i.ZERO
) -> void:
	_load_chunk_data(
		chunk_x,
		chunk_y,
		bytes,
		chunk_size,
		world_origin
	)


func _load_chunk_data(
	chunk_x: int,
	chunk_y: int,
	bytes: PackedByteArray,
	chunk_size: int,
	world_origin: Vector2i
) -> void:
	var expected_size := chunk_size * chunk_size * 2
	if bytes.size() < expected_size:
		push_error("Terrain chunk is truncated.")
		return
	var index := 0
	for local_y in range(chunk_size):
		for local_x in range(chunk_size):
			var terrain_id := bytes.decode_u16(index)
			index += 2
			if terrain_id <= 0:
				continue
			if not TerrainDB.has_terrain(terrain_id):
				push_error("Unknown saved terrain ID %d." % terrain_id)
				continue
			var cell := Vector2i(
				world_origin.x + chunk_x * chunk_size + local_x,
				world_origin.y + chunk_y * chunk_size + local_y
			)
			place_terrain(cell, terrain_id)
