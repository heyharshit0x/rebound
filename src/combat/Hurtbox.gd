class_name Hurtbox
extends Area2D

## Receives hostile damage and impact forces from incoming Hitboxes.
## Ignores strikes from the same faction, inactive triggers, and self-owned hitboxes.

signal damaged(damage: int, knockback: Vector2, is_parriable: bool, hitbox: Hitbox)

enum Faction { PLAYER, ENEMY, NEUTRAL }

@export var faction: Faction = Faction.PLAYER
@export var is_invulnerable: bool = false
@export var is_parrying: bool = false

func _init() -> void:
	collision_layer = 2   # Layer 2: Hurtboxes
	collision_mask = 4    # Layer 3: Hitboxes
	monitoring = true
	monitorable = true

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _physics_process(_delta: float) -> void:
	if is_invulnerable:
		return

	# Re-check ongoing overlaps when i-frames expire (e.g. standing in spikes or inside enemy collision)
	for area in get_overlapping_areas():
		if area is Hitbox:
			if _try_receive_hit(area as Hitbox):
				break

func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		_try_receive_hit(area as Hitbox)

func _try_receive_hit(hitbox: Hitbox) -> bool:
	if is_invulnerable:
		return false

	if not hitbox.monitorable or not hitbox.is_active:
		return false

	# Strictly ignore friendly fire and self-damage
	if hitbox.owner == owner or hitbox.get_parent() == get_parent():
		return false
	if hitbox.faction == faction and faction != Faction.NEUTRAL:
		return false

	var facing: int = -1 if hitbox.global_position.x > global_position.x else 1
	var impulse: Vector2 = hitbox.get_impact_velocity(facing)

	hitbox.hit_landed.emit(self)
	damaged.emit(hitbox.damage, impulse, hitbox.is_parriable, hitbox)
	if faction == Faction.ENEMY:
		AudioManager.play_sfx(&"hit", 2.5)
	return true
