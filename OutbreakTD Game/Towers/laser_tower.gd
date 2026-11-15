class_name LaserTower
extends BaseTower

@export var damage_per_second: float = 5.0

@onready var laser_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var beam_glow: Line2D = get_node_or_null("BeamGlow")
@onready var beam_core: Line2D = get_node_or_null("BeamCore")
@onready var windup_sound: AudioStreamPlayer2D = get_node_or_null("WindupSound")
@onready var fire_sound: AudioStreamPlayer2D = get_node_or_null("FireSound")

# Where the sustain loop starts/ends and where the stop-tail starts, within
# the single FireSound clip. Adjust these if you re-time the audio later.
const FIRE_LOOP_START := 0.1
const FIRE_LOOP_END := 0.6
const FIRE_TAIL_START := 0.7

var _is_firing: bool = false

# take_damage() expects an int, but DPS * delta is fractional — this
# accumulates fractional damage and only applies it once it rounds up to
# a whole point, so low DPS values still deal damage correctly over time.
var _damage_accumulator: float = 0.0


func _ready() -> void:
	super._ready()
	_set_beam_visible(false)


## Plays the "placement" animation once, then hands control back to normal
## idle behavior after deploy_duration seconds — independent of however
## long the animation itself actually takes.
func _start_deploy() -> void:
	if laser_sprite and laser_sprite.sprite_frames and laser_sprite.sprite_frames.has_animation("placement"):
		is_deploying = true
		laser_sprite.play("placement")
		await get_tree().create_timer(deploy_duration).timeout
		is_deploying = false
		if laser_sprite:
			laser_sprite.play("idle")
	elif laser_sprite:
		laser_sprite.play("idle")


func _process(delta: float) -> void:
	super._process(delta)  # keeps BaseTower's target detection/selection working
	if is_preview or is_deploying:
		_set_beam_visible(false)
		_stop_firing_sound()
		return

	if current_target and is_instance_valid(current_target):
		_update_beam(current_target)
		_apply_beam_damage(current_target, delta)
		_update_firing_sound()
	else:
		_set_beam_visible(false)
		_damage_accumulator = 0.0
		_stop_firing_sound()


func _update_beam(target: Node2D) -> void:
	_set_beam_visible(true)
	var local_target := to_local(target.global_position)
	if beam_glow:
		beam_glow.points = [Vector2.ZERO, local_target]
	if beam_core:
		beam_core.points = [Vector2.ZERO, local_target]


func _set_beam_visible(value: bool) -> void:
	if beam_glow:
		beam_glow.visible = value
	if beam_core:
		beam_core.visible = value


## Called every frame while a target is actively being beamed. Plays the
## windup once at the start, then loops just the 0.1-0.6s sustain section
## of FireSound by re-triggering it whenever it reaches the loop end.
func _update_firing_sound() -> void:
	if not _is_firing:
		_is_firing = true
		if windup_sound:
			windup_sound.play()
		if fire_sound:
			fire_sound.play(FIRE_LOOP_START)
		return

	if fire_sound and fire_sound.playing:
		if fire_sound.get_playback_position() >= FIRE_LOOP_END:
			fire_sound.play(FIRE_LOOP_START)


## Called once the beam stops (target lost, went into preview/deploy, etc).
## Lets FireSound's 0.7-0.9s tail play out once instead of cutting it dead.
func _stop_firing_sound() -> void:
	if not _is_firing:
		return
	_is_firing = false
	if fire_sound:
		fire_sound.play(FIRE_TAIL_START)


func _apply_beam_damage(target: Node2D, delta: float) -> void:
	if not target.has_method("take_damage"):
		return
	_damage_accumulator += damage_per_second * delta
	var whole_damage := int(_damage_accumulator)
	if whole_damage > 0:
		target.take_damage(whole_damage)
		_damage_accumulator -= whole_damage


func _on_preview_state_changed() -> void:
	super._on_preview_state_changed()
	if not is_inside_tree() or not laser_sprite:
		return
	var tint := Color.WHITE
	if is_preview:
		tint = Color(0.35, 0.35, 0.35, 0.65) if is_valid_placement else Color(1.0, 0.25, 0.25, 0.65)
	laser_sprite.modulate = tint
