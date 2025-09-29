extends RigidBody2D
class_name PhysicalBodyBase

var movement_speed = 100

func _physics_process(_delta: float) -> void:
	move_to_target()


func can_reach(pos: Vector2) -> bool:
	var map_rid = get_world_2d().navigation_map
	var closest_point = NavigationServer2D.map_get_closest_point(map_rid, pos)
	# If the closest point on the nav mesh is very close to the position, it's reachable.
	return pos.distance_to(closest_point) < 1.0


func target_pos(pos: Vector2) -> void:
	%NavigationAgent2D.target_position = pos


func move_to_target() -> void:
	if %NavigationAgent2D.is_navigation_finished():
		linear_velocity = Vector2.ZERO
		return

	var next_path_position: Vector2 = %NavigationAgent2D.get_next_path_position()
	var new_velocity: Vector2 = global_position.direction_to(next_path_position) * movement_speed
	# Using linear_velocity for RigidBody2D
	linear_velocity = new_velocity
