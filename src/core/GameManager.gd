extends Node

## Hit-stop timing, win/loss overlay orchestration, and camera shake bus listener.

const VICTORY_SCENE: String = "res://src/ui/Victory.tscn"

const LEVEL_SCENES: Array[String] = [
	"res://src/levels/Level01.tscn",
	"res://src/levels/Level02.tscn",
	"res://src/levels/Level03.tscn"
]

var _camera_ref: Camera2D = null
var _shake_tween: Tween = null
var _is_transitioning: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	Events.hit_stop_requested.connect(_on_hit_stop_requested)
	Events.player_died.connect(_on_player_died)
	Events.level_completed.connect(_on_level_completed)
	Events.camera_shake_requested.connect(_on_camera_shake_requested)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Secret developer warp directly to Level 3: F3 or Ctrl+3
		if event.keycode == KEY_F3 or (event.keycode == KEY_3 and event.ctrl_pressed):
			get_tree().paused = false
			_is_transitioning = false
			AudioManager.play_sfx(&"portal", 2.0)
			get_tree().change_scene_to_file("res://src/levels/Level03.tscn")

func _on_hit_stop_requested(_duration: float) -> void:
	# Avoid global time_scale dilation that locks player physics & input
	Engine.time_scale = 1.0

func _on_player_died() -> void:
	# Defeat UI and retry / main-menu routing is handled exclusively by HUD.gd's DefeatModal
	pass

func _on_level_completed(level_index: int, _stars: int, _clear_time: float) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	# Transition to next level or present grand victory if all levels cleared
	if level_index < LEVEL_SCENES.size():
		var next_scene_path: String = LEVEL_SCENES[level_index]
		await get_tree().create_timer(0.45, true, false, true).timeout
		_is_transitioning = false
		get_tree().change_scene_to_file(next_scene_path)
	else:
		await get_tree().create_timer(0.45, true, false, true).timeout
		_is_transitioning = false
		var current: Node = get_tree().current_scene
		if current and not current.has_node("VictoryScreen"):
			var overlay: PackedScene = load(VICTORY_SCENE)
			current.add_child(overlay.instantiate())

func _on_camera_shake_requested(intensity: float, duration: float) -> void:
	if _camera_ref == null:
		var cams: Array[Node] = get_tree().get_nodes_in_group("main_camera")
		if not cams.is_empty():
			_camera_ref = cams[0] as Camera2D
		else:
			var player_node: Node = get_tree().get_first_node_in_group("player")
			if player_node and player_node.has_node("Camera2D"):
				_camera_ref = player_node.get_node("Camera2D") as Camera2D

	if _camera_ref == null:
		return

	# Kill any existing shake tween so multiple impacts don't collide or drift the camera
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	var clamped_intensity: float = clampf(intensity, 1.0, 6.0)
	var clamped_duration: float = clampf(duration, 0.05, 0.15)
	var step_time: float = 0.025
	var steps: int = maxi(2, int(clamped_duration / step_time))

	_shake_tween = create_tween()
	for i: int in range(steps):
		var decay: float = 1.0 - (float(i) / float(steps))
		var current_amp: float = clamped_intensity * decay
		var offset: Vector2 = Vector2(randf_range(-current_amp, current_amp), randf_range(-current_amp, current_amp))
		_shake_tween.tween_property(_camera_ref, "offset", offset, step_time)

	# Always snap back cleanly to true resting position (Vector2.ZERO)
	_shake_tween.tween_property(_camera_ref, "offset", Vector2.ZERO, 0.02)
