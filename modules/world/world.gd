extends Node2D

@export var navigation_region_2d: NavigationRegion2D
@export var gaea_generator: GaeaGenerator
@export var mob_spawner_scene: PackedScene

func _ready() -> void:
	# Attendre que la scène soit complètement chargée et que Gaea termine la génération
	await get_tree().process_frame
	
	# Récupérer la taille du monde depuis Gaea
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
		push_error("\u00c9chec de l'instanciation du mob spawner!")
		return
	
	add_child(mob_spawner)
	
	mob_spawner.setup(self, navigation_region_2d)
	
	mob_spawner.spawn_mobs()
