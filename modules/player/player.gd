extends CharacterBase


@export var player_attack: Ability
@export var mob_detection_interval: float = 0.5  # How often to search for mobs (in seconds)

@export_group("Experience")
@export var base_level: int = 1
@export var base_experience: float = 0.0
@export var experience_to_next_level: float = 100.0
@export var experience_multiplier: float = 1.2
@export var base_characteristic_points: int = 0

var target_mob: Node2D = null
var mobs_in_attack_range: Array[Node2D] = []
var detected_mobs: Array[Node2D] = []
var mob_detection_timer: float = 0.0

func _ready() -> void:
	base_health = 500.0
	base_strength = 25.0
	base_dexterity = 25.0
	base_intelligence = 25.0
	movement_speed = 200.0
	
	super._ready()
	add_to_group("player")
	
	# Les attributs dérivés seront calculés automatiquement par setup_gameplay_systems()

func _physics_process(delta: float) -> void:
	if ability_container and ability_container.has_tag("dead"):
		return
	
	mob_detection_timer -= delta
	
	if mob_detection_timer <= 0:
		find_all_mobs()
		mob_detection_timer = mob_detection_interval
	
	find_mobs_in_attack_range()
	
	if not mobs_in_attack_range.is_empty():
		target_closest_mob_in_range()
		handle_attack_range_behavior()
		return
	
	if target_mob == null or !is_instance_valid(target_mob):
		find_closest_mob()
	
	if target_mob == null:
		return
		
	if !is_valid_mob_target(target_mob):
		find_closest_mob()
		if target_mob == null:
			return
	
	set_navigation_target()
	move_toward_target()

func setup_gameplay_systems() -> void:
	# Laisser la classe parent faire son setup
	super.setup_gameplay_systems()
	
	# Ajouter les attributs spécifiques au joueur
	if attribute_map:
		update_attribute("level", base_level)
		update_attribute("experience", base_experience)
		update_attribute("experience_required", experience_to_next_level)
		update_attribute("characteristic_points", base_characteristic_points)
	
	# Charger les capacités du joueur
	if ability_container:
		load_player_abilities()
	
	# Calculer les attributs dérivés spécifiques au joueur
	apply_derived_attributes()

func find_all_mobs() -> void:
	detected_mobs.clear()
	var mob_nodes = get_tree().get_nodes_in_group("mob")
	for mob in mob_nodes:
		if mob != self and is_valid_mob_target(mob):
			detected_mobs.append(mob)

func find_mobs_in_attack_range() -> void:
	mobs_in_attack_range.clear()
	
	for mob in detected_mobs:
		if global_position.distance_to(mob.global_position) <= attack_range:
			mobs_in_attack_range.append(mob)

func set_navigation_target() -> void:
	if target_mob and is_instance_valid(target_mob):
		navigation_agent_2d.target_position = target_mob.global_position

func is_within_attack_range() -> bool:
	if not target_mob or not is_instance_valid(target_mob):
		return false
		
	var distance_to_target = global_position.distance_to(target_mob.global_position)
	return distance_to_target <= attack_range

func handle_attack_range_behavior() -> void:
	stop_movement()
	
	if ability_container and not ability_container.has_tag("dead"):
		var has_attack_ready = ability_container.has_tag("attack_ready")
		var has_can_attack = ability_container.has_tag("can_attack")
		
		if has_attack_ready and has_can_attack:
			ability_container.activate_many()

func move_toward_target() -> void:
	if navigation_agent_2d.is_navigation_finished():
		return
	
	check_navigation_stuck()
	
	var next_position = navigation_agent_2d.get_next_path_position()
	var direction = calculate_direction_to(next_position)
	apply_movement_force(direction)

var last_position: Vector2 = Vector2.ZERO
var stuck_time: float = 0.0
var recalculation_timeout: float = 0.0
func check_navigation_stuck() -> void:
	if recalculation_timeout > 0:
		recalculation_timeout -= get_process_delta_time()
		return
	
	if last_position.distance_to(global_position) < 1.0:
		stuck_time += get_process_delta_time()
		if stuck_time > 1.0:
			if target_mob and is_instance_valid(target_mob):
				navigation_agent_2d.target_position = target_mob.global_position
				
			var random_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			apply_central_force(random_direction * movement_speed * 2)
			
			stuck_time = 0.0
			recalculation_timeout = 0.5
	else:
		stuck_time = 0.0
	
	last_position = global_position


func find_closest_mob() -> void:
	if detected_mobs.is_empty():
		target_mob = null
		return
	
	var closest_distance = INF
	target_mob = null
	
	for mob in detected_mobs:
		var distance = global_position.distance_to(mob.global_position)
		if distance < closest_distance:
			closest_distance = distance
			target_mob = mob
	
	if target_mob:
		navigation_agent_2d.target_position = target_mob.global_position

func target_closest_mob_in_range() -> void:
	if mobs_in_attack_range.is_empty():
		return
	
	var closest_distance = INF
	var closest_mob = null
	
	for mob in mobs_in_attack_range:
		var distance = global_position.distance_to(mob.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_mob = mob
	
	if closest_mob:
		target_mob = closest_mob

func is_valid_mob_target(mob: Node) -> bool:
	if mob.has_node("AbilityContainer"):
		var mob_ability_container = mob.get_node("AbilityContainer")
		return not mob_ability_container.has_tag("dead")
	return false

# Méthode override pour utiliser les attributs dérivés spécifiques au joueur
func apply_derived_attributes() -> void:
	if not attribute_map:
		return
	
	# Utiliser le calculateur pour les valeurs spécifiques au joueur
	var derived_values = DerivedStatsCalculator.calculate_player_derived_stats(attribute_map, movement_speed)
	
	# Appliquer via le calculateur
	DerivedStatsCalculator.apply_derived_stats(attribute_map, derived_values, "PlayerDerivedStats")

func add_experience(exp_amount: float) -> void:
	if not attribute_map:
		return
	
	var current_exp = get_attribute_value("experience")
	var new_exp = current_exp + exp_amount
	
	# Afficher l'XP gagnée
	var exp_color = Color(0.5, 0.5, 1.0)  # Couleur bleu clair pour l'XP
	show_floating_damage(exp_amount, false, exp_color)
	
	update_attribute("experience", new_exp)
	check_level_up()

func check_level_up() -> void:
	var max_levels = 10  # Protection contre boucle infinie
	
	for i in range(max_levels):
		var current_exp = get_attribute_value("experience")
		var exp_required = get_attribute_value("experience_required")
		var current_level = get_attribute_value("level")
		
		if current_exp < exp_required:
			break  # Plus de level up possible
		
		# Level up !
		current_level += 1
		current_exp -= exp_required
		var new_exp_required = exp_required * experience_multiplier
		
		update_attribute("level", current_level)
		update_attribute("experience", current_exp)
		update_attribute("experience_required", new_exp_required)
		
		apply_level_up_bonuses()
		show_floating_damage(current_level, true, Color(1.0, 0.8, 0.0))

func apply_level_up_bonuses() -> void:
	# Grant characteristic points
	var current_points = get_attribute_value("characteristic_points")
	update_attribute("characteristic_points", current_points + 5)

	
	# Augmenter la santé et mana maximales
	var health_attr = attribute_map.get_attribute_by_name("health")
	var mana_attr = attribute_map.get_attribute_by_name("mana")
	
	if health_attr:
		health_attr.maximum_value += 10
		health_attr.current_value = health_attr.maximum_value
		
	if mana_attr:
		mana_attr.maximum_value += 5
		mana_attr.current_value = mana_attr.maximum_value
	
	# Recalculer les attributs dérivés
	apply_derived_attributes()
	update_health_bar()


func spend_characteristic_point(stat_name: String) -> void:
	if not attribute_map:
		return

	var points = get_attribute_value("characteristic_points")
	if points > 0:
		update_attribute("characteristic_points", points - 1)
		
		var current_stat_value = get_attribute_value(stat_name)
		update_attribute(stat_name, current_stat_value + 1)
		
		recalculate_derived_attributes()

func load_player_abilities() -> void:
	ability_container.grant(player_attack)

func _on_attribute_effect_applied(attribute_effect: AttributeEffect, attribute: AttributeSpec) -> void:
	if attribute.attribute_name == "health":
		update_health_bar()
		
		if attribute_effect.minimum_value < 0:
			var damage_value = -attribute_effect.minimum_value
			show_floating_damage(damage_value, false, Color(1.0, 0.0, 0.0))
			
		elif attribute_effect.minimum_value > 0:
			pass
