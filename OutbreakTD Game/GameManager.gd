extends Node

signal base_health_changed(current_health)
signal game_over
signal game_won
signal wave_changed(current_wave)
signal base_damage_state_changed(state: int)
signal coins_changed(total: int)

enum DamageState { NONE, MINIMAL, MID, HEAVY, DESTROYED }

@export var max_base_health: int = 5
@export var starting_coins: int = 10  # change this number to tune how much gold you start with
@export var wave_health_scaling: float = 0.1  # +10% enemy health per wave, stacking linearly
@export var extra_wave_health_multiplier: Dictionary = {}  # extra flat multiplier stacked on TOP of the normal per-wave curve, for specific waves that need an extra kick — empty by default, add entries like {29: 1.5} if a specific wave needs it
var current_base_health: int = 5
var current_wave: int = 1
var coins: int = 200
var game_ended: bool = false
var _current_damage_state: int = DamageState.NONE


func _ready() -> void:
	current_base_health = max_base_health
	coins = starting_coins


func take_base_damage(amount: int) -> void:
	current_base_health = max(0, current_base_health - amount)
	base_health_changed.emit(current_base_health)
	_update_damage_state()

	print("Base hit! Health remaining: ", current_base_health)

	if current_base_health <= 0:
		trigger_game_over()


func trigger_game_over() -> void:
	if game_ended:
		return  # already won or lost, don't fire twice
	game_ended = true
	game_over.emit()
	print("GAME OVER!")


func trigger_win() -> void:
	if game_ended:
		return  # base already died, no win on top of a loss
	game_ended = true
	game_won.emit()
	print("YOU WIN!")


func set_wave(wave: int) -> void:
	current_wave = wave
	wave_changed.emit(current_wave)


# Wave 1 = 1.0x (no boost). Each wave after adds wave_health_scaling more —
# e.g. at 0.1, Wave 5 is 1.4x, Wave 10 is 1.9x, and so on, stacking linearly.
# extra_wave_health_multiplier then multiplies on top of that for specific
# waves (e.g. Wave 29's staged test wave) that need an extra kick beyond
# what the normal curve alone provides at that point.
func get_health_multiplier_for_wave(wave: int) -> float:
	var multiplier: float = 1.0 + float(wave - 1) * wave_health_scaling
	if extra_wave_health_multiplier.has(wave):
		multiplier *= float(extra_wave_health_multiplier[wave])
	return multiplier


# --- Gold ---------------------------------------------------------------

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func can_afford(amount: int) -> bool:
	return coins >= amount


# Returns true and takes the gold if you can afford it, false otherwise.
func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


# Called by Retry / Exit / New Game before changing scenes. GameManager is an
# autoload, so it survives scene changes and must be reset by hand.
func reset() -> void:
	current_base_health = max_base_health
	current_wave = 1
	coins = starting_coins
	game_ended = false
	_current_damage_state = DamageState.NONE


func _update_damage_state() -> void:
	var state: int

	if current_base_health <= 0:
		state = DamageState.DESTROYED
	elif current_base_health >= max_base_health:
		state = DamageState.NONE
	else:
		# Spread MINIMAL / MID / HEAVY evenly across however many hit points
		# sit between full health and destroyed.
		var mid_tier_count: int = DamageState.size() - 2  # MINIMAL, MID, HEAVY
		var lives_lost: int = max_base_health - current_base_health
		var max_lives_lost_before_death: int = max_base_health - 1
		var tier_index: int = clampi(
			int(ceil(float(lives_lost) / float(max_lives_lost_before_death) * mid_tier_count)),
			1, mid_tier_count
		)
		state = tier_index

	if state == _current_damage_state:
		return  # no redundant emits within the same tier

	_current_damage_state = state
	base_damage_state_changed.emit(state)


func get_current_damage_state() -> int:
	return _current_damage_state
