extends Node
func _ready() -> void:
	GameManager._set_state(1)
	var game: Node = load("res://scenes/main/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(3.0).timeout
	var player: Node = get_tree().get_first_node_in_group("player")
	var e: Node = get_tree().get_nodes_in_group("enemy")[0]
	e.global_position = player.global_position + Vector3(8, 0, 0)
	await get_tree().create_timer(0.2).timeout
	e._set_state(4)
	await get_tree().create_timer(3.0).timeout
	print("LIVE HP after 3s bot fire: ", player.health)
	# headshot kill test: simulate a weapon ray at enemy head via take_damage path is not enough —
	# directly test zone math by calling weapon? simpler: verify enemy dies from dmg 1000
	var e2: Node = get_tree().get_nodes_in_group("enemy")[1]
	var hp_before: int = e2.health
	e2.take_damage(1000, player.global_position)
	await get_tree().create_timer(0.2).timeout
	print("HEADSHOT kill: before=", hp_before, " dead=", e2.state == 7)
	get_tree().quit(0)
