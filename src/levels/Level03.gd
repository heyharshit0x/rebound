class_name Level03
extends Node2D

## Stage 3: The Void Spire.
## The final climax arena. Shattered spires suspended over an endless cosmic abyss.
## The Void Sovereign commands dark blade arts guarding the Master Key and Celestial Portal.

var _key_collected: bool = false
var _portal_unlocked: bool = false

@onready var portal: AnimatedSprite2D = $VoidPortal
@onready var portal_area: Area2D = $PortalArea
@onready var portal_label: Label = $VoidPortal/PortalStatusLabel

func _ready() -> void:
	portal.play("default")
	portal.modulate = Color(1.1, 0.7, 2.2, 0.5)
	portal_label.text = "LOCKED [Defeat Sovereign & Obtain Master Key]"

	Events.core_fragment_collected.connect(_on_key_collected)
	portal_area.body_entered.connect(_on_portal_entered)

	_announce_level()

func _announce_level() -> void:
	var label: Label = Label.new()
	label.text = "FINAL LEVEL: THE VOID SPIRE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.3, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 25
	label.top_level = true
	label.global_position = Vector2(145, 45)
	add_child(label)

	var tween: Tween = label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(1.8)
	tween.chain().tween_callback(label.queue_free)

func _on_key_collected(_key_name: StringName) -> void:
	_key_collected = true
	_portal_unlocked = true

	# Awaken final celestial gate with radiant nova
	portal_label.text = "CELESTIAL GATE OPEN [Enter to Conquer]"
	portal_label.modulate = Color(0.6, 1.3, 1.0, 1.0)

	var tween: Tween = create_tween()
	tween.tween_property(portal, "modulate", Color(1.5, 1.3, 2.5, 1.0), 0.5)
	tween.tween_property(portal, "scale", Vector2(0.82, 0.82), 0.25)
	tween.tween_property(portal, "scale", Vector2(0.72, 0.72), 0.25)

	Events.camera_shake_requested.emit(5.0, 0.22)
	VFX.play(&"gravity_burst", portal.global_position, {
		"scale": Vector2(0.85, 0.85),
		"modulate": Color(1.5, 1.1, 2.6, 1.0)
	})

func _on_portal_entered(body: Node2D) -> void:
	if _portal_unlocked and (body is PlayerController or body.is_in_group("player")):
		VFX.play(&"core_restored_pillar", portal.global_position, {
			"scale": Vector2(0.85, 0.85),
			"modulate": Color(1.8, 1.4, 2.8, 1.0)
		})
		Events.level_completed.emit(3, 3, 0.0)
