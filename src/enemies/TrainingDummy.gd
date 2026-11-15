class_name TrainingDummy
extends CharacterBody2D

## Sparring dummy: stationary combat target for practicing sword combos,
## heavy hammer slams, and rebound energy generation without unfair autohurt.

signal dummy_destroyed

@export var max_health: int = 15

var current_health: int = 15
var _flash_timer: float = 0.0
var _total_hits_received: int = 0

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_hitbox: Hitbox = $Hitbox
@onready var sprite: Sprite2D = $Sprite2D
@onready var hint_label: Label = $TutorialHint

func _ready() -> void:
	current_health = max_health
	hurtbox.damaged.connect(_on_damaged)

	# Strictly keep dummy hitbox inert so the player never takes accidental proximity damage
	attack_hitbox.set_active(false)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	move_and_slide()

	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			sprite.modulate = Color.WHITE

func _on_damaged(damage: int, knockback: Vector2, _is_parriable: bool, _hitbox: Hitbox) -> void:
	current_health -= damage
	_total_hits_received += 1
	velocity = knockback * 0.3
	_flash_timer = 0.08
	sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)

	var tween: Tween = create_tween()
	tween.tween_property(sprite, "rotation", randf_range(-0.14, 0.14), 0.05)
	tween.tween_property(sprite, "rotation", 0.0, 0.1).set_trans(Tween.TRANS_BOUNCE)

	VFX.play(&"dummy_hit", global_position + Vector2(0, -16), {"scale": Vector2(0.28, 0.28)})
	_spawn_damage_text(damage)

	if hint_label and _total_hits_received >= 3:
		create_tween().tween_property(hint_label, "modulate:a", 0.0, 0.4)

	if current_health <= 0:
		VFX.play(&"enemy_death_poof", global_position + Vector2(0, -18), {"scale": Vector2(0.38, 0.38)})
		dummy_destroyed.emit()
		_respawn_dummy()

func _respawn_dummy() -> void:
	hide()
	attack_hitbox.set_active(false)
	hurtbox.set_deferred("monitoring", false)
	set_physics_process(false)

	await get_tree().create_timer(1.5).timeout
	current_health = max_health
	show()
	set_physics_process(true)
	hurtbox.set_deferred("monitoring", true)

func _spawn_damage_text(amount: int) -> void:
	var label: Label = Label.new()
	label.text = "-%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 20
	label.top_level = true
	label.global_position = global_position + Vector2(randf_range(-8, 8) - 12, -32)

	var parent: Node = get_tree().current_scene if get_tree().current_scene else self
	parent.add_child(label)

	var tween: Tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 16.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
