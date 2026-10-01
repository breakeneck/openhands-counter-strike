extends Area3D
# Head hitbox: point-in-sphere test in world space.

func point_in_head(world_point: Vector3) -> bool:
	return global_position.distance_to(world_point) <= 0.32
