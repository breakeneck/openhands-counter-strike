extends Node
# Visual QA: instantiates scenes as children (no scene swap), captures screenshots.

var _shots := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # survive tree pause (victory screen)
	await get_tree().create_timer(0.5).timeout
	# menu
	var menu: Node = load("res://scenes/main/menu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(1.0).timeout
	_shoot("01_menu")
	menu.queue_free()
	await get_tree().create_timer(0.3).timeout
	# game
	GameManager._set_state(1)
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(3.0).timeout
	_shoot("02_spawn")
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.rotation.y = deg_to_rad(135.0)
		player.camera.rotation.x = -0.15
	await get_tree().create_timer(0.5).timeout
	_shoot("03_toward_objective")
	if player:
		player.global_position = Vector3(24, 1.0, -13)
		player.rotation.y = 0.0
	await get_tree().create_timer(1.0).timeout
	_shoot("04_objective")
	if player:
		player.global_position = Vector3(0, 1.0, 26)
		player.rotation.y = 0.0
	await get_tree().create_timer(0.5).timeout
	_shoot("05_containers")
	var wc: Node = player.camera.get_node("WeaponHolder")
	wc._select(2)
	await get_tree().create_timer(0.6).timeout
	_shoot("06_rifle")
	wc._select(4)
	Input.action_press("aim")
	await get_tree().create_timer(0.8).timeout
	_shoot("07_sniper_ads")
	Input.action_release("aim")
	wc._select(2)
	await get_tree().create_timer(0.5).timeout
	var w = wc.weapons[2]
	w.mag_ammo = 30
	w.try_fire()
	await get_tree().create_timer(0.03).timeout
	_shoot("08_muzzle")
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	if not enemies.is_empty():
		player.rotation.y = 0.0
		await get_tree().create_timer(0.3).timeout
		var e = enemies[0]
		e.global_position = player.global_position + Vector3(0, 0, -6)
		e.rotation.y = PI
	await get_tree().create_timer(0.5).timeout
	_shoot("09_enemy")
	if player:
		player.global_position = Vector3(-28, 1.2, 8)
		player.rotation.y = deg_to_rad(90)
	await get_tree().create_timer(1.0).timeout
	_shoot("10_interior")
	GameManager.win_round()
	await get_tree().create_timer(1.0).timeout
	_shoot("11_victory")
	print("SHOTS_DONE ", _shots)
	get_tree().quit()

func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "/home/server/dev/games/openhands-counter-strike/qa/%s.png" % name
	img.save_png(path)
	_shots += 1
	print("SHOT ", path)