extends Node2D

@export var mob_scene: PackedScene

var world_node: Node2D
var navigation_region: NavigationRegion2D
var player: Player
var world_size: Vector2i
var tile_size: int

var mob_packs: Array[Vector2] = []
var mobs_spawned: Array[Node] = []

const min_mob_packs: int = 3
const max_mob_packs: int = 7
const min_mobs_per_pack: int = 2
const max_mobs_per_pack: int = 5
const min_pack_distance: float = 25.0
const min_player_distance: float = 25.0

func setup(_world_node: Node2D, _navigation_region: NavigationRegion2D, _player: Player) -> void:
	world_node = _world_node
	navigation_region = _navigation_region
	player = _player
	
	tile_size = world_node.get_tile_size()

func spawn_mobs() -> void:
	world_size = world_node.get_world_size()
	
	var num_packs = randi_range(min_mob_packs, max_mob_packs)
	
	var max_global_attempts = 100
	var global_attempts = 0
	var packs_created = 0
	
	while packs_created < num_packs and global_attempts < max_global_attempts:
		if await create_mob_pack():
			packs_created += 1
		else:
			global_attempts += 1

func create_mob_pack() -> bool:
	var mobs_count = randi_range(min_mobs_per_pack, max_mobs_per_pack)
	
	var pack_position = find_valid_pack_position(mobs_count)
	if pack_position == Vector2.ZERO:
		return false
	
	mob_packs.append(pack_position)
	
	await spawn_mobs_in_pack(pack_position, mobs_count)
	
	return true

func find_valid_pack_position(mobs_count: int = 5) -> Vector2:
	var max_attempts = 20
	var attempts = 0
	
	var min_area_needed = mobs_count * 0.5 * PI
	var min_radius_needed = sqrt(min_area_needed / PI)
	
	min_radius_needed = max(min_radius_needed, 5.0)
		
	var border_margin = min_radius_needed * 1.5
	if border_margin > min(world_size.x, world_size.y) * 0.2:
		border_margin = min(world_size.x, world_size.y) * 0.2
	
	print_debug('world size', world_size.x, world_size.y)
	
	while attempts < max_attempts:
		var test_position = Vector2(
			randf_range(border_margin, world_size.x - border_margin),
			randf_range(border_margin, world_size.y - border_margin)
		)
		print_debug('test position = x:' + str(test_position.x) + ', y:' + str(test_position.x))
		if not is_position_navigable(test_position):
			attempts += 1
			continue
		var valid_surrounding = check_surrounding_area(test_position, min_radius_needed)
		if not valid_surrounding:
			attempts += 1
			continue
		
		var too_close_to_pack = false
		for pack_pos in mob_packs:
			if test_position.distance_to(pack_pos) < min_pack_distance + min_radius_needed:
				too_close_to_pack = true
				break
		
		if too_close_to_pack:
			attempts += 1
			continue
		
		var player_map_pos = player.global_position / tile_size
		if test_position.distance_to(player_map_pos) < min_player_distance / tile_size:
			attempts += 1
			continue
		
		return test_position
	
	if mob_packs.size() >= min_mob_packs:
		var reduced_distance = min_pack_distance * 0.5
		for i in range(10):
			var test_position = Vector2(
				randf_range(border_margin, world_size.x - border_margin),
				randf_range(border_margin, world_size.y - border_margin)
			)
			
			if is_position_navigable(test_position) and check_surrounding_area(test_position, min_radius_needed):
				var too_close = false
				for pack_pos in mob_packs:
					if test_position.distance_to(pack_pos) < reduced_distance:
						too_close = true
						break
				
				if not too_close:
					return test_position
	
	return Vector2.ZERO
	
func check_surrounding_area(center_pos: Vector2, radius: float) -> bool:
	var num_check_points = 8
	
	for i in range(num_check_points):
		var angle = TAU * i / num_check_points
		var check_pos = center_pos + Vector2(cos(angle), sin(angle)) * radius
		
		if not is_position_navigable(check_pos):
			return false
			
	return true

func is_position_navigable(pos: Vector2) -> bool:
	var world_rect = Rect2(Vector2.ZERO, world_size)
	if not world_rect.has_point(pos):
		push_warning("Position de navigation hors limites: ", pos, " (taille du monde: ", world_size, ")")
		return false
	
	var nav_map = navigation_region.get_navigation_map()
	if not nav_map:
		push_error("Impossible d'obtenir la carte de navigation!")
		return false
	
	var iteration_id = NavigationServer2D.map_get_iteration_id(nav_map)
	if iteration_id <= 0:
		push_warning("La carte de navigation n'est pas encore initialisée (iteration_id = ", iteration_id, ")")
		return false

	var world_pos = pos * tile_size
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collision_mask = 1
	
	var result = space_state.intersect_point(query)
	if not result.is_empty():
		return false
	
	var closest_point = NavigationServer2D.map_get_closest_point(nav_map, pos)
	var distance = pos.distance_to(closest_point)
	
	return distance < 1.0

func spawn_mobs_in_pack(center_position: Vector2, count: int) -> void:
	var pack_area = 0.5 * PI * count
	var optimal_radius = sqrt(pack_area / PI) * tile_size
	
	var leader_mob = await spawn_single_mob(center_position)
	if not leader_mob:
		return
	
	var golden_angle = PI * (3.0 - sqrt(5.0))
	
	for i in range(1, count):
		var angle = i * golden_angle
		
		var distance_factor = float(i) / float(count - 1) if count > 1 else 0.5
		var distance = optimal_radius * sqrt(distance_factor) * randf_range(0.5, 1.0)
		
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var potential_position = center_position + offset
		
		var max_position_attempts = 15
		var position_attempts = 0
		
		while not is_position_navigable(potential_position) and position_attempts < max_position_attempts:
			angle += randf_range(-0.3, 0.3)
			distance = optimal_radius * sqrt(distance_factor) * randf_range(0.4, 1.1)
			offset = Vector2(cos(angle), sin(angle)) * distance
			potential_position = center_position + offset
			position_attempts += 1
		
		if position_attempts < max_position_attempts:
			await spawn_single_mob(potential_position)
		else:
			push_warning("Impossible de placer un mob dans le pack après ", max_position_attempts, " tentatives")

func spawn_single_mob(spawn_position: Vector2) -> Node:
	if not is_position_navigable(spawn_position):
		push_warning("Tentative de spawn sur une position non navigable! Position: ", spawn_position)
		return null
	
	var mob_instance = mob_scene.instantiate()
	
	world_node.add_child(mob_instance)
		
	mob_instance.global_position = spawn_position
	print_debug('spawn mob at x:' + str(mob_instance.global_position.x) + ', y:' + str(mob_instance.global_position.y))
	
	await get_tree().process_frame
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mob_instance.global_position
	query.collision_mask = 1
	var result = space_state.intersect_point(query)
	
	if not result.is_empty():
		push_warning("Mob placé dans un obstacle - suppression!")
		mob_instance.queue_free()
		return null
	
	mobs_spawned.append(mob_instance)
	return mob_instance
