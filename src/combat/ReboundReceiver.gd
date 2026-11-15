class_name ReboundReceiver
extends Node

## Handles impact energy absorption, momentum scaling, and combo chaining.

signal rebound_absorbed(absorbed_energy: float, resulting_velocity: Vector2)
signal combo_increased(new_combo: int, multiplier: float)
signal counterstrike_ready(energy_ratio: float)

@export_group("Energy Parameters")
@export var max_energy: float = 100.0
@export var current_energy: float = 0.0
@export var energy_absorption_rate: float = 0.08
@export var energy_decay_rate: float = 3.5

@export_group("Momentum & Game Feel")
@export var rebound_impulse_scale: float = 1.25
@export var max_combo_multiplier: float = 4.0
@export var combo_timeout: float = 2.2

var combo_count: int = 0
var _combo_timer: float = 0.0
var _is_rebounding: bool = false

func _physics_process(delta: float) -> void:
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_reset_combo()

	# Slow baseline energy drain outside active combat
	if current_energy > 0.0 and _combo_timer <= 0.0:
		current_energy = maxf(0.0, current_energy - energy_decay_rate * delta)
		Events.rebound_energy_changed.emit(current_energy / max_energy)

func absorb_impact(raw_force: Vector2, is_perfect_parry: bool = false) -> Vector2:
	var energy_gain: float = 0.0
	var final_impulse: Vector2 = Vector2.ZERO

	if is_perfect_parry:
		# Parrying converts incoming violence directly into maximum energy with zero health loss
		energy_gain = 35.0
		combo_count += 2
		_combo_timer = combo_timeout * 1.5
		var push_dir: Vector2 = raw_force.normalized() if raw_force.length_squared() > 1.0 else Vector2(-1.0, -1.0).normalized()
		final_impulse = push_dir * 380.0
		# Guarantee solid upward pop so player leaps clear of the threat
		final_impulse.y = minf(final_impulse.y, -260.0)
		Events.camera_shake_requested.emit(4.5, 0.12)
		Events.hit_stop_requested.emit(0.04)
		Events.impact_frame_triggered.emit()
	else:
		# Intentional calculated hit: trade heart chip for explosive momentum
		energy_gain = raw_force.length() * energy_absorption_rate
		combo_count += 1
		_combo_timer = combo_timeout

		var multiplier: float = get_combo_multiplier()
		var push_dir: Vector2 = raw_force.normalized() if raw_force.length_squared() > 1.0 else Vector2(0.0, -1.0)
		final_impulse = push_dir * (raw_force.length() * rebound_impulse_scale * multiplier)
		# Ensure upward arc away from hazards
		final_impulse.y = minf(final_impulse.y, -200.0)
		Events.camera_shake_requested.emit(clampf(raw_force.length() * 0.01, 2.0, 4.5), 0.10)
		Events.hit_stop_requested.emit(0.03)

	current_energy = minf(max_energy, current_energy + energy_gain)
	_is_rebounding = true

	Events.rebound_energy_changed.emit(current_energy / max_energy)
	Events.rebound_impact_received.emit(final_impulse, energy_gain)
	Events.combo_incremented.emit(combo_count, get_combo_multiplier() * 100.0)

	rebound_absorbed.emit(energy_gain, final_impulse)
	combo_increased.emit(combo_count, get_combo_multiplier())

	if current_energy >= max_energy * 0.99:
		counterstrike_ready.emit(1.0)

	return final_impulse

func gain_strike_energy(amount: float) -> void:
	current_energy = minf(max_energy, current_energy + amount)
	_combo_timer = combo_timeout
	combo_count += 1
	Events.rebound_energy_changed.emit(current_energy / max_energy)
	Events.combo_incremented.emit(combo_count, get_combo_multiplier() * 100.0)

func spend_counterstrike() -> Dictionary:
	if current_energy <= 15.0:
		return {"success": false, "damage_bonus": 0, "energy_spent": 0.0}

	var ratio: float = current_energy / max_energy
	var bonus_damage: int = int(round(ratio * 4.0)) + combo_count
	var spent: float = current_energy

	current_energy = 0.0
	Events.rebound_energy_changed.emit(0.0)
	Events.counterstrike_released.emit(ratio, Vector2.ZERO)

	return {
		"success": true,
		"damage_bonus": bonus_damage,
		"energy_spent": spent,
		"ratio": ratio
	}

func get_combo_multiplier() -> float:
	return minf(max_combo_multiplier, 1.0 + (combo_count * 0.35))

func notify_grounded() -> void:
	# Ground touch doesn't instantly wipe combo; gives grace period for chained hops
	_is_rebounding = false

func _reset_combo() -> void:
	if combo_count > 0:
		combo_count = 0
		Events.combo_reset.emit()
