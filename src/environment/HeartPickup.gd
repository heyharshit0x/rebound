class_name HeartPickup
extends Area2D

## World collectible heart that restores player HP upon contact.

@export var heal_amount: int = 30

var _base_y: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	if sprite:
		sprite.play("default")

func _process(_delta: float) -> void:
	position.y = _base_y + sin(Time.get_ticks_msec() * 0.005) * 3.0

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController or body.is_in_group("player"):
		var player: PlayerController = body as PlayerController
		if player and player.has_method("heal"):
			player.heal(heal_amount)
			queue_free()
