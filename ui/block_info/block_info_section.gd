class_name BlockInfoSection
extends VBoxContainer

signal target_invalidated

var target_block: Block
var _summary_text := ""
var _turret_edit_button: Button

@onready var read_only_area: VBoxContainer = $ReadOnly
@onready var summary_label: Label = $ReadOnly/Summary
@onready var config_separator: HSeparator = $ConfigSeparator
@onready var configurable_area: VBoxContainer = $Configurable


func _ready() -> void:
	_set_mouse_filter_recursive(read_only_area, Control.MOUSE_FILTER_IGNORE)
	set_extended(false)


func bind_block(block: Block, summary: String) -> bool:
	unbind_block()
	if not _accepts_block(block):
		return false
	target_block = block if is_instance_valid(block) else null
	_summary_text = summary
	if is_instance_valid(target_block):
		target_block.health_changed.connect(_on_health_changed)
		target_block.block_destroyed.connect(_on_block_destroyed)
	_bind_target()
	_add_turret_edit_button()
	refresh()
	return true


func unbind_block() -> void:
	if is_instance_valid(_turret_edit_button):
		_turret_edit_button.queue_free()
	_turret_edit_button = null
	_unbind_target()
	if is_instance_valid(target_block):
		if target_block.health_changed.is_connected(_on_health_changed):
			target_block.health_changed.disconnect(_on_health_changed)
		if target_block.block_destroyed.is_connected(_on_block_destroyed):
			target_block.block_destroyed.disconnect(_on_block_destroyed)
	target_block = null
	_summary_text = ""


func update_summary(summary: String) -> void:
	_summary_text = summary
	_refresh_summary()


func refresh() -> void:
	_refresh_summary()
	_refresh_details()
	_set_mouse_filter_recursive(read_only_area, Control.MOUSE_FILTER_IGNORE)


func set_extended(extended: bool) -> void:
	var show_configuration := extended and has_configurable_content()
	config_separator.visible = show_configuration
	configurable_area.visible = show_configuration


func has_configurable_content() -> bool:
	return configurable_area.get_child_count() > 0


func _accepts_block(_block: Block) -> bool:
	return true


func _bind_target() -> void:
	pass


func _unbind_target() -> void:
	pass


func _refresh_details() -> void:
	pass


func _refresh_summary() -> void:
	if is_instance_valid(target_block):
		summary_label.text = "HP: %.1f / %.1f" % [
			maxf(target_block.hp, 0.0),
			target_block.max_hp,
		]
	else:
		summary_label.text = _summary_text


func _set_mouse_filter_recursive(
	control: Control,
	filter: Control.MouseFilter
) -> void:
	control.mouse_filter = filter
	for child: Node in control.get_children():
		if child is Control:
			_set_mouse_filter_recursive(child as Control, filter)


func _add_turret_edit_button() -> void:
	if not is_instance_valid(target_block) or not target_block.block_host is Turret:
		return
	_turret_edit_button = Button.new()
	_turret_edit_button.text = "Edit Turret"
	_turret_edit_button.pressed.connect(_on_turret_edit_pressed)
	configurable_area.add_child(_turret_edit_button)


func _on_turret_edit_pressed() -> void:
	if not is_instance_valid(target_block) or not target_block.block_host is Turret:
		return
	var turret := target_block.block_host as Turret
	var hud := get_tree().get_first_node_in_group("game_hud")
	if hud != null and hud.has_method("open_turret_editor"):
		var result: Dictionary = hud.call(
			"open_turret_editor",
			turret.mount
		)
		if bool(result.get("ok", false)):
			var ancestor := get_parent()
			while ancestor != null and not ancestor is BlockPanel:
				ancestor = ancestor.get_parent()
			if ancestor is BlockPanel:
				(ancestor as BlockPanel).call_deferred("close_panel")


func _on_health_changed() -> void:
	refresh()


func _on_block_destroyed() -> void:
	target_invalidated.emit()
