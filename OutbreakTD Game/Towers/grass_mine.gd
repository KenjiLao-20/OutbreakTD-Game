class_name MineTower
extends BaseTower

@export var blast_damage: int = 5
@export var blast_radius: float = 30.0

## Mines also fling out a ring of projectiles on top of the blast — same
## PlantProjectile, just 8 directions instead of Plant Tower's 6.
@export var projectile_scene: PackedScene  # assign PlantProjectile.tscn
@export var shrapnel_count: int = 8

@onready var mine_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var steppedon_sound: AudioStreamPlayer2D = get_node_or_null("Steppedon")
@onready var explosion_sound: AudioStreamPlayer2D = get_node_or_null("Explosion")

var _has_exploded: bool = false


func _ready() -> void:
	requires_path_tile = true
	super._ready()
	if mine_sprite:
		mine_sprite.play("idle")


# A mine's "attack" IS its explosion — BaseTower's existing "fire instantly
# on first target" behavior in _add_target() already matches "explodes when
# an enemy steps on it" perfectly, so no extra trigger logic is needed here.
func _fire(_target: Node2D) -> void:
	if _has_exploded:
		return
	_has_exploded = true
	_explode()


func _explode() -> void:
	if steppedon_sound:
		steppedon_sound.play()

	if range_area:
		# Deferred: this runs from inside RangeArea's own area_entered/
		# body_entered signal (via the instant-first-shot path), and Godot
		# disallows changing monitoring state synchronously mid-signal.
		range_area.set_deferred("monitoring", false)

	if mine_sprite and mine_sprite.sprite_frames and mine_sprite.sprite_frames.has_animation("explode"):
		mine_sprite.play("explode")
		mine_sprite.frame_changed.connect(_on_explode_frame_changed)
		mine_sprite.animation_finished.connect(_on_explode_finished, CONNECT_ONE_SHOT)
	else:
		# No explode animation set up yet — deal damage immediately and
		# remove the mine rather than leaving it stuck doing nothing.
		_deal_blast_damage()
		_fling_shrapnel()
		if explosion_sound:
			explosion_sound.play()
		queue_free()


func _on_explode_frame_changed() -> void:
	if mine_sprite.animation != "explode":
		return
	var last_frame := mine_sprite.sprite_frames.get_frame_count("explode") - 1
	if mine_sprite.frame == last_frame:
		_deal_blast_damage()
		_fling_shrapnel()
		if explosion_sound:
			explosion_sound.play()
		mine_sprite.frame_changed.disconnect(_on_explode_frame_changed)


func _on_explode_finished() -> void:
	queue_free()  # the mine is spent — remove it once the animation plays out


func _deal_blast_damage() -> void:
	for t in targets_in_range:
		if not is_instance_valid(t):
			continue
		if not t.has_method("take_damage"):
			continue
		if global_position.distance_to(t.global_position) <= blast_radius:
			t.take_damage(blast_damage)


func _fling_shrapnel() -> void:
	if projectile_scene == null or shrapnel_count <= 0:
		return
	for i in range(shrapnel_count):
		var angle := (TAU / shrapnel_count) * i
		var dir := Vector2.RIGHT.rotated(angle)
		var proj = projectile_scene.instantiate()
		# Deferred for the same reason as Plant Tower's burst — this runs
		# from inside a signal callback chain, and Godot disallows adding
		# new monitoring Area2D nodes mid-physics-query-flush.
		get_parent().add_child.call_deferred(proj)
		proj.call_deferred("launch", global_position, dir)


func _on_preview_state_changed() -> void:
	super._on_preview_state_changed()
	if not is_inside_tree() or not mine_sprite:
		return
	var tint := Color.WHITE
	if is_preview:
		tint = Color(0.35, 0.35, 0.35, 0.65) if is_valid_placement else Color(1.0, 0.25, 0.25, 0.65)
	mine_sprite.modulate = tint
