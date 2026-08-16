class_name BallisticSmokeTrail
extends Node2D

@export_category("Trajectory Sampling")
@export var sample_spacing := 5.0
@export_range(8, 1024, 1) var maximum_samples := 512

@export_category("Diffusion")
@export var initial_radius := 1
@export var final_radius := 10
@export var lifetime := 4.0
@export var initial_opacity := 0.6
@export var smoke_color := Color(0.271, 0.271, 0.271, 1.0)
@export var wind_velocity := Vector2.ZERO
@export var random_drift := 4.0

var _samples: Array[Dictionary] = []
var _last_sample_world := Vector2.ZERO
var _has_last_sample := false
var _recording := false
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	set_process(false)


func begin(world_position: Vector2) -> void:
	_random.randomize()
	_recording = true
	set_process(true)
	_add_sample(world_position)
	_last_sample_world = world_position
	_has_last_sample = true


func sample_position(world_position: Vector2) -> void:
	if not _recording:
		return
	if not _has_last_sample:
		begin(world_position)
		return
	var distance := _last_sample_world.distance_to(world_position)
	if distance < sample_spacing:
		return
	var direction := _last_sample_world.direction_to(world_position)
	var sample_count := floori(distance / sample_spacing)
	for index in range(1, sample_count + 1):
		_add_sample(_last_sample_world + direction * sample_spacing * index)
	_last_sample_world += direction * sample_spacing * sample_count


func stop() -> void:
	_recording = false
	if _samples.is_empty():
		queue_free()


func _process(delta: float) -> void:
	for index in range(_samples.size() - 1, -1, -1):
		var sample := _samples[index]
		sample["age"] = float(sample["age"]) + delta
		if float(sample["age"]) >= lifetime:
			_samples.remove_at(index)
			continue
		sample["position"] = (
			sample["position"] as Vector2
			+ (wind_velocity + sample["drift"] as Vector2) * delta
		)
	queue_redraw()
	if not _recording and _samples.is_empty():
		queue_free()


func _draw() -> void:
	for sample: Dictionary in _samples:
		var progress := clampf(float(sample["age"]) / lifetime, 0.0, 1.0)
		var diffusion := ease(progress, -1.5)
		var radius := lerpf(initial_radius, final_radius, diffusion)
		var opacity := initial_opacity * pow(1.0 - progress, 1.45)
		var position := sample["position"] as Vector2
		# Layered circles give each trajectory sample a soft, diffused edge.
		draw_circle(position, radius, Color(smoke_color, opacity * 0.16))
		draw_circle(position, radius * 0.72, Color(smoke_color, opacity * 0.30))
		draw_circle(position, radius * 0.42, Color(smoke_color, opacity * 0.54))


func _add_sample(world_position: Vector2) -> void:
	if _samples.size() >= maximum_samples:
		_samples.pop_front()
	var drift_angle := _random.randf_range(0.0, TAU)
	var drift_strength := _random.randf_range(0.25, 1.0) * random_drift
	_samples.append({
		"position": to_local(world_position),
		"age": 0.0,
		"drift": Vector2.from_angle(drift_angle) * drift_strength,
	})
	queue_redraw()
