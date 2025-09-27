extends Node2D
class_name MobSpawner

# Packed scene de mob à instancier
@export var mob_scene: PackedScene

# Paramètres de spawn
@export_group("Spawn Settings")
@export var min_mob_packs: int = 3
@export var max_mob_packs: int = 7
@export var min_mobs_per_pack: int = 2
@export var max_mobs_per_pack: int = 5
@export var pack_radius: float = 10.0  # Rayon maximal pour placer les mobs autour du centre du pack
@export var min_pack_distance: float = 25.0  # Distance minimale entre les centres de packs

# Référence au nœud World et navigation
var world_node: Node2D
var navigation_region: NavigationRegion2D
var world_size: Vector2

# Mémoriser les packs créés
var mob_packs: Array[Vector2] = []
var mobs_spawned: Array[Node] = []

func _ready() -> void:
	# Cette méthode sera appelée quand le spawner sera ajouté à la scène
	
	# Attendre un frame pour s'assurer que la scène est complètement chargée
	# et que les systèmes de navigation ont eu le temps de traiter les données
	# Note: Dans des scènes complexes avec beaucoup de navigation, on pourrait 
	# ajouter un second await pour donner plus de temps au NavigationServer2D
	await get_tree().process_frame

# Méthode principale pour spawner les mobs sur la carte
func spawn_mobs() -> void:
	print_debug("Démarrage du spawning de mobs...")
	
	# S'assurer que le monde est référencé
	if not world_node or not navigation_region:
		push_error("World node ou navigation region manquant!")
		return
	
	# Attendre que la carte de navigation soit prête
	await wait_for_navigation_map_ready()
	
	# Récupérer la taille du monde
	if world_node.has_method("get_world_size"):
		world_size = world_node.get_world_size()
	else:
		# Fallback si la méthode n'existe pas
		world_size = Vector2(1000, 1000)
	
	print_debug("Taille du monde: ", world_size)
	
	# Déterminer le nombre de packs à créer
	var num_packs = randi_range(min_mob_packs, max_mob_packs)
	print_debug("Nombre de packs à créer: ", num_packs)
	
	# Nombre maximum d'essais globaux
	var max_global_attempts = 100
	var global_attempts = 0
	var packs_created = 0
	
	# Essayer de créer le nombre désiré de packs
	while packs_created < num_packs and global_attempts < max_global_attempts:
		if create_mob_pack():
			packs_created += 1
		else:
			# Si on a échoué à créer un pack, on compte cet essai
			global_attempts += 1
			
			# Afficher un message tous les 10 essais
			if global_attempts % 10 == 0:
				print_debug("Essais de création de packs: ", global_attempts, "/", max_global_attempts)
	
	print_debug("Packs créés: ", packs_created, "/", num_packs, " après ", global_attempts, " tentatives globales")
	print_debug("Nombre total de mobs spawned: ", mobs_spawned.size())

# Crée un pack de mobs à une position valide
# Retourne true si le pack a été créé avec succès, false sinon
func create_mob_pack() -> bool:
	# 1. Déterminer le nombre de mobs dans ce pack
	var mobs_count = randi_range(min_mobs_per_pack, max_mobs_per_pack)
	
	# 2. Trouver un emplacement valide pour le pack en fonction du nombre de mobs
	var pack_position = find_valid_pack_position(mobs_count)
	if pack_position == Vector2.ZERO:
		# On ne fait pas de print_debug ici pour éviter de spammer la console
		# car cet échec est attendu et géré par la fonction appelante
		return false
	
	print_debug("Création d'un pack de ", mobs_count, " mobs à la position ", pack_position)
	
	# 3. Enregistrer la position du pack
	mob_packs.append(pack_position)
	
	# 4. Spawner les mobs autour de cette position
	spawn_mobs_in_pack(pack_position, mobs_count)
	
	return true

# Trouve une position valide pour placer un pack avec suffisamment d'espace pour tous les mobs
func find_valid_pack_position(mobs_count: int = 5) -> Vector2:
	# Debug: Afficher quand on essaie de trouver une position
	print_debug("Recherche d'une position pour ", mobs_count, " mobs")
	
	# On réduit le nombre d'essais par pack, car on a maintenant une logique globale
	var max_attempts = 20  # Nombre maximum de tentatives pour trouver une position valide
	var attempts = 0
	
	# Calculer la taille du cercle nécessaire pour contenir les mobs
	# On considère que chaque mob occupe une aire de 1 unité² et on multiplie par 1/2*Pi pour avoir un peu de marge
	var min_area_needed = mobs_count * 0.5 * PI
	# Rayon minimum nécessaire = √(aire/π)
	var min_radius_needed = sqrt(min_area_needed / PI)
	
	# Assurons-nous d'avoir au moins un rayon minimum pour les petits packs
	# avec une valeur plus raisonnable pour les petites cartes
	min_radius_needed = max(min_radius_needed, 5.0)
	
	# On affiche ce message seulement pour le premier essai de la série
	if attempts == 0:
		print_debug("Recherche d'un emplacement avec un rayon minimum de: ", min_radius_needed)
	
	# Définir une marge pour éviter les bords de la carte
	var border_margin = min_radius_needed * 1.5
	# Si la marge est trop grande par rapport à la taille de la carte, la réduire
	if border_margin > min(world_size.x, world_size.y) * 0.2:
		border_margin = min(world_size.x, world_size.y) * 0.2
	
	while attempts < max_attempts:
		# Générer une position vraiment aléatoire dans le monde, en évitant les bords
		var test_position = Vector2(
			randf_range(border_margin, world_size.x - border_margin),
			randf_range(border_margin, world_size.y - border_margin)
		)
		
		# Vérifier si la position centrale est navigable
		if not is_position_navigable(test_position):
			attempts += 1
			continue
		
		# Vérifier si les positions environnantes sont également navigables
		var valid_surrounding = check_surrounding_area(test_position, min_radius_needed)
		if not valid_surrounding:
			attempts += 1
			continue
		
		# Si aucun pack n'a encore été placé, on ne vérifie pas la distance
		if mob_packs.size() == 0:
			print_debug("Premier pack placé à: ", test_position)
			return test_position
		
		# Vérifier si la position est suffisamment éloignée des autres packs
		var too_close = false
		for pack_pos in mob_packs:
			if test_position.distance_to(pack_pos) < min_pack_distance + min_radius_needed:
				too_close = true
				break
		
		if too_close:
			attempts += 1
			continue
		
		# Si on arrive ici, la position est valide
		print_debug("Position valide trouvée à: ", test_position, " avec rayon: ", min_radius_needed)
		return test_position
	
	# Si on a déjà beaucoup de packs et qu'on n'arrive plus à placer, on peut assouplir la contrainte de distance
	if mob_packs.size() >= min_mob_packs:
		# On essaie une dernière fois avec une distance réduite
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
					print_debug("Position trouvée avec distance réduite: ", test_position)
					return test_position
	
	# Si on n'a toujours pas trouvé de position valide
	return Vector2.ZERO
	
# Vérifie si la zone entourant un point est navigable
func check_surrounding_area(center_pos: Vector2, radius: float) -> bool:
	# Nombre de points à vérifier autour du cercle
	var num_check_points = 8
	
	# Vérifier des points sur le cercle de rayon spécifié
	for i in range(num_check_points):
		var angle = TAU * i / num_check_points
		var check_pos = center_pos + Vector2(cos(angle), sin(angle)) * radius
		
		if not is_position_navigable(check_pos):
			return false
			
	# Si tous les points sont navigables, la zone est valide
	return true

# Vérifie si une position est navigable en utilisant NavigationServer2D
func is_position_navigable(pos: Vector2) -> bool:
	if not navigation_region:
		# Debug: Afficher si jamais navigation_region est null
		print_debug("Navigation region est null!")
		return false
		
	# Vérifier d'abord si le point est dans les limites du monde
	var world_rect = Rect2(Vector2.ZERO, world_size)
	if not world_rect.has_point(pos):
		# Debug: Afficher les points hors limites
		print_debug("Point hors limites: ", pos, ", monde: ", world_size)
		return false
	
	# Obtenir la carte de navigation
	var nav_map = navigation_region.get_navigation_map()
	
	# Utiliser NavigationServer2D pour trouver le point le plus proche sur la navigation mesh
	var closest_point = NavigationServer2D.map_get_closest_point(nav_map, pos)
	
	# Si le point le plus proche est suffisamment proche de notre point original,
	# c'est probablement un point navigable
	var distance = pos.distance_to(closest_point)
	
	# Debug: Toujours afficher la distance
	print_debug("Point (", pos, ") -> Distance au point navigable: ", distance, ", Valide: ", distance < 5.0)
		
	return distance < 5.0  # Tolérance de 5 pixels

# Spawne un groupe de mobs autour d'une position centrale dans un cercle
func spawn_mobs_in_pack(center_position: Vector2, count: int) -> void:
	# Calculer le rayon optimal pour ce groupe de mobs
	# Basé sur la formule: 0.5*π*nombre_de_mobs
	var pack_area = 0.5 * PI * count
	var optimal_radius = sqrt(pack_area / PI)
	# Limiter le rayon à des valeurs raisonnables
	optimal_radius = clamp(optimal_radius, 20.0, pack_radius)
	
	# Spawner le premier mob au centre (leader du pack)
	var leader_mob = spawn_single_mob(center_position)
	if not leader_mob:
		return
	
	print_debug("Spawning pack with ", count, " mobs, rayon: ", optimal_radius)
	
	# Spawner les mobs restants autour du centre, en utilisant une répartition plus contrôlée
	# Pour une meilleure répartition, nous utilisons le nombre d'or (golden angle)
	# qui donne une distribution équilibrée
	var golden_angle = PI * (3.0 - sqrt(5.0))  # Environ 2.4 radians
	
	for i in range(1, count):
		# Distribution plus uniforme des points basée sur l'angle d'or
		var angle = i * golden_angle
		
		# La distance du centre varie en fonction de la position dans la séquence
		# Les premiers mobs sont plus près du centre, les derniers plus éloignés
		var distance_factor = float(i) / float(count - 1) if count > 1 else 0.5
		var distance = optimal_radius * sqrt(distance_factor) * randf_range(0.5, 1.0)
		
		# Calculer la position potentielle
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var potential_position = center_position + offset
		
		# S'assurer que la position est navigable
		var max_position_attempts = 15  # Augmenter le nombre de tentatives
		var position_attempts = 0
		
		while not is_position_navigable(potential_position) and position_attempts < max_position_attempts:
			# Réessayer avec une distance et un angle légèrement modifiés
			angle += randf_range(-0.3, 0.3)  # Petite variation d'angle
			distance = optimal_radius * sqrt(distance_factor) * randf_range(0.4, 1.1)
			offset = Vector2(cos(angle), sin(angle)) * distance
			potential_position = center_position + offset
			position_attempts += 1
		
		if position_attempts < max_position_attempts:
			spawn_single_mob(potential_position)
		else:
			print_debug("Impossible de placer un mob dans le pack")

# Spawne un seul mob à la position spécifiée
func spawn_single_mob(spawn_position: Vector2) -> Node:
	if not mob_scene:
		push_error("Mob scene non définie!")
		return null
	
	# Instancier le mob
	var mob_instance = mob_scene.instantiate()
	if not mob_instance:
		push_error("Échec de l'instanciation du mob!")
		return null
	
	# Ajouter le mob à l'arbre de scène
	get_tree().current_scene.get_node("MainNode2D").add_child(mob_instance)
	
	# Récupérer la taille des tuiles du monde
	var tile_size = 16.0  # Valeur par défaut
	if world_node and world_node.has_method("get_tile_size"):
		tile_size = world_node.get_tile_size()
		
	# Positionner le mob en multipliant par la taille des tuiles
	mob_instance.global_position = spawn_position * tile_size
	print_debug("Position de mob réelle: ", spawn_position, " -> ", mob_instance.global_position)
	
	# Ajouter à notre liste de mobs
	mobs_spawned.append(mob_instance)
	
	return mob_instance

# Configure le spawner avec les références nécessaires
func setup(world: Node2D, nav_region: NavigationRegion2D) -> void:
	world_node = world
	navigation_region = nav_region

# Attends que la carte de navigation soit prête avant de l'utiliser
func wait_for_navigation_map_ready() -> void:
	print_debug("Attente de la synchronisation de la carte de navigation...")
	
	# Nous allons attendre plusieurs frames pour s'assurer que 
	# la carte de navigation est entièrement synchronisée
	
	# On se connecte au signal map_changed qui est émis quand la navigation map est mise à jour
	var connection_done = false
	var signal_name = "map_changed"
	
	# Vérifions d'abord si le NavigationServer2D a ce signal
	if NavigationServer2D.has_signal(signal_name):
		var callable = Callable(self, "_on_navigation_map_changed")
		if not NavigationServer2D.is_connected(signal_name, callable):
			NavigationServer2D.connect(signal_name, callable)
			connection_done = true
	
	# En attendant, donnons du temps à la navigation map pour se synchroniser
	# Attendre plusieurs frames est une approche simple mais efficace
	for i in range(5):
		await get_tree().process_frame
	
	# Déconnecter le signal si nous l'avons connecté
	if connection_done:
		var callable = Callable(self, "_on_navigation_map_changed")
		if NavigationServer2D.is_connected(signal_name, callable):
			NavigationServer2D.disconnect(signal_name, callable)
			
	print_debug("Carte de navigation synchronisée!")

# Fonction appelée quand la carte de navigation change
# Le signal map_changed transmet le RID de la carte qui a changé
func _on_navigation_map_changed(map_rid: RID) -> void:
	print_debug("Navigation map mise à jour: ", map_rid)
