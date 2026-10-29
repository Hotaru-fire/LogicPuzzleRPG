extends Control

@onready var analytics_scroll: ScrollContainer = $MainMargin/MainVBox/Content/AnalyticsScroll
@onready var leaderboards_scroll: ScrollContainer = $MainMargin/MainVBox/Content/LeaderboardsScroll
@onready var player_rows: VBoxContainer = $MainMargin/MainVBox/Content/LeaderboardsScroll/LeaderboardsPanel/LeaderboardsVBox/PlayerScroll/PlayerRows
@onready var total_players_value: Label = $MainMargin/MainVBox/Content/LeaderboardsScroll/LeaderboardsPanel/LeaderboardsVBox/SummaryCard/LeaderboardSummary/PlayersCard/PlayersVBox/TotalPlayersValue
@onready var my_rank_value: Label = $MainMargin/MainVBox/Content/LeaderboardsScroll/LeaderboardsPanel/LeaderboardsVBox/SummaryCard/LeaderboardSummary/RankCard/RankVBox2/MyRankValue
@onready var status_label: Label = $MainMargin/MainVBox/StatusLabel


func _ready() -> void:
	analytics_scroll.show()
	leaderboards_scroll.hide()
	status_label.hide()

	if not GameAPI.response_received.is_connected(_on_game_api_response_received):
		GameAPI.response_received.connect(_on_game_api_response_received)


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


func _on_leaderboards_button_pressed() -> void:
	analytics_scroll.hide()
	leaderboards_scroll.show()
	_show_status("Loading leaderboard...")

	if not GameAPI.get_leaderboard():
		_show_status("Could not start the leaderboard request.")


func _on_game_api_response_received(
	success: bool,
	message: String,
	data: Dictionary
) -> void:
	if str(data.get("action", "")) != "get_leaderboard":
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


func _add_row(rank: int, username: String, score: int) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 20)

	var rank_label := Label.new()
	rank_label.text = str(rank)
	rank_label.custom_minimum_size.x = 100.0
	row.add_child(rank_label)

	var username_label := Label.new()
	username_label.text = username
	username_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(username_label)

	var score_label := Label.new()
	score_label.text = str(score)
	score_label.custom_minimum_size.x = 160.0
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(score_label)

	player_rows.add_child(row)


func _clear_rows() -> void:
	for row in player_rows.get_children():
		row.queue_free()


func _show_status(message: String) -> void:
	status_label.text = message
	status_label.show()
