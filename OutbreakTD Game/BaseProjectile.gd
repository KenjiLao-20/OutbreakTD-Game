class_name BaseProjectile
extends Area2D

signal hit(target: Node)

@export var speed: float = 300.0
@export var damage: int = 1
@export var max_lifetime: float = 2.0  # seconds before it despawns if it hits nothing

## Set to -1 for unlimited piercing (hits every enemy in its path until it
## despawns from max_lifetime). Default 1 = despawns after its first hit,
## same as before this field existed — nothing changes for existing scenes.
@export var max_hits: int = 1

var direction: Vector2 = Vector2.RIGHT
var _traveled_time: float = 0.0
var _hit_count: int = 0
var _already_hit: Array[Node] = []  # prevents double-counting the same enemy


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	global_position += direction * speed * delta
	_traveled_time += delta
	if _traveled_time >= max_lifetime:
		queue_free()


## Call this right after instantiating, before adding to the tree or right after.
func launch(from_position: Vector2, dir: Vector2) -> void:
	global_position = from_position
	direction = dir.normalized()
	rotation = direction.angle()


func _on_area_entered(area: Area2D) -> void:
	var candidate = area.owner if area.owner else area.get_parent()
	_try_hit(candidate)


func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _try_hit(candidate: Node) -> void:
	if not candidate or not candidate.has_method("take_damage"):
		return
	if candidate in _already_hit:
		return  # don't double-hit the same enemy from one overlap event

	candidate.take_damage(damage)
	_already_hit.append(candidate)
	_hit_count += 1
	hit.emit(candidate)

	if max_hits >= 0 and _hit_count >= max_hits:
		queue_free()
