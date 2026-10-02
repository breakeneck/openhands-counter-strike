extends Node3D
# Hitscan weapon: RayCast3D + Timer + procedural model + particles + SFX.

signal ammo_changed(mag: int, reserve: int)
signal fired()
signal reloaded()
signal switched(weapon: Node3D)

var data: WeaponData
var mag_ammo: int
var reserve_ammo: int
var _reloading := false
var _trigger_held := false
var _next_shot := 0.0
var _reload_tween: Tween

@onready var muzzle: Node3D = $Muzzle
@onready var ray: RayCast3D = $Muzzle/RayCast3D
@onready var muzzle_flash: GPUParticles3D = $Muzzle/Flash
@onready var muzzle_light: OmniLight3D = $Muzzle/Flash/Light
@onready var shot_player: AudioStreamPlayer3D = $ShotPlayer
@onready var body_mesh: MeshInstance3D = $Body
@onready var barrel_mesh: MeshInstance3D = $Barrel
@onready var mag_mesh: MeshInstance3D = $Mag

var _shot_stream: AudioStream

func setup(d: WeaponData) -> void:
	data = d
	mag_ammo = d.magazine_size
	reserve_ammo = d.reserve_ammo
	# procedural geometry from resource params
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	body_mesh.mesh = bm
	body_mesh.scale = d.body_scale
	var barm := BoxMesh.new()
	barm.size = Vector3.ONE
	barrel_mesh.mesh = barm
	barrel_mesh.scale = d.barrel_scale
	barrel_mesh.position = Vector3(0, d.body_scale.y * 0.35, -(d.body_scale.z * 0.5 + d.barrel_scale.z * 0.4))
	var mm := BoxMesh.new()
	mm.size = Vector3.ONE
	mag_mesh.mesh = mm
	mag_mesh.scale = d.mag_scale
	mag_mesh.position = Vector3(0, -d.body_scale.y * 0.5 - d.mag_scale.y * 0.4, d.body_scale.z * 0.1)
	for m in [body_mesh, barrel_mesh, mag_mesh]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = d.body_color
		mat.metallic = 0.7
		mat.roughness = 0.35
		m.material_override = mat
	ray.target_position = Vector3(0, 0, -d.range_m)
	ray.collision_mask = 3
	shot_player.stream = load(d.shot_sound)
	ammo_changed.emit(mag_ammo, reserve_ammo)

func try_fire() -> bool:
	if _reloading or GameManager.state != GameManager.State.PLAYING:
		return false
	if Time.get_ticks_msec() / 1000.0 < _next_shot:
		return false
	if mag_ammo <= 0:
		_play_dry()
		_start_reload()
		return false
	_next_shot = Time.get_ticks_msec() / 1000.0 + 1.0 / data.fire_rate
	mag_ammo -= 1
	ammo_changed.emit(mag_ammo, reserve_ammo)
	_shoot()
	return true

func _shoot() -> void:
	fired.emit()
	muzzle_flash.restart()
	muzzle_light.visible = true
	get_tree().create_timer(0.05).timeout.connect(func(): muzzle_light.visible = false)
	shot_player.volume_db = randf_range(-2.0, 0.0)
	shot_player.play()
	var player := get_tree().get_first_node_in_group("player")
	var spread := data.spread_rad
	if Input.is_action_pressed("aim"):
		spread = data.ads_spread_rad
	for i in data.pellets:
		var dir := -global_transform.basis.z
		dir += Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))
		_raycast_hit(dir.normalized())
	if player:
		player.add_recoil(data.recoil_kick, data.recoil_yaw)
	# weapon kick animation
	var tw := create_tween()
	tw.tween_property(self, "position:z", 0.06, 0.04)
	tw.tween_property(self, "position:z", 0.0, 0.09)
	tw.parallel().tween_property(self, "rotation:x", -data.recoil_kick * 0.8, 0.04)
	tw.tween_property(self, "rotation:x", 0.0, 0.12)

func _raycast_hit(dir: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(muzzle.global_position, muzzle.global_position + dir.normalized() * data.range_m)
	q.collision_mask = 3
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var hit_point: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		var collider = hit["collider"]
		# damage — hit zones: head = instant kill, chest = full, limbs = reduced
		var dmg := data.damage
		var is_head := false
		var zone := "body"
		if collider.is_in_group("enemy"):
			var rel_y: float = hit_point.y - collider.global_position.y
			var head_area: Node = collider.get_node_or_null("HeadArea")
			var head_hit: bool = head_area and head_area.has_method("point_in_head") and head_area.point_in_head(hit_point)
			if head_hit or rel_y > 1.42:
				is_head = true
				zone = "head"
				dmg = 1000  # CS-style: headshot kills outright
			elif rel_y < 0.55:
				zone = "legs"
				dmg = int(dmg * 0.6)
			elif rel_y > 1.15:
				zone = "arms"
				dmg = int(dmg * 0.85)
			if collider.has_method("take_damage"):
				collider.take_damage(int(dmg), global_position)
			Effects.spawn_blood_splat(hit_point, is_head)
		elif collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(int(dmg), global_position)
		Effects.spawn_impact(hit_point, normal, collider)
		Effects.play_impact_sound(hit_point, collider)
		if collider.is_in_group("enemy"):
			Effects.play_hitmarker(is_head)

func _play_dry() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = preload("res://assets/audio/reload/dry_fire_02.ogg")
	p.volume_db = -6.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func start_reload() -> void:
	_start_reload()

func _start_reload() -> void:
	if _reloading or mag_ammo >= data.magazine_size or reserve_ammo <= 0:
		return
	_reloading = true
	_reload_tween = create_tween()
	_reload_tween.tween_property(self, "rotation:x", 0.9, data.reload_time * 0.35)
	_reload_tween.tween_property(self, "position:y", -0.15, data.reload_time * 0.3)
	_play_reload_step("reload/mag_out_01.ogg", data.reload_time * 0.2)
	_play_reload_step("reload/mag_in_01.ogg", data.reload_time * 0.55)
	_reload_tween.tween_property(self, "rotation:x", 0.0, data.reload_time * 0.3)
	_reload_tween.parallel().tween_property(self, "position:y", 0.0, data.reload_time * 0.3)
	_reload_tween.tween_callback(_finish_reload)

func _play_reload_step(snd: String, at: float) -> void:
	get_tree().create_timer(at).timeout.connect(func():
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s" % snd)
		p.volume_db = -8.0
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play())

func _finish_reload() -> void:
	var need := data.magazine_size - mag_ammo
	var take := mini(need, reserve_ammo)
	mag_ammo += take
	reserve_ammo -= take
	_reloading = false
	ammo_changed.emit(mag_ammo, reserve_ammo)
	reloaded.emit()

func set_trigger(held: bool) -> void:
	_trigger_held = held