class_name FlyingSkullEnemy
extends CharacterBody2D

## Aggressive flying demon skull that hovers and executes high-velocity dive-swoops.
## High risk, high reward: timed parry reflects the skull and gives massive rebound energy.

signal defeated

enum State { HOVER, TELEGRAPH, SWOOP, RECOVER, HURT, DEAD }

@export var max_health: int = 3
@export var hover_speed: float = 45.0
@export var swoop_speed: float = 240.0
@export var detection_range: float = 190.0

var current_health: int = 3
var current_state: State = State.HOVER
var _anchor_pos: Vector2
var _sine_time: float = 0.0
var _cooldown_timer: float = 1.0
var _telegraph_timer: float = 0.0
var _swoop_dir: Vector2 = Vector2.ZERO
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
	_anchor_pos = global_position
	hurtbox.damaged.connect(_on_damaged)
	sprite.play("default")

func _physics_process(delta: float) -> void:
	_sine_time += delta * 2.5
	_find_player()

	match current_state:
		State.HOVER:
			_process_hover(delta)
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.SWOOP:
			_process_swoop(delta)
		State.RECOVER:
			_process_recover(delta)
		State.HURT:
			_process_hurt(delta)

	move_and_slide()

func _find_player() -> void:
	if _player_ref == null:
		var node: Node = get_tree().get_first_node_in_group("player")
		if node and node is CharacterBody2D:
			_player_ref = node as CharacterBody2D

func _process_hover(delta: float) -> void:
	var target_pos: Vector2 = _anchor_pos + Vector2(cos(_sine_time) * 35.0, sin(_sine_time * 1.5) * 16.0)
	global_position = global_position.move_toward(target_pos, hover_speed * delta)

	if _player_ref:
		sprite.flip_h = (_player_ref.global_position.x < global_position.x)
		var dist: float = global_position.distance_to(_player_ref.global_position)
		if dist <= detection_range and _cooldown_timer <= 0.0:
			_start_dive_telegraph()

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

func _start_dive_telegraph() -> void:
	current_state = State.TELEGRAPH
	_telegraph_timer = 0.4
	velocity = Vector2.ZERO

	if _player_ref:
		_swoop_dir = ((_player_ref.global_position + Vector2(0, -10)) - global_position).normalized()

	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(3.0, 0.5, 0.5, 1.0), 0.35)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.28, 0.28), 0.35)
	VFX.play(&"hit_spark", global_position, {"scale": Vector2(0.3, 0.3)})

func _process_telegraph(delta: float) -> void:
	_telegraph_timer -= delta
	if _telegraph_timer <= 0.0:
		_execute_dive()

func _execute_dive() -> void:
	current_state = State.SWOOP
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2(0.24, 0.24)
	velocity = _swoop_dir * swoop_speed
	hitbox.set_active(true)
	VFX.play(&"plasma_ball", global_position, {"scale": Vector2(0.3, 0.3)})
	Events.camera_shake_requested.emit(2.5, 0.1)

func _process_swoop(delta: float) -> void:
	if is_on_floor() or is_on_wall() or global_position.y >= 235.0:
		_enter_recover()
		return

	if velocity.length() < 80.0:
		_enter_recover()
		return

	velocity = velocity.move_toward(Vector2.ZERO, 90.0 * delta)

func _enter_recover() -> void:
	current_state = State.RECOVER
	_cooldown_timer = 2.2
	hitbox.set_active(false)
	velocity = Vector2(0, -110.0)

func _process_recover(delta: float) -> void:
	global_position = global_position.move_toward(_anchor_pos, 85.0 * delta)
	if global_position.distance_to(_anchor_pos) < 15.0:
		current_state = State.HOVER

func _process_hurt(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 350.0 * delta)
	_telegraph_timer -= delta
	if _telegraph_timer <= 0.0:
		current_state = State.HOVER

func _on_damaged(damage: int, knockback: Vector2, _parriable: bool, _hb: Hitbox) -> void:
	if current_state == State.DEAD:
		return

	current_health -= damage
	if health_bar:
		health_bar.value = float(maxi(0, current_health))
	current_state = State.HURT
	_telegraph_timer = 0.25
	hitbox.set_active(false)
	velocity = knockback.normalized() * 160.0

	sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.2, 1.9, 2.5, 1.0), 0.15)

	_spawn_damage_text(damage)
	VFX.play(&"hit_spark", global_position, {"scale": Vector2(0.32, 0.32)})

	if current_health <= 0:
		_die()

func _die() -> void:
	current_state = State.DEAD
	set_physics_process(false)
	hitbox.set_active(false)
	VFX.play(&"enemy_death_poof", global_position, {"scale": Vector2(0.4, 0.4)})
	VFX.play(&"core_dark_explosion", global_position, {"scale": Vector2(0.3, 0.3)})
	Events.score_awarded.emit(120, &"skull_vanquished")
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
