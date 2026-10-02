extends CharacterBody3D
# Enemy bot: NavigationAgent3D + Quaternius soldier animations + simple FSM.

enum S { PATROL, INVESTIGATE, ALERT, SEARCH, ATTACK, TAKE_COVER, RETREAT, DEAD }

const SPEED_PATROL := 2.2
const SPEED_COMBAT := 4.2
const SPEED_RETREAT := 5.2

var state: int = S.PATROL
var health := 100
var damage := 12
var fire_rate := 2.5
var vision_range := 45.0
var vision_fov_cos := cos(deg_to_rad(75.0))
var accuracy := 0.06

var _target: Node = null
var _last_known := Vector3.INF
var _next_think := 0.0
var _next_shot := 0.0
var _state_time := 0.0
var _search_timer := 0.0
var _strafe_dir := 1.0
var _strafe_time := 0.0
var _cover_point := Vector3.INF
var _cover_cooldown := 0.0
var _anim := "idle"
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var anim_player: AnimationPlayer = $Soldier/AnimationPlayer
@onready var head_area: Area3D = $HeadArea
@onready var los: RayCast3D = $EyeRay
@onready var gun_tip: Node3D = $EyeRay/GunTip
@onready var muzzle_flash: GPUParticles3D = $EyeRay/GunTip/Flash
@onready var shot_player: AudioStreamPlayer3D = $ShotPlayer

var _shot_stream: AudioStream = preload("res://assets/audio/weapons/smg_01.ogg")

func _ready() -> void:
	add_to_group("enemy")
	nav.path_desired_distance = 0.8
	nav.target_desired_distance = 1.2
	nav.height = 1.7
	shot_player.stream = _shot_stream
	anim_player.speed_scale = 1.0
	_play_anim("CharacterArmature|Idle_Gun")
	# let the navmap bake/sync before first path query
	await get_tree().create_timer(1.0).timeout
	_pick_patrol_target()

func _play_anim(a: String) -> void:
	if _anim == a:
		return
	_anim = a
	if anim_player.has_animation(a):
		anim_player.play(a)

func _pick_patrol_target() -> void:
	var points := get_tree().get_nodes_in_group("patrol_point")
	if points.is_empty():
		return
	var p: Node3D = points.pick_random()
	nav.target_position = p.global_position

func _physics_process(delta: float) -> void:
	if state == S.DEAD:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	_state_time += delta
	_cover_cooldown -= delta
	var player := _find_player()

	_next_think -= delta
	if _next_think <= 0.0:
		_next_think = 0.15
		_perceive(player)

	_next_shot -= delta
	match state:
		S.ATTACK:
			_combat_move(delta, player)
			if _next_shot <= 0.0 and player:
				_next_shot = 1.0 / fire_rate
				_fire_at(player)
		S.TAKE_COVER:
			_move_to(_cover_point, SPEED_COMBAT, delta)
			if _arrived(_cover_point) or _state_time > 4.0:
				_set_state(S.ATTACK)
		S.RETREAT:
			_move_to(_retreat_point(), SPEED_RETREAT, delta)
			if _state_time > 3.0:
				_set_state(S.TAKE_COVER)
		S.SEARCH:
			_search_behavior(delta)
		S.INVESTIGATE:
			_move_to(_last_known if _last_known != Vector3.INF else global_position, SPEED_PATROL * 1.2, delta)
			if _arrived_last_known() or _state_time > 8.0:
				_set_state(S.PATROL)
				_pick_patrol_target()
		S.ALERT:
			pass
		S.PATROL:
			_move_to(nav.target_position, SPEED_PATROL, delta)
			if _arrived(nav.target_position) or _state_time > 15.0:
				_state_time = 0.0
				_pick_patrol_target()

	# face target
	var face_target: Vector3
	if player and state in [S.ATTACK, S.TAKE_COVER, S.RETREAT]:
		face_target = player.global_position
	elif _last_known != Vector3.INF and state in [S.SEARCH, S.INVESTIGATE, S.ALERT]:
		face_target = _last_known
	else:
		face_target = nav.target_position
	var flat := face_target - global_position
	if flat.length() > 0.3:
		var target_rot := atan2(flat.x, flat.z)
		rotation.y = lerp_angle(rotation.y, target_rot, 8.0 * delta)

	# animation by movement
	var hspeed := Vector2(velocity.x, velocity.z).length()
	# scale walk/run animation to actual speed so it doesn't look like moonwalking
	anim_player.speed_scale = clampf(hspeed / 3.0, 0.6, 1.6)
	if state in [S.ATTACK, S.TAKE_COVER, S.RETREAT]:
		if hspeed > 0.5:
			_play_anim("CharacterArmature|Run_Shoot")
		else:
			_play_anim("CharacterArmature|Idle_Gun")
	else:
		if hspeed > 0.5:
			_play_anim("CharacterArmature|Walk")
		else:
			_play_anim("CharacterArmature|Idle_Gun")

	move_and_slide()

func _find_player() -> Node3D:
	for p in get_tree().get_nodes_in_group("player"):
		if not p.dead:
			return p
	return null

func _perceive(player: Node) -> void:
	if not player or player.dead:
		return
	var to_p: Vector3 = player.global_position - global_position
	var dist: float = to_p.length()
	var see := false
	if dist < vision_range:
		var fwd := -global_transform.basis.z
		var dotf: float = fwd.normalized().dot(to_p.normalized())
		if dotf > vision_fov_cos or dist < 6.0:
			see = _los_clear(player, 1)
	if see:
		_target = player
		_last_known = player.global_position
		match state:
			S.PATROL, S.INVESTIGATE, S.SEARCH:
				_alert_nearby()
				_set_state(S.ALERT)
			S.ALERT:
				if _state_time > 0.6:
					_set_state(S.ATTACK)
			S.TAKE_COVER, S.RETREAT:
				if _cover_cooldown <= 0.0 and health > 35:
					_set_state(S.ATTACK)
		if dist < 12.0 and state != S.ATTACK:
			_set_state(S.ATTACK)
	else:
		match state:
			S.ALERT:
				if _state_time > 1.2:
					_set_state(S.SEARCH)
			S.ATTACK, S.TAKE_COVER, S.RETREAT:
				_set_state(S.SEARCH)

func _los_clear(player: Node, mask: int) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.5, 0)
	var to: Vector3 = player.global_position + Vector3(0, 1.2, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	q.collision_mask = mask
	return space.intersect_ray(q).is_empty()

func _alert_nearby() -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = preload("res://assets/audio/impacts/bullet_crack_01.wav")
	p.global_position = global_position
	p.max_distance = 30.0
	p.volume_db = -6.0
	get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != self and e.state in [S.PATROL, S.INVESTIGATE] and e.global_position.distance_to(global_position) < 35.0:
			e._last_known = _last_known
			e._set_state(S.ALERT)

func _set_state(s: int) -> void:
	if state == s:
		return
	state = s
	_state_time = 0.0
	match s:
		S.SEARCH:
			_search_timer = 6.0
			if _last_known != Vector3.INF:
				nav.target_position = _last_known
		S.TAKE_COVER:
			_cover_point = _find_cover()
			_cover_cooldown = 6.0

func _search_behavior(delta: float) -> void:
	_search_timer -= delta
	if _arrived(nav.target_position):
		var r := Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
		nav.target_position = (_last_known if _last_known != Vector3.INF else global_position) + r
	if _search_timer <= 0.0:
		_set_state(S.PATROL)
		_pick_patrol_target()
	_move_to(nav.target_position, SPEED_PATROL * 1.3, delta)

func _combat_move(delta: float, player: Node) -> void:
	if not player:
		return
	var dist := global_position.distance_to(player.global_position)
	_strafe_time -= delta
	if _strafe_time <= 0.0:
		_strafe_time = randf_range(0.8, 2.0)
		_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	if health < 30 and _cover_cooldown <= 0.0:
		_set_state(S.RETREAT if dist > 15.0 else S.TAKE_COVER)
		return
	var desired := 14.0
	var dir: Vector3 = (player.global_position - global_position).normalized()
	var strafe: Vector3 = dir.cross(Vector3.UP) * _strafe_dir
	var move := Vector3.ZERO
	if dist > desired + 3.0:
		move = dir + strafe * 0.4
	elif dist < desired - 3.0:
		move = -dir + strafe * 0.6
	else:
		move = strafe
	_move_toward(global_position + move * 10.0, SPEED_COMBAT, delta)

func _fire_at(player: Node) -> void:
	if not _los_clear(player, 1):
		return
	_play_anim("CharacterArmature|Gun_Shoot")
	muzzle_flash.restart()
	shot_player.volume_db = randf_range(-10.0, -6.0)
	shot_player.play()
	var from := gun_tip.global_position
	var dist: float = global_position.distance_to(player.global_position)
	# aim at chest with distance-scaled spread (close = deadly, far = suppressive)
	var spread: float = clampf(accuracy * dist * 0.12, 0.08, 1.2)
	var to: Vector3 = player.global_position + Vector3(0, 1.1, 0) + Vector3(randf_range(-1,1)*spread, randf_range(-1,1)*spread*0.6, randf_range(-1,1)*spread)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	q.collision_mask = 5
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var col: Object = hit["collider"]
		if col.is_in_group("player") and col.has_method("take_damage"):
			col.take_damage(damage, global_position)
		else:
			Effects.spawn_impact(hit["position"], hit["normal"], col)
			Effects.play_impact_sound(hit["position"], col)

func _find_cover() -> Vector3:
	if not _target:
		return global_position
	var best := global_position
	var best_score := -1e9
	for cover in get_tree().get_nodes_in_group("cover"):
		var c: Node3D = cover
		var d_player: float = c.global_position.distance_to(_target.global_position)
		if d_player < 6.0 or d_player > 30.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(c.global_position + Vector3(0, 1.2, 0), _target.global_position + Vector3(0, 1.2, 0))
		q.exclude = [get_rid()]
		q.collision_mask = 1
		var blocked := not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
		var score: float = (20.0 - abs(d_player - 15.0)) + (15.0 if blocked else 0.0) - global_position.distance_to(c.global_position) * 0.5
		if score > best_score:
			best_score = score
			best = c.global_position
	return best

func _retreat_point() -> Vector3:
	if not _target:
		return global_position
	return global_position + (global_position - _target.global_position).normalized() * 12.0

func _move_to(dest: Vector3, speed: float, delta: float) -> void:
	_move_toward(dest, speed, delta)

func _move_toward(dest: Vector3, speed: float, delta: float) -> void:
	if not dest.is_finite():
		return
	nav.target_position = dest
	var next := nav.get_next_path_position()
	var dir := next - global_position
	dir.y = 0
	if dir.length() > 0.2 and speed > 0:
		dir = dir.normalized()
		# slow down near the destination so bots stop instead of sliding
		var eff_speed: float = speed
		if global_position.distance_to(dest) < 2.5:
			eff_speed = speed * clampf(global_position.distance_to(dest) / 2.5, 0.25, 1.0)
		velocity.x = lerpf(velocity.x, dir.x * eff_speed, 6.0 * delta)
		velocity.z = lerpf(velocity.z, dir.z * eff_speed, 6.0 * delta)
	else:
		# friction when idle — no ice-skating
		velocity.x = lerpf(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerpf(velocity.z, 0.0, 10.0 * delta)

func _arrived(dest: Vector3) -> bool:
	return global_position.distance_to(dest) < 1.5

func _arrived_last_known() -> bool:
	return _last_known != Vector3.INF and global_position.distance_to(_last_known) < 2.0

func take_damage(amount: int, from_pos: Vector3) -> void:
	if state == S.DEAD:
		return
	health -= amount
	_last_known = from_pos
	_play_anim("CharacterArmature|HitRecieve")
	if health <= 0:
		die()
	elif state in [S.PATROL, S.INVESTIGATE, S.SEARCH]:
		_alert_nearby()
		_set_state(S.ATTACK)
	elif state == S.ATTACK and health < 30:
		_set_state(S.TAKE_COVER)

func die() -> void:
	state = S.DEAD
	remove_from_group("enemy")
	GameManager.add_kill()
	GameManager.enemy_died()
	velocity = Vector3.ZERO
	los.enabled = false
	collision_layer = 0
	anim_player.speed_scale = 1.4
	_anim = ""
	_play_anim("CharacterArmature|Death")
	var p := AudioStreamPlayer3D.new()
	p.stream = preload("res://assets/audio/impacts/concrete_02.ogg")
	p.global_position = global_position
	p.volume_db = -6.0
	get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	get_tree().create_timer(8.0).timeout.connect(queue_free)