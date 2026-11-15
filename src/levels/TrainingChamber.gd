class_name TrainingChamber
extends Node2D

## The Awakening — Training Chamber level.
## Introduces basic movement, sword combos, heavy hammer slams, and parry rebounds.
## Stepping into the dimensional portal immediately advances to Level 01 (Campaign).

@onready var portal_sprite: AnimatedSprite2D = $VoidPortal
@onready var portal_area: Area2D = $PortalArea
@onready var portal_label: Label = $VoidPortal/PortalStatusLabel

var _has_advanced: bool = false

func _ready() -> void:
	AudioManager.play_bgm()
	portal_area.body_entered.connect(_on_portal_entered)
	_show_prologue_announcement()

func _show_prologue_announcement() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var banner: Label = Label.new()
	banner.text = "✦ THE AWAKENING — TRAINING CHAMBER ✦\n[Master the Rebound • Enter Portal to Advance]"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 10)
	banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	banner.add_theme_constant_override("shadow_offset_x", 1)
	banner.add_theme_constant_override("shadow_offset_y", 1)
	banner.add_theme_constant_override("outline_size", 3)
	banner.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.06, 1.0))

	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 22.0
	banner.offset_bottom = 50.0
	banner.modulate.a = 0.0
	canvas.add_child(banner)

	var tween: Tween = create_tween()
	tween.tween_property(banner, "modulate:a", 1.0, 0.4)
	tween.tween_interval(3.5)
	tween.tween_property(banner, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(canvas.queue_free)

func _on_portal_entered(body: Node2D) -> void:
	if _has_advanced:
		return

	if body is PlayerController or body.is_in_group("player"):
		_has_advanced = true
		AudioManager.play_sfx(&"portal", 2.0)
		VFX.play(&"rift_portal", portal_sprite.global_position, {"scale": Vector2(0.8, 0.8)})
		Events.camera_shake_requested.emit(4.0, 0.2)

		var timer: SceneTreeTimer = get_tree().create_timer(0.4)
		timer.timeout.connect(func() -> void:
			get_tree().change_scene_to_file("res://src/levels/Level01.tscn")
		)
