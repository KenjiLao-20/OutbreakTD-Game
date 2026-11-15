class_name BaseTower
extends StaticBody2D

@export var attack_damage: int = 2
@export var rotation_speed: float = 10.0
@export var enable_idle_scan: bool = false
@export var scan_speed: float = 2.0
@export var scan_angle_deg: float = 60.0

# Range circle visuals
@export var valid_color: Color = Color(0.25, 0.25, 0.25, 0.45)
@export var invalid_color: Color = Color(1.0, 0.1, 0.1, 0.5)

# attack_range is READ from RangeArea/CollisionShape2D's CircleShape2D radius
# in _ready(). Set the tower's range by resizing that shape in the editor,
# not by editing a number here.
var attack_range: float = 0.0
var range_shape: CircleShape2D

var is_preview: bool = false : set = _set_is_preview
var is_valid_placement: bool = true : set = _set_is_valid_placement
var is_hovered: bool = false
var hover_area: Area2D
var is_deploying: bool = false

## How long a placed (non-preview) tower is locked out of targeting/firing
## while its "placement" animation plays. Independent of the animation's own
## frame count/FPS — set this to whatever feels right regardless.
@export var deploy_duration: float = 1.0

## If true, this tower can ONLY be placed on a path/unbuildable tile instead
## of a normal buildable one (e.g. a mine). main_map.gd checks this on the
## ghost instance when validating placement.
@export var requires_path_tile: bool = false

var targets_in_range: Array[Node2D] = []
var current_target: Node2D = null

var scan_time: float = 0.0
var base_facing_angle: float = 0.0

@onready var range_area: Area2D = get_node_or_null("RangeArea")
@onready var attack_timer: Timer = get_node_or_null("AttackTimer")

signal target_acquired(target: Node2D)

func _ready() -> void:
	if attack_timer:
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		attack_timer.stop()  # only runs once something is actually in range

	if range_area:
		range_area.body_entered.connect(_on_range_body_entered)
		range_area.body_exited.connect(_on_range_body_exited)
		range_area.area_entered.connect(_on_range_area_entered)
		range_area.area_exited.connect(_on_range_area_exited)
		range_area.input_pickable = false
		range_area.draw.connect(_draw_range)

		var range_collision := range_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if range_collision and range_collision.shape is CircleShape2D:
			range_collision.shape = range_collision.shape.duplicate()
			range_shape = range_collision.shape
			attack_range = range_shape.radius
		else:
			push_warning("%s has no CircleShape2D on RangeArea/CollisionShape2D." % name)

	_setup_hover_area()
	_on_preview_state_changed()  # apply whatever state was set before _ready ran

	# Ghost/preview towers never deploy — only towers that are actually
	# placed (is_preview false at _ready time) play their deploy animation.
	if not is_preview:
		_start_deploy()


func _setup_hover_area() -> void:
	hover_area = Area2D.new()
	hover_area.name = "HoverArea"
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	collision.shape = circle
	hover_area.add_child(collision)
	add_child(hover_area)

	hover_area.input_pickable = true
	hover_area.monitoring = false
	hover_area.monitorable = false
	hover_area.mouse_entered.connect(_on_mouse_entered)
	hover_area.mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	if is_preview:
		return
	is_hovered = true
	if range_area:
		range_area.queue_redraw()


func _on_mouse_exited() -> void:
	if is_preview:
		return
	is_hovered = false
	if range_area:
		range_area.queue_redraw()


func _draw_range() -> void:
	if not (is_hovered or is_preview):
		return
	var draw_color := invalid_color if (is_preview and not is_valid_placement) else valid_color
	range_area.draw_circle(Vector2.ZERO, attack_range, draw_color)


func _set_is_preview(value: bool) -> void:
	is_preview = value
	_on_preview_state_changed()


func _set_is_valid_placement(value: bool) -> void:
	is_valid_placement = value
	_on_preview_state_changed()


func _process(_delta: float) -> void:
	if is_preview or is_deploying:
		return
	_update_target()


func _update_target() -> void:
	# Drop anything mid-death too, not just freed instances — a dying enemy
	# is already a no-op for take_damage(), but towers shouldn't keep
	# beaming/shooting/aiming at something that's already dead visually.
	targets_in_range = targets_in_range.filter(
		func(t): return is_instance_valid(t) and not t.get("is_dead")
	)
	if targets_in_range.size() > 0:
		var old_target = current_target
		current_target = targets_in_range[0]
		if current_target != old_target:
			target_acquired.emit(current_target)
	else:
		current_target = null


func _on_attack_timer_timeout() -> void:
	if is_preview or is_deploying:
		return
	if current_target and is_instance_valid(current_target):
		_fire(current_target)


func _fire(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)


# Detection doesn't require a manually-assigned "enemies" group. Anything
# with a take_damage() method counts as a valid target, whether it arrives
# as a physics body or as an Area2D (e.g. a hurtbox).
func _add_target(candidate: Node) -> void:
	if not candidate or not candidate.has_method("take_damage"):
		return
	if targets_in_range.has(candidate):
		return
	var was_empty := targets_in_range.is_empty()
	targets_in_range.append(candidate)
	if was_empty:
		# Fire immediately on first target instead of waiting a full
		# attack_timer cycle, then start the timer for the cooldown
		# before the NEXT shot. Skipped entirely while still deploying.
		current_target = candidate
		target_acquired.emit(candidate)
		if not is_deploying:
			_fire(candidate)
		if attack_timer:
			attack_timer.start()


func _remove_target(candidate: Node) -> void:
	if candidate in targets_in_range:
		targets_in_range.erase(candidate)
		if targets_in_range.is_empty() and attack_timer:
			attack_timer.stop()


func _on_range_body_entered(body: Node2D) -> void:
	_add_target(body)


func _on_range_body_exited(body: Node2D) -> void:
	_remove_target(body)


func _on_range_area_entered(area: Area2D) -> void:
	var candidate = area.owner if area.owner else area.get_parent()
	_add_target(candidate)


func _on_range_area_exited(area: Area2D) -> void:
	var candidate = area.owner if area.owner else area.get_parent()
	_remove_target(candidate)


## Override in a variant script for tinting sprites, etc. Base implementation
## just makes sure the range circle redraws whenever state flips.
func _on_preview_state_changed() -> void:
	if range_area:
		range_area.queue_redraw()


## Override in a variant that has a "placement" deploy animation. Base does
## nothing, so towers without one (e.g. Sentry Gun) are instantly active.
func _start_deploy() -> void:
	pass
