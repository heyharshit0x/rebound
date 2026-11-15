extends Node

## Global Audio Manager for continuous orchestral BGM and dynamic SFX.
## Maintains polyphonic voice pool to prevent cutting off combat impacts.

const MAIN_BGM_PATH: String = "res://assets/audio/Powerful Massive And Dramatic Neo Classical Violin Music - The Demand of Man(MP3_160K).mp3"

const SFX_REGISTRY: Dictionary = {
	&"jump": "res://assets/audio/sfx_jump.wav",
	&"dash": "res://assets/audio/sfx_dash.wav",
	&"slash": "res://assets/audio/sfx_slash.wav",
	&"parry": "res://assets/audio/sfx_parry.wav",
	&"slam": "res://assets/audio/sfx_slam.wav",
	&"thrust": "res://assets/audio/sfx_thrust.wav",
	&"burst": "res://assets/audio/sfx_burst.wav",
	&"hit": "res://assets/audio/sfx_hit.wav",
	&"hurt": "res://assets/audio/sfx_hurt.wav",
	&"key_pickup": "res://assets/audio/sfx_key_pickup.wav",
	&"portal": "res://assets/audio/sfx_portal.wav",
	&"ui_hover": "res://assets/audio/sfx_ui_hover.wav",
	&"ui_click": "res://assets/audio/sfx_ui_click.wav",
	&"victory": "res://assets/audio/sfx_victory.wav",
	&"defeat": "res://assets/audio/sfx_defeat.wav"
}

var _bgm_player: AudioStreamPlayer = null
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}
var _pool_index: int = 0
const POOL_SIZE: int = 12

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bgm_player()
	_preload_sfx()
	_connect_events()
	play_bgm()

func _setup_bgm_player() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = &"Master"
	_bgm_player.volume_db = 1.0
	if ResourceLoader.exists(MAIN_BGM_PATH):
		var stream: AudioStream = load(MAIN_BGM_PATH) as AudioStream
		_bgm_player.stream = stream
	add_child(_bgm_player)

	for i in range(POOL_SIZE):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_sfx_pool.append(p)

func _preload_sfx() -> void:
	for id in SFX_REGISTRY.keys():
		var path: String = SFX_REGISTRY[id]
		if ResourceLoader.exists(path):
			_sfx_streams[id] = load(path) as AudioStream

func _connect_events() -> void:
	Events.player_damaged.connect(func(_amt: int, _kb: Vector2) -> void: play_sfx(&"hurt", 3.5))
	Events.parry_executed.connect(func(success: bool, _pos: Vector2) -> void:
		if success: play_sfx(&"parry", 2.0)
	)
	Events.core_fragment_collected.connect(func(_id: StringName) -> void: play_sfx(&"key_pickup", 2.0))
	Events.player_died.connect(func() -> void: play_sfx(&"defeat", 3.0))

func play_bgm() -> void:
	if _bgm_player and _bgm_player.stream:
		if not _bgm_player.playing:
			_bgm_player.play()

func stop_bgm() -> void:
	if _bgm_player and _bgm_player.playing:
		_bgm_player.stop()

func fade_bgm(target_db: float, duration: float) -> void:
	if _bgm_player:
		var tween: Tween = create_tween()
		tween.tween_property(_bgm_player, "volume_db", target_db, duration)

func play_sfx(sfx_id: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _sfx_streams.has(sfx_id):
		return

	var stream: AudioStream = _sfx_streams[sfx_id]
	var player: AudioStreamPlayer = _sfx_pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE

	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale + randf_range(-0.04, 0.04) # Subtle organic pitch variation
	player.play()
