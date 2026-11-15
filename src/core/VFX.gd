extends Node

## Spawns and manages pixel art visual effects across the game.
## Reads generated SpriteFrames resources and handles automatic cleanup for one-shots.

const VFX_BASE_PATH: String = "res://assets/vfx/"

var _cache: Dictionary = {}
var _manifest_data: Dictionary = {}

func _ready() -> void:
	_load_manifest()

func play(effect_id: StringName, spawn_pos: Vector2, options: Dictionary = {}) -> AnimatedSprite2D:
	var frames: SpriteFrames = get_frames(effect_id)
	if not frames:
		push_warning("VFX: Missing effect with id '%s'" % effect_id)
		return null

	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.top_level = options.get("top_level", true)
	sprite.global_position = spawn_pos
	sprite.z_index = options.get("z_index", 15)
	sprite.flip_h = options.get("flip_h", false)
	sprite.rotation = options.get("rotation", 0.0)
	sprite.modulate = options.get("modulate", Color.WHITE)

	if options.has("scale"):
		sprite.scale = options["scale"]

	var target_parent: Node = options.get("parent", null)
	if not target_parent:
		target_parent = get_tree().current_scene if get_tree().current_scene else self

	target_parent.add_child(sprite)
	sprite.play("default")

	var is_looping: bool = frames.get_animation_loop("default")
	if options.has("lifetime"):
		var lifetime: float = float(options["lifetime"])
		var tween: Tween = sprite.create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, lifetime)
		tween.chain().tween_callback(sprite.queue_free)
	elif not is_looping:
		sprite.animation_finished.connect(sprite.queue_free)
	else:
		var lifetime: float = 0.22
		var tween: Tween = sprite.create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, lifetime)
		tween.chain().tween_callback(sprite.queue_free)

	return sprite

func play_attached(effect_id: StringName, target_node: Node2D, offset: Vector2 = Vector2.ZERO) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = play(effect_id, target_node.global_position + offset, {
		"parent": target_node,
		"top_level": false
	})
	if sprite:
		sprite.position = offset
	return sprite

func get_frames(effect_id: StringName) -> SpriteFrames:
	if _cache.has(effect_id):
		return _cache[effect_id]

	var res_path: String = ""
	if _manifest_data.has(String(effect_id)):
		res_path = _manifest_data[String(effect_id)].get("tres", "")

	if res_path.is_empty():
		# Fallback direct lookup scan across standard categories
		for cat in ["combat", "player", "impacts", "enemies", "environment", "bosses", "pickups", "ui"]:
			var test_path: String = "%s%s/%s/%s.tres" % [VFX_BASE_PATH, cat, effect_id, effect_id]
			if ResourceLoader.exists(test_path):
				res_path = test_path
				break

	if res_path.is_empty() or not ResourceLoader.exists(res_path):
		return null

	var loaded_res: SpriteFrames = load(res_path) as SpriteFrames
	if loaded_res:
		_cache[effect_id] = loaded_res
	return loaded_res

func _load_manifest() -> void:
	var manifest_path: String = VFX_BASE_PATH + "manifest.json"
	if not FileAccess.file_exists(manifest_path):
		return

	var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
	if not file:
		return

	var json_str: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(json_str)
	if parsed is Array:
		for item in parsed:
			if item is Dictionary and item.has("name"):
				_manifest_data[item["name"]] = item
