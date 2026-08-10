class_name DrillBlockInfoSection
extends BlockInfoSection

const POWER_NONE := Color(0.85, 0.12, 0.12)
const POWER_PARTIAL := Color(1.0, 0.62, 0.08)
const POWER_FULL := Color(0.18, 0.82, 0.24)

var drill: Block

@onready var power_percentage: Label = (
	$ReadOnly/PowerRow/Percentage
)
@onready var storage_note: Label = $ReadOnly/StorageFull


func _accepts_block(block: Block) -> bool:
	return (
		is_instance_valid(block)
		and block.has_signal("drill_status_changed")
		and block.has_method("get_power_ratio")
	)


func _bind_target() -> void:
	var block := target_block
	drill = block
	drill.connect("drill_status_changed", refresh)


func _unbind_target() -> void:
	if (
		is_instance_valid(drill)
		and drill.is_connected("drill_status_changed", refresh)
	):
		drill.disconnect("drill_status_changed", refresh)
	drill = null


func _refresh_details() -> void:
	if not is_instance_valid(drill):
		_set_power_percentage(0.0)
		storage_note.hide()
		return
	var power_ratio := float(drill.call("get_power_ratio"))
	_set_power_percentage(power_ratio)
	storage_note.visible = bool(drill.get("storage_full"))


func _set_power_percentage(power_ratio: float) -> void:
	var clamped_ratio := clampf(power_ratio, 0.0, 1.0)
	power_percentage.text = "%d%%" % roundi(clamped_ratio * 100.0)
	if power_ratio <= 0.001:
		power_percentage.add_theme_color_override(
			"font_color",
			POWER_NONE
		)
	elif clamped_ratio >= 0.999:
		power_percentage.add_theme_color_override(
			"font_color",
			POWER_FULL
		)
	else:
		power_percentage.add_theme_color_override(
			"font_color",
			POWER_PARTIAL
		)
