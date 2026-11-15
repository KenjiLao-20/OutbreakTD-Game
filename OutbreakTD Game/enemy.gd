extends PathFollow2D
class_name BaseEnemy

@export var speed: float = 50.0
@export var max_health: int = 4
@export var damage_to_base: int = 1
@export var coin_value: int = 5  # gold paid out on a kill — set per enemy scene

var current_health: int = 0
var is_dead: bool = false

# Slow-status effect state. Multiple slows don't stack multiplicatively —
# the strongest multiplier wins, and duration extends to the longest one
# applied, so overlapping Ice Tower shots don't compound into a standstill.
var slow_multiplier: float = 1.0
var slow_time_left: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_2d: Area2D = $Area2D

# Optional — leave this node out of a scene entirely if that enemy has no
# death sound. Any enemy that wants one just adds an AudioStreamPlayer2D
# named exactly "DeathSound"; nothing else to wire up.
@onready var death_sound: AudioStreamPlayer2D = get_node_or_null("DeathSound")

func _ready() -> void:
	loop = false # Prevents path from wrapping ratio back to 0.0 at the end
	var health_multiplier: float = 1.0
	if GameManager and GameManager.has_method("get_health_multiplier_for_wave"):
		health_multiplier = GameManager.get_health_multiplier_for_wave(GameManager.current_wave)
	current_health = int(ceil(max_health * health_multiplier))
	if animated_sprite and animated_sprite.sprite_frames.has_animation("walk"):
		animated_sprite.play("walk")

func _process(delta: float) -> void:
	# Freeze position when dying so it doesn't slide along the path while popping
	if is_dead:
		return

	if slow_time_left > 0.0:
		slow_time_left -= delta
		if slow_time_left <= 0.0:
			slow_multiplier = 1.0

	var effective_speed := speed * slow_multiplier
	progress += effective_speed * delta

	# Using 0.99 catches precision rounding before loop boundary
	if progress_ratio >= 0.99:
		reach_base()

func reach_base() -> void:
	if GameManager and GameManager.has_method("take_base_damage"):
		GameManager.take_base_damage(damage_to_base)
	queue_free()

func take_damage(amount: int) -> void:
	if is_dead:
		return

	current_health -= amount
	if current_health <= 0:
		die()

## multiplier: 0.5 = half speed, lower = stronger slow. duration in seconds.
func apply_slow(multiplier: float, duration: float) -> void:
	if is_dead:
		return
	slow_multiplier = min(slow_multiplier, multiplier)
	slow_time_left = max(slow_time_left, duration)

func die() -> void:
	is_dead = true

	# Pay out immediately on death — a leaked enemy calls reach_base()
	# instead and never reaches this line, so leaks don't earn gold.
	if GameManager and GameManager.has_method("add_coins"):
		GameManager.add_coins(coin_value)

	if death_sound:
		death_sound.play()

	# Instantly disable collision so turrets stop targeting it
	if area_2d:
		area_2d.set_deferred("monitoring", false)
		area_2d.set_deferred("monitorable", false)

	# Play the death animation and wait for frame 5 to finish before removing
	if animated_sprite and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished

	queue_free()
