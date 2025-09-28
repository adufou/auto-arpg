extends CharacterBase

@export var mob_attack: Ability
@export var flee_health_threshold: float = 0.3  # Flee when health below this percentage
@export var experience_value: float = 10.0  # Valeur d'XP donnée quand le mob est tué

var target: Node2D = null

func _ready() -> void:
	base_health = 50.0
	
	super._ready()
	add_to_group("mob")
	
	# SUPPRIMÉ : Connexion redondante qui peut causer des cascades
	# if attribute_map:
	#	attribute_map.attribute_changed.connect(_on_attribute_changed)
	# 
	# La classe parent CharacterBase gère déjà les connexions nécessaires
	# via attribute_effect_applied et attribute_effect_removed

func _physics_process(_delta: float) -> void:
	# Protection supplémentaire : arrêter le processing si le mob est mort
	if ability_container and ability_container.has_tag("dead"):
		set_physics_process(false)  # Désactiver définitivement le physics_process
		return
	
	ensure_target_exists()
	
	if target == null:
		return
	
	var distance_to_target = global_position.distance_to(target.global_position)
	var current_stats = get_character_stats()
	var target_stats = get_target_stats()
	
	var behavior = AIBehaviors.decide_behavior(current_stats, target_stats, distance_to_target)
	
	match behavior:
		AIBehaviors.BehaviorState.ATTACKING:
			set_navigation_target()
			handle_attack_range_behavior()
		AIBehaviors.BehaviorState.PURSUING:
			set_navigation_target()
			move_toward_target()
		AIBehaviors.BehaviorState.FLEEING:
			handle_flee_behavior()
		AIBehaviors.BehaviorState.IDLE:
			pass
		AIBehaviors.BehaviorState.DEAD:
			pass

func setup_gameplay_systems() -> void:
	super.setup_gameplay_systems()
	
	if ability_container:
		load_mob_abilities()

func ensure_target_exists() -> void:
	if target == null:
		find_player()

func set_navigation_target() -> void:
	navigation_agent_2d.target_position = target.global_position

func is_within_attack_range() -> bool:
	var distance_to_target = global_position.distance_to(target.global_position)
	return distance_to_target <= attack_range

func find_player() -> void:
	target = null
	var main_node = get_parent()
	
	for node in main_node.get_children():
		if is_valid_player_target(node):
			target = node
			break

func is_valid_player_target(node: Node) -> bool:
	return node.name.contains("Player") and node != self

# Les attributs dérivés sont maintenant gérés automatiquement par CharacterBase
# Cette méthode n'est plus nécessaire car apply_derived_attributes() est appelée lors de l'initialisation

# SUPPRIMÉ : Cette méthode n'est plus connectée
# La gestion de la mort se fait maintenant via _on_attribute_effect_applied
# qui est connecté dans la classe parent CharacterBase

# Méthode séparée pour gérer la mort
func _handle_death() -> void:
	print("[Mob] _handle_death called")
	
	# Vérifier si l'objet est encore valide
	if not is_inside_tree():
		print("[Mob] Already removed from tree, skipping death handling")
		return
	
	# Arrêter le mouvement mais ne pas utiliser freeze pour éviter des bugs potentiels
	linear_velocity = Vector2.ZERO
	angular_velocity = 0
	
	# Désactiver le processing pour éviter les interactions
	set_physics_process(false)
	set_process(false)
	
	# Créer un timer pour la disparition du mob
	var death_timer = Timer.new()
	death_timer.wait_time = 1.5
	death_timer.one_shot = true
	death_timer.timeout.connect(_safe_queue_free)
	add_child(death_timer)
	death_timer.start()

# Méthode sécurisée pour supprimer le mob
func _safe_queue_free() -> void:
	print("[Mob] _safe_queue_free called")
	if is_inside_tree():
		queue_free()
	else:
		print("[Mob] Already removed from tree")

func load_mob_abilities() -> void:
	ability_container.grant(mob_attack)

func _on_attribute_effect_applied(attribute_effect: AttributeEffect, attribute: AttributeSpec) -> void:
	if attribute.attribute_name == "health":
		print("[Mob] Health changed to: " + str(attribute.current_buffed_value))
		update_health_bar()
		
		# Vérifier si le mob est mort (santé <= 0) et s'il n'est pas déjà marqué comme mort
		if attribute.current_buffed_value <= 0 and ability_container and not ability_container.has_tag("dead"):
			print("[Mob] Mob died!")
			# Marquer comme mort pour éviter les appels multiples
			ability_container.add_tag("dead")
			
			# Effet visuel
			modulate = Color(0.2, 0.0, 0.0, 0.7) # Rouge foncé transparent
			
			# Désactiver les collisions
			set_collision_layer(0)
			set_collision_mask(0)
			
			# Différer l'attribution d'XP pour éviter les interférences
			call_deferred("give_experience_to_player")
			
			# Utiliser un CallDeferred pour éviter les problèmes de timing
			call_deferred("_handle_death")
		
		if attribute_effect.minimum_value < 0:
			var damage_value = -attribute_effect.minimum_value
			
			var is_critical = false
			if attribute_effect.has_meta("critical") and attribute_effect.get_meta("critical") == true:
				is_critical = true
				
			var damage_color = Color.WHITE
			if is_critical:
				damage_color = Color(1.0, 1.0, 0.0)  # Yellow for player critical damage
			
			show_floating_damage(damage_value, is_critical, damage_color)
			
		elif attribute_effect.minimum_value > 0:
			pass

func _on_attribute_effect_removed(_attribute_effect: AttributeEffect, _attribute: AttributeSpec) -> void:
	pass

func _on_effect_applied(_effect: GameplayEffect) -> void:
	pass

func get_character_stats() -> Dictionary:
	var health_attr = attribute_map.get_attribute_by_name("health")
	var max_health = 50.0
	if health_attr:
		max_health = health_attr.maximum_value
	
	return {
		"health": get_attribute_value("health"),
		"max_health": max_health,
		"attack": get_attribute_value("attack"),
		"defense": get_attribute_value("defense"),
		"attack_range": attack_range,
		"detection_range": target_detection_range
	}

func get_target_stats() -> Dictionary:
	if not target or not target.has_node("GameplayAttributeMap"):
		return {
			"health": 100,
			"max_health": 100,
			"attack": 10,
			"defense": 5
		}
	
	var target_attr = target.get_node("GameplayAttributeMap")
	var health = get_target_attribute_value(target_attr, "health")
	
	var max_health = 100.0
	var health_attribute = target_attr.get_attribute_by_name("health")
	if health_attribute:
		max_health = health_attribute.maximum_value
	
	return {
		"health": health,
		"max_health": max_health,
		"attack": get_target_attribute_value(target_attr, "attack"),
		"defense": get_target_attribute_value(target_attr, "defense")
	}

func get_target_attribute_value(attr_map: GameplayAttributeMap, attr_name: String) -> float:
	var attr = attr_map.get_attribute_by_name(attr_name)
	if attr:
		return attr.current_buffed_value
	return 0.0

func handle_flee_behavior() -> void:
	if target == null:
		return
	
	var flee_direction = AIBehaviors.calculate_flee_direction(global_position, target.global_position)
	var flee_target_point = global_position + flee_direction * 200.0
	
	navigation_agent_2d.target_position = flee_target_point
	
	if not navigation_agent_2d.is_navigation_finished():
		var next_position = navigation_agent_2d.get_next_path_position()
		var nav_direction = calculate_direction_to(next_position)
		apply_movement_force(nav_direction)
	else:
		apply_movement_force(flee_direction)

func give_experience_to_player() -> void:
	print("[Mob] give_experience_to_player called")
	
	# Vérifier si le mob est encore dans l'arbre
	if not is_inside_tree():
		print("[Mob] Not in tree, skipping XP attribution")
		return
	
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		print("[Mob] No players found")
		return
		
	var player = players[0]
	var base_exp = experience_value
	
	print("[Mob] Giving " + str(base_exp) + " XP to player")
	
	if player.has_method("add_experience"):
		player.add_experience(base_exp)
	
	print("[Mob] XP attribution completed")
