class_name SlimeEnemy
extends CharacterBody2D

## Ground crawling slime that hops toward the player and deals contact damage.

signal defeated

@export var max_health: int = 4
@export var hop_speed: float = 75.0
@export var gravity: float = 900.0
@export var hop_force: float = -220.0
@export var detection_range: float = 180.0

var current_health: int = 4
var _facing: int = -1
var _hop_timer: float = 1.0
var _hurt_timer: float = 0.0
var _player_ref: CharacterBody2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var health_bar: ProgressBar = $OverheadBar/HealthBar

func _ready() -> void:
	current_health = max_health
	if health_bar:
		health_bar.max_value = float(max_health)
		health_bar.value = float(current_health)
	hurtbox.damaged.connect(_on_damaged)
	sprite.play("default")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 450.0 * delta)

	if _hurt_timer > 0.0:
		_hurt_timer -= delta
		move_and_slide()
		return

	_find_player()
	_update_hop_logic(delta)
	move_and_slide()

func _find_player() -> void:
	if _player_ref == null:
		var node: Node = get_tree().get_first_node_in_group("player")
		if node and node is CharacterBody2D:
			_player_ref = node as CharacterBody2D

func _update_hop_logic(delta: float) -> void:
	if is_on_floor():
		if _player_ref and global_position.distance_to(_player_ref.global_position) <= detection_range:
			_facing = -1 if _player_ref.global_position.x < global_position.x else 1
			sprite.flip_h = (_facing > 0)
		_hop_timer -= delta
		if _hop_timer <= 0.0:
			_execute_hop()

func _execute_hop() -> void:
	_hop_timer = randf_range(1.2, 1.8)

	if _player_ref:
		var dist: float = global_position.distance_to(_player_ref.global_position)
		if dist <= detection_range:
			_facing = -1 if _player_ref.global_position.x < global_position.x else 1
		else:
			if randf() > 0.5:
				_facing *= -1
	else:
		if randf() > 0.5:
			_facing *= -1

	sprite.flip_h = (_facing > 0)
	velocity.y = hop_force
	velocity.x = _facing * hop_speed

	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.32, 0.22), 0.08)
	tween.tween_property(sprite, "scale", Vector2(0.24, 0.32), 0.12)
	tween.tween_property(sprite, "scale", Vector2(0.28, 0.28), 0.15)

func _on_damaged(damage: int, knockback: Vector2, _is_parriable: bool, _hitbox: Hitbox) -> void:
	if current_health <= 0:
		return

	current_health -= damage
	if health_bar:
		health_bar.value = float(maxi(0, current_health))
	_hurt_timer = 0.2
	velocity = knockback.normalized() * 140.0 + Vector2(0, -90.0)

	sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.3, 2.3, 0.9, 1.0), 0.15)

	_spawn_damage_text(damage)
	VFX.play(&"hit_spark", global_position + Vector2(0, -10), {"scale": Vector2(0.3, 0.3)})

	# Enrage at low health
	if current_health <= 2 and current_health > 0:
		hop_speed = 115.0
		hop_force = -260.0
		sprite.modulate = Color(2.2, 0.35, 0.35, 1.0)
		VFX.play(&"hit_flash", global_position + Vector2(0, -10), {"scale": Vector2(0.35, 0.35)})
		Events.camera_shake_requested.emit(3.0, 0.1)

	if current_health <= 0:
		_die()

func _die() -> void:
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	VFX.play(&"enemy_death_poof", global_position + Vector2(0, -10), {"scale": Vector2(0.36, 0.36)})
	Events.score_awarded.emit(80, &"slime_squashed")
	defeated.emit()
	queue_free()

func _spawn_damage_text(amount: int) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 25
	label.top_level = true
	label.global_position = global_position + Vector2(randf_range(-6, 6) - 10, -22)

	var parent: Node = get_tree().current_scene if get_tree().current_scene else self
	parent.add_child(label)

	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 16.0, 0.35)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(label.queue_free)
