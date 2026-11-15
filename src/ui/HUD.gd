class_name HUD
extends CanvasLayer

## Combat HUD featuring animated health bar, rebound energy gauge,
## violent proximity ghosting, pause modal with Main Menu routing,
## and Runiga-styled Defeat overlay.

@onready var health_bar: ProgressBar = $MarginContainer/TopRow/StatusVBox/HealthRow/HealthBar
@onready var health_label: Label = $MarginContainer/TopRow/StatusVBox/HealthRow/HealthLabel
@onready var energy_bar: ProgressBar = $MarginContainer/TopRow/StatusVBox/EnergyRow/EnergyBar
@onready var energy_label: Label = $MarginContainer/TopRow/StatusVBox/EnergyRow/EnergyLabel
@onready var combo_label: Label = $MarginContainer/ComboContainer/ComboLabel
@onready var cooldown_label: Label = $MarginContainer/TopRow/ControlsPanel/ControlsVBox/CooldownRow
@onready var controls_panel: PanelContainer = $MarginContainer/TopRow/ControlsPanel
@onready var vignette: ColorRect = $DamageVignette
@onready var pause_modal: Control = $PauseModal
@onready var defeat_modal: Control = $DefeatModal

var _current_combo: int = 0
var _health_tween: Tween = null
var _player_ref: CharacterBody2D = null

var _pause_buttons: Array[Button] = []
var _pause_index: int = 0
var _defeat_buttons: Array[Button] = []
var _defeat_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_modal.visible = false
	defeat_modal.visible = false
	_gather_pause_buttons()
	_gather_defeat_buttons()

	Events.player_health_changed.connect(_on_health_changed)
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_died.connect(_on_player_died)
	Events.rebound_energy_changed.connect(_on_energy_changed)
	Events.combo_incremented.connect(_on_combo_incremented)
	Events.combo_reset.connect(_on_combo_reset)
	Events.power_cooldown_ticked.connect(_on_power_cooldown_ticked)

	combo_label.modulate.a = 0.0

func _gather_pause_buttons() -> void:
	_pause_buttons = [
		$PauseModal/Panel/VBox/ResumeBtn as Button,
		$PauseModal/Panel/VBox/RetryBtn as Button,
		$PauseModal/Panel/VBox/TrainingBtn as Button,
		$PauseModal/Panel/VBox/MenuBtn as Button
	]
	for i in range(_pause_buttons.size()):
		var idx: int = i
		_pause_buttons[i].mouse_entered.connect(func() -> void:
			_pause_index = idx
			_update_pause_cursor()
			AudioManager.play_sfx(&"ui_hover", -4.0)
		)

func _gather_defeat_buttons() -> void:
	_defeat_buttons = [
		$DefeatModal/Panel/VBox/RetryBtn as Button,
		$DefeatModal/Panel/VBox/MenuBtn as Button
	]
	for i in range(_defeat_buttons.size()):
		var idx: int = i
		_defeat_buttons[i].mouse_entered.connect(func() -> void:
			_defeat_index = idx
			_update_defeat_cursor()
			AudioManager.play_sfx(&"ui_hover", -4.0)
		)

func _update_pause_cursor() -> void:
	var labels: Array[String] = ["RESUME", "RESTART LEVEL", "TRAINING AREA", "RETURN TO TITLE MENU"]
	for i in range(_pause_buttons.size()):
		var base: String = labels[i]
		if i == _pause_index:
			_pause_buttons[i].text = "▶  " + base
			_pause_buttons[i].modulate = Color(1.3, 1.1, 0.6, 1.0)
		else:
			_pause_buttons[i].text = "    " + base
			_pause_buttons[i].modulate = Color(0.85, 0.85, 0.9, 0.85)

func _update_defeat_cursor() -> void:
	var labels: Array[String] = ["RETRY LEVEL (R)", "RETURN TO TITLE MENU (M)"]
	for i in range(_defeat_buttons.size()):
		var base: String = labels[i]
		if i == _defeat_index:
			_defeat_buttons[i].text = "▶  " + base
			_defeat_buttons[i].modulate = Color(1.3, 0.5, 0.6, 1.0)
		else:
			_defeat_buttons[i].text = "    " + base
			_defeat_buttons[i].modulate = Color(0.85, 0.85, 0.9, 0.85)

func _process(delta: float) -> void:
	if not get_tree().paused:
		_update_proximity_fade(delta)

func _unhandled_input(event: InputEvent) -> void:
	if defeat_modal.visible:
		if event.is_action_pressed("ui_up"):
			_defeat_index = (_defeat_index - 1 + _defeat_buttons.size()) % _defeat_buttons.size()
			_update_defeat_cursor()
			AudioManager.play_sfx(&"ui_hover", -4.0)
			return
		elif event.is_action_pressed("ui_down"):
			_defeat_index = (_defeat_index + 1) % _defeat_buttons.size()
			_update_defeat_cursor()
			AudioManager.play_sfx(&"ui_hover", -4.0)
			return
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
			match _defeat_index:
				0: _on_retry_pressed()
				1: _on_main_menu_pressed()
			return
		elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
			_on_retry_pressed()
			return
		elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_M):
			_on_main_menu_pressed()
			return
		return

	if pause_modal.visible:
		if event.is_action_pressed("ui_cancel"):
			toggle_pause()
			return
		elif event.is_action_pressed("ui_up"):
			_pause_index = (_pause_index - 1 + _pause_buttons.size()) % _pause_buttons.size()
			_update_pause_cursor()
			AudioManager.play_sfx(&"ui_hover", -4.0)
			return
		elif event.is_action_pressed("ui_down"):
			_pause_index = (_pause_index + 1) % _pause_buttons.size()
			_update_pause_cursor()
			AudioManager.play_sfx(&"ui_hover", -4.0)
			return
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
			match _pause_index:
				0: _on_resume_pressed()
				1: _on_retry_pressed()
				2: _on_switch_training_pressed()
				3: _on_main_menu_pressed()
			return

	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	var is_paused: bool = not get_tree().paused
	get_tree().paused = is_paused
	pause_modal.visible = is_paused
	if is_paused:
		_pause_index = 0
		_update_pause_cursor()
	AudioManager.play_sfx(&"ui_click", 1.5)

func _update_proximity_fade(delta: float) -> void:
	if not controls_panel:
		return
	if _player_ref == null:
		var node: Node = get_tree().get_first_node_in_group("player")
		if node and node is CharacterBody2D:
			_player_ref = node as CharacterBody2D
	if not _player_ref:
		return

	# Soft ghost-fade the controls panel whenever the player jumps into the upper screen area
	var canvas_transform: Transform2D = _player_ref.get_canvas_transform()
	var screen_pos: Vector2 = canvas_transform * _player_ref.global_position
	var is_in_top_screen: bool = screen_pos.y < 125.0
	var target_alpha: float = 0.15 if is_in_top_screen else 0.85
	controls_panel.modulate.a = move_toward(controls_panel.modulate.a, target_alpha, 4.5 * delta)

func _on_player_damaged(_amount: int, _knockback: Vector2) -> void:
	if vignette:
		vignette.modulate.a = 1.0
		var tween: Tween = create_tween()
		tween.tween_property(vignette, "modulate:a", 0.0, 0.28)

func _on_player_died() -> void:
	defeat_modal.visible = true
	_defeat_index = 0
	_update_defeat_cursor()
	var tween: Tween = create_tween()
	defeat_modal.modulate.a = 0.0
	tween.tween_property(defeat_modal, "modulate:a", 1.0, 0.40)

func _on_health_changed(current: int, max_health: int) -> void:
	health_bar.max_value = float(max_health)
	health_label.text = "%d / %d HP" % [maxi(0, current), max_health]

	if _health_tween and _health_tween.is_valid():
		_health_tween.kill()

	_health_tween = create_tween()
	_health_tween.tween_property(health_bar, "value", float(current), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var health_ratio: float = float(current) / float(maxi(1, max_health))
	if health_ratio <= 0.25:
		health_bar.modulate = Color(1.8, 0.4, 0.4, 1.0)
		health_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
	elif health_ratio <= 0.5:
		health_bar.modulate = Color(1.3, 1.1, 0.5, 1.0)
		health_label.modulate = Color(1.0, 0.9, 0.6, 1.0)
	else:
		health_bar.modulate = Color.WHITE
		health_label.modulate = Color.WHITE

func _on_energy_changed(ratio: float) -> void:
	var percent: int = int(ratio * 100.0)
	energy_bar.value = float(percent)
	energy_label.text = "%d%% REBOUND" % percent

	if ratio >= 0.98:
		energy_bar.modulate = Color(1.6, 1.4, 2.0, 1.0)
		energy_label.modulate = Color(1.4, 1.1, 1.8, 1.0)
	elif ratio >= 0.5:
		energy_bar.modulate = Color(0.9, 1.2, 1.6, 1.0)
		energy_label.modulate = Color(0.8, 0.95, 1.1, 1.0)
	else:
		energy_bar.modulate = Color(0.8, 0.8, 0.9, 1.0)
		energy_label.modulate = Color(0.65, 0.75, 0.85, 0.9)

func _on_combo_incremented(combo_count: int, _points: float) -> void:
	_current_combo = combo_count
	combo_label.text = "%dX COMBO" % combo_count

	var tween: Tween = create_tween()
	combo_label.scale = Vector2(1.1, 1.1)
	combo_label.modulate = Color(1.3, 1.1, 0.4, 1.0)
	tween.tween_property(combo_label, "scale", Vector2.ONE, 0.12)
	tween.parallel().tween_property(combo_label, "modulate:a", 1.0, 0.08)
	tween.tween_interval(0.7)
	tween.tween_property(combo_label, "modulate:a", 0.0, 0.25)

func _on_combo_reset() -> void:
	if _current_combo > 0:
		_current_combo = 0
		var tween: Tween = create_tween()
		tween.tween_property(combo_label, "modulate:a", 0.0, 0.25)

func _on_power_cooldown_ticked(powers: Dictionary) -> void:
	if not cooldown_label:
		return

	var dash_cd: float = float(powers.get("dash", 0.0))
	var parry_cd: float = float(powers.get("parry", 0.0))
	var thrust_cd: float = float(powers.get("thrust", 0.0))
	var burst_cd: float = float(powers.get("burst", 0.0))

	var dash_str: String = "%.1fs" % dash_cd if dash_cd > 0.05 else "OK"
	var parry_str: String = "%.1fs" % parry_cd if parry_cd > 0.05 else "OK"
	var thrust_str: String = "%.1fs" % thrust_cd if thrust_cd > 0.05 else "OK"
	var burst_str: String = "%.1fs" % burst_cd if burst_cd > 0.05 else "OK"

	cooldown_label.text = "F: %s • L: %s • E: %s • C: %s" % [dash_str, parry_str, thrust_str, burst_str]

	if dash_cd > 0.05 or parry_cd > 0.05 or thrust_cd > 0.05 or burst_cd > 0.05:
		cooldown_label.modulate = Color(1.1, 0.85, 0.5, 0.95)
	else:
		cooldown_label.modulate = Color(0.5, 0.95, 1.0, 0.95)

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_retry_pressed() -> void:
	get_tree().paused = false
	AudioManager.play_sfx(&"ui_click", 2.0)
	get_tree().reload_current_scene()

func _on_switch_training_pressed() -> void:
	get_tree().paused = false
	AudioManager.play_sfx(&"ui_click", 2.0)
	get_tree().change_scene_to_file("res://src/levels/TrainingChamber.tscn")

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	AudioManager.play_sfx(&"ui_click", 2.0)
	get_tree().change_scene_to_file("res://src/ui/MainMenu.tscn")
