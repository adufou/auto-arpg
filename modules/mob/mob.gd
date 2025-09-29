extends CharacterBase

@export var mob_attack: Ability

var flee_health_threshold: float = 0.3 # Flee when health below this ratio
var experience_value: float = 100.0  # Valeur d'XP donnée quand le mob est tué

var target: Node2D = null

func _ready() -> void:
	base_health = 50.0

	super._ready()
	add_to_group("mob")

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
	if PlayerManager.player:
		target = PlayerManager.player

func is_valid_player_target(node: Node) -> bool:
	return node.name.contains("Player") and node != self

# Les attributs dérivés sont gérés automatiquement par CharacterBase

# Méthode unique et simple pour gérer la mort
func handle_death() -> void:
	# Marquer comme mort
	ability_container.add_tag("dead")
	
	# Effets visuels et physiques
	modulate = Color(0.2, 0.0, 0.0, 0.7)
	set_collision_layer(0)
	set_collision_mask(0)
	set_physics_process(false)
	
	# Donner l'XP au joueur
	give_experience_to_player()
	
	# Supprimer après délai
	var timer = Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

func load_mob_abilities() -> void:
	ability_container.grant(mob_attack)

func _on_attribute_effect_applied(attribute_effect: AttributeEffect, attribute: AttributeSpec) -> void:
	if attribute.attribute_name == "health":
		update_health_bar()
		
		# Gestion simple de la mort
		if attribute.current_buffed_value <= 0 and not ability_container.has_tag("dead"):
			handle_death()
		
		# Affichage des dégâts
		if attribute_effect.minimum_value < 0:
			var damage_value = -attribute_effect.minimum_value
			var is_critical = attribute_effect.has_meta("critical") and attribute_effect.get_meta("critical")
			var damage_color = Color.YELLOW if is_critical else Color.WHITE
			show_floating_damage(damage_value, is_critical, damage_color)

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

# Méthode simplifiée pour donner l'XP
func give_experience_to_player() -> void:
	if PlayerManager.player and PlayerManager.player.has_method("add_experience"):
		PlayerManager.player.add_experience(experience_value)
