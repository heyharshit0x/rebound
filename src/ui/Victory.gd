class_name VictoryScreen
extends CanvasLayer

## Grand Victory Screen with Runiga font styling, triumphant fanfare,
## and complete navigation back to Campaign, Training, or Title Menu.

@onready var title_label: Label = $Panel/Title
@onready var subtitle_label: Label = $Panel/Subtitle

func _ready() -> void:
	AudioManager.play_story_credits_bgm()
	AudioManager.play_sfx(&"victory", 3.0)
	var tween: Tween = create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_BACK)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.30)

func _on_replay_pressed() -> void:
	AudioManager.restore_main_bgm()
	AudioManager.play_sfx(&"ui_click", 2.0)
	get_tree().change_scene_to_file("res://src/levels/Level01.tscn")

func _on_training_pressed() -> void:
	AudioManager.restore_main_bgm()
	AudioManager.play_sfx(&"ui_click", 2.0)
	get_tree().change_scene_to_file("res://src/levels/TrainingChamber.tscn")

func _on_menu_pressed() -> void:
	AudioManager.restore_main_bgm()
	AudioManager.play_sfx(&"ui_click", 2.0)
	get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		_on_replay_pressed()
	elif event.is_action_pressed("ui_cancel"):
		_on_menu_pressed()
