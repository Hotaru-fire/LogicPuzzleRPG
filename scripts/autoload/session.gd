extends Node

var user_id: int = -1
var username: String = ""

var selected_character: String = ""
var level: int = 1
var player_exp: int = 0
var gold: int = 0

var score: int = 0
var mobs_defeated: int = 0
var dungeon_enemies_defeated: int = 0
var bosses_killed: int = 0

# PLAYER ANALYTICS
var total_deaths: int = 0

var puzzle_clear_time: float = 0.0
var best_puzzle_clear_time: float = 0.0
var first_puzzle_clear_time: float = 0.0
var puzzle_time_improvement: float = 0.0
var puzzles_cleared: int = 0


func record_death() -> void:
	total_deaths += 1

	print("TOTAL PLAYER DEATHS: ", total_deaths)


func record_puzzle_clear(elapsed_seconds: float) -> void:
	if elapsed_seconds <= 0.0:
		return

	# Count successful puzzle clears and accumulate time.
	puzzles_cleared += 1
	puzzle_clear_time += elapsed_seconds

	# Remember the first successful clear as the baseline.
	if first_puzzle_clear_time <= 0.0:
		first_puzzle_clear_time = elapsed_seconds

	# Update the personal best.
	if best_puzzle_clear_time <= 0.0:
		best_puzzle_clear_time = elapsed_seconds
	else:
		best_puzzle_clear_time = minf(
			best_puzzle_clear_time,
			elapsed_seconds
		)

	# Improvement = first clear time minus best clear time.
	puzzle_time_improvement = maxf(
		0.0,
		first_puzzle_clear_time - best_puzzle_clear_time
	)

	print("PUZZLES CLEARED: ", puzzles_cleared)
	print("LATEST PUZZLE TIME: ", elapsed_seconds, " seconds")
	print("TOTAL PUZZLE TIME: ", puzzle_clear_time, " seconds")
	print("BEST PUZZLE TIME: ", best_puzzle_clear_time, " seconds")
	print("PUZZLE TIME IMPROVEMENT: ", puzzle_time_improvement, " seconds")


func is_logged_in() -> bool:
	return user_id > 0


func clear_session() -> void:
	user_id = -1
	username = ""
	selected_character = ""
	level = 1
	player_exp = 0
	gold = 0
	score = 0
	mobs_defeated = 0
	bosses_killed = 0
	dungeon_enemies_defeated = 0
	total_deaths = 0
	puzzle_clear_time = 0.0
	best_puzzle_clear_time = 0.0
	first_puzzle_clear_time = 0.0
	puzzle_time_improvement = 0.0
	puzzles_cleared = 0

func record_mob_kill(points: int = 10) -> void:
	mobs_defeated += 1
	score += points

	print("Total mobs killed: ", mobs_defeated)
	print("Current score: ", score)


func record_boss_kill(points: int = 100) -> void:
	bosses_killed += 1
	score += points

	print("Total bosses killed: ", bosses_killed)
	print("Current score: ", score)


func load_analytics(data: Dictionary) -> void:
	total_deaths = int(data.get("total_deaths", 0))

	puzzle_clear_time = float(
		data.get("puzzle_clear_time", 0.0)
	)

	best_puzzle_clear_time = float(
		data.get("best_puzzle_clear_time", 0.0)
	)

	first_puzzle_clear_time = float(
		data.get("first_puzzle_clear_time", 0.0)
	)

	puzzle_time_improvement = float(
		data.get("puzzle_time_improvement", 0.0)
	)

	puzzles_cleared = int(data.get("puzzles_cleared", 0))

	print("ANALYTICS LOADED")
	print("Total deaths: ", total_deaths)
	print("Puzzles cleared: ", puzzles_cleared)
	print("Total puzzle time: ", puzzle_clear_time)
	print("Best puzzle time: ", best_puzzle_clear_time)
	print("Puzzle time improvement: ", puzzle_time_improvement)


func reset_game_progress() -> void:
	level = 1
	player_exp = 0
	gold = 0
	score = 0
	mobs_defeated = 0
	dungeon_enemies_defeated = 0
	bosses_killed = 0

	total_deaths = 0
	puzzle_clear_time = 0.0
	best_puzzle_clear_time = 0.0
	first_puzzle_clear_time = 0.0
	puzzle_time_improvement = 0.0
	puzzles_cleared = 0
