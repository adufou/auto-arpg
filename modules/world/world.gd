extends Node2D

@export var navigation_region_2d: NavigationRegion2D
@export var gaea_generator: GaeaGenerator
@export var mob_spawner_scene: PackedScene

func _ready() -> void:
	# Attendre que la scène soit complètement chargée et que Gaea termine la génération
	await get_tree().process_frame
	
	# Récupérer la taille du monde depuis Gaea
	var world_size = gaea_generator.world_size
	
	# Obtenir la référence à la région de navigation
	var nav_region = navigation_region_2d
	if not nav_region:
		push_error("Aucune région de navigation trouvée!")
		return
	
	print_debug("Initialisation du système de navigation...")
	
	# Créer un nouveau polygon de navigation
	var nav_poly = NavigationPolygon.new()
	
	# Créer un contour basé sur la taille réelle de la map
	var outline = PackedVector2Array([
		Vector2(0, 0),
		Vector2(world_size.x, 0),
		Vector2(world_size.x, world_size.y),
		Vector2(0, world_size.y)
	])
	
	# Ajouter le contour au polygon de navigation
	nav_poly.add_outline(outline)
	
	# Générer les polygones à partir des contours
	nav_poly.make_polygons_from_outlines()
	
	# Appliquer le polygon à la région de navigation
	nav_region.navigation_polygon = nav_poly
	
	# S'assurer que la navigation map est mise à jour
	var nav_map = nav_region.get_navigation_map()
	if nav_map:
		# Forcer une mise à jour immédiate de la carte de navigation
		NavigationServer2D.map_force_update(nav_map)
	
	# Attendre quelques frames supplémentaires pour s'assurer que la carte de navigation est prête
	for i in range(3):
		await get_tree().process_frame
	
	print_debug("Maillage de navigation généré avec succès !")
	print_debug("Taille de la map : ", world_size)
	
	# Spawner les mobs sur la carte
	spawn_mobs()
	
	# Afficher les positions des entités pour débogage
	var player = $"../Player"
	if player:
		print_debug("Position du joueur: ", player.global_position)

# Retourne la taille du monde en unités de monde
func get_world_size() -> Vector2:
	# Conversion de Vector3i à Vector2
	var size_3d = gaea_generator.world_size
	return Vector2(size_3d.x, size_3d.y)

# Retourne la taille d'une tuile en pixels
func get_tile_size() -> float:
	# Récupérer la taille des tuiles depuis le TileMapLayer
	var tile_map_layer = find_child("TileMapLayer")
	if tile_map_layer and tile_map_layer.tile_set:
		return tile_map_layer.tile_set.tile_size.x  # Généralement carré, donc x == y
	
	push_error("Taille des tuiles non trouvée!")
	return 16.0

# Fonction pour spawner les mobs sur la carte
func spawn_mobs() -> void:
	# Vérifier que la région de navigation est prête
	if not navigation_region_2d:
		push_error("Aucune région de navigation disponible pour le spawning des mobs!")
		return
	
	var nav_map = navigation_region_2d.get_navigation_map()
	if not nav_map:
		push_error("La carte de navigation n'est pas disponible pour le spawning des mobs!")
		return
	
	# Vérifier l'ID d'itération de la carte
	var iteration_id = NavigationServer2D.map_get_iteration_id(nav_map)
	print_debug("Préparation au spawning des mobs avec iteration_id: ", iteration_id)
	
	# Attendre que la carte de navigation est prête
	await get_tree().create_timer(0.1).timeout
	
	# Instancier le mob spawner
	if not mob_spawner_scene:
		push_error("Mob spawner scene n'est pas défini!")
		return
	
	var mob_spawner = mob_spawner_scene.instantiate()
	if not mob_spawner:
		push_error("\u00c9chec de l'instanciation du mob spawner!")
		return
	
	# Ajouter le spawner à l'arbre de scène
	add_child(mob_spawner)
	
	# Configurer le spawner
	mob_spawner.setup(self, navigation_region_2d)
	
	# Lancer le spawning des mobs
	mob_spawner.spawn_mobs()
