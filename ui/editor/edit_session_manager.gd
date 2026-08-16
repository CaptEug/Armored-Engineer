class_name EditorManager
extends Node

signal session_changed(mode: StringName, active: bool)

const MODE_BUILDING := &"building"
const MODE_VEHICLE := &"vehicle"
const MODE_TURRET := &"turret"

var active_mode: StringName = &""
var active_owner: Node


func _ready() -> void:
	add_to_group("editor_manager")
	add_to_group("edit_session_manager")


func _process(_delta: float) -> void:
	if active_owner != null and not is_instance_valid(active_owner):
		active_owner = null
		active_mode = &""
		session_changed.emit(&"", false)


func try_begin(owner: Node, mode: StringName) -> Dictionary:
	if not is_instance_valid(owner):
		return {"ok": false, "message": "Editor is unavailable"}
	if active_owner == owner and active_mode == mode:
		return {"ok": true, "message": ""}
	if is_instance_valid(active_owner):
		return {
			"ok": false,
			"message": "Finish %s editing before entering another mode"
			% _display_name(active_mode),
		}
	active_owner = owner
	active_mode = mode
	session_changed.emit(active_mode, true)
	return {"ok": true, "message": ""}


func finish(owner: Node) -> void:
	if active_owner != owner:
		return
	var finished_mode := active_mode
	active_owner = null
	active_mode = &""
	session_changed.emit(finished_mode, false)


func is_active(mode: StringName = &"") -> bool:
	return (
		is_instance_valid(active_owner)
		and (mode.is_empty() or active_mode == mode)
	)


func get_conflict_message(requested_mode: StringName) -> String:
	if not is_active() or active_mode == requested_mode:
		return ""
	return "Finish %s editing before entering %s editing" % [
		_display_name(active_mode),
		_display_name(requested_mode),
	]


func _display_name(mode: StringName) -> String:
	match mode:
		MODE_BUILDING:
			return "building"
		MODE_VEHICLE:
			return "vehicle"
		MODE_TURRET:
			return "turret"
	return "current"
