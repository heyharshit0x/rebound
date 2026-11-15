class_name KeyPickup
extends Area2D

## World collectible key with legendary beacon effects:
## vertical celestial light pillar, dual counter-rotating rune halos, radiant core flare,
## glittering particle motes, and floating overhead glowing banner.

signal key_collected(key_name: StringName)

@export var key_name: StringName = &"steel_key"
@export var key_texture: Texture2D
@export var display_title: String = "KEY"

const BEAM_TEX: Texture2D = preload("res://assets/pickups/keys/key_light_beam.png")
const HALO_TEX: Texture2D = preload("res://assets/pickups/keys/key_halo.png")
const STAR_TEX: Texture2D = preload("res://assets/environment/tiles/star_particle.png")
const FLARE_TEX: Texture2D = preload("res://assets/environment/tiles/torch_halo.png")

var _base_y: float = 0.0
var _anim_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

var _halo_inner: Sprite2D = null
var _halo_outer: Sprite2D = null
var _beam_sprite: Sprite2D = null
var _flare_sprite: Sprite2D = null
var _particles: CPUParticles2D = null
var _title_label: Label = null

func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)

	var theme_color: Color = _get_theme_color()

	if sprite:
		sprite.hframes = 8
		sprite.scale = Vector2(2.4, 2.4)
		sprite.modulate = Color(theme_color.r * 1.5, theme_color.g * 1.5, theme_color.b * 1.5, 1.0)
		sprite.z_index = 8

	_setup_beacon_vfx(theme_color)

func _get_theme_color() -> Color:
	var key_str: String = String(key_name).to_lower()
	if "molten" in key_str:
		return Color(2.6, 1.4, 0.4, 1.0) # Fiery molten gold
	elif "master" in key_str or "void" in key_str:
		return Color(1.8, 0.8, 2.8, 1.0) # Celestial void purple
	else:
		return Color(1.2, 2.2, 2.8, 1.0) # Radiant celestial cyan/silver

func _setup_beacon_vfx(color_tint: Color) -> void:
	# Vertical celestial light pillar shooting to the heavens
	_beam_sprite = Sprite2D.new()
	_beam_sprite.texture = BEAM_TEX
	_beam_sprite.position = Vector2(0, -70)
	_beam_sprite.scale = Vector2(2.0, 1.5)
	_beam_sprite.modulate = Color(color_tint.r, color_tint.g, color_tint.b, 0.65)
	_beam_sprite.z_index = 4
	add_child(_beam_sprite)

	# Radiant additive core flare
	_flare_sprite = Sprite2D.new()
	_flare_sprite.texture = FLARE_TEX
	_flare_sprite.position = Vector2(0, 0)
	_flare_sprite.scale = Vector2(0.9, 0.9)
	_flare_sprite.modulate = Color(color_tint.r * 1.2, color_tint.g * 1.2, color_tint.b * 1.2, 0.8)
	_flare_sprite.z_index = 5
	add_child(_flare_sprite)

	# Inner rotating magic rune halo
	_halo_inner = Sprite2D.new()
	_halo_inner.texture = HALO_TEX
	_halo_inner.position = Vector2(0, 0)
	_halo_inner.scale = Vector2(1.25, 1.25)
	_halo_inner.modulate = Color(color_tint.r * 1.3, color_tint.g * 1.3, color_tint.b * 1.3, 0.85)
	_halo_inner.z_index = 6
	add_child(_halo_inner)

	# Outer counter-rotating magic rune halo
	_halo_outer = Sprite2D.new()
	_halo_outer.texture = HALO_TEX
	_halo_outer.position = Vector2(0, 0)
	_halo_outer.scale = Vector2(1.8, 1.8)
	_halo_outer.modulate = Color(color_tint.r * 0.9, color_tint.g * 0.9, color_tint.b * 0.9, 0.55)
	_halo_outer.z_index = 6
	add_child(_halo_outer)

	# Sparkling gold & cyan dust emitter
	_particles = CPUParticles2D.new()
	_particles.amount = 20
	_particles.lifetime = 1.3
	_particles.preprocess = 0.5
	_particles.texture = STAR_TEX
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 16.0
	_particles.direction = Vector2(0, -1)
	_particles.spread = 45.0
	_particles.gravity = Vector2(0, -22)
	_particles.initial_velocity_min = 14.0
	_particles.initial_velocity_max = 30.0
	_particles.scale_amount_min = 0.6
	_particles.scale_amount_max = 1.4
	_particles.color = Color(color_tint.r * 1.2, color_tint.g * 1.2, color_tint.b * 1.2, 0.95)
	_particles.z_index = 9
	add_child(_particles)

	# Overhead floating title banner
	_title_label = Label.new()
	var raw_title: String = display_title if not display_title.is_empty() else String(key_name).replace("_", " ").to_upper()
	_title_label.text = "✦ %s ✦" % raw_title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 8)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.65, 1.0))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 1)
	_title_label.position = Vector2(-50, -32)
	_title_label.size = Vector2(100, 14)
	_title_label.z_index = 10
	add_child(_title_label)

func _process(delta: float) -> void:
	var time_ms: float = float(Time.get_ticks_msec())
	position.y = _base_y + sin(time_ms * 0.004) * 4.0

	# Dual counter-rotating rune halos with breathing pulse
	if _halo_inner:
		_halo_inner.rotation += delta * 2.2
		var breathe_in: float = 1.25 + sin(time_ms * 0.006) * 0.12
		_halo_inner.scale = Vector2(breathe_in, breathe_in)

	if _halo_outer:
		_halo_outer.rotation -= delta * 1.4
		var breathe_out: float = 1.80 + cos(time_ms * 0.005) * 0.15
		_halo_outer.scale = Vector2(breathe_out, breathe_out)

	if _flare_sprite:
		var flare_pulse: float = 0.9 + sin(time_ms * 0.008) * 0.15
		_flare_sprite.scale = Vector2(flare_pulse, flare_pulse)

	if _beam_sprite:
		_beam_sprite.modulate.a = 0.50 + sin(time_ms * 0.005) * 0.20

	# Smooth key spin through its 8 frames
	_anim_timer += delta
	if _anim_timer >= 0.10:
		_anim_timer = 0.0
		if sprite and sprite.hframes > 1:
			sprite.frame = (sprite.frame + 1) % sprite.hframes

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController or body.is_in_group("player"):
		VFX.play(&"gravity_burst", global_position, {
			"scale": Vector2(0.85, 0.85),
			"modulate": _get_theme_color()
		})
		VFX.play(&"parry_clash", global_position, {
			"scale": Vector2(0.65, 0.65)
		})
		Events.camera_shake_requested.emit(4.5, 0.16)
		Events.score_awarded.emit(300, &"key_collected")
		key_collected.emit(key_name)
		Events.core_fragment_collected.emit(key_name)
		queue_free()
