extends Node
# Global round/objective state — the single justified autoload.

signal state_changed(state: int)
signal objective_progress(progress: float)
signal round_won()
signal round_lost
signal damage_taken(amount: int, health: int)
signal enemies_remaining(count: int)

enum State { MENU, PLAYING, PAUSED, VICTORY, DEFEAT }

var state: int = State.MENU
var health: int = 100
var max_health: int = 100
var objective_captured: bool = false
var objective_held: bool = false
var capture_progress: float = 0.0
var capture_time_needed: float = 20.0
var enemies_alive: int = 0
var kills: int = 0
var round_time: float = 0.0

const CAPTURE_RADIUS := 7.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_game() -> void:
	health = max_health
	objective_captured = false
	objective_held = false
	capture_progress = 0.0
	kills = 0
	round_time = 0.0
	_stop_objective_alarm()
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")
	_set_state(State.PLAYING)

func _set_state(s: int) -> void:
	state = s
	state_changed.emit(s)

func pause_game() -> void:
	if state != State.PLAYING:
		return
	_set_state(State.PAUSED)
	get_tree().paused = true

func resume_game() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	_set_state(State.PLAYING)

func quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/menu.tscn")
	_set_state(State.MENU)

func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	round_time += delta
	# capture logic: any player inside zone
	var in_zone := false
	for p in get_tree().get_nodes_in_group("player"):
		if p.has_method("get_capture_distance") and p.get_capture_distance() < CAPTURE_RADIUS:
			in_zone = true
	if in_zone and not objective_captured:
		if not objective_held:
			_play_objective_alarm()
		objective_held = true
		capture_progress = clampf(capture_progress + delta / capture_time_needed, 0.0, 1.0)
		objective_progress.emit(capture_progress)
		if capture_progress >= 1.0:
			objective_captured = true
			_on_objective_captured()
	elif objective_held and not in_zone and not objective_captured:
		objective_held = false
		_stop_objective_alarm()

var _alarm_player: AudioStreamPlayer

func _play_objective_alarm() -> void:
	if _alarm_player:
		return
	_alarm_player = AudioStreamPlayer.new()
	_alarm_player.stream = load("res://assets/audio/ui/bomb_alarm_loop_01.ogg")
	_alarm_player.volume_db = -10.0
	add_child(_alarm_player)
	_alarm_player.play()

func _stop_objective_alarm() -> void:
	if _alarm_player:
		_alarm_player.stop()
		_alarm_player.queue_free()
		_alarm_player = null

func _play_beep() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/ui/beep_01.wav")
	p.volume_db = -4.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func _on_objective_captured() -> void:
	_stop_objective_alarm()
	_play_beep()
	# remaining enemies become more aggressive, then victory once all dead or 15s hold
	var remaining := get_tree().get_nodes_in_group("enemy")
	if remaining.is_empty():
		win_round()
	else:
		get_tree().create_timer(15.0).timeout.connect(func():
			if state == State.PLAYING and objective_captured:
				win_round())

func win_round() -> void:
	if state != State.PLAYING:
		return
	_set_state(State.VICTORY)
	get_tree().paused = true
	round_won.emit()

func player_died() -> void:
	if state != State.PLAYING:
		return
	_set_state(State.DEFEAT)
	get_tree().paused = true
	round_lost.emit()

func take_damage(amount: int, from_pos: Vector3 = Vector3.INF) -> void:
	if state != State.PLAYING:
		return
	health = clampi(health - amount, 0, max_health)
	damage_taken.emit(amount, health)
	if health <= 0:
		player_died()

func add_kill() -> void:
	kills += 1

func enemy_died() -> void:
	enemies_remaining.emit(get_tree().get_nodes_in_group("enemy").size())