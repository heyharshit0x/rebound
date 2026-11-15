class_name VoidBeamProjectile
extends Area2D

## High-speed void laser beam emitted by Void Eye enemies.
## High risk, high reward: timed parry reflects the beam for massive rebound energy.

@export var speed: float = 250.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var _lifetime_timer: float = 0.0

@onready var hitbox: Hitbox = $Hitbox
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_lifetime_timer = lifetime
	sprite.play("default")
	rotation = direction.angle()
	hitbox.hit_landed.connect(_on_hit_landed)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

	_lifetime_timer -= delta
	if _lifetime_timer <= 0.0:
		_dissipate()

func _on_body_entered(_body: Node2D) -> void:
	_dissipate()

func _on_hit_landed(_target: Hurtbox) -> void:
	_dissipate()

func _dissipate() -> void:
	VFX.play(&"hit_spark", global_position, {"scale": Vector2(0.3, 0.3)})
	queue_free()
