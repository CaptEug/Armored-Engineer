class_name BlockPanel
extends FloatingPanel

const COMPACT_WIDTH := 260.0
const EXPANDED_WIDTH := 360.0
const CURSOR_OFFSET := Vector2(16.0, 16.0)

var target_block: Block
var hover_block: Block
var current_section: BlockInfoSection
var current_source_id := ""
var pinned := false

@onready var margin: MarginContainer = $Margin
@onready var content: VBoxContainer = $Margin/VBox
@onready var header: HBoxContainer = $Margin/VBox/Header
@onready var title_label: Label = $Margin/VBox/Header/Title
@onready var close_button: Button = $Margin/VBox/Header/CloseButton
@onready var section_scroll: ScrollContainer = (
	$Margin/VBox/SectionScroll
)
@onready var section_host: VBoxContainer = (
	$Margin/VBox/SectionScroll/SectionHost
)


func _ready() -> void:
	_set_compact_mode()
	hide()


func _physics_process(_delta: float) -> void:
	if pinned:
		if (
			not is_instance_valid(current_section)
			or not is_instance_valid(target_block)
		):
			close_panel()
		return
	if get_viewport().gui_get_hovered_control() != null:
		_hide_compact()
		return
	_update_hover_target()


func pin_hovered_block(
	screen_position: Vector2 = Vector2.ZERO
) -> bool:
	if (
		pinned
		or not visible
		or not is_instance_valid(hover_block)
		or not is_instance_valid(current_section)
		or not current_section.has_configurable_content()
	):
		return false
	target_block = hover_block
	hover_block = null
	pinned = true
	_set_expanded_mode()
	show()
	move_to_front()
	var target_position := position
	if screen_position != Vector2.ZERO:
		target_position = screen_position + CURSOR_OFFSET
	_resize_to_content()
	_place_inside_viewport(target_position)
	return true


func close_panel() -> void:
	pinned = false
	target_block = null
	hover_block = null
	current_source_id = ""
	hide()
	_clear_section()
	_set_compact_mode()


func is_pinned() -> bool:
	return pinned


func _update_hover_target() -> void:
	var current_scene := get_tree().current_scene as Node2D
	if current_scene == null:
		_hide_compact()
		return
	var world_position := current_scene.get_local_mouse_position()
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var vehicle: Vehicle
	var detected_world_block: Block
	var world_blocks: WorldBlockLayer
	var liquid_layer: LiquidLayer
	var known_world_anchor := WorldBlockLayer.INVALID_CELL
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_point(
		query
	):
		var collider: Object = hit.get("collider")
		if collider is Vehicle:
			vehicle = collider as Vehicle
		elif collider is Area2D:
			var area_block := (collider as Area2D).get_parent() as Block
			if area_block is VehicleBayBlock:
				detected_world_block = area_block
		elif collider is WorldBlockBody:
			var body := collider as WorldBlockBody
			world_blocks = body.world_block_layer
			known_world_anchor = body.anchor_cell
		elif collider is WorldBlockLayer:
			world_blocks = collider as WorldBlockLayer
		elif collider is LiquidLayer:
			liquid_layer = collider as LiquidLayer

	if vehicle != null:
		_show_vehicle_block(vehicle, world_position)
	elif is_instance_valid(detected_world_block):
		_show_live_block(detected_world_block)
	elif world_blocks != null:
		_show_world_block(
			world_blocks,
			world_position,
			known_world_anchor
		)
	elif liquid_layer != null:
		_show_liquid(liquid_layer, world_position)
	else:
		_hide_compact()


func _show_vehicle_block(
	vehicle: Vehicle,
	world_position: Vector2
) -> void:
	var block := vehicle.get_block(vehicle.world_to_cell(world_position))
	_show_live_block(block)


func _show_live_block(block: Block) -> void:
	if not is_instance_valid(block):
		_hide_compact()
		return
	_show_info(
		block.block_id,
		"HP: %.1f / %.1f" % [maxf(block.hp, 0.0), block.max_hp],
		block,
		"block:%d" % block.get_instance_id()
	)


func _show_world_block(
	layer: WorldBlockLayer,
	world_position: Vector2,
	known_anchor: Vector2i
) -> void:
	var cell := known_anchor
	if cell == WorldBlockLayer.INVALID_CELL:
		cell = layer.local_to_map(layer.to_local(world_position))
	var state := layer.get_block_state(cell)
	if state.is_empty():
		_hide_compact()
		return
	var functional_block := layer.get_functional_block_at(cell)
	if is_instance_valid(functional_block):
		_show_live_block(functional_block)
		return
	var block_id := int(state["block_id"])
	var max_hp := _get_world_block_max_hp(block_id, state)
	var anchor := layer.get_block_anchor(cell)
	if anchor == WorldBlockLayer.INVALID_CELL:
		anchor = cell
	_show_info(
		block_id,
		"HP: %.1f / %.1f" % [
			maxf(float(state["hp"]), 0.0),
			max_hp,
		],
		null,
		"world:%d:%d:%d" % [
			layer.get_instance_id(),
			anchor.x,
			anchor.y,
		]
	)


func _show_liquid(
	layer: LiquidLayer,
	world_position: Vector2
) -> void:
	var cell := layer.local_to_map(layer.to_local(world_position))
	var state := layer.get_celldata(cell)
	if state.is_empty():
		_hide_compact()
		return
	var total_mass := layer.get_total_liquid_mass(
		layer.get_connected_liquid(cell)
	)
	var mass_text := (
		"Total mass: %.0f kg" % total_mass
		if total_mass < 1000.0
		else "Total mass: %.1f T" % (total_mass / 1000.0)
	)
	_show_info(
		int(state["block_id"]),
		mass_text,
		null,
		"liquid:%d:%d:%d" % [
			layer.get_instance_id(),
			cell.x,
			cell.y,
		]
	)


func _show_info(
	block_id: int,
	summary: String,
	block: Block,
	source_id: String
) -> void:
	if not BlockDB.has_block(block_id):
		_hide_compact()
		return
	if source_id != current_source_id:
		if not _load_section(block_id, block, summary):
			_hide_compact()
			return
		current_source_id = source_id
	else:
		current_section.update_summary(summary)
	hover_block = block if is_instance_valid(block) else null
	title_label.text = BlockDB.get_block_name(block_id)
	_set_compact_mode()
	show()
	_resize_to_content()
	_place_inside_viewport(
		get_viewport().get_mouse_position() + CURSOR_OFFSET
	)


func _load_section(
	block_id: int,
	block: Block,
	summary: String
) -> bool:
	_clear_section()
	var section_scene := BlockDB.get_info_section_scene(block_id)
	if section_scene == null:
		return false
	var instance := section_scene.instantiate()
	var section := instance as BlockInfoSection
	if section == null:
		instance.queue_free()
		return false
	current_section = section
	section_host.add_child(current_section)
	current_section.target_invalidated.connect(_on_target_invalidated)
	current_section.minimum_size_changed.connect(
		_on_section_minimum_size_changed
	)
	if not current_section.bind_block(block, summary):
		_clear_section()
		return false
	return true


func _clear_section() -> void:
	if not is_instance_valid(current_section):
		current_section = null
		return
	current_section.unbind_block()
	section_host.remove_child(current_section)
	current_section.queue_free()
	current_section = null


func _hide_compact() -> void:
	if pinned:
		return
	hover_block = null
	current_source_id = ""
	hide()
	_clear_section()


func _set_compact_mode() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	section_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_button.hide()
	if is_instance_valid(current_section):
		current_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		current_section.set_extended(false)


func _set_expanded_mode() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	section_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.show()
	if is_instance_valid(current_section):
		current_section.mouse_filter = Control.MOUSE_FILTER_PASS
		current_section.set_extended(true)


func _resize_to_content() -> void:
	if not is_instance_valid(current_section):
		return
	var viewport_size := get_viewport_rect().size
	var section_size := current_section.get_combined_minimum_size()
	var header_height := header.get_combined_minimum_size().y
	var separation := content.get_theme_constant("separation")
	var vertical_margin := (
		margin.get_theme_constant("margin_top")
		+ margin.get_theme_constant("margin_bottom")
	)
	var desired_height := (
		header_height
		+ section_size.y
		+ separation
		+ vertical_margin
	)
	var desired_width := EXPANDED_WIDTH if pinned else COMPACT_WIDTH
	size = Vector2(
		minf(desired_width, viewport_size.x),
		minf(desired_height, viewport_size.y)
	)
	_place_inside_viewport(position)


func _place_inside_viewport(target_position: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	position = target_position.clamp(
		Vector2.ZERO,
		(viewport_size - size).max(Vector2.ZERO)
	)


func _get_world_block_max_hp(
	block_id: int,
	state: Dictionary
) -> float:
	var base_size := BlockDB.get_size(block_id)
	var stored_size: Vector2i = state.get("size", base_size)
	var base_units := maxi(base_size.x * base_size.y, 1)
	var stored_units := maxi(stored_size.x * stored_size.y, 1)
	return (
		BlockDB.get_max_hp(block_id)
		* float(stored_units)
		/ float(base_units)
	)


func _on_section_minimum_size_changed() -> void:
	if visible:
		call_deferred("_resize_to_content")


func _on_target_invalidated() -> void:
	if pinned:
		close_panel()
	else:
		_hide_compact()
