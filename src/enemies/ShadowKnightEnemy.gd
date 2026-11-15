class_name ShadowKnightEnemy
extends CharacterBody2D

## Corrupted mirror-knight rival guarding the steel key and void portal.
## Employs player combat mechanics: sword combos, high-speed afterimage dash,
## shield block/parry counter, and heavy cleave ground slams.

signal defeated

enum AIState {
	PATROL,
	APPROACH,
	SWORD_COMBO,
	DASH_EVADE,
	SHIELD_GUARD,
	GROUND_SLAM,
	HURT,
	DEAD
}

@export var max_health: int = 40
@export var move_speed: float = 135.0
@export var dash_speed: float = 340.0
@export var detection_range: float = 240.0
@export var attack_range: float = 46.0

var current_health: int = 40
var current_state: AIState = AIState.PATROL
var facing_direction: int = -1

var _state_timer: float = 0.0
var _cooldown_dash: float = 0.0
var _cooldown_guard: float = 0.0
var _cooldown_attack: float = 0.0
var _cooldown_slam: float = 0.0
var _cooldown_jump: float = 0.0
var _slam_has_left_floor: bool = false
var _dash_trail_timer: float = 0.0
var _combo_step: int = 0
var _player_ref: CharacterBody2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var sword_hitbox: Hitbox = $SwordHitbox
@onready var health_bar: ProgressBar = $OverheadBar/HealthBar
@onready var title_label: Label = $OverheadBar/TitleLabel

func _ready() -> void:
	current_health = max_health
	hurtbox.damaged.connect(_on_damaged)
	sword_hitbox.hit_landed.connect(_on_hit_landed)
	sword_hitbox.set_active(false)

	health_bar.max_value = float(max_health)
	health_bar.value = float(current_health)
	_enter_state(AIState.PATROL)

func _physics_process(delta: float) -> void:
	_update_cooldowns(delta)
	_find_player()

	if not is_on_floor() and current_state != AIState.DASH_EVADE:
		velocity.y += 980.0 * delta

	match current_state:
		AIState.PATROL:
			_process_patrol(delta)
		AIState.APPROACH:
			_process_approach(delta)
		AIState.SWORD_COMBO:
			_process_sword_combo(delta)
		AIState.DASH_EVADE:
			_process_dash_evade(delta)
		AIState.SHIELD_GUARD:
			_process_shield_guard(delta)
		AIState.GROUND_SLAM:
			_process_ground_slam(delta)
		AIState.HURT:
			_process_hurt(delta)
		AIState.DEAD:
			velocity = Vector2.ZERO

	move_and_slide()

func _update_cooldowns(delta: float) -> void:
	if _cooldown_dash > 0.0:
		_cooldown_dash -= delta
	if _cooldown_guard > 0.0:
		_cooldown_guard -= delta
	if _cooldown_attack > 0.0:
		_cooldown_attack -= delta
	if _cooldown_slam > 0.0:
		_cooldown_slam -= delta
	if _cooldown_jump > 0.0:
		_cooldown_jump -= delta

func _find_player() -> void:
	if _player_ref == null:
		var node: Node = get_tree().get_first_node_in_group("player")
		if node and node is CharacterBody2D:
			_player_ref = node as CharacterBody2D

func _face_player() -> void:
	if not _player_ref:
		return
	var dir_x: float = signf(_player_ref.global_position.x - global_position.x)
	if absf(dir_x) > 0.01:
		_set_facing(int(dir_x))

func _process_patrol(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	sprite.play("idle")

	if _player_ref:
		var dist: float = global_position.distance_to(_player_ref.global_position)
		if dist <= detection_range:
			_face_player()
			_enter_state(AIState.APPROACH)

func _process_approach(delta: float) -> void:
	if not _player_ref:
		_enter_state(AIState.PATROL)
		return

	_face_player()
	var dist: float = global_position.distance_to(_player_ref.global_position)
	var dy: float = _player_ref.global_position.y - global_position.y

	# High/low leap ground slam if player is below or at distance
	if (dy > 30.0 or (dist > 80.0 and dist < 210.0)) and _cooldown_slam <= 0.0 and is_on_floor():
		_cooldown_slam = 3.6
		_enter_state(AIState.GROUND_SLAM)
		return

	# Vertical platform hop to pursue player on elevated ledges
	if dy < -32.0 and is_on_floor() and absf(_player_ref.global_position.x - global_position.x) < 180.0:
		if _cooldown_jump <= 0.0:
			_cooldown_jump = 1.4
			velocity.y = -430.0
			velocity.x = facing_direction * 150.0
			sprite.play("jump")
			return

	# Tactical afterimage dash close or evade
	if dist > 70.0 and dist < 160.0 and _cooldown_dash <= 0.0 and absf(dy) < 40.0:
		_cooldown_dash = 2.4
		_enter_state(AIState.DASH_EVADE)
		return

	# Close quarters sword combo
	if dist <= attack_range and _cooldown_attack <= 0.0 and absf(dy) < 32.0:
		_cooldown_attack = 1.1
		_enter_state(AIState.SWORD_COMBO)
		return

	# Overcome walls, steps, or platform ledges
	if is_on_wall() and is_on_floor():
		velocity.y = -340.0
		velocity.x = facing_direction * move_speed * 1.2
	else:
		velocity.x = move_toward(velocity.x, facing_direction * move_speed, 650.0 * delta)

	sprite.play("run" if is_on_floor() else ("jump" if velocity.y < 0.0 else "fall"))

func _process_sword_combo(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	_state_timer -= delta

	if _state_timer <= 0.0:
		sword_hitbox.set_active(false)
		if _combo_step == 1 and _player_ref and global_position.distance_to(_player_ref.global_position) <= attack_range * 1.5:
			# Combo step 2: Face player and release double flame slash follow-up
			_face_player()
			_combo_step = 2
			_state_timer = 0.32
			sprite.play("attack_sword")
			velocity.x = facing_direction * 140.0
			sword_hitbox.damage = 18
			sword_hitbox.set_active(true)
			VFX.play(&"double_slash", global_position + Vector2(facing_direction * 20, -22), {
				"flip_h": facing_direction < 0,
				"scale": Vector2(0.42, 0.42),
				"modulate": Color(2.0, 0.5, 0.8, 1.0)
			})
			Events.camera_shake_requested.emit(3.0, 0.1)
		else:
			_combo_step = 0
			_enter_state(AIState.APPROACH)

func _process_dash_evade(delta: float) -> void:
	_state_timer -= delta
	velocity.y = 0.0

	_dash_trail_timer -= delta
	if _dash_trail_timer <= 0.0:
		_dash_trail_timer = 0.04
		VFX.play(&"dash_trail", global_position + Vector2(-facing_direction * 16.0, -20.0), {
			"flip_h": facing_direction < 0,
			"scale": Vector2(0.38, 0.38),
			"lifetime": 0.16,
			"modulate": Color(2.0, 0.4, 0.8, 0.85),
			"z_index": 2
		})

	if _state_timer <= 0.0:
		_enter_state(AIState.APPROACH)

func _process_shield_guard(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 450.0 * delta)
	_state_timer -= delta

	if _state_timer <= 0.0:
		hurtbox.is_parrying = false
		_enter_state(AIState.APPROACH)

func _process_ground_slam(delta: float) -> void:
	_state_timer -= delta

	if not is_on_floor():
		_slam_has_left_floor = true

	# Transition from jump apex to aggressive downward plunge
	if velocity.y > 0.0:
		sprite.play("fall")
		velocity.y = minf(560.0, velocity.y + 850.0 * delta)

	# Only trigger impact when hitting the floor after being airborne
	var impact_ready: bool = (_slam_has_left_floor and is_on_floor() and velocity.y >= 0.0)
	if impact_ready or _state_timer <= 0.0:
		velocity.x = 0.0
		if is_on_floor():
			# Ground slam shockwave ring rests flush on the ground surface at foot level
			VFX.play(&"ground_slam", global_position + Vector2(0, -40), {
				"scale": Vector2(0.65, 0.65),
				"modulate": Color(2.2, 0.5, 0.8, 1.0),
				"z_index": 8
			})
			VFX.play(&"heavy_landing", global_position + Vector2(0, -8), {
				"scale": Vector2(0.5, 0.5),
				"z_index": 9
			})
			Events.camera_shake_requested.emit(5.5, 0.18)

			if _player_ref and global_position.distance_to(_player_ref.global_position) <= 90.0:
				var kb: Vector2 = (_player_ref.global_position - global_position).normalized() * 340.0 + Vector2(0, -140)
				var p_hurt: Hurtbox = _player_ref.get_node_or_null("Hurtbox") as Hurtbox
				if p_hurt:
					p_hurt.damaged.emit(18, kb, true, sword_hitbox)

		_enter_state(AIState.APPROACH)

func _process_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(AIState.APPROACH)

func _enter_state(new_state: AIState) -> void:
	current_state = new_state

	match current_state:
		AIState.PATROL:
			sprite.play("idle")
		AIState.APPROACH:
			_face_player()
			sprite.play("run")
		AIState.SWORD_COMBO:
			_face_player()
			_combo_step = 1
			_state_timer = 0.28
			sprite.play("attack_sword")
			velocity.x = facing_direction * 110.0
			sword_hitbox.damage = 14
			sword_hitbox.set_active(true)
			VFX.play(&"sword_slash", global_position + Vector2(facing_direction * 18, -20), {
				"flip_h": facing_direction < 0,
				"scale": Vector2(0.36, 0.36),
				"modulate": Color(2.0, 0.6, 0.9, 1.0)
			})
		AIState.DASH_EVADE:
			_face_player()
			sprite.play("dash")
			_state_timer = 0.18
			_dash_trail_timer = 0.0
			velocity = Vector2(facing_direction * dash_speed, 0.0)
		AIState.SHIELD_GUARD:
			_face_player()
			sprite.play("parry")
			hurtbox.is_parrying = true
			_state_timer = 0.45
			VFX.play(&"shield_block", global_position + Vector2(facing_direction * 14, -20), {
				"flip_h": facing_direction < 0,
				"scale": Vector2(0.4, 0.4),
				"lifetime": 0.45,
				"modulate": Color(2.2, 0.4, 0.9, 1.0),
				"z_index": 7
			})
		AIState.GROUND_SLAM:
			_face_player()
			sprite.play("jump")
			_state_timer = 1.5
			_slam_has_left_floor = false
			velocity = Vector2(facing_direction * 190.0, -310.0)
		AIState.HURT:
			sprite.play("hurt")
			_state_timer = 0.16
		AIState.DEAD:
			_die()

func _set_facing(new_facing: int) -> void:
	if new_facing == 0 or new_facing == facing_direction:
		return
	facing_direction = new_facing
	sprite.flip_h = (facing_direction < 0)
	sword_hitbox.position.x = absf(sword_hitbox.position.x) * facing_direction

func _on_damaged(damage: int, knockback: Vector2, _is_parriable: bool, _hitbox: Hitbox) -> void:
	if current_health <= 0:
		return

	# Immediately turn to face the attacker
	if knockback.x != 0.0:
		_set_facing(-1 if knockback.x > 0.0 else 1)
	elif _player_ref:
		_face_player()

	# If in shield guard, block or counter-parry!
	if hurtbox.is_parrying:
		hurtbox.is_parrying = false
		VFX.play(&"parry_clash", global_position + Vector2(facing_direction * 14, -22), {
			"scale": Vector2(0.42, 0.42),
			"modulate": Color(2.2, 0.5, 0.9, 1.0)
		})
		Events.camera_shake_requested.emit(4.0, 0.12)
		# Counter-strike immediate heavy cleave
		_enter_state(AIState.SWORD_COMBO)
		return

	current_health -= damage
	health_bar.value = float(current_health)

	# Chance to react with reactive guard or dash at mid health
	if current_health < max_health * 0.65 and _cooldown_guard <= 0.0 and randf() > 0.45:
		_cooldown_guard = 2.5
		_enter_state(AIState.SHIELD_GUARD)
		return

	velocity = knockback.normalized() * 120.0 + Vector2(0, -70.0)
	sprite.modulate = Color(3.0, 2.5, 2.5, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.85, 0.45, 0.75, 1.0), 0.18)

	_spawn_damage_text(damage)
	VFX.play(&"hit_spark", global_position + Vector2(0, -20), {
		"scale": Vector2(0.35, 0.35)
	})

	if current_health <= 0:
		_enter_state(AIState.DEAD)
	else:
		_enter_state(AIState.HURT)

func _die() -> void:
	set_physics_process(false)
	sword_hitbox.set_active(false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)

	# Spectacular boss defeat burst
	VFX.play(&"core_dark_explosion", global_position + Vector2(0, -20), {
		"scale": Vector2(0.55, 0.55),
		"z_index": 12
	})
	VFX.play(&"enemy_death_poof", global_position + Vector2(0, -20), {
		"scale": Vector2(0.5, 0.5),
		"z_index": 11
	})
	Events.camera_shake_requested.emit(6.5, 0.25)
	Events.score_awarded.emit(500, &"shadow_knight_defeated")
	defeated.emit()
	queue_free()

func _on_hit_landed(_target: Hurtbox) -> void:
	VFX.play(&"hit_spark", global_position + Vector2(facing_direction * 22, -20), {
		"scale": Vector2(0.35, 0.35)
	})

func _spawn_damage_text(amount: int) -> void:
	var label: Label = Label.new()
	label.text = str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 25
	label.top_level = true
	label.global_position = global_position + Vector2(randf_range(-10, 10), -38)
	var scene_parent: Node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else self
	scene_parent.add_child(label)

	var tween: Tween = label.create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 18, 0.35).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.12)
	tween.chain().tween_callback(label.queue_free)
