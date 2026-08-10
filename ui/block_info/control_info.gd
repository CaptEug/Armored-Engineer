class_name ControlBlockInfoSection
extends BlockInfoSection

var control_block: ControlBlock

@onready var status_label: Label = $ReadOnly/ControlStatus
@onready var active_toggle: CheckButton = $Configurable/ActiveToggle


func _process(_delta: float) -> void:
	_refresh_details()


func _accepts_block(block: Block) -> bool:
	return block is ControlBlock


func _bind_target() -> void:
	control_block = target_block as ControlBlock


func _unbind_target() -> void:
	control_block = null


func _refresh_details() -> void:
	if not is_instance_valid(control_block):
		status_label.text = "Control unavailable"
		active_toggle.disabled = true
		active_toggle.set_pressed_no_signal(false)
		return
	var target_assembly := control_block.get_assembly()
	var available: bool = (
		target_assembly != null
		and target_assembly.has_control_block(control_block)
	)
	var is_active: bool = (
		available
		and target_assembly.is_active_control_block(control_block)
	)
	active_toggle.disabled = not available
	active_toggle.set_pressed_no_signal(is_active)
	status_label.text = (
		"Current functioning control"
		if is_active
		else "Inactive control"
	)


func _on_active_toggle_toggled(enabled: bool) -> void:
	if not is_instance_valid(control_block):
		return
	var target_assembly := control_block.get_assembly()
	if target_assembly == null:
		return
	if enabled:
		target_assembly.set_active_control_block(control_block)
	refresh()
