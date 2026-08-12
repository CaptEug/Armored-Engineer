class_name TurretMountBlockInfo
extends BlockInfoSection

var mount: TurretMount

@onready var mass_label: Label = $ReadOnly/Mass
@onready var radius_label: Label = $ReadOnly/Radius
@onready var power_label: Label = $ReadOnly/Power
@onready var edit_button: Button = $Configurable/EditButton
@onready var status_label: Label = $Configurable/Status


func _accepts_block(block: Block) -> bool:
	return block is TurretMount


func _bind_target() -> void:
	mount = target_block as TurretMount
	if not mount.turret_changed.is_connected(refresh):
		mount.turret_changed.connect(refresh)


func _unbind_target() -> void:
	if is_instance_valid(mount) and mount.turret_changed.is_connected(refresh):
		mount.turret_changed.disconnect(refresh)
	mount = null


func _refresh_details() -> void:
	if not is_instance_valid(mount) or not is_instance_valid(mount.turret):
		return
	mass_label.text = "Turret mass: %.1f / %.1f" % [
		mount.turret.get_total_mass(),
		mount.maximum_turret_mass,
	]
	radius_label.text = "Radius: %.1f / %.1f cells" % [
		mount.turret.get_swept_radius_tiles(),
		mount.maximum_turret_radius,
	]
	power_label.text = "Traverse power: %d%%" % roundi(
		mount.get_power_ratio() * 100.0
	)
	edit_button.text = (
		"Create Turret" if mount.turret.blocks.is_empty() else "Edit Turret"
	)


func _on_edit_button_pressed() -> void:
	var editor := get_tree().get_first_node_in_group("vehicle_editor") as VehicleEditor
	if editor == null:
		status_label.text = "Turret editor is unavailable"
		return
	var result := editor.begin_turret_edit(mount)
	status_label.text = str(result.get("message", ""))
