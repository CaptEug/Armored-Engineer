class_name EditorUIProfile
extends Resource

@export_enum("Vehicle", "Building", "Turret") var palette_context := 0
@export var toolbar_style: StyleBox
@export var palette_style: StyleBox
@export var palette_inner_style: StyleBox
@export var show_save := false
@export var show_load := false
@export var show_dismantle := true
@export var show_auto_construct := false
@export var show_center_of_mass := false

