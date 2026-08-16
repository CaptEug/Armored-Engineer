class_name Projectile
extends RigidBody2D

enum ShellType {
	AP,
	HE,
	APHE,
}

@export var shell_type: ShellType = ShellType.AP
@export var weight: float = 1.0
@export var max_K_DMG: float = 100.0
@export_range(1.0, 4000.0, 1.0) var full_kinetic_damage_speed := 200.0
@export var max_E_DMG: float = 100.0
@export var explosion_radius: int = 3
@export var ricochet_angle: float = 70.0 # degrees away from surface normal
@export_range(0.0, 1.0, 0.01) var ricochet_loss: float = 0.5

@export_category("Projectile Effects")
@export var effects_enabled := true
@export var smoke_trail: BallisticSmokeTrail

var source_vehicle: Vehicle
var source_turret: Turret
var source_assembly: BlockAssembly
var source_weapon: Weapon
var launch_speed := 0.0
var spawn_position := Vector2.ZERO
var remaining_K_DMG := 0.0

var last_pos := Vector2.ZERO
var source_cleared := false
var traversing_vehicle: Vehicle
var penetrated_block_ids: Dictionary = {}

var explosion_scene := preload("res://items/shells/explosion.tscn")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	mass = weight
	last_pos = global_position
	if spawn_position == Vector2.ZERO:
		spawn_position = global_position
	remaining_K_DMG = _get_kinetic_damage_ceiling(launch_speed)
	var shell_body := get_node_or_null("Area2D") as Area2D
	if shell_body != null:
		shell_body.collision_layer = 0
		shell_body.collision_mask = 0
		shell_body.monitoring = false
		shell_body.monitorable = false
	if effects_enabled:
		_prepare_projectile_effects()

func _physics_process(_delta: float) -> void:
	if is_instance_valid(smoke_trail):
		smoke_trail.sample_position(global_position)
	_decay_kinetic_damage_from_speed()
	var from := last_pos
	var to := global_position
	var step_distance := from.distance_to(to)
	if step_distance <= 0.001:
		return

	if not source_cleared:
		source_cleared = spawn_position.distance_to(to) >= Globals.TILE_SIZE * 2.0

	if is_instance_valid(traversing_vehicle):
		if _trace_vehicle_cells(traversing_vehicle, from, to, Vector2.ZERO):
			return
		if traversing_vehicle.get_block(traversing_vehicle.world_to_cell(to)) != null:
			last_pos = to
			return

	var exclusions: Array[RID] = [get_rid()]
	if not source_cleared and is_instance_valid(source_vehicle):
		exclusions.append(source_vehicle.get_rid())
	if is_instance_valid(source_turret):
		exclusions.append(source_turret.get_rid())
	if is_instance_valid(traversing_vehicle):
		exclusions.append(traversing_vehicle.get_rid())
	traversing_vehicle = null

	var query := PhysicsRayQueryParameters2D.create(from, to, 3, exclusions)
	query.collide_with_areas = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		last_pos = to
		return

	var collider: Object = hit.get("collider")
	var hit_position: Vector2 = hit.get("position", to)
	var hit_normal: Vector2 = hit.get("normal", Vector2.ZERO)
	if collider is Turret:
		var target_turret := collider as Turret
		if (
			source_assembly != null
			and target_turret.get_assembly_at(Vector2i.ZERO) == source_assembly
		):
			last_pos = hit_position + (to - from).normalized()
			return
		_handle_turret_impact(
			target_turret,
			int(hit.get("shape", -1)),
			hit_position,
			hit_normal,
			(to - from).normalized()
		)
		return
	elif collider is Vehicle:
		traversing_vehicle = collider as Vehicle
		if _trace_vehicle_cells(
			traversing_vehicle,
			hit_position + (to - from).normalized() * 0.5,
			to,
			hit_normal
		):
			return
	elif collider is WorldBlockLayer:
		_handle_world_block_impact(
			collider as WorldBlockLayer,
			hit_position,
			hit_normal,
			(to - from).normalized()
		)
		return
	elif collider is WorldBlockBody:
		var world_body := collider as WorldBlockBody
		_handle_world_block_impact(
			world_body.world_block_layer,
			hit_position,
			hit_normal,
			(to - from).normalized(),
			world_body.anchor_cell
		)
		return
	else:
		_handle_world_impact(hit_position, hit_normal)
		return

	last_pos = to


func _handle_turret_impact(
	target_turret: Turret,
	shape_index: int,
	hit_position: Vector2,
	hit_normal: Vector2,
	direction: Vector2
) -> void:
	var block := target_turret.get_block_for_shape(shape_index)
	if block == null:
		block = target_turret.get_block(target_turret.world_to_cell(hit_position))
	if block == null:
		_handle_world_impact(hit_position, hit_normal)
		return
	if shell_type != ShellType.HE and _should_ricochet(direction, hit_normal):
		ricochet(hit_normal, hit_position)
		return
	global_position = hit_position + direction.normalized()
	if shell_type == ShellType.HE:
		explode()
		queue_free()
		return
	var result := target_turret.damage_block_at(
		block.origin_cell,
		remaining_K_DMG,
		&"KINETIC"
	)
	_consume_kinetic_damage(result)
	if bool(result["destroyed"]) and remaining_K_DMG > 0.001:
		last_pos = global_position
		return
	if shell_type == ShellType.APHE:
		explode()
	queue_free()

func _trace_vehicle_cells(
	target_vehicle: Vehicle,
	from: Vector2,
	to: Vector2,
	entry_normal: Vector2
) -> bool:
	var distance := from.distance_to(to)
	var sample_step := maxf(Globals.TILE_SIZE * 0.2, 1.0)
	var sample_count := maxi(1, ceili(distance / sample_step))
	var first_new_block := true

	for index in range(sample_count + 1):
		var ratio := float(index) / float(sample_count)
		var sample_position := from.lerp(to, ratio)
		var block := target_vehicle.get_block(target_vehicle.world_to_cell(sample_position))
		if block == null:
			continue
		var block_id := block.get_instance_id()
		if penetrated_block_ids.has(block_id):
			continue

		if first_new_block and not entry_normal.is_zero_approx():
			if shell_type != ShellType.HE and _should_ricochet(
				(to - from).normalized(),
				entry_normal
			):
				ricochet(entry_normal, sample_position)
				return true
		first_new_block = false
		penetrated_block_ids[block_id] = true

		if shell_type == ShellType.HE:
			global_position = sample_position
			explode()
			queue_free()
			return true

		var result := target_vehicle.damage_block_at(
			block.origin_cell,
			remaining_K_DMG,
			&"KINETIC"
		)
		_consume_kinetic_damage(result)

		if remaining_K_DMG <= 0.001:
			global_position = sample_position
			if shell_type == ShellType.APHE:
				explode()
			queue_free()
			return true

	return false

func _should_ricochet(direction: Vector2, normal: Vector2) -> bool:
	if direction.is_zero_approx() or normal.is_zero_approx():
		return false
	var normal_alignment := clampf(direction.normalized().dot(-normal.normalized()), -1.0, 1.0)
	var incidence_degrees := rad_to_deg(acos(normal_alignment))
	return incidence_degrees >= ricochet_angle

func ricochet(normal: Vector2, hit_position: Vector2) -> void:
	linear_velocity = linear_velocity.bounce(normal) * ricochet_loss
	remaining_K_DMG *= ricochet_loss * ricochet_loss
	global_position = hit_position + normal * 1.0
	rotation = linear_velocity.angle() + PI * 0.5
	last_pos = global_position
	traversing_vehicle = null


func _handle_world_block_impact(
	world_blocks: WorldBlockLayer,
	hit_position: Vector2,
	hit_normal: Vector2,
	direction: Vector2,
	known_cell: Vector2i = WorldBlockLayer.INVALID_CELL
) -> void:
	if (
		shell_type != ShellType.HE
		and _should_ricochet(direction, hit_normal)
	):
		ricochet(hit_normal, hit_position)
		return

	var cell := known_cell
	if cell == WorldBlockLayer.INVALID_CELL:
		cell = world_blocks.get_solid_cell_at_world_position(
			hit_position,
			direction
		)
	if cell == WorldBlockLayer.INVALID_CELL:
		_handle_world_impact(hit_position, hit_normal)
		return
	if (
		not source_cleared
		and source_assembly != null
		and world_blocks.get_assembly_at(cell) == source_assembly
	):
		last_pos = hit_position + direction.normalized()
		return

	var impact_position := hit_position
	if not direction.is_zero_approx():
		impact_position += direction.normalized()
	global_position = impact_position
	if shell_type == ShellType.HE:
		explode()
		queue_free()
		return

	var result := world_blocks.damage_block_at(
		cell,
		remaining_K_DMG,
		&"KINETIC"
	)
	if not result["hit"]:
		_handle_world_impact(hit_position, hit_normal)
		return

	_consume_kinetic_damage(result)
	if result["destroyed"] and remaining_K_DMG > 0.001:
		last_pos = global_position
		return

	if shell_type == ShellType.APHE:
		explode()
	queue_free()


func _handle_world_impact(hit_position: Vector2, hit_normal: Vector2) -> void:
	if shell_type != ShellType.HE and _should_ricochet(
		linear_velocity.normalized(),
		hit_normal
	):
		ricochet(hit_normal, hit_position)
		return
	global_position = hit_position
	if shell_type == ShellType.HE or shell_type == ShellType.APHE:
		explode()
	queue_free()


func _consume_kinetic_damage(result: Dictionary) -> void:
	var damage_before := remaining_K_DMG
	remaining_K_DMG = maxf(
		remaining_K_DMG - float(result.get("damage_consumed", 0.0)),
		0.0
	)
	if damage_before <= 0.0 or remaining_K_DMG <= 0.0:
		linear_velocity = Vector2.ZERO
		return
	linear_velocity *= sqrt(remaining_K_DMG / damage_before)


func _decay_kinetic_damage_from_speed() -> void:
	remaining_K_DMG = minf(
		remaining_K_DMG,
		_get_kinetic_damage_ceiling(linear_velocity.length())
	)


func _get_kinetic_damage_ceiling(speed: float) -> float:
	if max_K_DMG <= 0.0 or full_kinetic_damage_speed <= 0.0:
		return 0.0
	var speed_ratio := clampf(speed / full_kinetic_damage_speed, 0.0, 1.0)
	return max_K_DMG * speed_ratio * speed_ratio

func explode() -> void:
	var explosion := explosion_scene.instantiate() as Explosion
	if explosion == null:
		return
	explosion.global_position = global_position
	explosion.radius = explosion_radius
	explosion.max_damage = max_E_DMG
	get_tree().current_scene.add_child(explosion)


func _prepare_projectile_effects() -> void:
	if not is_instance_valid(smoke_trail):
		return
	smoke_trail.reparent(get_parent(), true)
	smoke_trail.begin(spawn_position)
	tree_exiting.connect(_release_smoke_trail)


func _release_smoke_trail() -> void:
	if not is_instance_valid(smoke_trail):
		return
	var released_trail := smoke_trail
	smoke_trail = null
	released_trail.stop()
