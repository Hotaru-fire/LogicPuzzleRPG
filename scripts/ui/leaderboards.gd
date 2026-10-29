extends Control


@onready var analytics_scroll: ScrollContainer = $MainMargin/MainVBox/Content/AnalyticsScroll
@onready var leaderboards_scroll: ScrollContainer = $MainMargin/MainVBox/Content/LeaderboardsScroll


func _ready() -> void:
	# Show Analytics by default.
	analytics_scroll.show()
	leaderboards_scroll.hide()


func _on_back_button_pressed() -> void:
	var error = get_tree().change_scene_to_file(
		"res://scenes/main/MainMenu.tscn"
	)

	if error != OK:
		push_error("Failed to return to Main Menu. Error: " + str(error))


func _on_analytics_button_pressed() -> void:
	leaderboards_scroll.hide()
	analytics_scroll.show()

	print("Analytics panel displayed.")


func _on_leaderboards_button_pressed() -> void:
	analytics_scroll.hide()
	leaderboards_scroll.show()

	print("Leaderboards panel displayed.")
