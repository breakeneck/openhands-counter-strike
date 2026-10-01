extends CanvasLayer
# HUD: crosshair, health, ammo, objective, timer, damage dir, kill feed.

@onready var health_bar: ProgressBar = $Root/BottomLeft/HealthBar
@onready var health_label: Label = $Root/BottomLeft/HealthLabel
@onready var ammo_label: Label = $Root/BottomRight/AmmoLabel
@onready var weapon_label: Label = $Root/BottomRight/WeaponLabel
@onready var objective_label: Label = $Root/TopCenter/ObjectiveLabel
@onready var capture_bar: ProgressBar = $Root/TopCenter/CaptureBar
@onready var timer_label: Label = $Root/TopRight/TimerLabel
@onready var enemies_label: Label = $Root/TopRight/EnemiesLabel
@onready var damage_dir: Control = $DamageDir
@onready var hit_flash: ColorRect = $HitFlash
@onready var interact_hint: Label = $Root/CenterHint/InteractHint

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.damage_taken.connect(_on_damage)
	GameManager.objective_progress.connect(_on_progress)
	GameManager.enemies_remaining.connect(_on_enemies)
	capture_bar.value = 0
	_on_enemies(get_tree().get_nodes_in_group("enemy").size())

func set_ammo(mag: int, reserve: int, wname: String) -> void:
	ammo_label.text = "%d / %d" % [mag, reserve]
	weapon_label.text = wname

func _on_damage(_amount: int, hp: int) -> void:
	health_bar.value = hp
	health_label.text = str(hp)
	hit_flash.color = Color(0.8, 0.1, 0.05, 0.35)
	var tw := create_tween()
	tw.tween_property(hit_flash, "color:a", 0.0, 0.5)

func show_damage_direction(ang: float) -> void:
	damage_dir.rotation = -ang
	damage_dir.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(damage_dir, "modulate:a", 0.0, 0.7)

func _on_progress(p: float) -> void:
	capture_bar.value = p * 100.0
	objective_label.text = "CAPTURING POINT ALPHA — %d%%" % int(p * 100)

func _on_enemies(n: int) -> void:
	enemies_label.text = "HOSTILES: %d" % n

func _process(delta: float) -> void:
	if GameManager.state == GameManager.State.PLAYING:
		var t := int(GameManager.round_time)
		timer_label.text = "%02d:%02d" % [t / 60, t % 60]
		if GameManager.objective_captured:
			objective_label.text = "POINT SECURED — HOLD POSITION"
		# interact hint when near zone
		var player := get_tree().get_first_node_in_group("player")
		if player:
			var d: float = player.get_capture_distance()
			interact_hint.visible = d < GameManager.CAPTURE_RADIUS and not GameManager.objective_captured
