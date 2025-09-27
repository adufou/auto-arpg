extends Node2D

@export var navigation_region_2d: NavigationRegion2D
@export var gaea_generator: GaeaGenerator	

func _ready() -> void:
	# Attendre que la scène soit complètement chargée et que Gaea termine la génération
	await get_tree().process_frame
	
	# Récupérer la taille du monde depuis Gaea
	var world_size = gaea_generator.world_size
	
	# Obtenir la référence à la région de navigation
	var nav_region = navigation_region_2d
	
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
	
	print_debug("Maillage de navigation généré avec succès !")
	print_debug("Taille de la map : ", world_size)
	
	# Afficher les positions des entités pour débogage
	var player = $"../PlayerRigidBody2D"
	var mob = $"../MobRigidBody2D"
	if player and mob:
		print_debug("Position du joueur: ", player.global_position)
		print_debug("Position du mob: ", mob.global_position)
		print_debug("Distance: ", player.global_position.distance_to(mob.global_position))
