class_name MainMenu
extends Control

## Classic Retro Arcade / Indie Title Screen for REBOUND.
## Features classic keyboard + mouse navigation, iconic title presentation,
## story chronicles, and direct path into Training and Campaign.

@onready var menu_options: VBoxContainer = $CanvasLayer/CenterContainer/VBox/MenuButtons
@onready var story_modal: Control = $CanvasLayer/StoryModal
@onready var story_title: Label = $CanvasLayer/StoryModal/Panel/VBox/ChapterTitle
@onready var story_body: Label = $CanvasLayer/StoryModal/Panel/VBox/StoryBody
@onready var story_page: Label = $CanvasLayer/StoryModal/Panel/VBox/BottomRow/PageLabel

const STORY_CHAPTERS: Array[Dictionary] = [
	{
		"title": "CHAPTER I — THE CORE OF REBOUND",
		"body": "Long ago, a powerful kingdom was protected by an ancient magical source called the CORE OF REBOUND.\n\nIt had the ability to turn destruction into energy and weakness into strength. No calamity could break the realm, for every blow struck against it was absorbed and returned tenfold."
	},
	{
		"title": "CHAPTER II — THE CORRUPTED GUARDIAN",
		"body": "One day, the Chief Guardian corrupted the Core. The kingdom collapsed, its magical energy went wild, and everything was trapped inside a repeating cycle of ruin.\n\nThose who fell were bound to the abyss, twisted into corrupted sentinels guarding the fractured Keys of the Core."
	},
	{
		"title": "CHAPTER III — THE FALLEN KNIGHT",
		"body": "You awaken in the ruined training chamber. You have lost almost all your powers. The only ability remaining is a strange magical reaction:\n\nWHENEVER SOMETHING KNOCKS YOU BACK, YOU ABSORB ITS ENERGY.\n\nFall. Fight. Rise Stronger. Every force that pushes you down becomes the power that helps you rise again."
	},
	{
		"title": "CHAPTER IV — THE RESTORATION",
		"body": "You must travel through the fallen kingdom, defeat its corrupted guardians, recover the sacred Keys, and defeat the being responsible for the destruction.\n\nDefeat the Training Construct to begin your crusade through the Shadow Catacombs, Molten Bastion, and Void Spire!"
	}
]

var _selected_index: int = 0
var _current_chapter: int = 0
var _buttons: Array[Button] = []

func _ready() -> void:
	AudioManager.play_bgm()
	story_modal.visible = false
	_gather_buttons()
	_update_cursor()

func _gather_buttons() -> void:
	_buttons.clear()
	if menu_options:
		for child in menu_options.get_children():
			if child is Button:
				var btn: Button = child as Button
				var idx: int = _buttons.size()
				_buttons.append(btn)
				btn.mouse_entered.connect(func() -> void:
					_selected_index = idx
					_update_cursor()
					AudioManager.play_sfx(&"ui_hover", -4.0)
				)

func _unhandled_input(event: InputEvent) -> void:
	if story_modal.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_story()
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
			_next_chapter()
		elif event.is_action_pressed("ui_left"):
			_prev_chapter()
		return

	if event.is_action_pressed("ui_up"):
		_selected_index = (_selected_index - 1 + _buttons.size()) % _buttons.size()
		_update_cursor()
		AudioManager.play_sfx(&"ui_hover", -4.0)
	elif event.is_action_pressed("ui_down"):
		_selected_index = (_selected_index + 1) % _buttons.size()
		_update_cursor()
		AudioManager.play_sfx(&"ui_hover", -4.0)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		_activate_selected()

func _update_cursor() -> void:
	var labels: Array[String] = [
		"PLAY CAMPAIGN (LEVEL 1)",
		"TRAINING AREA (PROLOGUE)",
		"STORY OF REBOUND",
		"QUIT GAME"
	]
	for i in range(_buttons.size()):
		var base_text: String = labels[i] if i < labels.size() else _buttons[i].text
		if i == _selected_index:
			_buttons[i].text = "▶  " + base_text
			_buttons[i].modulate = Color(1.2, 1.1, 0.6, 1.0)
		else:
			_buttons[i].text = "    " + base_text
			_buttons[i].modulate = Color(0.85, 0.85, 0.9, 0.85)

func _activate_selected() -> void:
	AudioManager.play_sfx(&"ui_click", 1.5)
	match _selected_index:
		0: # Play Campaign (Direct into Level 1)
			get_tree().change_scene_to_file("res://src/levels/Level01.tscn")
		1: # Training Area (Chamber with dummy, moves to Level 1 through portal)
			get_tree().change_scene_to_file("res://src/levels/TrainingChamber.tscn")
		2: # Story Chronicles
			_open_story()
		3: # Quit Game
			get_tree().quit()

func _open_story() -> void:
	_current_chapter = 0
	_render_chapter()
	story_modal.visible = true

func _close_story() -> void:
	AudioManager.play_sfx(&"ui_click", 1.0)
	story_modal.visible = false

func _prev_chapter() -> void:
	if _current_chapter > 0:
		_current_chapter -= 1
		AudioManager.play_sfx(&"ui_click", 1.0)
		_render_chapter()

func _next_chapter() -> void:
	if _current_chapter < STORY_CHAPTERS.size() - 1:
		_current_chapter += 1
		AudioManager.play_sfx(&"ui_click", 1.0)
		_render_chapter()
	else:
		# End of story -> Begin Game!
		AudioManager.play_sfx(&"ui_click", 2.0)
		get_tree().change_scene_to_file("res://src/levels/TrainingChamber.tscn")

func _render_chapter() -> void:
	var chap: Dictionary = STORY_CHAPTERS[_current_chapter]
	story_title.text = chap["title"]
	story_body.text = chap["body"]
	story_page.text = "%d / %d  •  [ENTER / SPACE to Advance]" % [_current_chapter + 1, STORY_CHAPTERS.size()]

func _on_button_pressed(idx: int) -> void:
	_selected_index = idx
	_activate_selected()

func _on_play_campaign_pressed() -> void:
	_selected_index = 0
	_activate_selected()

func _on_training_pressed() -> void:
	_selected_index = 1
	_activate_selected()

func _on_story_pressed() -> void:
	_selected_index = 2
	_activate_selected()

func _on_quit_pressed() -> void:
	_selected_index = 3
	_activate_selected()

func _on_prev_chapter_pressed() -> void:
	_prev_chapter()

func _on_next_chapter_pressed() -> void:
	_next_chapter()

func _on_close_story_pressed() -> void:
	_close_story()
