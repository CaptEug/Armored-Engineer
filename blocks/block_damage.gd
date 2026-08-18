class_name BlockDamage
extends RefCounted

const DESTROYED_EPSILON := 0.001


static func miss() -> Dictionary:
	return {
		"hit": false,
		"destroyed": false,
		"hp_before": 0.0,
		"hp_after": 0.0,
		"damage_applied": 0.0,
		"damage_consumed": 0.0,
	}


static func apply_to_host(
	host: Object,
	cell: Vector2i,
	amount: float,
	damage_type: StringName
) -> Dictionary:
	if (
		not is_instance_valid(host)
		or not host.has_method("get_block_damage_state")
		or not host.has_method("commit_block_damage")
	):
		return miss()
	var state_value: Variant = host.call(
		"get_block_damage_state",
		cell
	)
	if not state_value is Dictionary:
		return miss()
	var state := state_value as Dictionary
	if state.is_empty():
		return miss()
	var block := state.get("block") as Block
	var result := calculate_armored(
		block,
		int(state.get("block_id", BlockDB.INVALID_BLOCK_ID)),
		float(state.get("hp", 0.0)),
		amount,
		damage_type
	)
	if result["hit"]:
		host.call("commit_block_damage", state, result)
	return result


static func calculate_armored(
	block: Block,
	block_id: int,
	current_hp: float,
	amount: float,
	damage_type: StringName
) -> Dictionary:
	if not is_instance_valid(block) or not block.is_armored:
		return calculate(block_id, current_hp, amount, damage_type)
	var armor_before := maxf(block.armor_hp, 0.0)
	var armor_multiplier := BlockDB.get_armor_damage_multiplier(damage_type)
	var armor_applied := 0.0
	var armor_consumed := 0.0
	if armor_multiplier <= 0.0:
		armor_consumed = amount
	else:
		armor_applied = minf(amount * armor_multiplier, armor_before)
		armor_consumed = minf(amount, armor_before / armor_multiplier)
	var armor_after := maxf(armor_before - armor_applied, 0.0)
	var remaining_amount := maxf(amount - armor_consumed, 0.0)
	var base_result := (
		calculate(block_id, current_hp, remaining_amount, damage_type)
		if remaining_amount > 0.0
		else calculate(block_id, current_hp, 0.0, damage_type)
	)
	if remaining_amount <= 0.0:
		base_result = {
			"hit": true,
			"destroyed": false,
			"hp_before": current_hp,
			"hp_after": current_hp,
			"damage_applied": 0.0,
			"damage_consumed": 0.0,
		}
	base_result["armor_hp_before"] = armor_before
	base_result["armor_hp_after"] = armor_after
	base_result["armor_damage_applied"] = armor_applied
	base_result["damage_applied"] = (
		float(base_result["damage_applied"]) + armor_applied
	)
	base_result["damage_consumed"] = (
		armor_consumed + float(base_result["damage_consumed"])
	)
	return base_result


static func calculate(
	block_id: int,
	current_hp: float,
	amount: float,
	damage_type: StringName
) -> Dictionary:
	if not BlockDB.has_block(block_id) or amount <= 0.0:
		return miss()

	var hp_before := maxf(current_hp, 0.0)
	var multiplier := BlockDB.get_damage_multiplier(
		block_id,
		damage_type
	)
	var result := {
		"hit": true,
		"destroyed": false,
		"hp_before": hp_before,
		"hp_after": hp_before,
		"damage_applied": 0.0,
		"damage_consumed": 0.0,
	}

	# A zero multiplier is impenetrable to this damage type. The hit consumes
	# the remaining attack without reducing HP.
	if multiplier <= 0.0:
		result["damage_consumed"] = amount
		return result

	var damage_applied := minf(amount * multiplier, hp_before)
	var damage_consumed := minf(amount, hp_before / multiplier)
	var hp_after := maxf(hp_before - damage_applied, 0.0)
	result["hp_after"] = hp_after
	result["damage_applied"] = damage_applied
	result["damage_consumed"] = damage_consumed
	result["destroyed"] = hp_after <= DESTROYED_EPSILON
	return result
