class_name PlayerController
extends CharacterBody2D

## Core CharacterBody2D controller implementing momentum absorption,
## input buffering, coyote forgiveness, and high-velocity rebound physics.

enum State {
	IDLE,
	RUN,
	AIR,
	PARRY,
	REBOUND_FLIGHT,
	ATTACK_SWORD,
	ATTACK_HAMMER,
	THRUST,
	GROUND_SLAM,
	BURST,
	DASH,
	HURT,
	DEAD
}

@export_group("Locomotion")
@export var move_speed: float = 175.0
@export var acceleration: float = 1400.0
@export var ground_friction: float = 1500.0
@export var air_acceleration: float = 950.0
@export var air_drag: float = 250.0

@export_group("Jump Physics")
@export var jump_force: float = -420.0
@export var jump_cut_multiplier: float = 0.5
@export var gravity: float = 980.0
@export var fall_gravity_multiplier: float = 1.3
@export var max_fall_speed: float = 500.0
@export var coyote_window: float = 0.14
@export var input_buffer_window: float = 0.14

@export_group("Combat & Cooldowns")
@export var max_health: int = 100
@export var parry_duration: float = 0.22
@export var dash_speed: float = 380.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.50
@export var parry_cooldown: float = 0.40
@export var thrust_cooldown: float = 0.70
@export var slam_cooldown: float = 0.80
@export var burst_cooldown: float = 1.00

var current_state: State = State.IDLE
var current_health: int = 100
var facing_direction: int = 1
var _jump_released: bool = false

# Input buffer timers (event-driven, preventing continuous action stuck states)
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _attack_buffer_timer: float = 0.0
var _hammer_buffer_timer: float = 0.0
var _parry_buffer_timer: float = 0.0
var _dash_buffer_timer: float = 0.0
var _burst_buffer_timer: float = 0.0
var _thrust_buffer_timer: float = 0.0
var _sword_combo_count: int = 0
var _sword_combo_window: float = 0.0

# Cooldown and state execution timers
var _state_timer: float = 0.0
var _invulnerability_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _parry_cooldown_timer: float = 0.0
var _thrust_cooldown_timer: float = 0.0
var _slam_cooldown_timer: float = 0.0
var _burst_cooldown_timer: float = 0.0
var _dash_trail_timer: float = 0.0
var _second_chance_available: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var sword_hitbox: Hitbox = $SwordHitbox
@onready var hammer_hitbox: Hitbox = $HammerHitbox
@onready var rebound_receiver: ReboundReceiver = $ReboundReceiver

func _ready() -> void:
	current_health = max_health
	Events.player_health_changed.emit(current_health, max_health)

	sword_hitbox.monitoring = false
	sword_hitbox.monitorable = false
	hammer_hitbox.monitoring = false
	hammer_hitbox.monitorable = false

	hurtbox.damaged.connect(_on_hurtbox_damaged)
	sword_hitbox.hit_landed.connect(_on_sword_hit_landed)
	hammer_hitbox.hit_landed.connect(_on_hammer_hit_landed)
	rebound_receiver.counterstrike_ready.connect(_on_counterstrike_ready)
	_enter_state(State.IDLE)

func _physics_process(delta: float) -> void:
	_update_timers(delta)

	if global_position.y > 320:
		_enter_state(State.DEAD)
		return

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.RUN:
			_process_run(delta)
		State.AIR:
			_process_air(delta)
		State.REBOUND_FLIGHT:
			_process_rebound_flight(delta)
		State.PARRY:
			_process_parry(delta)
		State.ATTACK_SWORD, State.ATTACK_HAMMER, State.THRUST:
			_process_attack(delta)
		State.GROUND_SLAM:
			_process_ground_slam(delta)
		State.BURST:
			_process_burst(delta)
		State.DASH:
			_process_dash(delta)
		State.HURT:
			_process_hurt(delta)

	move_and_slide()

	if is_on_floor() and current_state != State.REBOUND_FLIGHT:
		rebound_receiver.notify_grounded()

func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_window
	elif _coyote_timer > 0.0:
		_coyote_timer -= delta

	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta
	if _attack_buffer_timer > 0.0:
		_attack_buffer_timer -= delta
	if _hammer_buffer_timer > 0.0:
		_hammer_buffer_timer -= delta
	if _parry_buffer_timer > 0.0:
		_parry_buffer_timer -= delta
	if _dash_buffer_timer > 0.0:
		_dash_buffer_timer -= delta
	if _burst_buffer_timer > 0.0:
		_burst_buffer_timer -= delta
	if _thrust_buffer_timer > 0.0:
		_thrust_buffer_timer -= delta

	# Cooldown decrements
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)
	if _parry_cooldown_timer > 0.0:
		_parry_cooldown_timer = maxf(0.0, _parry_cooldown_timer - delta)
	if _thrust_cooldown_timer > 0.0:
		_thrust_cooldown_timer = maxf(0.0, _thrust_cooldown_timer - delta)
	if _slam_cooldown_timer > 0.0:
		_slam_cooldown_timer = maxf(0.0, _slam_cooldown_timer - delta)
	if _burst_cooldown_timer > 0.0:
		_burst_cooldown_timer = maxf(0.0, _burst_cooldown_timer - delta)

	Events.power_cooldown_ticked.emit({
		"dash": _dash_cooldown_timer,
		"parry": _parry_cooldown_timer,
		"thrust": _thrust_cooldown_timer,
		"slam": _slam_cooldown_timer,
		"burst": _burst_cooldown_timer,
		"max_dash": dash_cooldown,
		"max_parry": parry_cooldown,
		"max_thrust": thrust_cooldown,
		"max_slam": slam_cooldown,
		"max_burst": burst_cooldown
	})

	if _sword_combo_window > 0.0:
		_sword_combo_window -= delta
		if _sword_combo_window <= 0.0:
			_sword_combo_count = 0

	# Poll action just pressed directly so it NEVER depends on unhandled input delivery
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = input_buffer_window
	if Input.is_action_just_released("jump") and current_state == State.AIR:
		_jump_released = true
	if Input.is_action_just_pressed("attack"):
		_attack_buffer_timer = input_buffer_window
	if Input.is_action_just_pressed("hammer_attack"):
		_hammer_buffer_timer = input_buffer_window
	if Input.is_action_just_pressed("parry"):
		_parry_buffer_timer = input_buffer_window
	if Input.is_action_just_pressed("thrust_attack") or (Input.is_key_pressed(KEY_E) and _thrust_buffer_timer <= 0.0):
		_thrust_buffer_timer = input_buffer_window
	if Input.is_action_just_pressed("rebound_dash") or (Input.is_key_pressed(KEY_F) and _dash_buffer_timer <= 0.0):
		_dash_buffer_timer = input_buffer_window
	if Input.is_action_just_pressed("rebound_burst") or (Input.is_key_pressed(KEY_C) and _burst_buffer_timer <= 0.0):
		_burst_buffer_timer = input_buffer_window

	if _invulnerability_timer > 0.0:
		_invulnerability_timer -= delta
		sprite.visible = int(float(Time.get_ticks_msec()) / 60.0) % 2 == 0
		if _invulnerability_timer <= 0.0:
			_invulnerability_timer = 0.0
			hurtbox.is_invulnerable = false
			sprite.visible = true

func _get_move_input() -> float:
	var move: float = 0.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move += 1.0
	return move

# --- State Process Handlers ---
func _process_idle(delta: float) -> void:
	_apply_friction(delta)
	_apply_gravity(delta)

	if _try_combat_actions():
		return

	if _try_jump():
		return

	var move_input: float = _get_move_input()
	if absf(move_input) > 0.05:
		_enter_state(State.RUN)
		return

	if not is_on_floor():
		_enter_state(State.AIR)
		return

func _process_run(delta: float) -> void:
	var move_input: float = _get_move_input()
	if absf(move_input) < 0.05:
		_enter_state(State.IDLE)
		return

	_set_facing(signi(int(move_input)))
	velocity.x = move_toward(velocity.x, move_input * move_speed, acceleration * delta)
	_apply_gravity(delta)

	if _try_combat_actions():
		return

	if _try_jump():
		return

	if not is_on_floor():
		_enter_state(State.AIR)
		return

func _process_air(delta: float) -> void:
	var move_input: float = _get_move_input()
	if absf(move_input) > 0.05:
		_set_facing(signi(int(move_input)))
		velocity.x = move_toward(velocity.x, move_input * move_speed, air_acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, air_drag * delta)

	# Variable jump height cut on early button release — one-shot so we don't bleed momentum across frames
	if _jump_released and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
		_jump_released = false

	_apply_gravity(delta)

	if _try_combat_actions():
		return

	if is_on_floor():
		_enter_state(State.RUN if absf(velocity.x) > 15.0 else State.IDLE)
		return

func _process_rebound_flight(delta: float) -> void:
	if _state_timer > 0.0:
		_state_timer -= delta

	var move_input: float = _get_move_input()
	if absf(move_input) > 0.05:
		velocity.x = move_toward(velocity.x, move_input * (move_speed * 1.3), air_acceleration * delta)

	_apply_gravity(delta)

	if _try_combat_actions():
		return

	if _state_timer <= 0.0 and is_on_floor():
		_enter_state(State.RUN if absf(velocity.x) > 15.0 else State.IDLE)

func _process_parry(delta: float) -> void:
	_apply_friction(delta)
	_apply_gravity(delta)

	_state_timer -= delta
	if _state_timer <= 0.0:
		hurtbox.is_parrying = false
		_enter_state(State.IDLE if is_on_floor() else State.AIR)

func _process_attack(delta: float) -> void:
	_apply_friction(delta)
	_apply_gravity(delta)

	_state_timer -= delta
	if _state_timer <= 0.0:
		sword_hitbox.set_active(false)
		hammer_hitbox.set_active(false)
		_enter_state(State.IDLE if is_on_floor() else State.AIR)

func _process_dash(delta: float) -> void:
	_state_timer -= delta
	velocity.y = 0.0

	_dash_trail_timer -= delta
	if _dash_trail_timer <= 0.0:
		_dash_trail_timer = 0.045
		VFX.play(&"dash_trail", global_position + Vector2(-facing_direction * 14.0, -22.0), {
			"flip_h": facing_direction < 0,
			"scale": Vector2(0.35, 0.35),
			"lifetime": 0.14,
			"z_index": 2
		})

	if _state_timer <= 0.0:
		_enter_state(State.IDLE if is_on_floor() else State.AIR)

func _process_ground_slam(_delta: float) -> void:
	velocity.x = 0.0
	velocity.y = 540.0
	if is_on_floor():
		_execute_ground_slam_impact()
		_enter_state(State.IDLE)

func _process_burst(delta: float) -> void:
	_apply_friction(delta)
	_apply_gravity(delta)
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(State.IDLE if is_on_floor() else State.AIR)

func _process_hurt(delta: float) -> void:
	_apply_friction(delta)
	_apply_gravity(delta)

	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(State.IDLE if is_on_floor() else State.AIR)

func _enter_state(new_state: State) -> void:
	if current_state == State.PARRY and new_state != State.PARRY:
		hurtbox.is_parrying = false

	current_state = new_state

	match current_state:
		State.IDLE:
			sprite.play("idle")
		State.RUN:
			sprite.play("run")
		State.AIR:
			sprite.play("jump" if velocity.y < 0.0 else "fall")
		State.REBOUND_FLIGHT:
			sprite.play("rebound")
			_state_timer = 0.14
		State.PARRY:
			sprite.play("parry")
			hurtbox.is_parrying = true
			_state_timer = parry_duration
			VFX.play(&"shield_block", global_position + Vector2(facing_direction * 12, -20), {
				"flip_h": facing_direction < 0,
				"scale": Vector2(0.35, 0.35),
				"lifetime": parry_duration,
				"z_index": 7
			})
		State.ATTACK_SWORD:
			sprite.play("attack_sword")
			_state_timer = 0.26
			_trigger_sword_swing()
		State.ATTACK_HAMMER:
			sprite.play("attack_hammer")
			_state_timer = 0.42
			_trigger_hammer_slam()
		State.THRUST:
			sprite.play("attack_sword")
			_state_timer = 0.22
			_trigger_thrust_attack()
		State.GROUND_SLAM:
			sprite.play("attack_hammer")
			velocity = Vector2(0.0, 540.0)
		State.BURST:
			sprite.play("attack_sword")
			_state_timer = 0.18
			_execute_overdrive_burst()
		State.DASH:
			sprite.play("dash")
			AudioManager.play_sfx(&"dash", 2.0)
			_state_timer = dash_duration
			_dash_trail_timer = 0.0
			velocity = Vector2(facing_direction * dash_speed, 0.0)
			VFX.play(&"dash_trail", global_position + Vector2(-facing_direction * 16.0, -22.0), {
				"flip_h": facing_direction < 0,
				"scale": Vector2(0.35, 0.35),
				"lifetime": 0.16,
				"z_index": 2
			})
		State.HURT:
			sprite.play("hurt")
			_state_timer = 0.16
			_invulnerability_timer = 0.5
		State.DEAD:
			set_physics_process(false)
			Events.player_died.emit()

func _on_counterstrike_ready(_ratio: float) -> void:
	VFX.play(&"rebound_charge", global_position + Vector2(0, -20), {
		"scale": Vector2(0.38, 0.38),
		"lifetime": 0.35,
		"z_index": 6
	})

func _trigger_sword_swing() -> void:
	sword_hitbox.set_active(true)
	var counter: Dictionary = rebound_receiver.spend_counterstrike()
	var bonus: int = int(counter["damage_bonus"]) if counter["success"] else 0
	AudioManager.play_sfx(&"slash", 2.0)

	if _sword_combo_window > 0.0 and _sword_combo_count == 2:
		# 3rd hit (Finisher!): Blazing Heavy Cleave Execution!
		_sword_combo_count = 0
		_sword_combo_window = 0.0
		sword_hitbox.damage = 3 + bonus
		velocity.x = facing_direction * 180.0
		VFX.play(&"heavy_cleave", global_position + Vector2(facing_direction * 22, -26), {
			"flip_h": facing_direction < 0,
			"scale": Vector2(0.42, 0.42)
		})
		Events.camera_shake_requested.emit(4.5, 0.14)
	elif _sword_combo_window > 0.0 and _sword_combo_count == 1:
		# 2nd hit: Blazing Double Flame Slash!
		_sword_combo_count = 2
		_sword_combo_window = 0.50
		sword_hitbox.damage = 2 + bonus
		velocity.x = facing_direction * 130.0
		VFX.play(&"double_slash", global_position + Vector2(facing_direction * 20, -24), {
			"flip_h": facing_direction < 0,
			"scale": Vector2(0.38, 0.38)
		})
		Events.camera_shake_requested.emit(3.0, 0.10)
	else:
		# 1st hit: Swift sword slash
		_sword_combo_count = 1
		_sword_combo_window = 0.45
		sword_hitbox.damage = 1 + bonus
		VFX.play(&"sword_slash", global_position + Vector2(facing_direction * 16, -22), {
			"flip_h": facing_direction < 0,
			"scale": Vector2(0.32, 0.32)
		})

func _trigger_thrust_attack() -> void:
	sword_hitbox.set_active(true)
	sword_hitbox.damage = 2
	velocity.x = facing_direction * 260.0
	AudioManager.play_sfx(&"thrust", 2.5)

	VFX.play(&"thrust", global_position + Vector2(facing_direction * 26, -20), {
		"flip_h": facing_direction < 0,
		"scale": Vector2(0.42, 0.42)
	})
	Events.camera_shake_requested.emit(3.5, 0.12)

func _trigger_hammer_slam() -> void:
	hammer_hitbox.set_active(true)
	var counter: Dictionary = rebound_receiver.spend_counterstrike()
	hammer_hitbox.damage = 3 + (int(counter["damage_bonus"]) if counter["success"] else 0)
	AudioManager.play_sfx(&"slam", 3.0)

	VFX.play(&"hammer_smash", global_position + Vector2(facing_direction * 20, -16), {
		"flip_h": facing_direction < 0,
		"scale": Vector2(0.38, 0.38)
	})
	Events.camera_shake_requested.emit(5.0, 0.16)

func _execute_ground_slam_impact() -> void:
	# Ground slam shockwave ring rests flush on the ground surface at foot level
	AudioManager.play_sfx(&"slam", 4.0)
	VFX.play(&"ground_slam", global_position + Vector2(0, -40), {
		"scale": Vector2(0.65, 0.65),
		"z_index": 8
	})
	VFX.play(&"heavy_landing", global_position + Vector2(0, -8), {
		"scale": Vector2(0.5, 0.5),
		"z_index": 9
	})
	Events.camera_shake_requested.emit(6.0, 0.15)
	Events.hit_stop_requested.emit(0.04)

	# Radial ground wave damages nearby enemies
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for node in enemies:
		if node is Node2D:
			var enemy_node: Node2D = node as Node2D
			var dist: float = global_position.distance_to(enemy_node.global_position)
			if dist <= 90.0:
				var hurtbox_node: Hurtbox = enemy_node.get_node_or_null("Hurtbox") as Hurtbox
				if hurtbox_node:
					var kb: Vector2 = (enemy_node.global_position - global_position).normalized() * 320.0 + Vector2(0, -120)
					hurtbox_node.damaged.emit(3, kb, false, hammer_hitbox)

func _execute_overdrive_burst() -> void:
	AudioManager.play_sfx(&"burst", 4.5)
	# Fire Tornado cyclone erupting flush on top of tile surface
	VFX.play(&"fire_tornado", global_position + Vector2(facing_direction * 22, -31), {
		"scale": Vector2(0.5, 0.5),
		"z_index": 8
	})
	VFX.play(&"spin_slash", global_position + Vector2(0, -24), {
		"scale": Vector2(0.42, 0.42),
		"z_index": 9
	})
	VFX.play(&"gravity_burst", global_position + Vector2(0, -26), {
		"scale": Vector2(0.48, 0.48),
		"z_index": 10
	})
	Events.camera_shake_requested.emit(5.5, 0.16)
	Events.hit_stop_requested.emit(0.04)

	# Radial energy expulsion blasts all enemies & repels projectiles
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for node in enemies:
		if node is Node2D:
			var enemy_node: Node2D = node as Node2D
			var dist: float = global_position.distance_to(enemy_node.global_position)
			if dist <= 110.0:
				var hurtbox_node: Hurtbox = enemy_node.get_node_or_null("Hurtbox") as Hurtbox
				if hurtbox_node:
					var kb: Vector2 = (enemy_node.global_position - global_position).normalized() * 380.0
					hurtbox_node.damaged.emit(2, kb, false, sword_hitbox)

	# Vaporize incoming projectiles within burst radius
	var scene: Node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else null
	if scene:
		for child in scene.get_children():
			if child is WispProjectile:
				if global_position.distance_to((child as Node2D).global_position) <= 120.0:
					child.queue_free()

func _try_jump() -> bool:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_jump_released = false
		velocity.y = jump_force
		AudioManager.play_sfx(&"jump", -1.0)
		_enter_state(State.AIR)
		return true
	return false

func _try_combat_actions() -> bool:
	if _burst_buffer_timer > 0.0 and rebound_receiver.current_energy >= 25.0 and _burst_cooldown_timer <= 0.0:
		_burst_buffer_timer = 0.0
		_burst_cooldown_timer = burst_cooldown
		rebound_receiver.current_energy -= 25.0
		Events.rebound_energy_changed.emit(rebound_receiver.current_energy / rebound_receiver.max_energy)
		_enter_state(State.BURST)
		return true

	if _parry_buffer_timer > 0.0 and _parry_cooldown_timer <= 0.0:
		_parry_buffer_timer = 0.0
		_parry_cooldown_timer = parry_cooldown
		_enter_state(State.PARRY)
		return true

	if _dash_buffer_timer > 0.0 and _dash_cooldown_timer <= 0.0:
		_dash_buffer_timer = 0.0
		_dash_cooldown_timer = dash_cooldown
		if rebound_receiver.current_energy >= 10.0:
			rebound_receiver.current_energy -= 10.0
			Events.rebound_energy_changed.emit(rebound_receiver.current_energy / rebound_receiver.max_energy)
		_enter_state(State.DASH)
		return true

	if _thrust_buffer_timer > 0.0 and _thrust_cooldown_timer <= 0.0:
		_thrust_buffer_timer = 0.0
		_thrust_cooldown_timer = thrust_cooldown
		_enter_state(State.THRUST)
		return true

	if _attack_buffer_timer > 0.0:
		_attack_buffer_timer = 0.0
		_enter_state(State.ATTACK_SWORD)
		return true

	if _hammer_buffer_timer > 0.0:
		_hammer_buffer_timer = 0.0
		if not is_on_floor():
			if _slam_cooldown_timer <= 0.0:
				_slam_cooldown_timer = slam_cooldown
				_enter_state(State.GROUND_SLAM)
				return true
		else:
			_enter_state(State.ATTACK_HAMMER)
			return true

	return false

func _apply_gravity(delta: float) -> void:
	var grav: float = gravity
	if velocity.y > 0.0:
		grav *= fall_gravity_multiplier
	velocity.y = minf(max_fall_speed, velocity.y + grav * delta)

func _apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)

func _set_facing(new_facing: int) -> void:
	if new_facing == 0 or new_facing == facing_direction:
		return
	facing_direction = new_facing
	sprite.flip_h = (facing_direction < 0)
	sword_hitbox.position.x = absf(sword_hitbox.position.x) * facing_direction
	hammer_hitbox.position.x = absf(hammer_hitbox.position.x) * facing_direction

func _on_hurtbox_damaged(damage: int, knockback: Vector2, is_parriable: bool, _hitbox: Hitbox) -> void:
	if current_state == State.DEAD:
		return

	if hurtbox.is_parrying and is_parriable:
		hurtbox.is_parrying = false
		_invulnerability_timer = 0.25
		hurtbox.is_invulnerable = true
		VFX.play(&"parry_clash", global_position + Vector2(facing_direction * 14, -22), {
			"scale": Vector2(0.35, 0.35)
		})
		var parry_impulse: Vector2 = rebound_receiver.absorb_impact(-knockback, true)
		velocity = parry_impulse
		_enter_state(State.REBOUND_FLIGHT)

		# Rewarding parry defense with a slight health recovery pulse
		current_health = mini(max_health, current_health + 6)
		Events.player_health_changed.emit(current_health, max_health)
		return

	current_health = maxi(0, current_health - damage)
	Events.player_health_changed.emit(current_health, max_health)
	Events.player_damaged.emit(damage, knockback)

	_invulnerability_timer = 0.75
	hurtbox.is_invulnerable = true

	# Visceral hurt feedback: red flash, camera jolt, and hit sparks
	sprite.modulate = Color(3.5, 0.3, 0.3, 1.0)
	var hurt_tween: Tween = create_tween()
	hurt_tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	Events.hit_stop_requested.emit(0.04)

	VFX.play(&"hit_spark", global_position + Vector2(0, -22), {
		"scale": Vector2(0.35, 0.35)
	})
	VFX.play(&"hit_flash", global_position + Vector2(0, -22), {
		"scale": Vector2(0.3, 0.3)
	})

	if current_health <= 0:
		if _second_chance_available:
			_trigger_second_chance()
		else:
			_enter_state(State.DEAD)
		return

	var rebound_vel: Vector2 = rebound_receiver.absorb_impact(knockback, false)
	velocity = rebound_vel
	_enter_state(State.REBOUND_FLIGHT)

func heal(amount: int) -> void:
	if current_state == State.DEAD:
		return
	current_health = mini(max_health, current_health + amount)
	Events.player_health_changed.emit(current_health, max_health)
	_spawn_heal_text(amount)
	VFX.play(&"collect_burst", global_position + Vector2(0, -20), {"scale": Vector2(0.35, 0.35)})

func _spawn_heal_text(amount: int) -> void:
	var label: Label = Label.new()
	label.text = "+%d HP" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.5, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 25
	label.top_level = true
	label.global_position = global_position + Vector2(-15, -38)

	var parent: Node = get_tree().current_scene if get_tree().current_scene else self
	parent.add_child(label)

	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 18.0, 0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(label.queue_free)

func _trigger_second_chance() -> void:
	_second_chance_available = false
	current_health = 30
	Events.player_health_changed.emit(current_health, max_health)
	Events.second_chance_triggered.emit(global_position)
	Events.hit_stop_requested.emit(0.04)
	_enter_state(State.HURT)

func _on_sword_hit_landed(_target_hurtbox: Hurtbox) -> void:
	rebound_receiver.gain_strike_energy(14.0)
	Events.camera_shake_requested.emit(2.5, 0.08)
	Events.hit_stop_requested.emit(0.03)

func _on_hammer_hit_landed(_target_hurtbox: Hurtbox) -> void:
	rebound_receiver.gain_strike_energy(28.0)
	Events.camera_shake_requested.emit(5.0, 0.14)
	Events.hit_stop_requested.emit(0.06)
