class_name WispEnemy
extends CharacterBody2D

## Floating spectral enemy that patrols airspace and fires parriable plasma orbs.

signal defeated

enum State { PATROL, CHASE, TELEGRAPH, SHOOT_COOLDOWN, HURT, DEAD }

@export var max_health: int = 3
@export var patrol_distance: float = 60.0
@export var patrol_speed: float = 40.0
@export var chase_speed: float = 60.0
@export var detection_range: float = 160.0
@export var shoot_range: float = 140.0
@export var attack_cooldown: float = 2.4

var current_health: int = 3
var current_state: State = State.PATROL
var _anchor_position: Vector2
var _patrol_dir: int = 1
var _sine_time: float = 0.0
var _cooldown_timer: float = 1.0
var _telegraph_timer: float = 0.0
var _hurt_timer: float = 0.0
var _player_ref: CharacterBody2D = null

const PROJECTILE_SCENE: PackedScene = preload("res://src/enemies/WispProjectile.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health_bar: ProgressBar = $OverheadBar/HealthBar

func _ready() -> void:
	current_health = max_health
	if health_bar:
		health_bar.max_value = float(max_health)
		health_bar.value = float(current_health)
	_anchor_position = global_position
	hurtbox.damaged.connect(_on_damaged)
	sprite.play("default")

func _physics_process(delta: float) -> void:
	_sine_time += delta * 2.2
	_find_player()

	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.SHOOT_COOLDOWN:
			_process_shoot_cooldown(delta)
		State.HURT:
			_process_hurt(delta)

	move_and_slide()

func _find_player() -> void:
	if _player_ref == null:
		var node: Node = get_tree().get_first_node_in_group("player")
		if node and node is CharacterBody2D:
			_player_ref = node as CharacterBody2D

func _process_patrol(_delta: float) -> void:
	var offset_x: float = global_position.x - _anchor_position.x
	if offset_x > patrol_distance:
		_patrol_dir = -1
	elif offset_x < -patrol_distance:
		_patrol_dir = 1

	velocity.x = _patrol_dir * patrol_speed
	velocity.y = sin(_sine_time) * 18.0
	sprite.flip_h = (_patrol_dir < 0)

	if _player_ref and global_position.distance_to(_player_ref.global_position) < detection_range:
		current_state = State.CHASE

func _process_chase(delta: float) -> void:
	if not _player_ref:
		current_state = State.PATROL
		return

	var dist: float = global_position.distance_to(_player_ref.global_position)
	if dist > detection_range * 1.5:
		current_state = State.PATROL
		return

	# Spectral blink retreat when player rushes in too close
	if dist < 42.0:
		var escape_dir: Vector2 = (global_position - _player_ref.global_position).normalized()
		VFX.play(&"enemy_death_poof", global_position, {"scale": Vector2(0.25, 0.25)})
		global_position += escape_dir * 70.0
		global_position.y = clampf(global_position.y, 40.0, 210.0)
		VFX.play(&"plasma_ball", global_position, {"scale": Vector2(0.25, 0.25)})
		return

	var to_player: Vector2 = (_player_ref.global_position - global_position).normalized()
	velocity.x = move_toward(velocity.x, to_player.x * chase_speed, 180.0 * delta)
	velocity.y = move_toward(velocity.y, (to_player.y * chase_speed * 0.5) + sin(_sine_time) * 14.0, 180.0 * delta)
	sprite.flip_h = (velocity.x < 0)

	if dist <= shoot_range and _cooldown_timer <= 0.0:
		_start_telegraph()

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

func _start_telegraph() -> void:
	current_state = State.TELEGRAPH
	_telegraph_timer = 0.45
	velocity = Vector2.ZERO

	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 1.4, 3.0, 1.0), 0.4)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.3, 0.3), 0.4)

func _process_telegraph(delta: float) -> void:
	_telegraph_timer -= delta
	if _telegraph_timer <= 0.0:
		_fire_projectile()

func _fire_projectile() -> void:
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2(0.24, 0.24)

	if _player_ref:
		var root: Node = get_tree().current_scene
		var aim_pos: Vector2 = _player_ref.global_position + Vector2(0, -12)
		var base_dir: Vector2 = (aim_pos - global_position).normalized()

		# Triple barrage spread
		for angle_offset in [-0.24, 0.0, 0.24]:
			var proj: WispProjectile = PROJECTILE_SCENE.instantiate() as WispProjectile
			proj.direction = base_dir.rotated(angle_offset)
			proj.global_position = global_position
			if root:
				root.add_child(proj)

		VFX.play(&"plasma_ball", global_position, {"scale": Vector2(0.32, 0.32)})
		Events.camera_shake_requested.emit(2.2, 0.1)

	_cooldown_timer = attack_cooldown
	current_state = State.SHOOT_COOLDOWN

func _process_shoot_cooldown(delta: float) -> void:
	_cooldown_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)
	velocity.y = sin(_sine_time) * 12.0

	if _cooldown_timer <= attack_cooldown - 0.6:
		current_state = State.CHASE

func _process_hurt(delta: float) -> void:
	_hurt_timer -= delta
	velocity = velocity.move_toward(Vector2.ZERO, 350.0 * delta)
	if _hurt_timer <= 0.0:
		current_state = State.CHASE

func _on_damaged(damage: int, knockback: Vector2, _is_parriable: bool, _hitbox: Hitbox) -> void:
	if current_state == State.DEAD:
		return

	current_health -= damage
	if health_bar:
		health_bar.value = float(maxi(0, current_health))
	_hurt_timer = 0.25
	current_state = State.HURT

	velocity = knockback.normalized() * 120.0
	sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.1, 2.0, 2.6, 1.0), 0.2)

	_spawn_damage_text(damage)
	VFX.play(&"hit_spark", global_position, {"scale": Vector2(0.3, 0.3)})

	if current_health <= 0:
		_die()

func _die() -> void:
	current_state = State.DEAD
	set_physics_process(false)
	VFX.play(&"enemy_death_poof", global_position, {"scale": Vector2(0.38, 0.38)})
	Events.score_awarded.emit(100, &"wisp_banished")
	defeated.emit()
	queue_free()

func _spawn_damage_text(amount: int) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1.0))
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
