extends Node
# Shared combat VFX/SFX spawner — small, stateless helpers.

var _impact_mat_concrete: StandardMaterial3D
var _impact_mat_metal: StandardMaterial3D
var _impact_mat_wood: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _decal_tex: Texture2D
var _impact_streams := {}
var _hit_stream: AudioStream
var _head_stream: AudioStream

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var p := "res://assets/audio/"
	_impact_mat_concrete = _mat(Color(0.55, 0.53, 0.5))
	_impact_mat_metal = _mat(Color(0.9, 0.85, 0.6))
	_impact_mat_wood = _mat(Color(0.55, 0.4, 0.22))
	_spark_mat = _mat(Color(1.0, 0.7, 0.25))
	_spark_mat.emission_enabled = true
	_spark_mat.emission = Color(1.0, 0.6, 0.2)
	_spark_mat.emission_energy_multiplier = 4.0
	_decal_tex = _make_decal_texture()
	_impact_streams["concrete"] = load(p + "impacts/concrete_01.ogg")
	_impact_streams["metal"] = load(p + "impacts/impactMetal_heavy_000.ogg")
	_impact_streams["wood"] = load(p + "footsteps/footstep_wood_000.ogg")
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

func spawn_impact(point: Vector3, normal: Vector3, collider) -> void:
	var mat := _impact_mat_concrete
	if collider.is_in_group("metal"): mat = _impact_mat_metal
	elif collider.is_in_group("wood"): mat = _impact_mat_wood
	# sparks
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.35
	p.one_shot = true
	p.explosiveness = 1.0
	var m := ParticleProcessMaterial.new()
	m.direction = normal
	m.spread = 55.0
	m.gravity = Vector3(0, -9.0, 0)
	m.initial_velocity_min = 2.0
	m.initial_velocity_max = 6.0
	m.scale_min = 0.02
	m.scale_max = 0.05
	p.process_material = m
	p.draw_pass_1 = _quad(_spark_mat)
	p.global_position = point + normal * 0.02
	get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.restart()
	# decal
	var d := Decal.new()
	d.texture_albedo = _decal_tex
	var s := randf_range(0.15, 0.3)
	d.size = Vector3(s, 0.1, s)
	d.global_transform = Transform3D(_decal_basis(normal), point + normal * 0.01)
	get_tree().root.add_child(d)
	get_tree().create_timer(20.0).timeout.connect(d.queue_free)

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
	elif collider.is_in_group("enemy"): key = "concrete"
	var p := AudioStreamPlayer3D.new()
	p.stream = _impact_streams[key]
	p.global_position = point
	p.max_distance = 30.0
	p.volume_db = randf_range(-12.0, -6.0)
	get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func play_hitmarker(headshot: bool) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _head_stream if headshot else _hit_stream
	p.volume_db = -8.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()