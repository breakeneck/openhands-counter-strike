extends Node
# Wires player signals to HUD, handles pause menu & end screens.

@onready var hud: CanvasLayer = $HUD
@onready var pause_menu: Control = $PauseMenu
@onready var end_screen: Control = $EndScreen
@onready var end_title: Label = $EndScreen/VBox/Title
@onready var ambience: AudioStreamPlayer = $Ambience

func _ready() -> void:
	ambience.stream = load("res://assets/audio/ambience/urban_loop_01.ogg")
	ambience.volume_db = -14.0
	ambience.play()
	GameManager.round_won.connect(func(): _show_end("POINT SECURED", "VICTORY", Color(0.3, 0.9, 0.4)))
	GameManager.round_lost.connect(func(): _show_end("YOU DIED", "DEFEAT", Color(0.9, 0.25, 0.2)))
	pause_menu.hide()
	end_screen.hide()
	GameManager.state_changed.connect(_on_state)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.damage_direction.connect(hud.show_damage_direction)
		player.health_changed.connect(func(hp): hud.health_bar.value = hp)
	for w in get_tree().get_nodes_in_group("weapon_controller"):
		w.ammo_changed.connect(hud.set_ammo)

func _on_state(s: int) -> void:
	match s:
		GameManager.State.PAUSED:
			pause_menu.show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		GameManager.State.PLAYING:
			pause_menu.hide()
			end_screen.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		GameManager.State.VICTORY, GameManager.State.DEFEAT:
			pause_menu.hide()
			end_screen.show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _show_end(title: String, sub: String, color: Color) -> void:
	end_title.text = title
	end_title.add_theme_color_override("font_color", color)
	var j := AudioStreamPlayer.new()
	j.stream = load("res://assets/audio/music/%s_jingle_01.ogg" % ("victory" if sub == "VICTORY" else "defeat"))
	add_child(j)
	j.play()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		match GameManager.state:
			GameManager.State.PLAYING:
				GameManager.pause_game()
			GameManager.State.PAUSED:
				GameManager.resume_game()
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume() -> void:
	GameManager.resume_game()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_restart() -> void:
	GameManager.resume_game()
	GameManager.start_game()

func _on_quit() -> void:
	GameManager.quit_to_menu()
