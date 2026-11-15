extends Node2D

@export var path_node: Path2D

## Parallel arrays: assign each enemy scene here, and give it the matching
## name string used by wave_data below. Keep both arrays the same length
## and paired at the same index — order doesn't matter otherwise.
@export var enemy_names: Array[String] = []
@export var enemy_scenes: Array[PackedScene] = []

@export var spawn_delay: float = 1.0
@export var time_between_waves: float = 5.0
@export var wave_timeout: float = 15.0
@export var initial_wait: float = 3.0

## Spawn delay speeds up wave by wave instead of staying fixed the whole
## game. Wave 1 spawns at spawn_delay; by wave_ramp_target it's reached
## min_spawn_delay, and stays there for every wave after.
@export var min_spawn_delay: float = 0.2
@export var wave_ramp_target: int = 27

## Waves listed here spawn EVERY enemy for that wave in one frame instead of
## staggered — true instant burst.
@export var burst_wave_numbers: Array[int] = []

## Waves listed here IGNORE the ramp above and use fast_spawn_delay instead
## — a hard override for a specific "everything at once" moment.
@export var fast_spawn_wave_numbers: Array[int] = [28]
@export var fast_spawn_delay: float = 0.12

## Testing helper: set to 1 to end the game (win) after wave 1.
## 0 = play all waves normally. Remember to set back to 0 before handing in!
@export var wave_limit: int = 0

## Testing helper: set to e.g. 29 to skip straight to that wave instead of
## playing 1 through it first. 0 = start normally at wave 1. You'll start
## with the same 10 gold and no towers, same as a real run — this only
## skips the early waves, not the economy.
@export var debug_start_wave: int = 0

## Formation used when a staged wave's stage bursts multiple enemies at
## once: instead of dropping everyone in one rigid, locked-together grid,
## they pour out in quick pairs (or however many "abreast"), a fraction of
## a second apart. Each one then follows the path completely on its own —
## nothing stays artificially attached to anything else, so corners/turns
## look natural instead of the whole group rotating as one stiff block.
@export var formation_abreast: int = 2            # how many spawn side by side at once
@export var formation_side_spacing: float = 8.0    # perpendicular gap between them — keep this tight, arm to arm
@export var formation_spawn_interval: float = 0.5  # seconds between each little group — this is what spaces out front-to-back

var enemies_alive: int = 0
var current_wave: int = 1
var wave_complete_handled: bool = false
var spawn_queue: Array[String] = []
var in_staged_wave: bool = false

@onready var spawn_timer: Timer = $SpawnTimer

# ---------------------------------------------------------------------------
# WAVE STRUCTURE — each entry is a Dictionary of enemy_name -> count for
# that wave. Edit numbers here directly; nothing else needs to change.
# Enemy name keys used below: "Crawler", "Soldier", "Bat", "Ooze", "Ant",
# "BlueAnt", "Slime" — must exactly match what you type into enemy_names.
# ---------------------------------------------------------------------------
var wave_data: Array[Dictionary] = [
	{"Ooze": 5},                                                                   # Wave 1
	{"Ooze": 8},                                                                   # Wave 2
	{"Ooze": 10, "Bat": 3},                                                        # Wave 3
	{"Bat": 8},                                                                    # Wave 4 — intro
	{"Bat": 10, "Ooze": 5},                                                        # Wave 5
	{"Ooze": 8, "Bat": 8},                                                         # Wave 6
	{"Ooze": 10, "Bat": 10},                                                       # Wave 7
	{"Ooze": 10, "Bat": 10, "Slime": 5},                                           # Wave 8
	{"Ooze": 12, "Slime": 12},                                                     # Wave 9 — horde
	{"Ant": 8},                                                                    # Wave 10 — intro, earlier + bigger
	{"Ant": 10, "Slime": 8},                                                       # Wave 11
	{"Ant": 12, "Slime": 10, "Bat": 6},                                            # Wave 12
	{"Ant": 10, "Bat": 10},                                                        # Wave 13
	{"Ant": 12, "Bat": 12, "Ooze": 6},                                             # Wave 14
	{"BlueAnt": 8},                                                                # Wave 15 — intro, earlier + bigger
	{"BlueAnt": 8, "Ooze": 8},                                                     # Wave 16
	{"BlueAnt": 10, "Ant": 10},                                                    # Wave 17 — siege
	{"BlueAnt": 10, "Bat": 10},                                                    # Wave 18
	{"BlueAnt": 8, "Ant": 8, "Ooze": 8, "Slime": 8},                               # Wave 19 — medium horde
	{"Soldier": 5},                                                                # Wave 20 — intro, earlier + bigger
	{"Soldier": 6, "Ant": 8},                                                      # Wave 21
	{"Soldier": 6, "BlueAnt": 6, "Ant": 6},                                        # Wave 22
	{"Soldier": 6, "Bat": 6, "Ooze": 6},                                           # Wave 23
	{"Crawler": 8},                                                                # Wave 24 — intro, earlier + bigger
	{"Soldier": 12, "Crawler": 12},                                                # Wave 25 — rush
	{"Soldier": 18, "Crawler": 18},                                                # Wave 26 — rush +
	{"Crawler": 8, "Soldier": 8, "Bat": 8, "Ooze": 8, "Ant": 8, "BlueAnt": 8, "Slime": 8},           # Wave 27
	{"Crawler": 20, "Soldier": 20, "Bat": 20, "Ooze": 20, "Ant": 20, "BlueAnt": 20, "Slime": 20},    # Wave 28 — FINALE
]

# ---------------------------------------------------------------------------
# STAGED WAVES — for waves that need scheduled, stacked bursts instead of
# the normal trickle-out queue. Each entry is wave number -> an ordered
# Array of stages. A stage is {"delay": seconds from wave start, "enemies":
# {name: count}}. Every enemy in a stage spawns INSTANTLY, all stacked at
# the path start, to read as a single heavy push rather than a trickle.
#
# A staged wave ignores wave_timeout entirely (it has to run its full
# length no matter what) and doesn't end until every stage has fired AND
# every enemy from it is dead. Numbers below are a first pass — playtest
# and retune freely.
# ---------------------------------------------------------------------------
var staged_waves: Dictionary = {
	29: [
		{"delay": 0.0,  "enemies": {"Soldier": 25}},                    # opening battalion — green rush
		{"delay": 15.0, "enemies": {"Crawler": 25}},                    # crawler battalion, while soldiers still mid-path
		{"delay": 35.0, "enemies": {"Soldier": 60, "Crawler": 20}},     # huge soldier-led push, overlapping both
	],
}


func _ready() -> void:
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	if debug_start_wave > 0:
		current_wave = debug_start_wave
		GameManager.set_wave(current_wave)
	await get_tree().create_timer(initial_wait).timeout
	start_wave()


func _last_wave() -> int:
	var natural_last: int = max(wave_data.size(), _highest_staged_wave())
	return wave_limit if wave_limit > 0 else natural_last


func _highest_staged_wave() -> int:
	var highest: int = 0
	for w in staged_waves.keys():
		highest = max(highest, w)
	return highest


## Smoothly speeds up spawning from spawn_delay (wave 1) down to
## min_spawn_delay (by wave_ramp_target and beyond).
func _get_ramped_spawn_delay(wave: int) -> float:
	if wave_ramp_target <= 1:
		return min_spawn_delay
	var t: float = clampf(float(wave - 1) / float(wave_ramp_target - 1), 0.0, 1.0)
	return lerpf(spawn_delay, min_spawn_delay, t)


func _get_scene_for(enemy_name: String) -> PackedScene:
	var idx := enemy_names.find(enemy_name)
	if idx == -1:
		push_warning("Spawner: no scene assigned for enemy name '%s'. Check enemy_names/enemy_scenes in the Inspector." % enemy_name)
		return null
	return enemy_scenes[idx]


func _build_spawn_queue(wave_index: int) -> Array[String]:
	var queue: Array[String] = []
	if wave_index < 0 or wave_index >= wave_data.size():
		return queue
	for enemy_name in wave_data[wave_index]:
		var count: int = wave_data[wave_index][enemy_name]
		for i in range(count):
			queue.append(enemy_name)
	queue.shuffle()  # interleave types instead of spawning in strict blocks
	return queue


func start_wave() -> void:
	enemies_alive = 0
	wave_complete_handled = false

	if staged_waves.has(current_wave):
		print("Starting Wave: ", current_wave, " (staged battalion wave)")
		_run_staged_wave(current_wave)
		return

	spawn_queue = _build_spawn_queue(current_wave - 1)
	print("Starting Wave: ", current_wave, " (", spawn_queue.size(), " enemies)")

	if spawn_queue.is_empty():
		print("No wave data for wave ", current_wave, " — nothing to spawn.")
		return

	if current_wave in burst_wave_numbers:
		_spawn_burst()
	else:
		if current_wave in fast_spawn_wave_numbers:
			spawn_timer.wait_time = fast_spawn_delay
		else:
			spawn_timer.wait_time = _get_ramped_spawn_delay(current_wave)
		spawn_timer.start()


func _spawn_burst() -> void:
	for enemy_name in spawn_queue:
		_spawn_one(enemy_name)
	spawn_queue.clear()
	_check_wave_complete()
	_start_wave_timeout()


## Runs a staged wave's scheduled bursts in order, then waits for the last
## survivors of the final stage to die before letting the wave end. Ignores
## wave_timeout entirely — this is meant to run its full length regardless.
func _run_staged_wave(wave: int) -> void:
	in_staged_wave = true
	var elapsed: float = 0.0

	for stage in staged_waves[wave]:
		var wait_time: float = max(0.0, float(stage["delay"]) - elapsed)
		if wait_time > 0.0:
			await get_tree().create_timer(wait_time).timeout
		elapsed = float(stage["delay"])
		await _spawn_stage_burst(stage["enemies"])

	# Every stage has fired. Now just wait for the last enemy from the final
	# stage to actually die — enemies_alive is still tracked normally via
	# _on_enemy_removed(), this just polls it instead of reacting to it.
	while enemies_alive > 0:
		await get_tree().create_timer(0.5).timeout

	in_staged_wave = false
	if not wave_complete_handled:
		wave_complete_handled = true
		_prepare_next_wave()


## Trickles a stage's enemies out in small side-by-side groups instead of
## one instant, rigid grid. Each group gets a brief perpendicular offset
## just so the pair isn't spawning on the exact same pixel — after that,
## every enemy follows the path completely independently.
func _spawn_stage_burst(enemies: Dictionary) -> void:
	var flat: Array[String] = []
	for enemy_name in enemies:
		var count: int = enemies[enemy_name]
		for i in range(count):
			flat.append(enemy_name)

	var i := 0
	while i < flat.size():
		var group_size: int = min(formation_abreast, flat.size() - i)
		for slot in range(group_size):
			var col_offset: float = (float(slot) - float(group_size - 1) / 2.0) * formation_side_spacing
			_spawn_one(flat[i + slot], col_offset)
		i += group_size
		if i < flat.size():
			await get_tree().create_timer(formation_spawn_interval).timeout


func _spawn_one(enemy_name: String, v_offset: float = 0.0) -> void:
	var scene := _get_scene_for(enemy_name)
	if scene == null or path_node == null:
		return
	var new_enemy = scene.instantiate()
	path_node.add_child(new_enemy)
	if new_enemy is PathFollow2D:
		new_enemy.v_offset = v_offset
	enemies_alive += 1
	new_enemy.tree_exited.connect(_on_enemy_removed)


func _on_spawn_timer_timeout() -> void:
	if spawn_queue.is_empty():
		spawn_timer.stop()
		return
	var enemy_name: String = spawn_queue.pop_front()
	_spawn_one(enemy_name)
	if spawn_queue.is_empty():
		spawn_timer.stop()
		_check_wave_complete()
		_start_wave_timeout()


func _on_enemy_removed() -> void:
	if not is_inside_tree():
		return
	enemies_alive -= 1
	_check_wave_complete()


func _check_wave_complete() -> void:
	if wave_complete_handled or in_staged_wave:
		return  # staged waves manage their own completion in _run_staged_wave()
	if spawn_queue.is_empty() and enemies_alive <= 0:
		wave_complete_handled = true
		_prepare_next_wave()


func _start_wave_timeout() -> void:
	await get_tree().create_timer(wave_timeout).timeout
	if wave_complete_handled:
		return
	if current_wave >= _last_wave():
		return  # final wave: player has to clear it, no forced skip
	print("Wave ", current_wave, " timed out with enemies still alive — forcing next wave.")
	wave_complete_handled = true
	_prepare_next_wave()


func _prepare_next_wave() -> void:
	if current_wave >= _last_wave():
		print("All waves complete!")
		GameManager.trigger_win()
		return

	current_wave += 1
	GameManager.set_wave(current_wave)

	await get_tree().create_timer(time_between_waves).timeout
	start_wave()
