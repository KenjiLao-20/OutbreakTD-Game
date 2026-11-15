extends StaticBody2D


@export var attack_damage: int = 2
@export var rotation_speed: float = 10.0

# Optional idle scanning (Set to TRUE for Sentry, FALSE for standard turrets)
@export var enable_idle_scan: bool = false 
@export var scan_speed: float = 2.0      # How fast it sweeps back and forth
@export var scan_angle_deg: float = 60.0 # Total sweep arc in degrees

var attack_range: float = 0.0
var range_shape: CircleShape2D 

@export var valid_color: Color = Color(0.25, 0.25, 0.25, 0.45)
@export var invalid_color: Color = Color(1.0, 0.1, 0.1, 0.5)

var targets_in_range: Array[Node2D] = []
var current_target: Node2D = null
var scan_time: float = 0.0
var base_facing_angle: float = 0.0

# Hover & Placement preview states
var is_preview: bool = false : set = set_preview
var is_valid_placement: bool = true : set = set_valid_placement
var is_hovered: bool = false
var hover_area: Area2D

@onready var turret_head: Node2D = $TurretHead
@onready var head_sprite: AnimatedSprite2D = $TurretHead/HeadSprite
@onready var base_sprite: Sprite2D = $BaseSprite
@onready var range_area: Area2D = $RangeArea
@onready var attack_timer: Timer = $AttackTimer

# Sound Effect Nodes
@onready var detect_sound: AudioStreamPlayer2D = $DetectSound
@onready var shoot_sound: AudioStreamPlayer2D = $ShootSound

func set_preview(value: bool) -> void:
	is_preview = value
	_update_visuals()

func set_valid_placement(value: bool) -> void:
	is_valid_placement = value
	_update_visuals()

func _update_visuals() -> void:
	var target_range_area = range_area if range_area else get_node_or_null("RangeArea")
	if target_range_area:
		target_range_area.queue_redraw()

	var active_head = head_sprite if head_sprite else get_node_or_null("TurretHead/HeadSprite")
	var active_base = base_sprite if base_sprite else get_node_or_null("BaseSprite")

	var tint = Color(1.0, 0.3, 0.3, 0.7) if (is_preview and not is_valid_placement) else Color.WHITE
	if active_head: active_head.modulate = tint
	if active_base: active_base.modulate = tint

func _ready() -> void:
	if turret_head:
		base_facing_angle = turret_head.rotation

	if range_area:
		range_area.input_pickable = false
		range_area.draw.connect(_on_range_area_draw)

		var range_collision = range_area.get_node_or_null("CollisionShape2D")
		if range_collision and range_collision.shape is CircleShape2D:
			range_collision.shape = range_collision.shape.duplicate()
			range_shape = range_collision.shape
			attack_range = range_shape.radius
		else:
			push_warning("Tower '%s' has no CircleShape2D on RangeArea/CollisionShape2D." % name)

		range_area.area_entered.connect(_on_range_area_entered)
		range_area.area_exited.connect(_on_range_area_exited)

	if attack_timer:
		attack_timer.timeout.connect(_on_attack_timer_timeout)

	if head_sprite:
		head_sprite.animation_finished.connect(_on_animation_finished)
		head_sprite.play("idle")

	hover_area = Area2D.new()
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	collision.shape = circle
	hover_area.add_child(collision)
	add_child(hover_area)

	hover_area.input_pickable = true
	hover_area.mouse_entered.connect(_on_mouse_entered)
	hover_area.mouse_exited.connect(_on_mouse_exited)

	_update_visuals()

func set_attack_range_runtime(new_radius: float) -> void:
	attack_range = new_radius
	if range_shape:
		range_shape.radius = new_radius
	if range_area:
		range_area.queue_redraw()

func _on_range_area_draw() -> void:
	if is_hovered or is_preview:
		var draw_color = invalid_color if (is_preview and not is_valid_placement) else valid_color
		range_area.draw_circle(Vector2.ZERO, attack_range, draw_color)

func _on_mouse_entered() -> void:
	if not is_preview:
		is_hovered = true
		_update_visuals()

func _on_mouse_exited() -> void:
	if not is_preview:
		is_hovered = false
		_update_visuals()

func _on_range_area_entered(area: Area2D) -> void:
	if is_preview:
		return

	var enemy = area.owner if area.owner else area.get_parent()
	if enemy and enemy.has_method("take_damage") and not targets_in_range.has(enemy):
		if targets_in_range.is_empty():
			if detect_sound: detect_sound.play()
			if attack_timer and attack_timer.is_stopped():
				attack_timer.start()

		targets_in_range.append(enemy)

func _on_range_area_exited(area: Area2D) -> void:
	if is_preview:
		return

	var enemy = area.owner if area.owner else area.get_parent()
	if enemy in targets_in_range:
		targets_in_range.erase(enemy)
		if targets_in_range.is_empty() and attack_timer:
			attack_timer.stop()

func _process(delta: float) -> void:
	if is_preview:
		return

	targets_in_range = targets_in_range.filter(
		func(target): return is_instance_valid(target) and not target.get("is_dead")
	)

	if targets_in_range.is_empty() and attack_timer and not attack_timer.is_stopped():
		attack_timer.stop()

	if targets_in_range.size() > 0:
		targets_in_range.sort_custom(func(a, b): return a.progress > b.progress)
		current_target = targets_in_range[0]

		var target_angle = (current_target.global_position - turret_head.global_position).angle()
		turret_head.rotation = lerp_angle(turret_head.rotation, target_angle, rotation_speed * delta)
	else:
		current_target = null
		# Only sweep if idle scan is explicitly enabled for this tower
		if enable_idle_scan:
			scan_time += delta * scan_speed
			var sweep_offset = sin(scan_time) * deg_to_rad(scan_angle_deg / 2.0)
			var desired_scan_angle = base_facing_angle + sweep_offset
			turret_head.rotation = lerp_angle(turret_head.rotation, desired_scan_angle, rotation_speed * delta)

func _on_attack_timer_timeout() -> void:
	if not is_preview and current_target and is_instance_valid(current_target):
		shoot()

func shoot() -> void:
	if head_sprite and head_sprite.sprite_frames.has_animation("shoot"):
		head_sprite.frame = 0
		head_sprite.play("shoot")
	if shoot_sound:
		shoot_sound.play()

	if current_target and current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)

func _on_animation_finished() -> void:
	if head_sprite and head_sprite.animation == "shoot":
		head_sprite.play("idle")
