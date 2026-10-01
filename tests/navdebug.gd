extends Node
func _ready() -> void:
	GameManager._set_state(1)
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(3.0).timeout
	var player := get_tree().get_first_node_in_group("player")
	player.global_position = Vector3(0, 1.0, 26)
	player.rotation.y = 0.0
	player.camera.rotation.x = 0.0
	await get_tree().create_timer(0.5).timeout
	var e = get_tree().get_nodes_in_group("enemy")[0]
	e.global_position = Vector3(0, 1.0, 20)
	e.rotation.y = PI
	await get_tree().create_timer(0.5).timeout
	print("enemy pos=", e.global_position, " visible=", e.visible)
	var sp: Vector3 = player.camera.unproject_position(e.global_position + Vector3(0, 1.0, 0))
	print("screen pos=", sp)
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(player.camera.global_position, e.global_position + Vector3(0, 1.2, 0))
	q.collision_mask = 3
	var hit: Dictionary = space.intersect_ray(q)
	print("occluder: ", hit.get("collider", null), " at ", hit.get("position", Vector3.INF))
	# check soldier mesh visibility flags
	var sol: Node = e.get_node("Soldier")
	var stack: Array = [sol]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		for ch in c.get_children():
			stack.append(ch)
		if c is MeshInstance3D:
			print("mesh ", c.name, " visible=", c.visible, " in_tree=", c.is_inside_tree(), " top_level=", c.is_top_level())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/server/dev/games/openhands-counter-strike/qa/dbg_enemy.png")
	get_tree().quit()
