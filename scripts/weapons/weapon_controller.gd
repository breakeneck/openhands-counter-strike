extends Node3D
# Manages 6 weapon instances under WeaponHolder; input routing; ammo HUD feed.

signal ammo_changed(mag: int, reserve: int, name: String)
signal weapon_switched(name: String)

const WEAPON_SCENE := "res://scenes/weapons/weapon.tscn"
const WEAPON_DATA := [
	"res://data/weapons/pistol.tres",
	"res://data/weapons/smg.tres",
	"res://data/weapons/rifle.tres",
	"res://data/weapons/shotgun.tres",
	"res://data/weapons/sniper.tres",
	"res://data/weapons/mg.tres",
]

var weapons: Array[Node3D] = []
var current: Node3D
var _switching := false

func _ready() -> void:
	add_to_group("weapon_controller")
	for path in WEAPON_DATA:
		var w: Node3D = load(WEAPON_SCENE).instantiate()
		add_child(w)
		w.setup(load(path))
		w.visible = false
		weapons.append(w)
	current = weapons[0]
	current.visible = true
	_emit_ammo()

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_switch(1)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_switch(-1)
	elif event.is_action_pressed("weapon_1"):
		_select(0)
	elif event.is_action_pressed("weapon_2"):
		_select(1)
	elif event.is_action_pressed("reload"):
		if current:
			current.start_reload()

func _process(_delta: float) -> void:
	if not current or GameManager.state != GameManager.State.PLAYING:
		return
	var want_fire := Input.is_action_pressed("fire") if current.data.auto else Input.is_action_just_pressed("fire")
	if want_fire:
		current.try_fire()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		if Input.is_action_pressed("aim"):
			player.set_ads_zoom(current.data.ads_zoom)
		else:
			player.reset_ads_zoom()
	# ADS pose
	var target_pos := Vector3(0, -0.12, -0.55) if Input.is_action_pressed("aim") else Vector3(0.25, -0.25, -0.45)
	position = position.lerp(target_pos, 0.2)

func _switch(dir: int) -> void:
	_select((weapons.find(current) + dir + weapons.size()) % weapons.size())

func _select(idx: int) -> void:
	if idx == weapons.find(current) or _switching:
		return
	_switching = true
	for w in weapons:
		w.visible = false
	current = weapons[idx]
	current.visible = true
	current.start_reload() if false else null
	_emit_ammo()
	weapon_switched.emit(current.data.display_name)
	var tw := create_tween()
	tw.tween_property(self, "position:y", -0.5, 0.12)
	tw.tween_property(self, "position:y", 0.0, 0.2)
	tw.tween_callback(func(): _switching = false)

func _emit_ammo() -> void:
	current.ammo_changed.disconnect(_on_ammo) if current.ammo_changed.is_connected(_on_ammo) else null
	current.ammo_changed.connect(_on_ammo)
	ammo_changed.emit(current.mag_ammo, current.reserve_ammo, current.data.display_name)

func _on_ammo(mag: int, reserve: int) -> void:
	ammo_changed.emit(mag, reserve, current.data.display_name)