extends Node2D

@export var navigation_region_2d: NavigationRegion2D
@export var gaea_generator: GaeaGenerator
@export var mob_spawner_scene: PackedScene
@export var player_margin: float = 3.0
@export var mob_player_min_distance: float = 16.0

func _ready() -> void:
	gaea_generator.generate()
	await get_tree().process_frame

	var world_size = gaea_generator.world_size
	
	var nav_region = navigation_region_2d
	if not nav_region:
		push_error("Aucune région de navigation trouvée!")
		return
		
	var nav_poly = NavigationPolygon.new()
	
	var outline = PackedVector2Array([
		Vector2(0, 0),
		Vector2(world_size.x, 0),
		Vector2(world_size.x, world_size.y),
		Vector2(0, world_size.y)
	])
	
	nav_poly.add_outline(outline)
	
	nav_poly.make_polygons_from_outlines()
	
	nav_region.navigation_polygon = nav_poly
	
	var nav_map = nav_region.get_navigation_map()
	if nav_map:
		NavigationServer2D.map_force_update(nav_map)
	
	create_map_boundaries(Vector2(world_size.x, world_size.y))
	
	# Attendre que la carte de navigation soit prête
	await wait_for_navigation_map_ready()
	
	place_player_on_edge()
	
	for i in range(3):
		await get_tree().process_frame
	
	spawn_mobs()

func get_world_size() -> Vector2:
	var size_3d = gaea_generator.world_size
	return Vector2(size_3d.x, size_3d.y)

func get_tile_size() -> float:
	var tile_map_layer = find_child("TileMapLayer")
	if tile_map_layer and tile_map_layer.tile_set:
		return tile_map_layer.tile_set.tile_size.x
	
	push_error("Taille des tuiles non trouvée!")
	return 16.0

func create_map_boundaries(world_size: Vector2) -> void:
	var border_thickness: float = 32.0
	
	create_boundary(Vector2(world_size.x/2, -border_thickness/2), Vector2(world_size.x, border_thickness))
	create_boundary(Vector2(world_size.x/2, world_size.y + border_thickness/2), Vector2(world_size.x, border_thickness))
	create_boundary(Vector2(-border_thickness/2, world_size.y/2), Vector2(border_thickness, world_size.y))
	create_boundary(Vector2(world_size.x + border_thickness/2, world_size.y/2), Vector2(border_thickness, world_size.y))

func create_boundary(pos: Vector2, size: Vector2) -> void:
	var static_body = StaticBody2D.new()
	static_body.position = pos
	
	var collision_shape = CollisionShape2D.new()
	var rectangle_shape = RectangleShape2D.new()
	rectangle_shape.size = size
	collision_shape.shape = rectangle_shape
	
	static_body.add_child(collision_shape)
	add_child(static_body)
func place_player_on_edge() -> void:
	var world_size = get_world_size()
	var player = get_tree().get_first_node_in_group("player")
	
	if not player:
		push_error("Aucun joueur trouvé dans le groupe 'player'!")
		return
	
	if not player.is_in_group("player"):
		player.add_to_group("player")
	
	var edge = randi() % 4
	var tile_size = get_tile_size()
	var margin = player_margin * tile_size
	var player_pos = Vector2.ZERO
	
	match edge:
		0:
			player_pos = Vector2(randf_range(margin, world_size.x * tile_size - margin), margin)
		1:
			player_pos = Vector2(world_size.x * tile_size - margin, randf_range(margin, world_size.y * tile_size - margin))
		2:
			player_pos = Vector2(randf_range(margin, world_size.x * tile_size - margin), world_size.y * tile_size - margin)
		3:
			player_pos = Vector2(margin, randf_range(margin, world_size.y * tile_size - margin))
	
	var map_position = player_pos / tile_size
	if is_position_navigable(map_position):
		player.global_position = player_pos
	else:
		var found_position = false
		var attempts = 0
		var max_attempts = 20
		var search_radius = 3.0
		
		while not found_position and attempts < max_attempts:
			var random_offset = Vector2(randf_range(-search_radius, search_radius), randf_range(-search_radius, search_radius)) * tile_size
			var test_position = player_pos + random_offset
			var test_map_position = test_position / tile_size
			
			if is_position_navigable(test_map_position) and test_position.x >= margin and test_position.x <= world_size.x * tile_size - margin \
			   and test_position.y >= margin and test_position.y <= world_size.y * tile_size - margin:
				player.global_position = test_position
			
			attempts += 1
		
		if not found_position:
			player.global_position = Vector2(world_size.x * tile_size / 2, world_size.y * tile_size / 2)
			push_warning("Impossible de placer le joueur sur un bord. Placement au centre.")
			
func is_position_navigable(pos: Vector2) -> bool:
	if not navigation_region_2d:
		return false
	
	var world_rect = Rect2(Vector2.ZERO, get_world_size())
	if not world_rect.has_point(pos):
		return false
	
	var nav_map = navigation_region_2d.get_navigation_map()
	if not nav_map:
		return false
	
	var closest_point = NavigationServer2D.map_get_closest_point(nav_map, pos)
	var distance = pos.distance_to(closest_point)
	
	return distance < 1.0

func wait_for_navigation_map_ready() -> void:
	if not navigation_region_2d:
		push_error("Navigation region n'est pas définie!")
		return
		
	var nav_map = navigation_region_2d.get_navigation_map()
	if not nav_map:
		push_error("Impossible d'obtenir la carte de navigation!")
		return
		
	var start_iteration_id = NavigationServer2D.map_get_iteration_id(nav_map)
	
	# Attendre quelques frames pour que la navigation se mette à jour
	var frames_waited = 0
	var max_frames = 10
	
	while frames_waited < max_frames:
		NavigationServer2D.map_force_update(nav_map)
		await get_tree().process_frame
		frames_waited += 1
		
		var current_iteration_id = NavigationServer2D.map_get_iteration_id(nav_map)
		if current_iteration_id > start_iteration_id:
			break
			
	if frames_waited >= max_frames:
		push_warning("La carte de navigation n'est peut-être pas complètement synchronisée après", frames_waited, "frames")

func spawn_mobs() -> void:
	if not navigation_region_2d:
		push_error("Aucune région de navigation disponible pour le spawning des mobs!")
		return
	
	var nav_map = navigation_region_2d.get_navigation_map()
	if not nav_map:
		push_error("La carte de navigation n'est pas disponible pour le spawning des mobs!")
		return
	
	await get_tree().create_timer(0.1).timeout
	
	if not mob_spawner_scene:
		push_error("Mob spawner scene n'est pas défini!")
		return
	
	var mob_spawner = mob_spawner_scene.instantiate()
	if not mob_spawner:
		push_error("Échec de l'instanciation du mob spawner!")
		return
	
	add_child(mob_spawner)
	
	mob_spawner.setup(self, navigation_region_2d)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		mob_spawner.set_player_data(player, mob_player_min_distance * get_tile_size())
	
	mob_spawner.spawn_mobs()
