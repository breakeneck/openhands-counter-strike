extends Node3D
# Tactical map: built from data via primitives + CC0 procedural textures.
# Blockout validated for routes/cover/verticality/interiors.

const TEX_DIR := "res://assets/textures/"

var _mats := {}

var _geo_root: Node3D

func _ready() -> void:
	_geo_root = NavigationRegion3D.new()
	_geo_root.name = "MapNavRegion"
	add_child(_geo_root)
	_build_materials()
	_build_environment()
	_build_ground_and_road()
	_build_buildings()
	_build_containers_and_props()
	_build_verticality()
	_build_objective()
	_spawn_entities()
	_bake_navigation()

# ---------- materials ----------
func _build_materials() -> void:
	for t: String in ["asphalt","concrete","concrete_floor","brick","brick2","metal","metal_rust","wood_crate","wood_pallet","roof_gravel","sand","tiles","roof_metal"]:
		var m := StandardMaterial3D.new()
		var tex_path := TEX_DIR + t + ".png"
		if ResourceLoader.exists(tex_path):
			m.albedo_texture = load(tex_path)
			m.uv1_scale = Vector3(0.25, 0.25, 0.25)
			var rpath := TEX_DIR + t + "_r.png"
			if ResourceLoader.exists(rpath):
				m.roughness_texture = load(rpath)
		else:
			m.albedo_color = Color(0.5, 0.5, 0.5)
		m.roughness = 0.9
		_mats[t] = m
	# fallbacks for missing textures handled above

func _mat(t: String) -> StandardMaterial3D:
	return _mats.get(t, _mats.get("concrete"))

# ---------- box helper ----------
func _box(pos: Vector3, size: Vector3, tex: String, groups: PackedStringArray = PackedStringArray(), y_rot: float = 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(tex)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	_geo_root.add_child(sb)
	sb.global_position = pos
	sb.rotation.y = y_rot
	for g in groups:
		sb.add_to_group(g)
	return sb

# ---------- environment ----------
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var proc := ProceduralSkyMaterial.new()
	proc.sky_top_color = Color(0.35, 0.5, 0.7)
	proc.sky_horizon_color = Color(0.75, 0.68, 0.55)
	proc.ground_bottom_color = Color(0.2, 0.18, 0.16)
	proc.ground_horizon_color = Color(0.75, 0.68, 0.55)
	sky.sky_material = proc
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.8, 0.75, 0.65)
	env.fog_density = 0.006
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(0.8, 0.78, 0.72)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 135, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)

func _omni(pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	l.shadow_enabled = false
	add_child(l)

# ---------- ground ----------
func _build_ground_and_road() -> void:
	_box(Vector3(0, -0.25, 0), Vector3(140, 0.5, 140), "sand", ["world"])
	# main road (mid lane) N-S
	_box(Vector3(0, 0.02, 0), Vector3(14, 0.06, 120), "asphalt", ["world"])
	# cross road E-W
	_box(Vector3(0, 0.02, 30), Vector3(120, 0.06, 12), "asphalt", ["world"])
	_box(Vector3(0, 0.02, -34), Vector3(120, 0.06, 12), "asphalt", ["world"])
	# sidewalks
	_box(Vector3(-10, 0.08, 0), Vector3(4, 0.18, 120), "concrete_floor", ["world"])
	_box(Vector3(10, 0.08, 0), Vector3(4, 0.18, 120), "concrete_floor", ["world"])

# ---------- buildings ----------
func _wall(seg: Array, tex: String) -> void:
	# seg = [x1,z1,x2,z2,height,thickness]
	var x1: float = seg[0]; var z1: float = seg[1]; var x2: float = seg[2]; var z2: float = seg[3]
	var h: float = seg[4]; var t: float = seg[5]
	var dx := x2 - x1; var dz := z2 - z1
	var length := sqrt(dx * dx + dz * dz)
	var center := Vector3((x1 + x2) * 0.5, h * 0.5, (z1 + z2) * 0.5)
	var ang := atan2(dz, dx)
	_box(center, Vector3(length, h, t), tex, ["world"], -ang)

func _build_buildings() -> void:
	# === Building A (NW): two-room interior, roof, entry from mid ===
	var h := 6.0; var t := 0.4
	var ax := -28.0; var az := 8.0  # center
	# floor slab
	_box(Vector3(ax, 0.1, az), Vector3(20, 0.2, 16), "concrete_floor", ["world"])
	# outer walls with door gap on east side facing mid road
	_wall([ax-10, az-8, ax+10, az-8, h, t], "brick")        # north
	_wall([ax-10, az+8, ax+10, az+8, h, t], "brick")        # south
	_wall([ax-10, az-8, ax-10, az+8, h, t], "brick")        # west
	_wall([ax+10, az-8, ax+10, az-2.2, h, t], "brick")      # east lower
	_wall([ax+10, az+2.2, ax+10, az+8, h, t], "brick")      # east upper (door gap 4.4)
	# interior divider
	_wall([ax-10, az, ax+3, az, h - 1.0, t], "concrete")
	_wall([ax+6, az, ax+10, az, h - 1.0, t], "concrete")
	# roof
	_box(Vector3(ax, h + 0.15, az), Vector3(20.6, 0.3, 16.6), "roof_gravel", ["world"])
	# roof access ramp (verticality) exterior
	_ramp(Vector3(ax - 12.5, 0, az - 4), 6.2, 9.0, 3.0, "metal_rust")
	_box(Vector3(ax - 10.2, h + 1.2, az - 4), Vector3(0.3, 2.2, 4), "metal_rust", ["world"])
	# windows (visual): dark inset quads
	_window(Vector3(ax, h - 2.0, az + 8.05), Vector2(4, 2))
	_window(Vector3(ax - 10.05, h - 2.0, az), Vector2(4, 2), true)
	_omni(Vector3(ax, h - 1.0, az), Color(1, 0.85, 0.6), 1.6, 16)
	_omni(Vector3(ax + 5, h - 1.0, az - 3), Color(1, 0.9, 0.7), 1.0, 12)

	# === Building B (NE): warehouse, big doors, catwalk anchor ===
	var bx := 26.0; var bz := 12.0
	_box(Vector3(bx, 0.1, bz), Vector3(22, 0.2, 18), "concrete_floor", ["world"])
	_wall([bx-11, bz-9, bx+11, bz-9, 8, t], "brick2")
	_wall([bx-11, bz+9, bx-4, bz+9, 8, t], "brick2")
	_wall([bx+4, bz+9, bx+11, bz+9, 8, t], "brick2")   # big south door gap
	_wall([bx-11, bz-9, bx-11, bz+9, 8, t], "brick2")
	_wall([bx+11, bz-9, bx+11, bz+9, 8, t], "brick2")
	_box(Vector3(bx, 8.15, bz), Vector3(22.6, 0.3, 18.6), "roof_metal", ["world"])
	# interior shelves (cover inside)
	for i in 3:
		_box(Vector3(bx - 6 + i * 6, 1.5, bz - 3), Vector3(1.6, 3.0, 10), "wood_pallet", ["world", "cover"])
	_omni(Vector3(bx, 6.5, bz), Color(0.8, 0.85, 1.0), 1.0, 18)
	# crate stack entry ramp
	_ramp(Vector3(bx + 13.5, 0, bz + 4), 8.0, 9.0, 3.0, "metal_rust")

	# === Building C (SW): small shop, interior, back door ===
	var cx := -24.0; var cz := -30.0
	_box(Vector3(cx, 0.1, cz), Vector3(14, 0.2, 12), "tiles", ["world"])
	_wall([cx-7, cz-6, cx+7, cz-6, 4.5, t], "concrete")
	_wall([cx-7, cz+6, cx-1.8, cz+6, 4.5, t], "concrete")
	_wall([cx+1.8, cz+6, cx+7, cz+6, 4.5, t], "concrete")  # north door
	_wall([cx-7, cz-6, cx-7, cz+6, 4.5, t], "concrete")
	_wall([cx+7, cz-6, cx+7, cz-1, 4.5, t], "concrete")
	_wall([cx+7, cz+2, cx+7, cz+6, 4.5, t], "concrete")    # back door gap
	_box(Vector3(cx, 4.65, cz), Vector3(14.6, 0.3, 12.6), "roof_gravel", ["world"])
	_omni(Vector3(cx, 3.5, cz), Color(1, 0.9, 0.7), 1.4, 14)
	# awning
	_box(Vector3(cx, 3.2, cz + 7.5), Vector3(10, 0.15, 3), "metal", ["world"])

	# === Building D (SE): compound with courtyard (objective site) ===
	var dx := 24.0; var dz := -28.0
	_box(Vector3(dx, 0.1, dz), Vector3(24, 0.2, 20), "concrete_floor", ["world"])
	# perimeter wall with two entrances
	_wall([dx-12, dz-10, dx+12, dz-10, 4.0, t], "brick")
	_wall([dx-12, dz+10, dx-2, dz+10, 4.0, t], "brick")
	_wall([dx+2, dz+10, dx+12, dz+10, 4.0, t], "brick")    # main north gate
	_wall([dx-12, dz-10, dx-12, dz+10, 4.0, t], "brick")
	_wall([dx+12, dz-10, dx+12, dz-4, 4.0, t], "brick")
	_wall([dx+12, dz+1, dx+12, dz+10, 4.0, t], "brick")    # side gate
	# guardhouse inside courtyard
	_box(Vector3(dx + 6, 0.1, dz - 4), Vector3(6, 0.2, 6), "tiles", ["world"])
	_wall([dx+3, dz-7, dx+9, dz-7, 3.5, t], "concrete")
	_wall([dx+3, dz-1, dx+9, dz-1, 3.5, t], "concrete")
	_wall([dx+3, dz-7, dx+3, dz-1, 3.5, t], "concrete")
	_wall([dx+9, dz-7, dx+9, dz-1, 3.5, t], "concrete")
	_box(Vector3(dx + 6, 3.6, dz - 4), Vector3(6.6, 0.25, 6.6), "roof_metal", ["world"])
	_omni(Vector3(dx, 4.5, dz), Color(1, 0.8, 0.5), 0.9, 16)

func _window(pos: Vector3, size: Vector2, rotated: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, size.y, 0.1) if not rotated else Vector3(0.1, size.y, size.x)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.06, 0.08)
	m.metallic = 0.6
	m.roughness = 0.2
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos

func _ramp(base: Vector3, top_h: float, length: float, width: float, tex: String) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.3, sqrt(length * length + top_h * top_h))
	mi.mesh = bm
	mi.material_override = _mat(tex)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = base + Vector3(0, top_h * 0.5, -length * 0.5)
	sb.rotation.x = atan2(top_h, length)
	_geo_root.add_child(sb)
	# support legs
	_box(base + Vector3(0, top_h * 0.25, -length * 0.9), Vector3(width, top_h * 0.5, 0.3), tex, ["world"])

# ---------- containers & props ----------
func _build_containers_and_props() -> void:
	# shipping containers — mid lane cover
	_box(Vector3(-4, 1.75, 18), Vector3(6, 3.5, 2.8), "metal", ["world", "cover"], PI / 2)
	_box(Vector3(5, 1.75, -12), Vector3(6, 3.5, 2.8), "metal_rust", ["world", "cover"], PI / 2)
	_box(Vector3(-3, 1.75, -20), Vector3(6, 3.5, 2.8), "metal", ["world", "cover"], 0.3)
	_box(Vector3(14, 1.75, 28), Vector3(6, 3.5, 2.8), "metal_rust", ["world", "cover"], 0.0)
	_box(Vector3(-16, 1.75, 28), Vector3(6, 3.5, 2.8), "metal", ["world", "cover"], 1.57)
	# stacked pair
	_box(Vector3(16, 5.25, -18), Vector3(6, 3.5, 2.8), "metal", ["world", "cover"], 1.57)
	_box(Vector3(16, 1.75, -18), Vector3(6, 3.5, 2.8), "metal_rust", ["world", "cover"], 1.57)
	# crates & barrels
	var crate_spots := [Vector3(-13, 0.7, 4), Vector3(-12, 0.7, 14), Vector3(12, 0.7, 6), Vector3(9, 0.7, 22), Vector3(-20, 0.7, -12), Vector3(2, 0.7, 40), Vector3(-8, 0.7, -44), Vector3(30, 0.7, 2), Vector3(-30, 0.7, 26), Vector3(40, 0.7, -30)]
	for s in crate_spots:
		_box(s, Vector3(1.4, 1.4, 1.4), "wood_crate", ["world", "cover", "wood"])
		_box(s + Vector3(1.3, -0.1, 0.4), Vector3(1.0, 1.2, 1.0), "wood_pallet", ["world", "cover", "wood"])
	var barrel_spots := [Vector3(-11, 0.6, -2), Vector3(11.5, 0.6, 12), Vector3(-18, 0.6, 20), Vector3(20, 0.6, 36), Vector3(-34, 0.6, -20), Vector3(34, 0.6, -12)]
	for s in barrel_spots:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.45; cm.bottom_radius = 0.45; cm.height = 1.2
		mi.mesh = cm
		mi.material_override = _mat("metal_rust")
		sb.add_child(mi)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.45; cyl.height = 1.2
		cs.shape = cyl
		sb.add_child(cs)
		_geo_root.add_child(sb)
		sb.global_position = s
		sb.add_to_group("world"); sb.add_to_group("cover"); sb.add_to_group("metal")
	# low walls / jersey barriers for cover lanes
	for i in 6:
		_box(Vector3(-6 + (i % 2) * 12, 0.55, -6 + i * 9), Vector3(3, 1.1, 0.8), "concrete", ["world", "cover"], PI / 2 if i % 3 == 0 else 0)
	# street lamps (props + light)
	for p in [Vector3(-10, 0, 20), Vector3(10, 0, -10), Vector3(-10, 0, -30), Vector3(10, 0, 40)]:
		_box(p + Vector3(0, 3, 0), Vector3(0.2, 6, 0.2), "metal_rust", ["world"])
		_box(p + Vector3(0, 6, 0.6), Vector3(0.5, 0.2, 1.4), "metal", ["world"])
		_omni(p + Vector3(0, 5.6, 1.0), Color(1, 0.85, 0.55), 0.5, 10)

# ---------- verticality ----------
func _build_verticality() -> void:
	# catwalk Building A roof -> container stack -> Building B roof is too far;
	# instead: catwalk over mid road connecting A-roof level platform to a tower
	var tower_x := 30.0; var tower_z := 30.0
	_box(Vector3(tower_x, 4, tower_z), Vector3(4, 8, 4), "concrete", ["world"])
	_box(Vector3(tower_x, 8.2, tower_z), Vector3(6, 0.3, 6), "roof_metal", ["world"])
	_ramp(Vector3(tower_x + 5, 0, tower_z), 8.2, 11.0, 2.5, "metal_rust")
	# railing on tower
	_box(Vector3(tower_x, 9.2, tower_z - 2.8), Vector3(6, 1.0, 0.15), "metal_rust", ["world"])
	_box(Vector3(tower_x, 9.2, tower_z + 2.8), Vector3(6, 1.0, 0.15), "metal_rust", ["world"])
	_box(Vector3(tower_x - 2.8, 9.2, tower_z), Vector3(0.15, 1.0, 6), "metal_rust", ["world"])
	# catwalk from tower toward Building B roof (8m high) — bridge at y=8
	_box(Vector3((tower_x + 26) * 0.5, 8.1, (30 + 12) * 0.5), Vector3(20, 0.25, 2.2), "metal_rust", ["world"], atan2(12 - 30, 26 - tower_x) + PI / 2)
	_box(Vector3(22, 9.1, 21), Vector3(0.15, 1.0, 9), "metal_rust", ["world"], 0.69)

# ---------- objective ----------
func _build_objective() -> void:
	var zone := Node3D.new()
	zone.name = "ObjectiveZone"
	zone.add_to_group("objective_zone")
	add_child(zone)
	zone.global_position = Vector3(24, 0, -28)
	# visual: capture ring
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 6.2; torus.outer_radius = 6.8
	ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.9, 0.2, 0.15)
	rm.emission_enabled = true
	rm.emission = Color(0.9, 0.2, 0.15)
	rm.emission_energy_multiplier = 1.5
	ring.material_override = rm
	ring.position = Vector3(0, 0.3, 0)
	zone.add_child(ring)
	var pl := OmniLight3D.new()
	pl.light_color = Color(1, 0.3, 0.2)
	pl.light_energy = 1.2
	pl.omni_range = 14
	pl.position = Vector3(0, 6, 0)
	zone.add_child(pl)
	# intel crate in center
	_box(Vector3(24, 0.7, -28), Vector3(1.2, 1.4, 1.2), "wood_crate", ["world", "wood"])
	# zone progress ring pulses via script
	var pulse := _CapturePulse.new()
	zone.add_child(pulse)

class _CapturePulse extends Node:
	func _process(_d: float) -> void:
		var zone := get_parent() as Node3D
		if not zone:
			return
		var prog: float = GameManager.capture_progress
		var ring := zone.get_child(0) as MeshInstance3D
		if ring:
			var m := ring.material_override as StandardMaterial3D
			m.emission_energy_multiplier = 1.0 + prog * 3.0 + sin(Time.get_ticks_msec() / 200.0) * 0.3
			ring.rotation.y += _d * (0.3 + prog * 2.0)

# ---------- entities ----------
func _spawn_entities() -> void:
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var player: Node = player_scene.instantiate()
	add_child(player)
	player.global_position = Vector3(-2, 1.2, 52)

	var enemy_scene: PackedScene = load("res://scenes/enemies/enemy.tscn")
	var spawns := [Vector3(24, 1.2, -20), Vector3(26, 1.2, 12), Vector3(-28, 1.2, 8), Vector3(-24, 1.2, -30), Vector3(30, 1.2, 30), Vector3(2, 1.2, -40)]
	for s in spawns:
		var e: Node = enemy_scene.instantiate()
		add_child(e)
		e.global_position = s

	# patrol points along routes
	var patrol_pts := [Vector3(-2, 0, 45), Vector3(-2, 0, 15), Vector3(-2, 0, -15), Vector3(-2, 0, -45), Vector3(-25, 0, 30), Vector3(25, 0, 30), Vector3(-25, 0, -20), Vector3(25, 0, -15), Vector3(20, 0, 5), Vector3(-15, 0, 5)]
	for p in patrol_pts:
		var n := Node3D.new()
		n.add_to_group("patrol_point")
		add_child(n)
		n.global_position = p

# ---------- navigation ----------
func _bake_navigation() -> void:
	var region := _geo_root as NavigationRegion3D
	var nm := NavigationMesh.new()
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_radius = 0.45
	nm.agent_height = 1.7
	nm.agent_max_climb = 0.9
	nm.agent_max_slope = deg_to_rad(42.0)
	region.navigation_mesh = nm
	# bake from all world geometry
	region.bake_navigation_mesh(true)
	# enemies spawn after bake; they query nav at runtime
	print("[MAP] navigation bake queued")