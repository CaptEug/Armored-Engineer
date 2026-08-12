class_name TurretMount
extends Block

signal turret_changed

@export_category("Turret Mount")
@export var maximum_turret_mass := 100.0
@export var maximum_turret_radius := 8.0
@export var unpowered_rotation_speed := 0.08
@export var powered_rotation_speed := 0.6
@export var traverse_power_demand := 100.0

var turret: Turret
var supplied_power := 0.0


func _ready() -> void:
	super()
	turret = Turret.new()
	turret.name = "Turret"
	add_child(turret)
	turret.setup(self)
	call_deferred("notify_turret_changed")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(turret) or _editor_is_active():
		return
	var current_assembly := get_assembly()
	if current_assembly == null or not current_assembly.has_aim_command():
		return
	var direction := current_assembly.get_aim_target() - turret.global_position
	if direction.is_zero_approx():
		return
	var desired := direction.angle() + PI * 0.5
	var ratio := (
		1.0 if traverse_power_demand <= 0.0
		else clampf(supplied_power / traverse_power_demand, 0.0, 1.0)
	)
	var speed := lerpf(
		maxf(unpowered_rotation_speed, 0.0),
		maxf(powered_rotation_speed, unpowered_rotation_speed),
		ratio
	)
	turret.global_rotation = rotate_toward(
		turret.global_rotation,
		desired,
		speed * delta
	)


func is_power_consumer() -> bool:
	return true


func get_power_demand() -> float:
	if (
		not is_instance_valid(turret)
		or turret.blocks.is_empty()
		or _editor_is_active()
	):
		return 0.0
	var current_assembly := get_assembly()
	if current_assembly == null or not current_assembly.has_aim_command():
		return 0.0
	var direction := current_assembly.get_aim_target() - turret.global_position
	if direction.is_zero_approx():
		return 0.0
	var desired := direction.angle() + PI * 0.5
	return (
		0.0 if absf(angle_difference(turret.global_rotation, desired)) < 0.005
		else maxf(traverse_power_demand, 0.0)
	)


func set_supplied_power(amount: float) -> void:
	supplied_power = clampf(amount, 0.0, maxf(traverse_power_demand, 0.0))


func get_power_ratio() -> float:
	return (
		1.0 if traverse_power_demand <= 0.0
		else clampf(supplied_power / traverse_power_demand, 0.0, 1.0)
	)


func get_save_state() -> Dictionary:
	return turret.capture_save_data() if is_instance_valid(turret) else {}


func apply_save_state(state: Dictionary) -> void:
	if is_instance_valid(turret) and not state.is_empty():
		if not turret.restore_save_data(state):
			push_warning("Turret mount ignored invalid saved turret data.")


func notify_turret_changed() -> void:
	var current_assembly := get_assembly()
	if current_assembly != null:
		var host := current_assembly.host
		if host is Vehicle:
			(host as Vehicle).update_vehicle()
		elif host is Building:
			var building := host as Building
			building.refresh_functional_state()
			if (
				building.world_block_layer != null
				and building.world_block_layer.building_system != null
			):
				building.world_block_layer.building_system.refresh_building_activity(
					building
				)
	turret_changed.emit()


func _editor_is_active() -> bool:
	if not is_inside_tree():
		return false
	var editor := get_tree().get_first_node_in_group("vehicle_editor") as VehicleEditor
	return editor != null and editor.is_editing_turret(turret)
