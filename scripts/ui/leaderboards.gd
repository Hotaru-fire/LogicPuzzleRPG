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
