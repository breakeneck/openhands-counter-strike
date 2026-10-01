extends Node
# Automated validation: scenes load, required nodes exist, weapons valid, shooting works.

var failures: Array[String] = []

func _ready() -> void:
	_check("menu scene", func(): return load("res://scenes/main/menu.tscn") != null)
	_check("game scene", func(): return load("res://scenes/main/game.tscn") != null)
	_check("player scene", func(): return load("res://scenes/player/player.tscn") != null)
	_check("weapon scene", func(): return load("res://scenes/weapons/weapon.tscn") != null)
	_check("enemy scene", func(): return load("res://scenes/enemies/enemy.tscn") != null)
	for w in ["pistol","smg","rifle","shotgun","sniper","mg"]:
		_check("weapon data " + w, func():
			var d = load("res://data/weapons/%s.tres" % w)
			return d != null and d.damage > 0 and d.magazine_size > 0 and d.fire_rate > 0 and ResourceLoader.exists(d.shot_sound))
	# instantiate game scene as child of this persistent node (no scene swap)
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.05).timeout
	GameManager._set_state(1)  # PLAYING
	# wait for async navmesh bake (up to 20s)
	var world := game.get_node_or_null("World")
	var waited := 0.0
	while waited < 45.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
		var nr := world.get_node_or_null("MapNavRegion") if world else null
		if nr and nr.navigation_mesh and nr.navigation_mesh.get_polygon_count() > 0:
			break
	_check("game instantiated", func(): return game != null)
	_check("world builder", func(): return world != null)
	var player: Array = get_tree().get_nodes_in_group("player")
	_check("player in world", func(): return player.size() == 1)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	_check("6 enemies spawned", func(): return enemies.size() == 6)
	_check("objective zone", func(): return not get_tree().get_nodes_in_group("objective_zone").is_empty())
	_check("patrol points", func(): return get_tree().get_nodes_in_group("patrol_point").size() >= 8)
	_check("cover nodes", func(): return get_tree().get_nodes_in_group("cover").size() >= 10)
	_check("nav region baked", func():
		var nr := world.get_node_or_null("MapNavRegion")
		return nr != null and nr.navigation_mesh != null and nr.navigation_mesh.get_polygon_count() > 0)
	# combat test: enemy takes damage and dies
	var e = enemies[0]
	e.take_damage(200, Vector3.ZERO)
	await get_tree().process_frame
	_check("enemy dies", func(): return e.state == 7)
	# player damage
	var pl = player[0]
	pl.take_damage(50, Vector3(0, 0, -10))
	_check("player damaged", func(): return pl.health == 50)
	# weapon fire: give player weapon controller, fire at a target
	var wc: Node = pl.camera.get_node_or_null("WeaponHolder")
	_check("weapon holder", func(): return wc != null and wc.weapons.size() == 6)
	# switch weapons and check ammo signals
	var seen := {"ammo": false, "switch": false}
	wc.ammo_changed.connect(func(m, r, n): seen["ammo"] = m > 0)
	wc.weapon_switched.connect(func(n): seen["switch"] = true)
	wc._select(3)
	await get_tree().process_frame
	_check("weapon switch signal", func(): return seen["switch"])
	# fire pistol at enemy corpse area (should not crash)
	var w = wc.weapons[2]
	w.mag_ammo = 30
	for i in 5:
		w.try_fire()
		await get_tree().create_timer(1.0 / w.data.fire_rate + 0.02).timeout
	_check("firing decrements ammo", func(): return w.mag_ammo == 25)
	# reload
	w.mag_ammo = 5
	w.start_reload()
	await get_tree().create_timer(w.data.reload_time + 0.4).timeout
	_check("reload refills", func(): return w.mag_ammo == w.data.magazine_size)
	# game manager round flow
	GameManager.health = 100
	GameManager.objective_captured = false
	GameManager.win_round()
	_check("victory state", func(): return GameManager.state == 3)
	get_tree().paused = false
	GameManager._set_state(1)
	GameManager.take_damage(999)
	_check("defeat state", func(): return GameManager.state == 4)
	print("=== VALIDATION RESULT ===")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
	else:
		for f in failures:
			print("FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(name: String, fn: Callable) -> void:
	var ok := false
	var err := ""
	var res = fn.call()
	ok = res if res is bool else false
	if ok:
		print("PASS: " + name)
	else:
		failures.append(name)
		print("FAIL: " + name)