extends Node2D

@export var player_scene: PackedScene
@export var player_margin: float = 3.0
@export var mob_player_min_distance: float = 16.0

var navigation_map: RID

func _ready() -> void:
	%GaeaGenerator.generate()
	await get_tree().process_frame

	var world_size = %GaeaGenerator.world_size
	var nav_poly = NavigationPolygon.new()
	
	var outline = PackedVector2Array([
		Vector2(0, 0),
		Vector2(world_size.x, 0),
		Vector2(world_size.x, world_size.y),
		Vector2(0, world_size.y)
	])
	
	nav_poly.add_outline(outline)
	
	nav_poly.make_polygons_from_outlines()
	
	%NavigationRegion2D.navigation_polygon = nav_poly
	
	navigation_map = %NavigationRegion2D.get_navigation_map()
	NavigationServer2D.map_force_update(navigation_map)
	
	create_map_boundaries(Vector2(world_size.x, world_size.y))
	
	# Attendre que la carte de navigation soit prête
	await wait_for_navigation_map_ready()
	
	place_player_on_edge()
	
	%MobSpawner.setup(self, %NavigationRegion2D, PlayerManager.player)
	spawn_mobs()

func get_world_size() -> Vector2:
	var size_3d = %GaeaGenerator.world_size * get_tile_size()
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
	
func place_player_on_edge():
	print_debug('Place player on edge -- TODO (spawning in the middle for now)')
	var player: Player = player_scene.instantiate()
	add_child(player)
	
	PlayerManager.player = player
	PlayerManager.player.position = Vector2(get_world_size().x/2, get_world_size().y/2)

func spawn_mobs():
	%MobSpawner.spawn_mobs()

func wait_for_navigation_map_ready() -> void:
	var start_iteration_id = NavigationServer2D.map_get_iteration_id(navigation_map)
	
	# Attendre quelques frames pour que la navigation se mette à jour
	var frames_waited = 0
	var max_frames = 10
	
	while frames_waited < max_frames:
		NavigationServer2D.map_force_update(navigation_map)
		await get_tree().process_frame
		frames_waited += 1
		
		var current_iteration_id = NavigationServer2D.map_get_iteration_id(navigation_map)
		if current_iteration_id > start_iteration_id:
			break
			
	if frames_waited >= max_frames:
		push_warning("La carte de navigation n'est peut-être pas complètement synchronisée après", frames_waited, "frames")
