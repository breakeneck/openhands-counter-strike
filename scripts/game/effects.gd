extends Node
# Shared combat VFX/SFX spawner — small, stateless helpers.

var _impact_mat_concrete: StandardMaterial3D
var _impact_mat_metal: StandardMaterial3D
var _impact_mat_wood: StandardMaterial3D
var _blood_mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _decal_tex: Texture2D
var _blood_decal_tex: Texture2D
var _impact_streams := {}
var _hit_stream: AudioStream
var _head_stream: AudioStream

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var p := "res://assets/audio/"
	_impact_mat_concrete = _mat(Color(0.55, 0.53, 0.5))
	_impact_mat_metal = _mat(Color(0.9, 0.85, 0.6))
	_impact_mat_wood = _mat(Color(0.55, 0.4, 0.22))
	_blood_mat = _mat(Color(0.45, 0.02, 0.02))
	_spark_mat = _mat(Color(1.0, 0.7, 0.25))
	_spark_mat.emission_enabled = true
	_spark_mat.emission = Color(1.0, 0.6, 0.2)
	_spark_mat.emission_energy_multiplier = 4.0
	_decal_tex = _make_decal_texture()
	_blood_decal_tex = _make_blood_decal_texture()
	_impact_streams["concrete"] = load(p + "impacts/concrete_01.ogg")
	_impact_streams["metal"] = load(p + "impacts/impactMetal_heavy_000.ogg")
	_impact_streams["wood"] = load(p + "footsteps/footstep_wood_000.ogg")
	_impact_streams["flesh"] = load(p + "impacts/concrete_01.ogg")
	_hit_stream = load(p + "ui/beep_01.wav")
	_head_stream = load(p + "ui/confirm_01.ogg")

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func _make_decal_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 64:
		for x in 64:
			var d := Vector2(x - 32, y - 32).length() / 32.0
			var a := 0.0
			if d < 0.35:
				a = 0.9
			elif d < 0.55:
				a = randf() * 0.5
			elif d < 0.7 and randf() < 0.15:
				a = randf() * 0.3
			img.set_pixel(x, y, Color(0.05, 0.04, 0.03, a))
	return ImageTexture.create_from_image(img)

func _make_blood_decal_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# irregular splat: several overlapping blobs
	var blobs: Array[Vector2] = []
	for i in 6:
		blobs.append(Vector2(randf_range(18, 46), randf_range(18, 46)))
	for y in 64:
		for x in 64:
			var pos := Vector2(x, y)
			var a := 0.0
			for b in blobs:
				var d := pos.distance_to(b) / randf_range(6.0, 12.0)
				if d < 1.0:
					a = maxf(a, (1.0 - d) * 0.95)
			# drips below blobs
			for b in blobs:
				if absf(pos.x - b.x) < 2.5 and pos.y > b.y and pos.y < b.y + randf_range(4, 14):
					a = maxf(a, 0.5)
			if a > 0.0:
				img.set_pixel(x, y, Color(0.35, 0.01, 0.01, a))
	return ImageTexture.create_from_image(img)

func spawn_impact(point: Vector3, normal: Vector3, collider) -> void:
	var is_flesh: bool = collider.is_in_group("enemy")
	var mat := _impact_mat_concrete
	if is_flesh: mat = _blood_mat
	elif collider.is_in_group("metal"): mat = _impact_mat_metal
	elif collider.is_in_group("wood"): mat = _impact_mat_wood
	# particles: blood spray for flesh, sparks otherwise
	var p := GPUParticles3D.new()
	p.amount = 26 if is_flesh else 10
	p.lifetime = 0.6 if is_flesh else 0.35
	p.one_shot = true
	p.explosiveness = 1.0
	var m := ParticleProcessMaterial.new()
	m.direction = normal
	m.spread = 35.0 if is_flesh else 55.0
	m.gravity = Vector3(0, -9.8, 0)
	if is_flesh:
		m.initial_velocity_min = 1.5
		m.initial_velocity_max = 4.5
		m.scale_min = 0.03
		m.scale_max = 0.09
	else:
		m.initial_velocity_min = 2.0
		m.initial_velocity_max = 6.0
		m.scale_min = 0.02
		m.scale_max = 0.05
	p.process_material = m
	p.draw_pass_1 = _quad(mat if is_flesh else _spark_mat)
	get_tree().root.add_child(p)
	p.global_position = point + normal * 0.02
	p.finished.connect(p.queue_free)
	p.restart()
	# decal (skip for flesh — blood decals handled by spawn_blood_splat)
	if not is_flesh:
		var d := Decal.new()
		d.texture_albedo = _decal_tex
		var s := randf_range(0.15, 0.3)
		d.size = Vector3(s, 0.1, s)
		get_tree().root.add_child(d)
		d.global_transform = Transform3D(_decal_basis(normal), point + normal * 0.01)
		get_tree().create_timer(20.0).timeout.connect(d.queue_free)

# Big red splash + dripping blood decals at the hit point (CS-style headshot feedback).
func spawn_blood_splat(point: Vector3, headshot: bool) -> void:
	var p := GPUParticles3D.new()
	p.amount = 60 if headshot else 30
	p.lifetime = 0.9 if headshot else 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 180.0
	m.gravity = Vector3(0, -12.0, 0)
	m.initial_velocity_min = 2.0 if headshot else 1.0
	m.initial_velocity_max = 6.5 if headshot else 3.5
	m.scale_min = 0.04
	m.scale_max = 0.14 if headshot else 0.09
	p.process_material = m
	p.draw_pass_1 = _quad(_blood_mat)
	get_tree().root.add_child(p)
	p.global_position = point
	p.finished.connect(p.queue_free)
	p.restart()
	# blood decals: on the ground below + a couple at the hit point
	var ground_y := 0.02
	var n := 3 if headshot else 1
	for i in n:
		var d := Decal.new()
		d.texture_albedo = _blood_decal_tex
		var s := randf_range(0.4, 0.9) if headshot else randf_range(0.25, 0.5)
		d.size = Vector3(s, 0.15, s)
		var pos := point + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		pos.y = ground_y if i == 0 else point.y + randf_range(-0.3, 0.3)
		get_tree().root.add_child(d)
		d.global_transform = Transform3D(Basis(), pos)
		get_tree().create_timer(25.0).timeout.connect(d.queue_free)

func _decal_basis(normal: Vector3) -> Basis:
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	return Basis().looking_at(-normal, up)

func _quad(mat: StandardMaterial3D) -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	q.material = mat
	return q

func play_impact_sound(point: Vector3, collider) -> void:
	var key := "concrete"
	if collider.is_in_group("metal"): key = "metal"
	elif collider.is_in_group("wood"): key = "wood"
	elif collider.is_in_group("enemy"): key = "flesh"
	var p := AudioStreamPlayer3D.new()
	p.stream = _impact_streams[key]
	p.max_distance = 30.0
	p.volume_db = randf_range(-12.0, -6.0)
	get_tree().root.add_child(p)
	p.global_position = point
	p.finished.connect(p.queue_free)
	p.play()

signal hitmarker(headshot: bool)

func play_hitmarker(headshot: bool) -> void:
	hitmarker.emit(headshot)
	var p := AudioStreamPlayer.new()
	p.stream = _head_stream if headshot else _hit_stream
	p.volume_db = -8.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()