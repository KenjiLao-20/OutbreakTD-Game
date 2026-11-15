class_name PlantTower
extends BaseTower

@export var projectile_scene: PackedScene  # assign PlantProjectile.tscn in the Inspector
@export var burst_count: int = 6

@onready var plant_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var plant_shoot_sound: AudioStreamPlayer2D = get_node_or_null("Shoot")
@onready var hit_sound: AudioStreamPlayer2D = get_node_or_null("HittedanEnemy")


func _ready() -> void:
	super._ready()
	if plant_sprite:
		plant_sprite.animation_finished.connect(_on_animation_finished)


## Plays the "placement" animation once, then hands control back to normal
## idle/attack behavior after deploy_duration seconds — independent of
## however long the animation itself actually takes.
func _start_deploy() -> void:
	if plant_sprite and plant_sprite.sprite_frames and plant_sprite.sprite_frames.has_animation("placement"):
		is_deploying = true
		plant_sprite.play("placement")
		await get_tree().create_timer(deploy_duration).timeout
		is_deploying = false
		if plant_sprite:
			plant_sprite.play("idle")
	elif plant_sprite:
		plant_sprite.play("idle")


# Radial burst ignores the specific target passed in — BaseTower's
# "current_target exists" check is just used as the "something is in
# range" gate. The burst itself hits in all fixed directions at once.
func _fire(_target: Node2D) -> void:
	if plant_sprite:
		plant_sprite.frame = 0
		plant_sprite.play("shoot")
	if plant_shoot_sound:
		plant_shoot_sound.play()
	_burst()


func _burst() -> void:
	if projectile_scene == null or burst_count <= 0:
		return
	for i in range(burst_count):
		var angle := (TAU / burst_count) * i
		var dir := Vector2.RIGHT.rotated(angle)
		var proj = projectile_scene.instantiate()
		# Deferred: this can be called from inside RangeArea's area_entered/
		# body_entered signal (the instant-first-shot path), and Godot
		# disallows adding new monitoring Area2D nodes to the tree while
		# still flushing that physics query. call_deferred waits until it's
		# safe.
		get_parent().add_child.call_deferred(proj)
		proj.call_deferred("launch", global_position, dir)
		proj.hit.connect(_on_projectile_hit)


func _on_projectile_hit(_target: Node) -> void:
	if hit_sound:
		hit_sound.play()


func _on_animation_finished() -> void:
	if plant_sprite and plant_sprite.animation == "shoot":
		plant_sprite.play("idle")


func _on_preview_state_changed() -> void:
	super._on_preview_state_changed()
	if not is_inside_tree() or not plant_sprite:
		return
	var tint := Color.WHITE
	if is_preview:
		tint = Color(0.35, 0.35, 0.35, 0.65) if is_valid_placement else Color(1.0, 0.25, 0.25, 0.65)
	plant_sprite.modulate = tint
