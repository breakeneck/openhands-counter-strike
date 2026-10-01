extends Control

@onready var music: AudioStreamPlayer = $Music

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	music.stream = load("res://assets/audio/music/menu_loop_02.ogg")
	music.volume_db = -12.0
	music.play()

func _on_start() -> void:
	_click()
	GameManager.start_game()

func _on_quit() -> void:
	get_tree().quit()

func _click() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/ui/click_01.ogg")
	add_child(p)
	p.play()
