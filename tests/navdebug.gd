extends Node
func _ready() -> void:
	var region := NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	region.navigation_mesh = nm
	add_child(region)
	var sb := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(20, 1, 20)
	mi.mesh = bm
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	cs.shape = bs
	sb.add_child(cs)
	region.add_child(sb)
	sb.position = Vector3(0, -0.5, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	region.bake_navigation_mesh(false)
	print("sync bake: polys=", nm.get_polygon_count())
	await get_tree().create_timer(2.0).timeout
	print("after 2s: polys=", nm.get_polygon_count())
	get_tree().quit()