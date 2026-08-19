extends Node

const INVALID_TERRAIN_ID := -1
const DEEP_OCEAN := 1
const SHALLOW_WATER := 2
const SAND_GROUND := 3
const SANDSTONE_GROUND := 4

const SURFACE_DEEP_WATER := &"deep_water"
const SURFACE_SHALLOW_WATER := &"shallow_water"
const SURFACE_LAND := &"land"

var terrains := {
	DEEP_OCEAN: {
		"terrain_name": "Deep Ocean",
		"color": Color("123859"),
		"buildable": false,
		"surface": SURFACE_DEEP_WATER,
	},
	SHALLOW_WATER: {
		"terrain_name": "Shallow Water",
		"color": Color("287b91"),
		"buildable": false,
		"surface": SURFACE_SHALLOW_WATER,
	},
	SAND_GROUND: {
		"terrain_name": "Sand Ground",
		"color": Color("c99a5a"),
		"buildable": true,
		"surface": SURFACE_LAND,
	},
	SANDSTONE_GROUND: {
		"terrain_name": "Sandstone Ground",
		"color": Color("88402d"),
		"buildable": true,
		"surface": SURFACE_LAND,
	},
}

var _name_to_id: Dictionary = {}


func _ready() -> void:
	rebuild_indexes()


func rebuild_indexes() -> void:
	_name_to_id.clear()
	for terrain_id: int in terrains:
		var terrain_name := str(
			(terrains[terrain_id] as Dictionary).get(
				"terrain_name",
				""
			)
		)
		if not terrain_name.is_empty():
			_name_to_id[terrain_name] = terrain_id


func has_terrain(terrain_id: int) -> bool:
	return terrains.has(terrain_id)


func get_terrain(terrain_id: int) -> Dictionary:
	return terrains.get(terrain_id, {})


func get_id_for_name(terrain_name: String) -> int:
	return int(
		_name_to_id.get(terrain_name, INVALID_TERRAIN_ID)
	)


func get_terrain_name(terrain_id: int) -> String:
	return str(
		get_terrain(terrain_id).get("terrain_name", "Unknown Terrain")
	)


func get_color(terrain_id: int) -> Color:
	return get_terrain(terrain_id).get("color", Color.MAGENTA)


func is_buildable(terrain_id: int) -> bool:
	return bool(get_terrain(terrain_id).get("buildable", false))


func get_surface(terrain_id: int) -> StringName:
	return StringName(get_terrain(terrain_id).get("surface", &""))


func validate_database(tile_set: TileSet) -> PackedStringArray:
	rebuild_indexes()
	var errors := PackedStringArray()
	var names := {}
	var visual_ids := {}
	if tile_set != null:
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
				if terrain_id > 0:
					visual_ids[terrain_id] = true
	for terrain_id: int in terrains:
		var definition: Dictionary = terrains[terrain_id]
		var terrain_name := str(definition.get("terrain_name", ""))
		if terrain_name.is_empty():
			errors.append(
				"Terrain ID %d has no terrain_name." % terrain_id
			)
		elif names.has(terrain_name):
			errors.append("Duplicate terrain name: %s." % terrain_name)
		else:
			names[terrain_name] = terrain_id
		if not definition.get("color", null) is Color:
			errors.append("Terrain %s has no valid color." % terrain_name)
		if not visual_ids.has(terrain_id):
			errors.append(
				"Terrain %s has no TileSet terrain_id visual."
				% terrain_name
			)
	return errors
