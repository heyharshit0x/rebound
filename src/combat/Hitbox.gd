@warning_ignore("unused_signal")
class_name Hitbox
extends Area2D

## Modular combat trigger for damaging actors and delivering impulses.
## Tagged with factions to strictly prevent friendly fire and self-hits.

signal hit_landed(target_hurtbox: Hurtbox)

enum Faction { PLAYER, ENEMY, NEUTRAL }

@export_group("Combat Attributes")
@export var faction: Faction = Faction.PLAYER
@export var damage: int = 1
@export var knockback_force: float = 380.0
@export var knockback_direction: Vector2 = Vector2.RIGHT
@export var is_parriable: bool = true
@export var is_heavy_impact: bool = false
@export var hit_stop_duration: float = 0.08
@export var is_active: bool = true

func _init() -> void:
	collision_layer = 4   # Layer 3: Hitboxes
	collision_mask = 0

func set_active(active: bool) -> void:
	is_active = active
	set_deferred("monitoring", active)
	set_deferred("monitorable", active)
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not active)

func get_impact_velocity(attacker_facing: int) -> Vector2:
	var dir: Vector2 = knockback_direction.normalized()
	dir.x *= attacker_facing
	return dir * knockback_force
