class_name Level02
extends Node2D

## Stage 2: The Molten Bastion.
## Fiery depths requiring platforming over lava/spike chasms to secure the Molten Key
## and overcome the Crimson Champion guarding the Void Portal to Level 3.

var _key_collected: bool = false
var _portal_unlocked: bool = false

@onready var portal: AnimatedSprite2D = $VoidPortal
@onready var portal_area: Area2D = $PortalArea
@onready var portal_label: Label = $VoidPortal/PortalStatusLabel

func _ready() -> void:
	portal.play("default")
	portal.modulate = Color(1.2, 0.6, 0.4, 0.45)
	portal_label.text = "LOCKED [Find Molten Key]"

	Events.core_fragment_collected.connect(_on_key_collected)
	portal_area.body_entered.connect(_on_portal_entered)

	# Level introduction announcement
	_announce_level()

func _announce_level() -> void:
	var label: Label = Label.new()
	label.text = "LEVEL 2: MOLTEN BASTION"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 25
	label.top_level = true
	label.global_position = Vector2(160, 45)
	add_child(label)

	var tween: Tween = label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(1.6)
	tween.chain().tween_callback(label.queue_free)

func _on_key_collected(_key_name: StringName) -> void:
	_key_collected = true
	_portal_unlocked = true

	# Awakens the molten portal with solar flare
	portal_label.text = "PORTAL OPEN [Enter to Advance]"
	portal_label.modulate = Color(1.0, 0.85, 0.3, 1.0)

	var tween: Tween = create_tween()
	tween.tween_property(portal, "modulate", Color(2.2, 1.1, 0.6, 1.0), 0.5)
	tween.tween_property(portal, "scale", Vector2(0.76, 0.76), 0.2)
	tween.tween_property(portal, "scale", Vector2(0.68, 0.68), 0.2)

	Events.camera_shake_requested.emit(4.0, 0.18)
	VFX.play(&"gravity_burst", portal.global_position, {
		"scale": Vector2(0.75, 0.75),
		"modulate": Color(2.4, 0.8, 0.4, 1.0)
	})

func _on_portal_entered(body: Node2D) -> void:
	if _portal_unlocked and (body is PlayerController or body.is_in_group("player")):
		VFX.play(&"core_restored_pillar", portal.global_position, {
			"scale": Vector2(0.75, 0.75),
			"modulate": Color(2.5, 0.9, 0.5, 1.0)
		})
		Events.level_completed.emit(2, 3, 0.0)
