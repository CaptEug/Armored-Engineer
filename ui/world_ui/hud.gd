extends Control

enum Mode {
	NORMAL,
	VEHICLE_EDIT,
	BUILDING_EDIT,
	TURRET_EDIT,
}

enum BlueprintDialogMode {
	NONE,
	SAVE,
	LOAD,
}

@export var UI_root: CanvasLayer
@export var gamescene: GameScene
@export var vehicle_editor: VehicleEditor
@export var turret_editor: TurretEditor
@export var vehicle_panel: VehiclePanel
@export var building_constructor: BuildingConstructor
@export var settings_panel: FloatingPanel
@export var minimap: FloatingPanel

var mode := Mode.NORMAL
var blueprint_dialog_mode := BlueprintDialogMode.NONE

@onready var tool_bar: Panel = $Toolbar
@onready var clock: Label = $Toolbar/Clock
@onready var build_button: TextureButton = $Toolbar/BuildButton
@onready var settings_button: TextureButton = $Toolbar/SettingsButton
@onready var map_button: TextureButton = $Toolbar/MapButton
@onready var editor_toolbar: HBoxContainer = $Toolbar/EditorToolbar
@onready var editor_dock: Panel = $EditorDock
@onready var palette_panel: Panel = $EditorDock/PaletteArea/Panel
@onready var palette_inner_panel: Panel = $EditorDock/PaletteArea/Panel/Clipper
@onready var status_label: Label = $Toolbar/EditorToolbar/Status
@onready var palette: BlockPalette = $EditorDock/PaletteArea/Panel/Clipper/BlockPalette
@onready var save_button: TextureButton = $Toolbar/EditorToolbar/SaveButton
@onready var load_button: TextureButton = $Toolbar/EditorToolbar/LoadButton
@onready var dismantle_button: TextureButton = $Toolbar/EditorToolbar/DismantleButton
@onready var auto_construct_button: TextureButton = $Toolbar/EditorToolbar/AutoConstructButton
@onready var com_button: CheckButton = $Toolbar/EditorToolbar/CoMButton
@onready var blueprint_dialog: FileDialog = $BlueprintDialog
@onready var com_icon: Sprite2D = $COMicon


func _ready() -> void:
	add_to_group("game_hud")
	if building_constructor != null:
		building_constructor.active_changed.connect(_on_building_session_changed)
		building_constructor.status_changed.connect(_on_editor_status_changed)
	if vehicle_editor != null:
		vehicle_editor.workshop_session_changed.connect(_on_vehicle_session_changed)
		vehicle_editor.status_changed.connect(_on_editor_status_changed)
	if turret_editor != null:
		turret_editor.session_changed.connect(_on_turret_session_changed)
		turret_editor.status_changed.connect(_on_editor_status_changed)
	set_mode(Mode.NORMAL)


func _process(_delta: float) -> void:
	if gamescene != null:
		clock.text = get_clock_string(gamescene.game_time)
	_update_com_indicator()


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.NORMAL:
		return
	if event.is_action_pressed("ui_cancel"):
		match mode:
			Mode.VEHICLE_EDIT:
				vehicle_editor.cancel_workshop_edit("Vehicle editing cancelled")
			Mode.BUILDING_EDIT:
				building_constructor.set_active(false)
			Mode.TURRET_EDIT:
				var result := turret_editor.finish_turret_edit()
				if not bool(result.get("ok", false)):
					_on_editor_status_changed(str(result.get("message", "")))
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ROTATE"):
		var editor := get_active_editor()
		if editor != null and editor.has_method("rotate_preview"):
			editor.call("rotate_preview")
			get_viewport().set_input_as_handled()
		return
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_X
	):
		set_dismantle_tool(not dismantle_button.button_pressed)
		get_viewport().set_input_as_handled()


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	tool_bar.visible = true
	settings_button.visible = mode == Mode.NORMAL
	build_button.visible = mode == Mode.NORMAL
	map_button.visible = mode == Mode.NORMAL
	clock.visible = mode == Mode.NORMAL
	editor_toolbar.visible = mode != Mode.NORMAL
	editor_dock.visible = mode != Mode.NORMAL
	if mode != Mode.NORMAL:
		move_to_front()
	palette.clear_selection()
	dismantle_button.set_pressed_no_signal(false)
	com_button.set_pressed_no_signal(false)
	com_icon.hide()
	status_label.text = ""
	match mode:
		Mode.VEHICLE_EDIT:
			palette.set_context(BlockPalette.Context.VEHICLE)
			status_label.text = "Select a block to construct"
		Mode.BUILDING_EDIT:
			palette.set_context(BlockPalette.Context.BUILDING)
			status_label.text = "Select a block to construct"
		Mode.TURRET_EDIT:
			palette.set_context(BlockPalette.Context.TURRET)
			status_label.text = "Select a block to construct"
	_apply_editor_ui_profile()
	_apply_capabilities()


func get_active_editor() -> Node:
	match mode:
		Mode.VEHICLE_EDIT:
			return vehicle_editor
		Mode.BUILDING_EDIT:
			return building_constructor
		Mode.TURRET_EDIT:
			return turret_editor
	return null


func _get_active_ui_profile() -> EditorUIProfile:
	var editor := get_active_editor() as EditorController
	return editor.get_ui_profile() if editor != null else null


func _apply_editor_ui_profile() -> void:
	var profile := _get_active_ui_profile()
	_apply_panel_style(tool_bar, profile.toolbar_style if profile != null else null)
	_apply_panel_style(
		palette_panel,
		profile.palette_style if profile != null else null
	)
	_apply_panel_style(
		palette_inner_panel,
		profile.palette_inner_style if profile != null else null
	)
	if profile != null:
		palette.set_context(profile.palette_context)


func _apply_panel_style(panel: Panel, style: StyleBox) -> void:
	if style == null:
		panel.remove_theme_stylebox_override("panel")
	else:
		panel.add_theme_stylebox_override("panel", style)


func get_selected_block() -> Block:
	return palette.selected_block


func clear_palette_selection() -> void:
	palette.clear_selection()


func set_dismantle_tool(enabled: bool) -> void:
	if mode == Mode.NORMAL:
		return
	dismantle_button.set_pressed_no_signal(enabled)
	var editor := get_active_editor()
	if editor != null and editor.has_method("set_edit_tool"):
		editor.call("set_edit_tool", enabled)


func open_turret_editor(mount: TurretMount) -> Dictionary:
	if turret_editor == null:
		return {"ok": false, "message": "Turret editor is unavailable"}
	return turret_editor.begin_turret_edit(mount)


func get_clock_string(time: float) -> String:
	var total_minutes := (time / Globals.CYCLE_DURATION) * 24.0 * 60.0
	var hour := int(total_minutes / 60.0) % 24
	var minute := int(total_minutes) % 60
	return "%02d:%02d" % [hour, minute]


func _apply_capabilities() -> void:
	var profile := _get_active_ui_profile()
	save_button.visible = profile != null and profile.show_save
	load_button.visible = profile != null and profile.show_load
	auto_construct_button.visible = (
		profile != null and profile.show_auto_construct
	)
	com_button.visible = profile != null and profile.show_center_of_mass
	dismantle_button.visible = profile != null and profile.show_dismantle


func _update_com_indicator() -> void:
	if (
		mode != Mode.VEHICLE_EDIT
		or not com_button.button_pressed
		or vehicle_editor == null
		or not is_instance_valid(vehicle_editor.vehicle)
	):
		com_icon.hide()
		return
	var target := vehicle_editor.vehicle
	com_icon.position = get_viewport().get_canvas_transform() * target.to_global(
		target.center_of_mass
	)
	com_icon.show()


func _on_build_button_toggled(enabled: bool) -> void:
	if building_constructor == null:
		build_button.set_pressed_no_signal(false)
		return
	building_constructor.set_active(enabled)
	build_button.set_pressed_no_signal(building_constructor.is_active())
	if enabled and not building_constructor.is_active():
		var sessions := get_tree().get_first_node_in_group(
			"edit_session_manager"
		) as EditorManager
		if sessions != null:
			build_button.tooltip_text = sessions.get_conflict_message(
				EditorManager.MODE_BUILDING
			)
	else:
		build_button.tooltip_text = "Construct building"
	if building_constructor.is_active() and vehicle_panel != null:
		vehicle_panel.close_panel()


func _on_vehicle_session_changed(active: bool) -> void:
	if active:
		set_mode(Mode.VEHICLE_EDIT)
		_refresh_editor_ui.call_deferred()
	elif mode == Mode.VEHICLE_EDIT:
		set_mode(Mode.NORMAL)


func _on_building_session_changed(active: bool) -> void:
	build_button.set_pressed_no_signal(active)
	if active:
		set_mode(Mode.BUILDING_EDIT)
		_refresh_editor_ui.call_deferred()
	elif mode == Mode.BUILDING_EDIT:
		set_mode(Mode.NORMAL)


func _on_turret_session_changed(active: bool) -> void:
	if active:
		set_mode(Mode.TURRET_EDIT)
		_refresh_editor_ui.call_deferred()
	elif mode == Mode.TURRET_EDIT:
		set_mode(Mode.NORMAL)


func _refresh_editor_ui() -> void:
	if mode == Mode.NORMAL:
		return
	tool_bar.show()
	editor_toolbar.show()
	editor_dock.show()
	_apply_editor_ui_profile()
	_apply_capabilities()
	move_to_front()


func _on_editor_status_changed(message: String) -> void:
	status_label.text = message


func _on_dismantle_toggled(enabled: bool) -> void:
	set_dismantle_tool(enabled)


func _on_finish_pressed() -> void:
	match mode:
		Mode.VEHICLE_EDIT:
			var result := vehicle_editor.finish_workshop_edit()
			if not bool(result.get("ok", false)):
				_on_editor_status_changed(str(result.get("message", "")))
		Mode.BUILDING_EDIT:
			building_constructor.set_active(false)
		Mode.TURRET_EDIT:
			var result := turret_editor.finish_turret_edit()
			if not bool(result.get("ok", false)):
				_on_editor_status_changed(str(result.get("message", "")))


func _on_auto_construct_pressed() -> void:
	if mode == Mode.VEHICLE_EDIT:
		vehicle_editor.auto_construct_missing_blocks()


func _on_com_toggled(_enabled: bool) -> void:
	_update_com_indicator()


func _on_save_button_pressed() -> void:
	_open_blueprint_dialog(BlueprintDialogMode.SAVE)


func _on_load_button_pressed() -> void:
	_open_blueprint_dialog(BlueprintDialogMode.LOAD)


func _open_blueprint_dialog(dialog_mode: BlueprintDialogMode) -> void:
	if mode != Mode.VEHICLE_EDIT or not is_instance_valid(vehicle_editor.vehicle):
		return
	var directory_result := VehicleBlueprint.ensure_directory()
	if not bool(directory_result["ok"]):
		_on_editor_status_changed(str(directory_result["error"]))
		return
	blueprint_dialog_mode = dialog_mode
	blueprint_dialog.access = FileDialog.ACCESS_USERDATA
	blueprint_dialog.current_dir = VehicleBlueprint.DIRECTORY
	if dialog_mode == BlueprintDialogMode.SAVE:
		blueprint_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		blueprint_dialog.title = "Save Vehicle Blueprint"
		blueprint_dialog.ok_button_text = "Save"
		blueprint_dialog.current_file = (
			vehicle_editor.vehicle.vehicle_name.validate_filename() + ".json"
		)
	else:
		blueprint_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		blueprint_dialog.title = "Load Vehicle Blueprint"
		blueprint_dialog.ok_button_text = "Load"
		blueprint_dialog.current_file = ""
	blueprint_dialog.popup_centered_ratio(0.7)


func _on_blueprint_file_selected(path: String) -> void:
	var selected_mode := blueprint_dialog_mode
	blueprint_dialog_mode = BlueprintDialogMode.NONE
	if selected_mode == BlueprintDialogMode.SAVE:
		vehicle_editor.save_blueprint_to_path(path)
	elif selected_mode == BlueprintDialogMode.LOAD:
		vehicle_editor.load_blueprint_from_path(path)


func _on_blueprint_dialog_canceled() -> void:
	blueprint_dialog_mode = BlueprintDialogMode.NONE


func _on_settings_button_pressed() -> void:
	settings_panel.visible = true


func _on_map_button_pressed() -> void:
	minimap.visible = not minimap.visible
