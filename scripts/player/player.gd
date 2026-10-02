extends CharacterBody3D
# FPS controller: CharacterBody3D + Camera3D. No custom physics.

signal health_changed(hp: int)
signal position_updated(pos: Vector3)
signal damage_direction(angle_rad: float)

const SPEED_WALK := 5.2
const SPEED_SPRINT := 8.0
const SPEED_CROUCH := 2.6
const ACCEL := 10.0
const DECEL := 12.0
const JUMP_VELOCITY := 4.8
const STAND_HEIGHT := 1.7
const CROUCH_HEIGHT := 1.05
const MOUSE_SENS := 0.0022

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var health: int = 100
var is_crouching := false
var is_sprinting := false
var dead := false

var _pitch := 0.0
var _yaw := 0.0
var _bob_time := 0.0
var _recoil_pitch := 0.0
var _recoil_yaw := 0.0
var _bob_amp := 0.0

@onready var camera: Camera3D = $Camera3D
@onready var collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameManager.health = health
	camera.fov = 75.0

func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.45, 1.45)
		rotation.y = _yaw
		camera.rotation.x = _pitch + _recoil_pitch
		camera.rotation.y = _recoil_yaw

func add_recoil(pitch_kick: float, yaw_kick: float) -> void:
	_recoil_pitch += pitch_kick
	_recoil_yaw += randf_range(-yaw_kick, yaw_kick)

func set_ads_zoom(zoom_mult: float) -> void:
	var target := 75.0 * zoom_mult
	camera.fov = lerpf(camera.fov, target, 0.35)

func reset_ads_zoom() -> void:
	camera.fov = lerpf(camera.fov, 75.0, 0.25)

func _physics_process(delta: float) -> void:
	if dead:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY

	is_crouching = Input.is_action_pressed("crouch")
	is_sprinting = Input.is_action_pressed("sprint") and Input.get_vector("move_left","move_right","move_forward","move_back").y < -0.1 and not is_crouching

	var speed := SPEED_CROUCH if is_crouching else (SPEED_SPRINT if is_sprinting else SPEED_WALK)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target := Vector3(dir.x * speed, velocity.y, dir.z * speed)
	var accel := ACCEL if input_dir != Vector2.ZERO else DECEL
	velocity.x = lerpf(velocity.x, target.x, accel * delta)
	velocity.z = lerpf(velocity.z, target.z, accel * delta)
	move_and_slide()

	# head bob
	var hspeed := Vector2(velocity.x, velocity.z).length()
	_bob_time += delta * hspeed * 1.4
	var target_amp := 0.035 if is_on_floor() else 0.0
	if is_crouching: target_amp *= 0.5
	if is_sprinting: target_amp *= 1.4
	_bob_amp = lerpf(_bob_amp, target_amp, 8.0 * delta)
	camera.position.y = (STAND_HEIGHT if not is_crouching else CROUCH_HEIGHT) - 0.15 + sin(_bob_time * 2.0) * _bob_amp
	camera.position.x = sin(_bob_time) * _bob_amp * 0.5

	# recoil recovery
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, 8.0 * delta)
	_recoil_yaw = lerpf(_recoil_yaw, 0.0, 8.0 * delta)
	camera.rotation.x = _pitch + _recoil_pitch
	camera.rotation.y = _recoil_yaw

	# crouch collision height
	collision.shape.height = CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	collision.position.y = (CROUCH_HEIGHT if is_crouching else STAND_HEIGHT) * 0.5

	# footsteps
	_step_cooldown -= delta
	if is_on_floor() and hspeed > 1.0 and _step_cooldown <= 0.0:
		_step_cooldown = 0.34 if not is_sprinting else 0.24
		_play_footstep()

	position_updated.emit(global_position)

var _step_cooldown := 0.0
var _step_stream: AudioStream = preload("res://assets/audio/footsteps/footstep_concrete_000.ogg")

func _play_footstep() -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _step_stream
	p.global_position = global_position + Vector3(0, 0.1, 0)
	p.max_distance = 18.0
	p.volume_db = -10.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func take_damage(amount: int, from_pos: Vector3) -> void:
	if dead:
		return
	health = clampi(health - amount, 0, 100)
	GameManager.health = health
	health_changed.emit(health)
	# directional damage feedback
	if from_pos != Vector3.INF:
		var local := to_local(from_pos)
		var ang := atan2(local.x, -local.z)
		damage_direction.emit(ang)
	if health <= 0:
		die()

func die() -> void:
	if dead:
		return
	dead = true
	GameManager.player_died()
	camera.fov = 60.0
	var tw := create_tween()
	tw.tween_property(camera, "rotation:z", 0.8, 1.2)
	tw.parallel().tween_property(camera, "position:y", 0.35, 1.2)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func get_capture_distance() -> float:
	var zones := get_tree().get_nodes_in_group("objective_zone")
	if zones.is_empty():
		return 999.0
	return global_position.distance_to(zones[0].global_position)