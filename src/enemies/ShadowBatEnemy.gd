class_name ShadowBatEnemy
extends CharacterBody2D

## Rapid, erratic aerial bat that roosts near ceilings and dives down in predatory swoops.
## Parriable upon descent for massive rebound momentum.

signal defeated

enum State { ROOST, SWOOP, SCREECH, RETREAT, HURT, DEAD }

@export var max_health: int = 3
@export var swoop_speed: float = 210.0
@export var retreat_speed: float = 95.0
@export var detection_range: float = 160.0

var current_health: int = 3
var current_state: State = State.ROOST
var _roost_pos: Vector2
var _dive_dir: Vector2 = Vector2.ZERO
var _screech_timer: float = 0.0
var _cooldown_timer: float = 0.8
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
	_roost_pos = global_position
	hurtbox.damaged.connect(_on_damaged)
	sprite.play("default")

func _physics_process(delta: float) -> void:
	_find_player()

	match current_state:
		State.ROOST:
			_process_roost(delta)
		State.SWOOP:
			_process_swoop(delta)
		State.SCREECH:
			_process_screech(delta)
		State.RETREAT:
			_process_retreat(delta)
		State.HURT:
			_process_hurt(delta)

	move_and_slide()

func _find_player() -> void:
	if _player_ref == null:
		var node: Node = get_tree().get_first_node_in_group("player")
		if node and node is CharacterBody2D:
			_player_ref = node as CharacterBody2D

func _process_roost(delta: float) -> void:
	velocity = Vector2.ZERO
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		return

	if _player_ref:
		sprite.flip_h = (_player_ref.global_position.x < global_position.x)
		var dist: float = global_position.distance_to(_player_ref.global_position)
		if dist <= detection_range:
			_start_swoop()

func _start_swoop() -> void:
	current_state = State.SWOOP
	if _player_ref:
		_dive_dir = ((_player_ref.global_position + Vector2(0, -8)) - global_position).normalized()
	velocity = _dive_dir * swoop_speed
	hitbox.set_active(true)
	VFX.play(&"hit_spark", global_position, {"scale": Vector2(0.25, 0.25)})

func _process_swoop(delta: float) -> void:
	if is_on_floor() or is_on_wall() or global_position.y >= 235.0:
		_enter_screech()
		return

	if velocity.length() < 70.0:
		_enter_screech()
		return

	velocity = velocity.move_toward(Vector2.ZERO, 120.0 * delta)

func _enter_screech() -> void:
	current_state = State.SCREECH
	_screech_timer = 0.35
	velocity = Vector2.ZERO
	hitbox.set_active(false)
	VFX.play(&"plasma_ball", global_position, {"scale": Vector2(0.28, 0.28)})
	Events.camera_shake_requested.emit(2.0, 0.1)

func _process_screech(delta: float) -> void:
	_screech_timer -= delta
	if _screech_timer <= 0.0:
		current_state = State.RETREAT

func _process_retreat(delta: float) -> void:
	global_position = global_position.move_toward(_roost_pos, retreat_speed * delta)
	if global_position.distance_to(_roost_pos) < 10.0:
		current_state = State.ROOST
		_cooldown_timer = 1.8

func _process_hurt(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 350.0 * delta)
	_screech_timer -= delta
	if _screech_timer <= 0.0:
		current_state = State.RETREAT

func _on_damaged(damage: int, knockback: Vector2, _parriable: bool, _hb: Hitbox) -> void:
	if current_state == State.DEAD:
		return

	current_health -= damage
	if health_bar:
		health_bar.value = float(maxi(0, current_health))
	current_state = State.HURT
	_screech_timer = 0.2
	hitbox.set_active(false)
	velocity = knockback.normalized() * 150.0

	sprite.modulate = Color(3.0, 2.0, 2.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.2, 0.8, 1.8, 1.0), 0.15)

	_spawn_damage_text(damage)
	VFX.play(&"hit_spark", global_position, {"scale": Vector2(0.3, 0.3)})

	if current_health <= 0:
		_die()

func _die() -> void:
	current_state = State.DEAD
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	VFX.play(&"enemy_death_poof", global_position, {"scale": Vector2(0.35, 0.35)})
	Events.score_awarded.emit(100, &"shadow_bat_slain")
	defeated.emit()
	queue_free()

func _spawn_damage_text(amount: int) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 25
	label.top_level = true
	label.global_position = global_position + Vector2(randf_range(-6, 6) - 10, -20)

	var parent: Node = get_tree().current_scene if get_tree().current_scene else self
	parent.add_child(label)

	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 16.0, 0.35)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(label.queue_free)
