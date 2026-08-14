class_name TurretEditor
extends Control

signal status_changed(message: String)

enum EditMode { BUILD, DISMANTLE }

const TURRET_EDIT_DIM := Color(0.35, 0.35, 0.35, 1.0)

var active_turret: Turret
var active_turret_mount: TurretMount
var base_vehicle: Vehicle
var vehicle_bay: VehicleBayBlock
var previous_vehicle_freeze := false
var previous_camera_rotation := 0.0
var dimmed_items: Array[Dictionary] = []
var selected_block: Block
var preview_block: Block
var preview_cell := Vector2i.ZERO
var preview_rotation := 0
var edit_mode := EditMode.BUILD
var removal_hover: RemovalOverlay

@onready var palette: BlockPalette = $EditorDock/PaletteArea/Panel/Clipper/BlockPalette
@onready var dismantle_button: TextureButton = $EditorDock/EditorTools/DismantleButton
@onready var status_label: Label = $EditorDock/Status


func _ready() -> void:
	add_to_group("turret_editor")
	_set_editor_visible(false)
	set_process(false)
	set_process_unhandled_input(false)


func _exit_tree() -> void:
	_restore_edit_visuals()
	if is_instance_valid(removal_hover):
		removal_hover.queue_free()


func _process(_delta: float) -> void:
	if active_turret != null and not is_instance_valid(active_turret):
		finish_turret_edit(false)
		return
	selected_block = palette.selected_block
	update_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not is_editing_turret():
		return
	if event.is_action_pressed("ui_cancel"):
		finish_turret_edit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ROTATE"):
		if selected_block != null and BlockDB.is_rotatable(selected_block.block_id):
			preview_rotation = wrapi(preview_rotation + 1, 0, 4)
		else:
			preview_rotation = 0
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X:
		_toggle_edit_mode()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if edit_mode == EditMode.BUILD:
			palette.selected_block = null
		else:
			_set_edit_mode(EditMode.BUILD)
		get_viewport().set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if edit_mode == EditMode.BUILD:
			place_block()
		else:
			remove_block()
		get_viewport().set_input_as_handled()


func begin_turret_edit(mount: TurretMount) -> Dictionary:
	if not is_instance_valid(mount) or not is_instance_valid(mount.turret):
		return _error("Turret mount is unavailable")
	if is_editing_turret():
		return _error("A turret editing session is already active")
	var assembly := mount.get_assembly()
	var target_vehicle: Vehicle
	var target_bay: VehicleBayBlock
	if assembly != null and assembly.host is Vehicle:
		target_vehicle = assembly.host as Vehicle
		target_bay = target_vehicle.get_docked_vehicle_bay()
		if not is_instance_valid(target_bay):
			return _error("Vehicle must be docked in a maintenance bay before editing its turret")
	var lock_result := _session_manager().try_begin(self, EditSessionManager.MODE_TURRET)
	if not bool(lock_result["ok"]):
		return _error(str(lock_result["message"]))
	active_turret_mount = mount
	active_turret = mount.turret
	base_vehicle = target_vehicle
	vehicle_bay = target_bay
	if is_instance_valid(base_vehicle):
		previous_vehicle_freeze = base_vehicle.freeze
		base_vehicle.linear_velocity = Vector2.ZERO
		base_vehicle.angular_velocity = 0.0
		base_vehicle.freeze = true
	_apply_edit_visuals(assembly)
	var camera := get_viewport().get_camera_2d()
	previous_camera_rotation = camera.global_rotation if camera != null else 0.0
	if camera != null:
		camera.set("target_pos", active_turret.global_position)
		camera.set("target_rot", active_turret.global_rotation)
	palette.set_turret_mode(true)
	_set_edit_mode(EditMode.BUILD)
	_set_editor_visible(true)
	set_process(true)
	set_process_unhandled_input(true)
	_show_status("Editing turret")
	return {"ok": true, "message": "Turret editor opened"}


func finish_turret_edit(require_valid: bool = true) -> Dictionary:
	if active_turret == null:
		return _error("No turret editing session is active")
	if require_valid and is_instance_valid(active_turret):
		var validation := active_turret.validate_layout()
		if not bool(validation["ok"]):
			return _error(str(validation["message"]))
	clear_preview()
	palette.set_turret_mode(false)
	_restore_edit_visuals()
	if is_instance_valid(base_vehicle):
		base_vehicle.freeze = previous_vehicle_freeze
		base_vehicle.sleeping = true
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		camera.set("target_rot", previous_camera_rotation)
	active_turret = null
	active_turret_mount = null
	base_vehicle = null
	vehicle_bay = null
	_set_editor_visible(false)
	set_process(false)
	set_process_unhandled_input(false)
	_session_manager().finish(self)
	return {"ok": true, "message": "Turret editing finished"}


func is_editing_turret(target: Turret = null) -> bool:
	return is_instance_valid(active_turret) and (target == null or active_turret == target)


func _set_editor_visible(enabled: bool) -> void:
	visible = enabled
	if enabled:
		move_to_front()


func update_preview() -> void:
	if not is_instance_valid(active_turret):
		clear_preview()
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	preview_cell = active_turret.world_to_cell(camera.get_global_mouse_position())
	if edit_mode == EditMode.DISMANTLE:
		clear_preview_block()
		update_removal_hover()
		return
	clear_removal_hover()
	if selected_block == null:
		clear_preview_block()
		return
	if preview_block == null or preview_block.block_id != selected_block.block_id:
		create_preview_block()
	if is_instance_valid(preview_block):
		preview_block.update_turret_transform(active_turret, preview_cell, preview_rotation)


func create_preview_block() -> void:
	clear_preview_block()
	if selected_block == null or not is_instance_valid(active_turret):
		return
	var scene := BlockDB.get_scene(selected_block.block_id)
	preview_block = (
		scene.instantiate() as Block if scene != null else null
	)
	if preview_block == null:
		return
	preview_block.block_id = selected_block.block_id
	active_turret.add_child(preview_block)
	preview_block.process_mode = Node.PROCESS_MODE_DISABLED
	_disable_preview_features(preview_block)


func place_block() -> void:
	if selected_block == null or not is_instance_valid(active_turret):
		return
	var scene := BlockDB.get_scene(selected_block.block_id)
	if scene == null:
		return
	var candidate := scene.instantiate() as Block
	if candidate == null:
		return
	candidate.block_id = selected_block.block_id
	candidate.update_turret_transform(active_turret, preview_cell, preview_rotation)
	var can_place := active_turret.can_place_block(candidate, preview_cell)
	candidate.free()
	if not can_place:
		_show_status("Cannot build here")
		return
	var cost := BlockDB.get_construction_cost(selected_block.block_id)
	var assembly := active_turret_mount.get_assembly()
	var storages: Array[ItemStorage] = assembly.get_construction_storages() if assembly != null else []
	var payment := ConstructionSupport.consume(cost, storages)
	if not bool(payment["ok"]):
		_show_status("Missing: %s" % ConstructionSupport.format_cost(payment["missing"]))
		return
	if not active_turret.place_block(scene, preview_cell, preview_rotation):
		ConstructionSupport.refund(payment["withdrawals"])
		_show_status("Cannot build here; materials returned")


func remove_block() -> void:
	if not is_instance_valid(active_turret):
		return
	var block := active_turret.get_block(preview_cell)
	if block != null:
		active_turret.destroy_block(block)


func update_removal_hover() -> void:
	var block := active_turret.get_block(preview_cell) if is_instance_valid(active_turret) else null
	if block == null:
		clear_removal_hover()
		return
	var overlay := _ensure_removal_hover()
	overlay.attach_to(active_turret)
	var centers: Array[Vector2] = []
	for cell: Vector2i in block.get_occupied_cells():
		centers.append(active_turret.cell_to_local_center(cell))
	overlay.show_centers(centers)


func clear_preview() -> void:
	clear_preview_block()
	clear_removal_hover()


func clear_preview_block() -> void:
	if is_instance_valid(preview_block):
		preview_block.queue_free()
	preview_block = null
	preview_rotation = 0


func clear_removal_hover() -> void:
	if is_instance_valid(removal_hover):
		removal_hover.clear()


func _ensure_removal_hover() -> RemovalOverlay:
	if not is_instance_valid(removal_hover):
		removal_hover = RemovalOverlay.new()
	return removal_hover


func _disable_preview_features(node: Node) -> void:
	if node is CollisionShape2D:
		(node as CollisionShape2D).disabled = true
	elif node is CollisionPolygon2D:
		(node as CollisionPolygon2D).disabled = true
	elif node is Area2D:
		(node as Area2D).monitoring = false
		(node as Area2D).monitorable = false
	for child: Node in node.get_children():
		_disable_preview_features(child)


func _apply_edit_visuals(assembly: BlockAssembly) -> void:
	_restore_edit_visuals()
	if assembly == null:
		return
	for block: Block in assembly.blocks:
		if not is_instance_valid(block) or block.block_host == active_turret:
			continue
		if block == active_turret_mount:
			for child: Node in block.get_children():
				if child != active_turret and child is CanvasItem:
					_dim_item(child as CanvasItem)
		else:
			_dim_item(block)
	if assembly.host is Vehicle and is_instance_valid((assembly.host as Vehicle).passive_visuals):
		_dim_item((assembly.host as Vehicle).passive_visuals)


func _dim_item(item: CanvasItem) -> void:
	dimmed_items.append({"item": item, "modulate": item.modulate})
	item.modulate *= TURRET_EDIT_DIM


func _restore_edit_visuals() -> void:
	for entry: Dictionary in dimmed_items:
		var item: Variant = entry.get("item")
		if is_instance_valid(item) and item is CanvasItem:
			(item as CanvasItem).modulate = entry.get("modulate", Color.WHITE)
	dimmed_items.clear()


func _session_manager() -> EditSessionManager:
	return get_tree().get_first_node_in_group("edit_session_manager") as EditSessionManager


func _show_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
	status_changed.emit(message)


func _error(message: String) -> Dictionary:
	_show_status(message)
	return {"ok": false, "message": message}


func _on_finish_button_pressed() -> void:
	finish_turret_edit()


func _on_dismantle_button_pressed() -> void:
	_toggle_edit_mode()


func _toggle_edit_mode() -> void:
	_set_edit_mode(
		EditMode.DISMANTLE
		if edit_mode == EditMode.BUILD
		else EditMode.BUILD
	)


func _set_edit_mode(new_mode: EditMode) -> void:
	edit_mode = new_mode
	if is_instance_valid(dismantle_button):
		dismantle_button.set_pressed_no_signal(
			edit_mode == EditMode.DISMANTLE
		)
	_show_status(
		"Dismantle: select a turret block"
		if edit_mode == EditMode.DISMANTLE
		else "Select a block to construct"
	)
	clear_preview()
