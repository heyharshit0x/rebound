@warning_ignore("unused_signal")
extends Node

## Global Event Bus for decoupled cross-system communication.
## Connect listeners in _ready() and emit via Events.<signal_name>.emit(...)

# --- Combat & Rebound Core ---
signal player_health_changed(current: int, max_health: int)
signal player_damaged(amount: int, knockback: Vector2)
signal player_died
signal second_chance_triggered(revive_position: Vector2)
signal power_cooldown_ticked(powers: Dictionary)

signal rebound_energy_changed(current_ratio: float)
signal rebound_impact_received(impact_vector: Vector2, absorbed_energy: float)
signal rebound_bounce_executed(combo_count: int, bounce_velocity: Vector2)
signal parry_executed(success: bool, contact_point: Vector2)
signal counterstrike_released(charge_ratio: float, origin: Vector2)

# --- Scoring & Combo Feedback ---
signal combo_incremented(combo_count: int, points: float)
signal combo_reset
signal score_awarded(points: int, reason: StringName)

# --- Juice & Game Feel ---
signal camera_shake_requested(intensity: float, duration: float)
signal hit_stop_requested(freeze_duration: float)
signal impact_frame_triggered

# --- Level & Progression ---
signal checkpoint_activated(checkpoint_id: StringName, spawn_coords: Vector2)
signal core_fragment_collected(fragment_id: StringName)
signal level_completed(level_index: int, stars: int, clear_time: float)
signal boss_health_updated(current: float, max_value: float)
