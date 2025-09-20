# res://scripts/HUD.gd
extends CanvasLayer

@export var total_time_seconds: int = 60

# runtime
var seconds_left: float = 0.0
var timer_running: bool = false

# node refs (typed)
var parts_label: Label
var timer_label: Label
var win_panel: Control
var lose_panel: Control

func _ready() -> void:
	# cache UI nodes (your HUD tree: HUD -> Control -> PartsLabel, TimerLabel, WinPanel, LosePanel)
	parts_label = get_node_or_null("Control/PartsLabel") as Label
	timer_label = get_node_or_null("Control/TimerLabel") as Label
	win_panel = get_node_or_null("Control/WinPanel") as Control
	lose_panel = get_node_or_null("Control/LosePanel") as Control

	# hide panels if present
	if win_panel:
		win_panel.visible = false
	if lose_panel:
		lose_panel.visible = false

	# safely connect buttons (only if Button exists)
	_safe_connect_button("Control/WinPanel/Buttons/RestartBtn", Callable(self, "_on_restart_pressed"))
	_safe_connect_button("Control/WinPanel/Buttons/QuitBtn", Callable(self, "_on_quit_pressed"))
	_safe_connect_button("Control/LosePanel/Buttons/RestartBtn2", Callable(self, "_on_restart_pressed"))
	_safe_connect_button("Control/LosePanel/Buttons/QuitBtn2", Callable(self, "_on_quit_pressed"))

	# wait briefly for GameManager autoload to be present (if needed)
	var gm: Node = null
	var tries: int = 0
	while tries < 60 and gm == null:
		gm = get_node_or_null("/root/GameManager")
		if gm:
			break
		tries += 1
		await get_tree().process_frame

	if gm == null:
		printerr("HUD: GameManager not found at /root/GameManager. Add it as AutoLoad named 'GameManager'.")
	else:
		# connect signals and pull initial totals immediately
		gm.connect("overall_updated", Callable(self, "_on_overall_updated"))
		gm.connect("all_parts_collected", Callable(self, "_on_all_collected"))
		_update_parts_from_gm(gm)

	# start timer
	seconds_left = float(total_time_seconds)
	timer_running = true
	_update_timer_label()

func _process(_delta: float) -> void:
	if not timer_running:
		return
	seconds_left -= _delta
	if seconds_left <= 0.0:
		seconds_left = 0.0
		timer_running = false
		_time_ran_out()
	_update_timer_label()

# helper to connect a button safely
func _safe_connect_button(path: String, callable: Callable) -> void:
	var node = get_node_or_null(path)
	if node and node is Button:
		(node as Button).pressed.connect(callable)

# reads totals from GameManager and updates the parts label
func _update_parts_from_gm(gm: Node) -> void:
	if not gm:
		return
	var total_required: int = 0
	var total_collected: int = 0
	for k in gm.required_parts.keys():
		total_required += int(gm.required_parts[k])
		total_collected += int(gm.collected_parts.get(k, 0))
	var remaining: int = max(total_required - total_collected, 0)
	if parts_label:
		parts_label.text = "Parts left: %d" % remaining

func _update_timer_label() -> void:
	if not timer_label:
		return
	var mm: int = int(seconds_left) / 60
	var ss: int = int(seconds_left) % 60
	timer_label.text = "Time left: %02d:%02d" % [mm, ss]

# GameManager signal handlers
func _on_overall_updated(total_collected: int, total_required: int) -> void:
	var remaining: int = max(total_required - total_collected, 0)
	if parts_label:
		parts_label.text = "Parts left: %d" % remaining

func _on_all_collected() -> void:
	# stop timer immediately and show win UI
	timer_running = false
	_show_win()

func _time_ran_out() -> void:
	_show_lose()

# show win: make UI visible and freeze gameplay by setting time scale to 0
func _show_win() -> void:
	if win_panel:
		win_panel.visible = true
		var wlbl: Label = win_panel.get_node_or_null("WinLabel") as Label
		if wlbl:
			wlbl.text = "Signal activated — You are saved!"
	# freeze gameplay by stopping time (UI will still work)
	Engine.time_scale = 0.0

# show lose: similar handling
func _show_lose() -> void:
	if lose_panel:
		lose_panel.visible = true
		var llbl: Label = lose_panel.get_node_or_null("LoseLabel") as Label
		if llbl:
			llbl.text = "Everything is frozen! Try again..."
	Engine.time_scale = 0.0

# restart / quit handlers
func _on_restart_pressed() -> void:
	# restore time scale and reload scene
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().quit()
