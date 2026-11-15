class_name IceTower
extends BaseTower

## How strong the slow is (0.5 = half speed) and how long it lasts.
@export var slow_multiplier: float = 0.5
@export var slow_duration: float = 2.0

## AOE radius the slow actually spreads to, separate from (and usually
## smaller than) the tower's detection range. Start small, tune from here.
@export var aoe_radius: float = 40.0

@onready var ice_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var cast_sound: AudioStreamPlayer2D = get_node_or_null("Casting")
@onready var hit_sound: AudioStreamPlayer2D = get_node_or_null("HittedEffect")

# The enemy that was targeted when the shot was fired. The AOE centers on
# THIS enemy's position when the shot lands, not on the tower's own
# position — like an ice ball that hits a target and bursts there.
var pending_target: Node2D = null


func _ready() -> void:
	super._ready()
	if ice_sprite:
		ice_sprite.animation_finished.connect(_on_animation_finished)


## Plays the "placement" animation once, then hands control back to normal
## idle/attack behavior after deploy_duration seconds — independent of
## however long the animation itself actually takes.
func _start_deploy() -> void:
	if ice_sprite and ice_sprite.sprite_frames and ice_sprite.sprite_frames.has_animation("placement"):
		is_deploying = true
		ice_sprite.play("placement")
		await get_tree().create_timer(deploy_duration).timeout
		is_deploying = false
		if ice_sprite:
			ice_sprite.play("idle")
	elif ice_sprite:
		ice_sprite.play("idle")


# Level 1 behavior: slow only, no damage, AOE around wherever the shot
# actually landed (the target it was aimed at when fired), not the tower.
# The actual slow is applied in _on_animation_finished, not here — this
# just starts the windup (animation + cast sound) and remembers the target.
func _fire(target: Node2D) -> void:
	pending_target = target
	if ice_sprite:
		ice_sprite.frame = 0
		ice_sprite.play("shoot")
	if cast_sound:
		cast_sound.play()


func _apply_aoe_slow() -> void:
	if pending_target == null or not is_instance_valid(pending_target):
		return

	var burst_center: Vector2 = pending_target.global_position

	for t in targets_in_range:
		if not is_instance_valid(t):
			continue
		if not t.has_method("apply_slow"):
			continue
		if burst_center.distance_to(t.global_position) <= aoe_radius:
			t.apply_slow(slow_multiplier, slow_duration)

	pending_target = null

	if hit_sound:
		hit_sound.play()


func _on_animation_finished() -> void:
	if ice_sprite and ice_sprite.animation == "shoot":
		_apply_aoe_slow()
		ice_sprite.play("idle")


func _on_preview_state_changed() -> void:
	super._on_preview_state_changed()
	if not is_inside_tree() or not ice_sprite:
		return
	var tint := Color.WHITE
	if is_preview:
		tint = Color(0.35, 0.35, 0.35, 0.65) if is_valid_placement else Color(1.0, 0.25, 0.25, 0.65)
	ice_sprite.modulate = tint
