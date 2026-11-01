extends Control

const ANALYTICS_REFRESH_INTERVAL := 5.0
const ANALYTICS_REQUIRED_FIELDS := [
	"character_class",
	"level",
	"exp",
	"gold",
	"score",
	"mobs_defeated",
	"dungeon_enemies_defeated",
	"bosses_killed",
	"boss_completed",
	"total_deaths",
	"hp",
	"max_hp",
	"attack",
	"defense",
	"playtime_seconds",
	"puzzles_cleared",
	"first_puzzle_clear_time",
	"puzzle_clear_time",
	"best_puzzle_clear_time",
	"puzzle_time_improvement"
]
const ANALYTICS_VALUE_LABELS := [
	"ScoreValue",
	"LevelValue",
	"EnemiesValue",
	"GoldValue",
	"MobsDefeatedValue",
	"DungeonEnemiesValue",
	"BossesKilledValue",
	"BossesCompletedValue",
	"TotalDeathsValue",
	"HealthValue",
	"AttackValue",
	"DefenseValue",
	"DeathsValue",
	"PlaytimeValue",
	"PuzzlesClearedValue",
	"FirstClearTimeValue",
	"LatestClearTimeValue",
	"BestClearTimeValue",
	"TimeImprovementvalue"
]

@onready var analytics_scroll: ScrollContainer = $MainMargin/MainVBox/Content/AnalyticsScroll
@onready var leaderboards_scroll: ScrollContainer = $MainMargin/MainVBox/Content/LeaderboardsScroll
@onready var player_rows: VBoxContainer = $MainMargin/MainVBox/Content/LeaderboardsScroll/LeaderboardsPanel/LeaderboardsVBox/PlayerScroll/PlayerRows
@onready var total_players_value: Label = $MainMargin/MainVBox/Content/LeaderboardsScroll/LeaderboardsPanel/LeaderboardsVBox/SummaryCard/LeaderboardSummary/PlayersCard/PlayersVBox/TotalPlayersValue
@onready var my_rank_value: Label = $MainMargin/MainVBox/Content/LeaderboardsScroll/LeaderboardsPanel/LeaderboardsVBox/SummaryCard/LeaderboardSummary/RankCard/RankVBox2/MyRankValue
@onready var status_label: Label = $MainMargin/MainVBox/StatusLabel

var analytics_refresh_timer: Timer
var analytics_value_labels: Dictionary = {}
var analytics_request_pending := false
var analytics_request_user_id := -1
var analytics_display_user_id := -1


func _ready() -> void:
	analytics_scroll.show()
	leaderboards_scroll.hide()
	status_label.hide()
	_cache_analytics_labels()
	_set_analytics_placeholders("--")
	_set_analytics_identity(
		Session.username if Session.is_logged_in() else "Not logged in",
		"Loading database..."
	)

	if not GameAPI.response_received.is_connected(_on_game_api_response_received):
		GameAPI.response_received.connect(_on_game_api_response_received)

	analytics_refresh_timer = Timer.new()
	analytics_refresh_timer.wait_time = ANALYTICS_REFRESH_INTERVAL
	analytics_refresh_timer.timeout.connect(_on_analytics_refresh_timeout)
	add_child(analytics_refresh_timer)
	_start_analytics_updates()


func _exit_tree() -> void:
	if GameAPI.response_received.is_connected(_on_game_api_response_received):
		GameAPI.response_received.disconnect(_on_game_api_response_received)


func _on_back_button_pressed() -> void:
	var error = get_tree().change_scene_to_file(
		"res://scenes/main/MainMenu.tscn"
	)

	if error != OK:
		push_error("Failed to return to Main Menu. Error: " + str(error))


func _on_analytics_button_pressed() -> void:
	leaderboards_scroll.hide()
	analytics_scroll.show()
	status_label.hide()
	print("Analytics panel displayed.")
	_start_analytics_updates()


func _on_leaderboards_button_pressed() -> void:
	analytics_refresh_timer.stop()
	analytics_scroll.hide()
	leaderboards_scroll.show()
	_show_status("Loading leaderboard...")

	if not GameAPI.get_leaderboard():
		_show_status("Could not start the leaderboard request.")


func _start_analytics_updates() -> void:
	if not Session.is_logged_in():
		analytics_refresh_timer.stop()
		analytics_display_user_id = -1
		_set_analytics_placeholders("--")
		_set_analytics_identity("Not logged in", "--")
		_show_status("Log in to view your user analytics.")
		return

	if analytics_display_user_id != Session.user_id:
		_set_analytics_placeholders("--")
		_set_analytics_identity(Session.username, "Loading database...")

	status_label.hide()
	analytics_refresh_timer.start()
	_request_user_analytics()


func _on_analytics_refresh_timeout() -> void:
	if not analytics_scroll.visible:
		return
	if not Session.is_logged_in():
		_start_analytics_updates()
		return
	if analytics_display_user_id != Session.user_id:
		_set_analytics_placeholders("--")
		_set_analytics_identity(Session.username, "Loading database...")
	_request_user_analytics()


func _request_user_analytics() -> void:
	if analytics_request_pending or not Session.is_logged_in():
		return

	analytics_request_user_id = Session.user_id
	analytics_request_pending = true
	if not GameAPI.load_save():
		analytics_request_pending = false
		_show_status("Could not start the database analytics request.")


func _on_game_api_response_received(
	success: bool,
	message: String,
	data: Dictionary
) -> void:
	var action := str(data.get("action", ""))
	if action == "load_save":
		_on_user_analytics_response(success, message, data)
		return

	if action != "get_leaderboard":
		return

	if not success:
		_show_status(message)
		return

	var entries: Variant = data.get("leaderboard", [])
	if not (entries is Array):
		_show_status("The server returned invalid leaderboard data.")
		return

	_clear_rows()
	total_players_value.text = str(int(data.get("total_players", 0)))
	my_rank_value.text = "N/A"

	for entry in entries:
		if not (entry is Dictionary):
			continue

		var rank := int(entry.get("rank", 0))
		var username := str(entry.get("username", ""))
		var score := int(entry.get("score", 0))
		_add_row(rank, username, score)

		if username == Session.username:
			my_rank_value.text = str(rank)

	status_label.hide()


func _on_user_analytics_response(
	success: bool,
	message: String,
	data: Dictionary
) -> void:
	if not analytics_request_pending:
		return

	analytics_request_pending = false
	if (
		not Session.is_logged_in()
		or Session.user_id != analytics_request_user_id
	):
		return

	if not success:
		_show_status("Could not load user analytics: " + message)
		return

	if not bool(data.get("has_save", false)):
		analytics_display_user_id = Session.user_id
		_set_analytics_placeholders("--")
		_set_analytics_identity(Session.username, "No database save yet")
		status_label.hide()
		return

	for field in ANALYTICS_REQUIRED_FIELDS:
		if not data.has(field):
			_show_status(
				"Database analytics response is missing '%s'." % field
			)
			return

	analytics_display_user_id = Session.user_id
	_display_database_analytics(data)
	status_label.hide()


func _cache_analytics_labels() -> void:
	for label_name in ANALYTICS_VALUE_LABELS:
		var label := analytics_scroll.find_child(
			label_name,
			true,
			false
		) as Label
		if label == null:
			push_error(
				"User analytics scene is missing the '%s' label."
				% label_name
			)
			continue
		analytics_value_labels[label_name] = label


func _set_analytics_placeholders(value: String) -> void:
	for label_name in analytics_value_labels:
		var label: Label = analytics_value_labels[label_name]
		label.text = value


func _set_analytics_identity(username: String, update_text: String) -> void:
	var username_label := analytics_scroll.find_child(
		"UsernameLabel",
		true,
		false
	) as Label
	var class_label := analytics_scroll.find_child(
		"CharacterClassLabel",
		true,
		false
	) as Label
	var updated_label := analytics_scroll.find_child(
		"LastUpdatedLabel",
		true,
		false
	) as Label

	if username_label != null:
		username_label.text = username
	if class_label != null:
		class_label.text = "Class: --"
	if updated_label != null:
		updated_label.text = update_text


func _display_database_analytics(data: Dictionary) -> void:
	var health := int(data["hp"])
	var max_health := int(data["max_hp"])
	var analytics_values := {
		"ScoreValue": str(int(data["score"])),
		"LevelValue": str(int(data["level"])),
		"EnemiesValue": str(int(data["exp"])),
		"GoldValue": str(int(data["gold"])),
		"MobsDefeatedValue": str(int(data["mobs_defeated"])),
		"DungeonEnemiesValue": str(int(data["dungeon_enemies_defeated"])),
		"BossesKilledValue": str(int(data["bosses_killed"])),
		"BossesCompletedValue": (
			"Yes" if bool(data["boss_completed"]) else "No"
		),
		"TotalDeathsValue": str(int(data["total_deaths"])),
		"HealthValue": "%d / %d" % [health, max_health],
		"AttackValue": str(int(data["attack"])),
		"DefenseValue": str(int(data["defense"])),
		"DeathsValue": str(int(data["total_deaths"])),
		"PlaytimeValue": _format_playtime(int(data["playtime_seconds"])),
		"PuzzlesClearedValue": str(int(data["puzzles_cleared"])),
		"FirstClearTimeValue": _format_puzzle_time(
			float(data["first_puzzle_clear_time"])
		),
		"LatestClearTimeValue": _format_puzzle_time(
			float(data["puzzle_clear_time"])
		),
		"BestClearTimeValue": _format_puzzle_time(
			float(data["best_puzzle_clear_time"])
		),
		"TimeImprovementvalue": _format_puzzle_time(
			float(data["puzzle_time_improvement"])
		)
	}

	for label_name in analytics_values:
		if not analytics_value_labels.has(label_name):
			continue
		var label: Label = analytics_value_labels[label_name]
		label.text = str(analytics_values[label_name])

	var username_label := analytics_scroll.find_child(
		"UsernameLabel",
		true,
		false
	) as Label
	var class_label := analytics_scroll.find_child(
		"CharacterClassLabel",
		true,
		false
	) as Label
	var updated_label := analytics_scroll.find_child(
		"LastUpdatedLabel",
		true,
		false
	) as Label
	if username_label != null:
		username_label.text = Session.username
	if class_label != null:
		class_label.text = "Class: %s" % str(data["character_class"])
	if updated_label != null:
		updated_label.text = "Database updated: " + Time.get_time_string_from_system()


func _format_playtime(total_seconds: int) -> String:
	var hours := int(total_seconds / 3600)
	var minutes := int((total_seconds % 3600) / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func _format_puzzle_time(seconds: float) -> String:
	return "%.2f s" % seconds


# Set this path to your gold bar's HBoxContainer (the one holding RANK / PLAYER / SCORE)
@onready var header_row: HBoxContainer = $MainMargin/MainVBox/Content/LeaderboardsScroll/LeaderboardsPanel/LeaderboardsVBox/TableCard/TableHeader


const ROW_HEIGHT := 40.0
const CELL_PADDING := 24.0


func _add_cell(row: Control, text: String, header_cell: Control) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = false
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	row.add_child(label)  # add first so the theme/font is applied before measuring

	var text_width := label.get_minimum_size().x + CELL_PADDING
	var width := maxf(header_cell.size.x, text_width)
	var center_x := header_cell.global_position.x + header_cell.size.x * 0.5 - player_rows.global_position.x

	label.position = Vector2(center_x - width * 0.5, 0.0)
	label.size = Vector2(width, ROW_HEIGHT)


func _add_row(rank: int, username: String, score: int) -> void:
	var header_cells := header_row.get_children()
	if header_cells.size() < 3:
		push_error("Header row needs 3 children (rank, player, score).")
		return

	var row := Control.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = false
	player_rows.add_child(row)

	_add_cell(row, str(rank), header_cells[0])
	_add_cell(row, username, header_cells[1])
	_add_cell(row, str(score), header_cells[2])


func _clear_rows() -> void:
	for row in player_rows.get_children():
		row.queue_free()


func _show_status(message: String) -> void:
	status_label.text = message
	status_label.show()
