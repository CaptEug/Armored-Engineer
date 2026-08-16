class_name Turret
extends Area2D

const TILE_SIZE := Globals.TILE_SIZE

var mount: TurretMount
var grid: Dictionary = {}
var blocks: Array[Block] = []
var total_mass := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("turrets")


func setup(turret_mount: TurretMount) -> void:
	mount = turret_mount
	position = Vector2.ZERO
	z_index = 1


func get_pivot_cells() -> Vector2:
	return Vector2(mount.size) * 0.5 if is_instance_valid(mount) else Vector2.ZERO


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local := to_local(world_position) / TILE_SIZE + get_pivot_cells()
	return Vector2i(floori(local.x), floori(local.y))


func cell_to_local_center(cell: Vector2i) -> Vector2:
	return (
		Vector2(cell) + Vector2(0.5, 0.5) - get_pivot_cells()
	) * TILE_SIZE


func get_block(cell: Vector2i) -> Block:
	return grid.get(cell, null) as Block


func get_block_id_at(cell: Vector2i) -> int:
	var block := get_block(cell)
	return block.block_id if block != null else BlockDB.INVALID_BLOCK_ID


func get_block_rotation_at(cell: Vector2i) -> int:
	var block := get_block(cell)
	return block.rotation_index if block != null else 0


func get_visual_merge_data_at(cell: Vector2i) -> Dictionary:
	var block := get_block(cell)
	if block == null:
		return {}
	return {
		"group": BlockVisualSystem.get_block_merge_group(block.block_id),
		"rotation": block.rotation_index,
	}


func get_assembly_at(_cell: Vector2i) -> BlockAssembly:
	return mount.get_assembly() if is_instance_valid(mount) else null


func can_place_block(block: Block, cell: Vector2i) -> bool:
	if (
		block == null
		or block is Track
		or block is TurretMount
		or not BlockDB.has_block(block.block_id)
		or not BlockDB.is_constructed(block.block_id)
	):
		return false
	block.origin_cell = cell
	for occupied_cell: Vector2i in block.get_occupied_cells():
		if grid.has(occupied_cell):
			return false
	var next_mass := get_total_mass() + _get_configured_block_mass(block)
	if is_instance_valid(mount) and next_mass > mount.maximum_turret_mass:
		return false
	return _block_fits_radius(block)


func place_block(
	block_scene: PackedScene,
	cell: Vector2i,
	rotation_index: int,
	block_size: Vector2i = Vector2i.ZERO,
	update_after_placement: bool = true
) -> bool:
	if block_scene == null:
		return false
	var block := block_scene.instantiate() as Block
	if block == null:
		return false
	block.block_id = BlockDB.get_id_for_scene(block_scene.resource_path)
	if block is ExpandableBlock:
		var configured_size := block.size if block_size == Vector2i.ZERO else block_size
		if not (block as ExpandableBlock).configure_union_size(configured_size):
			block.free()
			return false
	elif block_size != Vector2i.ZERO and block_size != block.size:
		block.free()
		return false
	block.update_turret_transform(self, cell, rotation_index)
	if not can_place_block(block, cell):
		block.free()
		return false
	for occupied_cell: Vector2i in block.get_occupied_cells():
		grid[occupied_cell] = block
	add_child(block)
	blocks.append(block)
	total_mass += _get_configured_block_mass(block)
	_attach_collision(block)
	refresh_block_visuals_around(block.get_occupied_cells())
	if update_after_placement:
		_notify_changed()
	return true


func destroy_block(block: Block, prune_disconnected: bool = false) -> bool:
	if block == null or not blocks.has(block):
		return false
	var removed_cells := block.get_occupied_cells()
	_remove_block(block)
	if prune_disconnected:
		var connected := _get_connected_blocks_from_attachment()
		for remaining: Block in blocks.duplicate():
			if not connected.has(remaining):
				removed_cells.append_array(remaining.get_occupied_cells())
				_remove_block(remaining)
	refresh_block_visuals_around(removed_cells)
	_notify_changed()
	return true


func get_total_mass() -> float:
	return total_mass


func get_swept_radius_tiles() -> float:
	var result := 0.0
	var pivot := get_pivot_cells()
	for block: Block in blocks:
		for cell: Vector2i in block.get_occupied_cells():
			for corner: Vector2 in [
				Vector2(cell),
				Vector2(cell) + Vector2.RIGHT,
				Vector2(cell) + Vector2.DOWN,
				Vector2(cell) + Vector2.ONE,
			]:
				result = maxf(result, corner.distance_to(pivot))
	return result


func validate_layout() -> Dictionary:
	if blocks.is_empty():
		return {"ok": true, "message": "Turret mount is empty"}
	if not _has_attachment_block():
		return {
			"ok": false,
			"message": "A turret block must cover the 3x3 mount area",
		}
	var connected := _get_connected_blocks_from_attachment()
	if connected.size() != blocks.size():
		return {
			"ok": false,
			"message": "Every turret block must connect to the mount area",
		}
	return {"ok": true, "message": "Turret layout is valid"}


func get_block_damage_state(cell: Vector2i) -> Dictionary:
	var block := get_block(cell)
	if block == null:
		return {}
	return {"block": block, "block_id": block.block_id, "hp": block.hp}


func commit_block_damage(state: Dictionary, result: Dictionary) -> void:
	var block := state.get("block") as Block
	if not is_instance_valid(block) or not blocks.has(block):
		return
	block.apply_vehicle_damage_result(result)
	if bool(result.get("destroyed", false)):
		destroy_block(block, true)


func damage_block_at(
	cell: Vector2i,
	amount: float,
	damage_type: StringName
) -> Dictionary:
	return BlockDamage.apply_to_host(self, cell, amount, damage_type)


func get_block_for_shape(shape_index: int) -> Block:
	if shape_index < 0:
		return null
	var owner_index := shape_find_owner(shape_index)
	if owner_index < 0:
		return null
	var shape_owner := shape_owner_get_owner(owner_index)
	for block: Block in blocks:
		if block.collision == shape_owner:
			return block
	return null


func capture_save_data() -> Dictionary:
	var block_records: Array = []
	var sorted_blocks: Array[Block] = blocks.duplicate()
	sorted_blocks.sort_custom(
		func(first: Block, second: Block) -> bool:
			return (
				first.origin_cell.y < second.origin_cell.y
				or (
					first.origin_cell.y == second.origin_cell.y
					and first.origin_cell.x < second.origin_cell.x
				)
			)
	)
	for block: Block in sorted_blocks:
		var health := (
			0 if block.max_hp <= 0.0
			else clampi(roundi(block.hp / block.max_hp * 65535.0), 0, 65535)
		)
		var record: Array = [
			block.block_id,
			block.origin_cell.x,
			block.origin_cell.y,
			block.rotation_index,
			health,
		]
		var extra := {}
		if block.size != BlockDB.get_size(block.block_id):
			extra["size"] = [block.size.x, block.size.y]
		var state := block.get_save_state()
		if not state.is_empty():
			extra["state"] = state
		if not extra.is_empty():
			record.append(extra)
		block_records.append(record)
	return {"rotation": rotation, "blocks": block_records}


func restore_save_data(data: Dictionary) -> bool:
	clear_blocks()
	rotation = float(data.get("rotation", 0.0))
	var records: Variant = data.get("blocks", [])
	if not records is Array:
		return false
	for value: Variant in records:
		if not value is Array:
			clear_blocks()
			return false
		var record := value as Array
		if record.size() < 5 or record.size() > 6:
			clear_blocks()
			return false
		var block_id := int(record[0])
		var scene := BlockDB.get_scene(block_id)
		var block_size := Vector2i.ZERO
		var block_state := {}
		if record.size() == 6 and record[5] is Dictionary:
			var extra := record[5] as Dictionary
			var size_value: Variant = extra.get("size")
			if size_value is Array and (size_value as Array).size() == 2:
				block_size = Vector2i(int(size_value[0]), int(size_value[1]))
			if extra.get("state") is Dictionary:
				block_state = extra["state"]
		if not place_block(
			scene,
			Vector2i(int(record[1]), int(record[2])),
			int(record[3]),
			block_size,
			false
		):
			clear_blocks()
			return false
		var restored := get_block(Vector2i(int(record[1]), int(record[2])))
		restored.hp = restored.max_hp * float(clampi(int(record[4]), 0, 65535)) / 65535.0
		restored.apply_save_state(block_state)
	_notify_changed()
	return true


func clear_blocks() -> void:
	for block: Block in blocks:
		if is_instance_valid(block):
			if is_instance_valid(block.collision):
				block.collision.queue_free()
			block.queue_free()
	blocks.clear()
	grid.clear()
	total_mass = 0.0


func refresh_block_visuals_around(cells: Array[Vector2i]) -> void:
	var affected := {}
	for cell: Vector2i in cells:
		var block := get_block(cell)
		if block != null:
			affected[block] = true
		for direction: Vector2i in BlockVisualSystem.NEIGHBOR_DIRECTIONS:
			var neighbor := get_block(cell + direction)
			if neighbor != null:
				affected[neighbor] = true
	for block: Block in affected:
		block.refresh_shared_visual()


func _attach_collision(block: Block) -> void:
	if block.collision == null:
		return
	var collision := block.collision
	var old_global := collision.global_transform
	block.remove_child(collision)
	add_child(collision)
	collision.global_transform = old_global


func _remove_block(block: Block) -> void:
	total_mass = maxf(
		total_mass - _get_configured_block_mass(block),
		0.0
	)
	blocks.erase(block)
	for cell: Vector2i in block.get_occupied_cells():
		grid.erase(cell)
	if is_instance_valid(block.collision):
		block.collision.queue_free()
	block.queue_free()


func _block_fits_radius(block: Block) -> bool:
	if not is_instance_valid(mount):
		return false
	var pivot := get_pivot_cells()
	for cell: Vector2i in block.get_occupied_cells():
		for corner: Vector2 in [
			Vector2(cell),
			Vector2(cell) + Vector2.RIGHT,
			Vector2(cell) + Vector2.DOWN,
			Vector2(cell) + Vector2.ONE,
		]:
			if corner.distance_to(pivot) > mount.maximum_turret_radius:
				return false
	return true


func _get_configured_block_mass(block: Block) -> float:
	var definition := BlockDB.get_block(block.block_id)
	var base_size: Vector2i = definition.get("size", block.size)
	var base_units := maxi(base_size.x * base_size.y, 1)
	var configured_units := maxi(block.size.x * block.size.y, 1)
	return (
		float(definition.get("mass", 0.0))
		* float(configured_units)
		/ float(base_units)
	)


func _has_attachment_block() -> bool:
	if not is_instance_valid(mount):
		return false
	for y in mount.size.y:
		for x in mount.size.x:
			if grid.has(Vector2i(x, y)):
				return true
	return false


func _get_connected_blocks_from_attachment() -> Dictionary:
	var connected := {}
	var queue: Array[Block] = []
	for y in mount.size.y:
		for x in mount.size.x:
			var block := get_block(Vector2i(x, y))
			if block != null and not connected.has(block):
				connected[block] = true
				queue.append(block)
	while not queue.is_empty():
		var current: Block = queue.pop_front()
		for cell: Vector2i in current.get_occupied_cells():
			for side: int in Block.Side.values():
				var direction: Vector2i = Block.SIDE_DIRS[side]
				var neighbor := get_block(cell + direction)
				if (
					neighbor != null
					and not connected.has(neighbor)
					and current.is_edge_connectable(cell, side)
					and neighbor.is_edge_connectable(
						cell + direction,
						Block.OPPOSITE_SIDE[side]
					)
				):
					connected[neighbor] = true
					queue.append(neighbor)
	return connected


func _notify_changed() -> void:
	if is_instance_valid(mount):
		mount.notify_turret_changed()
