extends Panel

@export var UI_root : CanvasLayer
@export var gamescene : GameScene
@export var vehicle_editor : VehicleEditor
@export var turret_editor: TurretEditor
@export var vehicle_panel: VehiclePanel
@export var building_constructor: BuildingConstructor
@export var settings_panel : FloatingPanel
@export var minimap : FloatingPanel

@onready var clock = $Clock
@onready var build_button: TextureButton = $BuildButton

func _ready() -> void:
	add_to_group("game_hud")
	if building_constructor != null:
		building_constructor.active_changed.connect(
			_on_building_constructor_active_changed
		)


func open_turret_editor(mount: TurretMount) -> Dictionary:
	if turret_editor == null:
		return {"ok": false, "message": "Turret editor is unavailable"}
	var result := turret_editor.begin_turret_edit(mount)
	if bool(result.get("ok", false)):
		turret_editor.visible = true
		turret_editor.move_to_front()
	return result


func _process(_delta):
	if gamescene:
		clock.text = get_clock_string(gamescene.game_time)


func get_clock_string(time) -> String:
	var cycle_duration = Globals.CYCLE_DURATION
	var total_minutes = (time / cycle_duration) * 24.0 * 60.0
	var hour = int(total_minutes / 60.0) % 24
	var minute = int(total_minutes) % 60
	return "%02d:%02d" % [hour, minute]


func _on_build_button_toggled(enabled: bool) -> void:
	if building_constructor == null:
		build_button.set_pressed_no_signal(false)
		return
	building_constructor.set_active(enabled)
	build_button.set_pressed_no_signal(building_constructor.is_active())
	if enabled and not building_constructor.is_active():
		var sessions := get_tree().get_first_node_in_group(
			"edit_session_manager"
		) as EditSessionManager
		if sessions != null:
			build_button.tooltip_text = sessions.get_conflict_message(
				EditSessionManager.MODE_BUILDING
			)
	else:
		build_button.tooltip_text = "Building editor"
	if building_constructor.is_active() and vehicle_panel != null:
		vehicle_panel.close_panel()


func _on_building_constructor_active_changed(enabled: bool) -> void:
	build_button.set_pressed_no_signal(enabled)


func _on_settings_button_pressed() -> void:
	settings_panel.visible = true


func _on_map_button_pressed():
	minimap.visible = !minimap.visible
