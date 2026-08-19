class_name BlockPalette
extends Control

enum Context {
	VEHICLE,
	BUILDING,
	TURRET,
}

@export_enum("vehicle", "world", "turret") var host_name := BlockDB.HOST_VEHICLE
@export var constructed_only := true

var blocks: Array[Block] = []
var selected_block : Block
var zoom:int = 2
var max_zoom:int = 4
var min_zoom:int = 1
var context := Context.VEHICLE


func _ready():
	for child: Node in get_children():
		var block := child as Block
		if block == null:
			continue
		blocks.append(block)
		create_button(block)
		block.visible = _is_available(block)
		block.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in get_children():
		var button := child as BlockButton
		if button != null:
			button.visible = _is_available(button.block)
	scale = Vector2(zoom, zoom)


func _is_available(block: Block) -> bool:
	return (
		BlockDB.can_place_on(block.block_id, host_name)
		and (
			not constructed_only
			or BlockDB.is_constructed(block.block_id)
		)
	)


func create_button(block : Block):
	var button = BlockButton.new()
	button.block = block
	button.intiatialize()
	add_child(button)


func set_turret_mode(enabled: bool) -> void:
	set_context(Context.TURRET if enabled else Context.VEHICLE)


func set_context(new_context: Context) -> void:
	context = new_context
	match context:
		Context.BUILDING:
			host_name = BlockDB.HOST_WORLD
		Context.TURRET:
			host_name = BlockDB.HOST_TURRET
		_:
			host_name = BlockDB.HOST_VEHICLE
	selected_block = null
	for block: Block in blocks:
		block.visible = _is_available(block)
	for child: Node in get_children():
		var button := child as BlockButton
		if button != null:
			button.visible = _is_available(button.block)


func clear_selection() -> void:
	selected_block = null


func _on_zoom_in_button_pressed():
	zoom = clampi(zoom + 1, min_zoom, max_zoom)
	scale = Vector2(zoom, zoom)


func _on_zoom_out_button_pressed():
	zoom = clampi(zoom - 1, min_zoom, max_zoom)
	scale = Vector2(zoom, zoom)
