extends Node2D
class_name MobSpawner

@export var mob_scene: PackedScene

@export_group("Spawn Settings")
@export var min_mob_packs: int = 3
@export var max_mob_packs: int = 7
@export var min_mobs_per_pack: int = 2
@export var max_mobs_per_pack: int = 5
@export var pack_radius: float = 10.0
@export var min_pack_distance: float = 25.0

var world_node: Node2D
var navigation_region: NavigationRegion2D
var world_size: Vector2

var mob_packs: Array[Vector2] = []
var mobs_spawned: Array[Node] = []

func _ready() -> void:
	
	# Attendre un frame pour s'assurer que la scène est complètement chargée
	# et que les systèmes de navigation ont eu le temps de traiter les données
	# Note: Dans des scènes complexes avec beaucoup de navigation, on pourrait 
	# ajouter un second await pour donner plus de temps au NavigationServer2D
	await get_tree().process_frame

func spawn_mobs() -> void:
	
	if not world_node or not navigation_region:
		push_error("World node ou navigation region manquant!")
		return
	
	await wait_for_navigation_map_ready()
	
	if world_node.has_method("get_world_size"):
		world_size = world_node.get_world_size()
	else:
		push_error("World node n'a pas de méthode get_world_size!")
		world_size = Vector2(1000, 1000)
	
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
	
	while attempts < max_attempts:
		var test_position = Vector2(
			randf_range(border_margin, world_size.x - border_margin),
			randf_range(border_margin, world_size.y - border_margin)
		)
		
		if not is_position_navigable(test_position):
			attempts += 1
			continue
		var valid_surrounding = check_surrounding_area(test_position, min_radius_needed)
		if not valid_surrounding:
			attempts += 1
			continue
		
		var too_close = false
		for pack_pos in mob_packs:
			if test_position.distance_to(pack_pos) < min_pack_distance + min_radius_needed:
				too_close = true
				break
		
		if too_close:
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
	if not navigation_region:
		push_error("Navigation region est null dans is_position_navigable!")
		return false
		
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

	var tile_size = 16.0
	if world_node and world_node.has_method("get_tile_size"):
		tile_size = world_node.get_tile_size()
	
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
	var optimal_radius = sqrt(pack_area / PI)
	optimal_radius = clamp(optimal_radius, 20.0, pack_radius)
	
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
	if not mob_scene:
		push_error("Mob scene non définie!")
		return null
	
	if not is_position_navigable(spawn_position):
		push_warning("Tentative de spawn sur une position non navigable! Position: ", spawn_position)
		return null
	
	var mob_instance = mob_scene.instantiate()
	if not mob_instance:
		push_error("Échec de l'instanciation du mob!")
		return null
	
	get_tree().current_scene.get_node("MainNode2D").add_child(mob_instance)
	
	var tile_size = 16.0
	if world_node and world_node.has_method("get_tile_size"):
		tile_size = world_node.get_tile_size()
		
	mob_instance.global_position = spawn_position * tile_size
	
	await get_tree().process_frame
	if not is_instance_valid(mob_instance):
		return null
	
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

func setup(world: Node2D, nav_region: NavigationRegion2D) -> void:
	world_node = world
	navigation_region = nav_region

func wait_for_navigation_map_ready() -> void:
	if not navigation_region:
		push_error("Navigation region n'est pas définie!")
		return
		
	var nav_map = navigation_region.get_navigation_map()
	if not nav_map:
		push_error("Impossible d'obtenir la carte de navigation!")
		return
		
	var start_iteration_id = NavigationServer2D.map_get_iteration_id(nav_map)
	
	var is_map_ready = func() -> bool:
		var current_iteration_id = NavigationServer2D.map_get_iteration_id(nav_map)
		return current_iteration_id > start_iteration_id
	
	var map_changed_signal = "map_changed"
	var callable = Callable(self, "_on_navigation_map_changed")
	var connected = false
	
	if NavigationServer2D.has_signal(map_changed_signal):
		if not NavigationServer2D.is_connected(map_changed_signal, callable):
			NavigationServer2D.connect(map_changed_signal, callable)
			connected = true
	
	var frames_waited = 0
	var max_frames = 20
	
	while frames_waited < max_frames:
		NavigationServer2D.map_force_update(nav_map)
		
		await get_tree().process_frame
		frames_waited += 1
		
		if is_map_ready.call():
			break
	
	if frames_waited >= max_frames:
		push_warning("La carte de navigation n'est peut-être pas complètement synchronisée après ", frames_waited, " frames")
	
	if connected:
		if NavigationServer2D.is_connected(map_changed_signal, callable):
			NavigationServer2D.disconnect(map_changed_signal, callable)

func _on_navigation_map_changed(_map_rid: RID) -> void:
	pass
