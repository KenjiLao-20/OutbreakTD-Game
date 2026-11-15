class_name SentryGun
extends BaseTower

@onready var turret_head: Node2D = $TurretHead
@onready var head_sprite: AnimatedSprite2D = $TurretHead/HeadSprite
@onready var base_sprite: Sprite2D = $BaseSprite
@onready var detect_sound: AudioStreamPlayer2D = $DetectSound
@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound

func _ready() -> void:
	super._ready()
	scan_speed = 2.0
	scan_angle_deg = 60.0
	enable_idle_scan = true

	if turret_head:
		base_facing_angle = turret_head.rotation
	if head_sprite:
		head_sprite.animation_finished.connect(_on_animation_finished)
		head_sprite.play("idle")

	target_acquired.connect(_on_target_acquired)  # was missing before

func _on_target_acquired(_enemy: Node2D) -> void:
	if targets_in_range.size() == 1 and detect_sound:
		detect_sound.play()

func _process(delta: float) -> void:
	super._process(delta)
	if is_preview:
		return

	if current_target and is_instance_valid(current_target):
		if turret_head:
			var target_angle := (current_target.global_position - turret_head.global_position).angle()
			turret_head.rotation = lerp_angle(turret_head.rotation, target_angle, rotation_speed * delta)
	else:
		scan_time += delta * scan_speed
		var sweep_offset := sin(scan_time) * deg_to_rad(scan_angle_deg / 2.0)
		var desired_angle := base_facing_angle + sweep_offset
		if turret_head:
			turret_head.rotation = lerp_angle(turret_head.rotation, desired_angle, rotation_speed * delta)

func _fire(target: Node2D) -> void:
	if head_sprite:
		head_sprite.frame = 0
		head_sprite.play("shoot")
	if shoot_sound:
		shoot_sound.play()
	super._fire(target)

func _on_animation_finished() -> void:
	if head_sprite and head_sprite.animation == "shoot":
		head_sprite.play("idle")

func _on_preview_state_changed() -> void:
	super._on_preview_state_changed()
	if not is_inside_tree():
		return
	var tint := Color.WHITE
	if is_preview:
		tint = Color(0.35, 0.35, 0.35, 0.65) if is_valid_placement else Color(1.0, 0.25, 0.25, 0.65)
	if base_sprite:
		base_sprite.modulate = tint
	if head_sprite:
		head_sprite.modulate = tint
