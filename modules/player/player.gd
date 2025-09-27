extends RigidBody2D

@export var navigation_agent_2d: NavigationAgent2D
@export var movement_speed: float = 100.0
@export var target_detection_range: float = 500.0
@export var attack_range: float = 50.0  # Distance when we're "close enough"
@export var force_multiplier: float = 20.0  # For movement responsiveness

# Reference to the current target mob
var target_mob: Node2D = null

func _ready() -> void:
	initialize_navigation_agent()

# Main physics process - manages the core gameplay loop
func _physics_process(_delta: float) -> void:
	ensure_target_exists()
	
	if target_mob == null:
		return
		
	set_navigation_target()
	
	if is_within_attack_range():
		handle_attack_range_behavior()
		return
	
	move_toward_target()

# Initialize navigation agent with default settings
func initialize_navigation_agent() -> void:
	navigation_agent_2d.path_desired_distance = 5.0
	navigation_agent_2d.target_desired_distance = 5.0

# Make sure we have a valid target
func ensure_target_exists() -> void:
	if target_mob == null:
		find_closest_mob()

# Update navigation agent with target position
func set_navigation_target() -> void:
	navigation_agent_2d.target_position = target_mob.global_position

# Check if player is within attack range of the target
func is_within_attack_range() -> bool:
	var distance_to_target = global_position.distance_to(target_mob.global_position)
	return distance_to_target <= attack_range

# Handle behavior when within attack range
func handle_attack_range_behavior() -> void:
	print("CLOSE ENOUGH")
	stop_movement()

# Stop the player's movement
func stop_movement() -> void:
	apply_central_force(Vector2.ZERO - linear_velocity * 10.0)

# Move the player toward the current navigation target
func move_toward_target() -> void:
	if navigation_agent_2d.is_navigation_finished():
		return
		
	var next_position = navigation_agent_2d.get_next_path_position()
	print(next_position)
	var direction = calculate_direction_to(next_position)
	apply_movement_force(direction)

# Calculate direction vector to a target position
func calculate_direction_to(target_position: Vector2) -> Vector2:
	return (target_position - global_position).normalized()

# Apply physics force for movement in a direction
func apply_movement_force(direction: Vector2) -> void:
	var desired_velocity = direction * movement_speed
	apply_central_force((desired_velocity - linear_velocity) * force_multiplier)

# Find the closest mob as a target
func find_closest_mob() -> void:
	target_mob = null
	var main_node = get_parent()
	var closest_distance = target_detection_range
	
	for node in main_node.get_children():
		if is_valid_mob_target(node):
			var distance = global_position.distance_to(node.global_position)
			if distance < closest_distance:
				closest_distance = distance
				target_mob = node
	
	if target_mob:
		print('FOUND MOB')
		navigation_agent_2d.target_position = target_mob.global_position
		print(target_mob.global_position)

# Check if a node is a valid mob target
func is_valid_mob_target(node: Node) -> bool:
	return node.name.contains("Mob") and node != self
