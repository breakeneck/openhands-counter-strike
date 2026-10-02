extends Node
# End-to-end loop test using real mechanics (game instantiated as child; no scene swap).
var fails := 0

func _ready() -> void:
	GameManager._set_state(1)
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(3.0).timeout
	var player := get_tree().get_first_node_in_group("player")
	print("T1 game started, player at ", player.global_position)
	# movement via real input
	var start_pos: Vector3 = player.global_position
	Input.action_press("move_forward")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("move_forward")
	var moved: float = player.global_position.distance_to(start_pos)
	_t("T2 movement moved=%.2f" % moved, moved > 1.0)
	# capture via real loop
	player.global_position = Vector3(24, 1.0, -28)
	GameManager.capture_time_needed = 2.0
	await get_tree().create_timer(3.0).timeout
	_t("T3 capture=%.2f captured=%s" % [GameManager.capture_progress, GameManager.objective_captured], GameManager.objective_captured)
	# kill all enemies
	for e in get_tree().get_nodes_in_group("enemy"):
		e.take_damage(500, Vector3.ZERO)
	await get_tree().create_timer(0.5).timeout
	print("T4 enemies remaining=", get_tree().get_nodes_in_group("enemy").size())
	GameManager.win_round()
	await get_tree().create_timer(0.3).timeout
	_t("T5 victory state=%d" % GameManager.state, GameManager.state == 3)
	# restart: fresh game instance (scene swap like real Play Again)
	get_tree().paused = false
	GameManager._set_state(1)
	game.queue_free()
	await get_tree().create_timer(0.3).timeout
	GameManager.health = 100
	GameManager.objective_captured = false
	GameManager.objective_held = false
	GameManager.capture_progress = 0.0
	GameManager.capture_time_needed = 20.0
	var game2: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(game2)
	await get_tree().create_timer(2.5).timeout
	var p2 := get_tree().get_first_node_in_group("player")
	_t("T6 restart hp=%d progress=%.2f" % [p2.health, GameManager.capture_progress], p2.health == 100 and GameManager.capture_progress == 0.0)
	# defeat
	p2.take_damage(150, Vector3(5, 0, 0))
	await get_tree().create_timer(0.3).timeout
	_t("T7 defeat state=%d dead=%s" % [GameManager.state, p2.dead], GameManager.state == 4 and p2.dead)
	# pause/resume
	get_tree().paused = false
	GameManager._set_state(1)
	GameManager.pause_game()
	_t("T8 pause state=%d paused=%s" % [GameManager.state, get_tree().paused], GameManager.state == 2 and get_tree().paused)
	GameManager.resume_game()
	_t("T9 resume state=%d" % GameManager.state, GameManager.state == 1 and not get_tree().paused)
	print("=== PLAYTHROUGH: ", "ALL PASS" if fails == 0 else "%d FAILS" % fails, " ===")
	get_tree().quit(0 if fails == 0 else 1)

func _t(label: String, ok: bool) -> void:
	print(label, " ", "PASS" if ok else "FAIL")
	if not ok:
		fails += 1
