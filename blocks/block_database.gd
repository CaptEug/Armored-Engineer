extends Node

const INVALID_BLOCK_ID := -1
const CLASS_NATURAL := "natural"
const CLASS_CONSTRUCTED := "constructed"
const HOST_WORLD := "world"
const HOST_VEHICLE := "vehicle"
const INFO_GENERIC := "res://ui/block_info/block_info_section.tscn"
const INFO_STORAGE := "res://ui/block_info/storage_info.tscn"
const INFO_WEAPON := "res://ui/block_info/weapon_info.tscn"
const INFO_CONTROL := "res://ui/block_info/control_info.tscn"
const INFO_DRILL := "res://ui/block_info/drill_info.tscn"
const INFO_VEHICLE_BAY := "res://ui/block_info/vehiclebay_info.tscn"
const INFO_TURRET_MOUNT := "res://ui/block_info/turret_mount_info.tscn"
const ARMOR_BLOCK_ID := 16
const ARMOR_ITEM_NAME := "RHA"
const ARMOR_KINETIC_MULTIPLIER := 0.35
const ARMOR_EXPLOSIVE_MULTIPLIER := 0.65

# Integer block IDs are the compact runtime/save identity. block_name is the
# stable String identity used by developer-authored data.
var blocks := {
	1: {
		"block_name": "Structural Frame",
		"block_class": CLASS_CONSTRUCTED,
		"allowed_hosts": [HOST_VEHICLE],
		"scene_path": "res://blocks/structural/structural_frame.tscn",
		"info_section_path": INFO_GENERIC,
		"world_functional": false,
		"size": Vector2i(1, 1),
		"rotatable": false,
		"max_hp": 50.0,
		"mass": 1.0,
		"kinetic_damage_multiplier": 1.0,
		"explosive_damage_multiplier": 1.0,
		"color": Color(0.52, 0.57, 0.61),
		"construction_cost": {
			"metal": 1,
		},
	},
	2: {
		"block_name": "Liquid Container",
		"block_class": CLASS_CONSTRUCTED,
		"allowed_hosts": [HOST_WORLD, HOST_VEHICLE],
		"scene_path": "res://blocks/logistic/liquid_tank.tscn",
		"info_section_path": INFO_STORAGE,
		"world_functional": true,
		"size": Vector2i(1, 1),
		"rotatable": true,
		"max_hp": 100.0,
		"mass": 1.0,
		"kinetic_damage_multiplier": 1.0,
		"explosive_damage_multiplier": 1.0,
		"color": Color(0.18, 0.58, 0.72),
		"construction_cost": {},
	},
	3: {
		"block_name": "Cargo Container",
		"block_class": CLASS_CONSTRUCTED,
		"allowed_hosts": [HOST_WORLD, HOST_VEHICLE],
		"scene_path": "res://blocks/logistic/cargo_box.tscn",
		"info_section_path": INFO_STORAGE,
		"world_functional": true,
		"size": Vector2i(1, 1),
		"rotatable": true,
		"max_hp": 100.0,
		"mass": 1.0,
		"kinetic_damage_multiplier": 1.0,
		"explosive_damage_multiplier": 1.0,
		"color": Color(0.68, 0.49, 0.25),
		"construction_cost": {},
	},
	4: {
		"block_name": "V2 Engine",
		"block_class": CLASS_CONSTRUCTED,
		"allowed_hosts": [HOST_WORLD, HOST_VEHICLE],
		"scene_path": "res://blocks/mobility/powerpack/v_2.tscn",
		"info_section_path": INFO_GENERIC,
		"world_functional": true,
		"size": Vector2i(1, 2),
		"rotatable": true,
		"max_hp": 100.0,
		"mass": 1.0,
		"kinetic_damage_multiplier": 1.0,
		"explosive_damage_multiplier": 1.0,
		"color": Color(0.91, 0.34, 0.12),
		"construction_cost": {},
	},
	5: {
		"block_name": "Metal Track",
		"block_class": CLASS_CONSTRUCTED,
		"allowed_hosts": [HOST_VEHICLE],
		"scene_path": "res://blocks/mobility/track/metal_track.tscn",
		"info_section_path": INFO_GENERIC,
		"world_functional": false,
		"size": Vector2i(1, 1),
		"rotatable": true,
		"max_hp": 100.0,
		"mass": 1.0,
		"kinetic_damage_multiplier": 1.0,
		"explosive_damage_multiplier": 1.0,
		"color": Color(0.28, 0.31, 0.34),
		"construction_cost": {},
	},
	6: {
		"block_name": "8.8 cm KwK 43 L/71",
		"block_class": CLASS_CONSTRUCTED,
		"allowed_hosts": [HOST_WORLD, HOST_VEHICLE],
		"scene_path": "res://blocks/weapon/KwK_43.tscn",
		"info_section_path": INFO_WEAPON,
		"world_functional": true,
		"size": Vector2i(1, 8),
		"rotatable": true,
		"max_hp": 100.0,
		"mass": 1.0,
		"kinetic_damage_multiplier": 1.0,
		"explosive_damage_multiplier": 1.0,
		"color": Color(0.78, 0.13, 0.10),
		"construction_cost": {},
	},
	7: {
		"block_name": "Dump Container",
		"block_class": CLASS_CONSTRUCTED,
		"allowed_hosts": [HOST_WORLD, HOST_VEHICLE],
		"scene_path": "res://blocks/logistic/dump_container.tscn",
		"info_section_path": INFO_STORAGE,
		"world_functional": true,
		"size": Vector2i(1, 1),
		"rotatable": true,
		"max_hp": 100.0,
		"mass": 1.0,
		"kinetic_damage_multiplier": 1.0,
		"explosive_damage_multiplier": 1.0,
		"color": Color(0.50, 0.34, 0.20),
		"construction_cost": {},
	},
	8: {
		"block_name": "Manual Cockpit",
		"block_class": CLASS_CONSTRUCTED,
		"allowed_hosts": [HOST_WORLD, HOST_VEHICLE],
		"scene_path": "res://blocks/control/manual_cockpit.tscn",
		"info_section_path": INFO_CONTROL,
		"world_functional": true,
		"size": Vector2i(1, 1),
		"rotatable": true,
		"max_hp": 100.0,
		"mass": 1.0,
		"kinetic_damage_multiplier": 1.0,
		"explosive_damage_multiplier": 1.0,
		"color": Color(1.0, 0.67, 0.12),
		"construction_cost": {},
	},
	9: {
		"block_name": "Sandstone",
		"block_class": CLASS_NATURAL,
		"allowed_hosts": [HOST_WORLD],
		"scene_path": "res://blocks/natural/sandstone.tscn",
		"info_section_path": INFO_GENERIC,
		"world_functional": false,
		"size": Vector2i(1, 1),
		"rotatable": false,
		"max_hp": 100.0,
		"mass": 100.0,
		"kinetic_damage_multiplier": 1.0,
		"explosive_damage_multiplier": 1.0,
		"mining_yield": "sandstone",
		"color": Color(0.361, 0.137, 0.114),
		"particle_path": "res://assets/particles/sandstone_shard.tscn",
		"construction_cost": {},
	},
	10: {
		"block_name": "Hematite",
		"block_class": CLASS_NATURAL,
		"allowed_hosts": [HOST_WORLD],
		"scene_path": "res://blocks/natural/hematite.tscn",
		"info_section_path": INFO_GENERIC,
		"world_functional": false,
		"size": Vector2i(1, 1),
		"rotatable": false,
		"max_hp": 200.0,
		"mass": 100.0,
		"kinetic_damage_multiplier": 1.0,
		"explosive_damage_multiplier": 0.5,
		"mining_yield": "hematite",
		"color": Color.LIGHT_STEEL_BLUE,
		"particle_path": "res://assets/particles/sandstone_shard.tscn",
		"construction_cost": {},
	},
	11: {
		"block_name": "Crude Oil",
		"phase": "liquid",
		"info_section_path": INFO_GENERIC,
		"mass": 1000.0,
		"mining_yield": "crude_oil",
		"color": Color(0.149, 0.078, 0.310),
	},
	12: {
		"block_name": "Sandstone Ground",
		"phase": "ground",
		"info_section_path": INFO_GENERIC,
		"color": Color(0.533, 0.251, 0.176),
	},
	13: {
		"block_name": "Drill",
		"block_class": CLASS_CONSTRUCTED,
		"allowed_hosts": [HOST_VEHICLE],
		"scene_path": "res://blocks/industrial/drill.tscn",
		"info_section_path": INFO_DRILL,
		"world_functional": false,
		"size": Vector2i(2, 3),
		"rotatable": true,
		"max_hp": 100.0,
		"mass": 1.0,
		"kinetic_damage_multiplier": 1.0,
		"explosive_damage_multiplier": 1.0,
		"color": Color(0.78, 0.58, 0.16),
		"construction_cost": {},
	},
	14: {
		"block_name": "Vehicle Bay",
		"block_class": CLASS_CONSTRUCTED,
		"allowed_hosts": [HOST_WORLD],
		"scene_path": "res://blocks/structural/vehicle_bay.tscn",
		"info_section_path": INFO_VEHICLE_BAY,
		"world_functional": true,
		"size": Vector2i(2, 2),
		"rotatable": false,
		"max_hp": 100.0,
		"mass": 1.0,
		"kinetic_damage_multiplier": 0.0,
		"explosive_damage_multiplier": 1.0,
		"color": Color(0.24, 0.52, 0.58),
		"construction_cost": {},
	},
	15: {
		"block_name": "3x3 Turret Mount",
		"block_class": CLASS_CONSTRUCTED,
		"allowed_hosts": [HOST_WORLD, HOST_VEHICLE],
		"scene_path": "res://blocks/structural/turret_mount.tscn",
		"info_section_path": INFO_TURRET_MOUNT,
		"world_functional": true,
		"size": Vector2i(3, 3),
		"rotatable": true,
		"max_hp": 300.0,
		"mass": 15.0,
		"kinetic_damage_multiplier": 1.0,
		"explosive_damage_multiplier": 1.0,
		"color": Color(0.34, 0.36, 0.39),
		"construction_cost": {},
	},
	ARMOR_BLOCK_ID: {
		"block_name": "RHA Armor",
		"block_class": CLASS_CONSTRUCTED,
		"allowed_hosts": [HOST_VEHICLE],
		"scene_path": "res://blocks/structural/armor.tscn",
		"info_section_path": INFO_GENERIC,
		"world_functional": false,
		"size": Vector2i(1, 1),
		"rotatable": false,
		"max_hp": 150.0,
		"mass": 2.0,
		"kinetic_damage_multiplier": ARMOR_KINETIC_MULTIPLIER,
		"explosive_damage_multiplier": ARMOR_EXPLOSIVE_MULTIPLIER,
		"color": Color(0.38, 0.41, 0.44),
		"construction_cost": {ARMOR_ITEM_NAME: 1},
	},
}

var _name_to_id: Dictionary = {}
var _scene_to_id: Dictionary = {}
var _scene_cache: Dictionary = {}
var _info_section_cache: Dictionary = {}
var _indexes_ready := false


func _ready() -> void:
	rebuild_indexes()


func rebuild_indexes() -> void:
	_name_to_id.clear()
	_scene_to_id.clear()
	_scene_cache.clear()
	_info_section_cache.clear()
	for block_id: int in blocks:
		var definition: Dictionary = blocks[block_id]
		var block_name := str(definition.get("block_name", ""))
		if not block_name.is_empty():
			_name_to_id[block_name] = block_id
		var scene_path := str(definition.get("scene_path", ""))
		if not scene_path.is_empty():
			_scene_to_id[scene_path] = block_id
	_indexes_ready = true


func _ensure_indexes() -> void:
	if not _indexes_ready:
		rebuild_indexes()


func get_block(block_id: int) -> Dictionary:
	return blocks.get(block_id, {})


func get_block_by_name(block_name: String) -> Dictionary:
	return get_block(get_id_for_name(block_name))


func has_block(block_id: int) -> bool:
	return blocks.has(block_id)


func get_scene(block_id: int) -> PackedScene:
	_ensure_indexes()
	if _scene_cache.has(block_id):
		return _scene_cache[block_id] as PackedScene
	var scene_path := str(get_block(block_id).get("scene_path", ""))
	if scene_path.is_empty():
		return null
	var scene := load(scene_path) as PackedScene
	_scene_cache[block_id] = scene
	return scene


func get_info_section_scene(block_id: int) -> PackedScene:
	var scene_path := str(
		get_block(block_id).get("info_section_path", INFO_GENERIC)
	)
	if scene_path.is_empty():
		return null
	if _info_section_cache.has(scene_path):
		return _info_section_cache[scene_path] as PackedScene
	var scene := load(scene_path) as PackedScene
	_info_section_cache[scene_path] = scene
	return scene


func get_block_name(block_id: int) -> String:
	return str(get_block(block_id).get("block_name", "unknown_block"))


func get_color(block_id: int) -> Color:
	return get_block(block_id).get("color", Color.MAGENTA)


func get_id_for_scene(scene_path: String) -> int:
	_ensure_indexes()
	return int(_scene_to_id.get(scene_path, INVALID_BLOCK_ID))


func get_id_for_name(block_name: String) -> int:
	_ensure_indexes()
	return int(_name_to_id.get(block_name, INVALID_BLOCK_ID))


func get_construction_cost(block_id: int) -> Dictionary:
	return get_block(block_id).get("construction_cost", {}).duplicate(true)


func is_armor_block(block_id: int) -> bool:
	return block_id == ARMOR_BLOCK_ID


func get_armor_damage_multiplier(damage_type: StringName) -> float:
	match String(damage_type).to_upper():
		"KINETIC":
			return ARMOR_KINETIC_MULTIPLIER
		"EXPLOSIVE":
			return ARMOR_EXPLOSIVE_MULTIPLIER
	return 1.0


func get_construction_cost_for_scene(scene_path: String) -> Dictionary:
	return get_construction_cost(get_id_for_scene(scene_path))


func get_mining_yield(block_id: int) -> String:
	return str(get_block(block_id).get("mining_yield", ""))


func can_place_on(block_id: int, host_name: String) -> bool:
	return get_block(block_id).get("allowed_hosts", []).has(host_name)


func is_constructed(block_id: int) -> bool:
	return get_block(block_id).get("block_class", "") == CLASS_CONSTRUCTED


func is_natural(block_id: int) -> bool:
	return get_block(block_id).get("block_class", "") == CLASS_NATURAL


func is_world_functional(block_id: int) -> bool:
	return bool(get_block(block_id).get("world_functional", false))


func is_liquid(block_id: int) -> bool:
	return get_block(block_id).get("phase", "") == "liquid"


func is_ground(block_id: int) -> bool:
	return get_block(block_id).get("phase", "") == "ground"


func get_default_liquid_mass(block_id: int) -> float:
	if not is_liquid(block_id):
		return 0.0
	return maxf(float(get_block(block_id).get("mass", 0.0)), 0.0)


func is_rotatable(block_id: int) -> bool:
	return bool(get_block(block_id).get("rotatable", false))


func normalize_rotation(block_id: int, rotation_index: int) -> int:
	if not is_rotatable(block_id):
		return 0
	return wrapi(rotation_index, 0, 4)


func get_size(block_id: int) -> Vector2i:
	return get_block(block_id).get("size", Vector2i.ONE)


func get_max_hp(block_id: int) -> float:
	return maxf(float(get_block(block_id).get("max_hp", 0.0)), 0.0)


func get_damage_multiplier(block_id: int, damage_type: StringName) -> float:
	var key := ""
	match String(damage_type).to_upper():
		"KINETIC":
			key = "kinetic_damage_multiplier"
		"EXPLOSIVE":
			key = "explosive_damage_multiplier"
		_:
			return 1.0
	return maxf(float(get_block(block_id).get(key, 1.0)), 0.0)


func validate_database(tile_set: TileSet = null) -> PackedStringArray:
	rebuild_indexes()
	var errors := PackedStringArray()
	var names := {}
	for block_id: int in blocks:
		var definition: Dictionary = blocks[block_id]
		var block_name := str(definition.get("block_name", ""))
		if block_name.is_empty():
			errors.append("Block ID %d has no block_name." % block_id)
		elif names.has(block_name):
			errors.append("Duplicate block_name: %s." % block_name)
		else:
			names[block_name] = block_id
		if not definition.get("color", null) is Color:
			errors.append("Block %s has no valid color." % block_name)
		var info_section_path := str(
			definition.get("info_section_path", "")
		)
		if info_section_path.is_empty():
			errors.append(
				"Block %s has no information section." % block_name
			)
		elif not ResourceLoader.exists(info_section_path):
			errors.append(
				"Block %s has missing information section %s."
				% [block_name, info_section_path]
			)
		if is_liquid(block_id):
			if get_default_liquid_mass(block_id) <= 0.0:
				errors.append(
					"Liquid block %s has invalid mass." % block_name
				)
			if not BlockVisualSystem.has_block_tile_visual(block_id):
				errors.append(
					"Liquid block %s has no TileSet block_id visual."
					% block_name
				)
			continue
		if is_ground(block_id):
			if not BlockVisualSystem.has_block_tile_visual(block_id):
				errors.append(
					"Ground block %s has no TileSet block_id visual."
					% block_name
				)
			continue
		if float(definition.get("max_hp", 0.0)) <= 0.0:
			errors.append("Block %s has invalid max_hp." % block_name)
		var scene_path := str(definition.get("scene_path", ""))
		if scene_path.is_empty():
			errors.append("Block %s has no scene file." % block_name)
		elif not ResourceLoader.exists(scene_path):
			errors.append("Block %s has missing scene %s." % [
				block_name,
				scene_path,
			])
		if (
			not bool(definition.get("world_functional", false))
			and definition.get("allowed_hosts", []).has(HOST_WORLD)
			and not BlockVisualSystem.has_block_tile_visual(block_id)
		):
			errors.append(
				"Passive world block %s has no TileSet block_id visual."
				% block_name
			)
	return errors
