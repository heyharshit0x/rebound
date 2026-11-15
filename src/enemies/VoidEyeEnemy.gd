class_name VoidEyeEnemy
extends CharacterBody2D

## Eldritch floating eye that hovers, fires piercing void laser beams,
## and summons gravitational distortion singularities.

signal defeated

enum State { HOVER, CHARGE_BEAM, RECOVER, HURT, DEAD }

@export var max_health: int = 5
@export var hover_speed: float = 38.0
@export var detection_range: float = 210.0
@export var attack_range: float = 175.0
@export var beam_cooldown: float = 2.6

var current_health: int = 5
var current_state: State = State.HOVER
var _anchor_pos: Vector2
var _sine_time: float = 0.0
var _cooldown_timer: float = 1.0
var _charge_timer: float = 0.0
var _player_ref: CharacterBody2D = null

const BEAM_SCENE: PackedScene = preload("res://src/enemies/VoidBeamProjectile.tscn")

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
	_sine_time += delta * 2.0
	_find_player()

	match current_state:
		State.HOVER:
			_process_hover(delta)
		State.CHARGE_BEAM:
			_process_charge(delta)
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
	var target_pos: Vector2 = _anchor_pos + Vector2(cos(_sine_time) * 30.0, sin(_sine_time * 1.4) * 18.0)
	global_position = global_position.move_toward(target_pos, hover_speed * delta)

	if _player_ref:
		sprite.flip_h = (_player_ref.global_position.x < global_position.x)
		var dist: float = global_position.distance_to(_player_ref.global_position)
		if dist <= attack_range and _cooldown_timer <= 0.0:
			_start_beam_charge()

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

func _start_beam_charge() -> void:
	current_state = State.CHARGE_BEAM
	_charge_timer = 0.5
	velocity = Vector2.ZERO

	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.5, 0.4, 3.0, 1.0), 0.45)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.28, 0.28), 0.45)
	VFX.play(&"plasma_ball", global_position, {"scale": Vector2(0.25, 0.25)})

func _process_charge(delta: float) -> void:
	_charge_timer -= delta
	if _charge_timer <= 0.0:
		_fire_beam()

func _fire_beam() -> void:
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2(0.24, 0.24)
	_cooldown_timer = beam_cooldown
	current_state = State.RECOVER

	if _player_ref:
		var aim_pos: Vector2 = _player_ref.global_position + Vector2(0, -10)
		var aim_dir: Vector2 = (aim_pos - global_position).normalized()
		var beam: VoidBeamProjectile = BEAM_SCENE.instantiate() as VoidBeamProjectile
		beam.direction = aim_dir
		beam.global_position = global_position + aim_dir * 16.0
		var root: Node = get_tree().current_scene
		if root:
			root.add_child(beam)

	Events.camera_shake_requested.emit(3.0, 0.12)

func _process_recover(delta: float) -> void:
	global_position = global_position.move_toward(_anchor_pos, 45.0 * delta)
	if global_position.distance_to(_anchor_pos) < 15.0:
		current_state = State.HOVER

func _process_hurt(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	_charge_timer -= delta
	if _charge_timer <= 0.0:
		current_state = State.HOVER

func _on_damaged(damage: int, knockback: Vector2, _parriable: bool, _hb: Hitbox) -> void:
	if current_state == State.DEAD:
		return

	current_health -= damage
	if health_bar:
		health_bar.value = float(maxi(0, current_health))
	current_state = State.HURT
	_charge_timer = 0.2
	velocity = knockback.normalized() * 120.0

	sprite.modulate = Color(3.0, 1.0, 3.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.8, 1.1, 2.4, 1.0), 0.15)

	_spawn_damage_text(damage)
	VFX.play(&"hit_spark", global_position, {"scale": Vector2(0.32, 0.32)})

	# Void Singularity and Dimensional Tornado cyclone trigger at low health
	if current_health == 2:
		VFX.play(&"dimensional_tornado", global_position + Vector2(0, -32), {
			"scale": Vector2(0.48, 0.48),
			"z_index": 8
		})
		VFX.play(&"void_singularity", global_position, {
			"scale": Vector2(0.4, 0.4),
			"z_index": 9
		})
		Events.camera_shake_requested.emit(5.0, 0.25)

	if current_health <= 0:
		_die()

func _die() -> void:
	current_state = State.DEAD
	set_physics_process(false)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	VFX.play(&"enemy_death_poof", global_position, {"scale": Vector2(0.42, 0.42)})
	VFX.play(&"core_dark_explosion", global_position, {"scale": Vector2(0.35, 0.35)})
	Events.score_awarded.emit(150, &"void_eye_shattered")
	defeated.emit()
	queue_free()

func _spawn_damage_text(amount: int) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.9, 0.4, 1.0, 1.0))
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
