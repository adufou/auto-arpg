extends CharacterBase

@export var player_attack: Ability
@export var mob_detection_interval: float = 0.5  # How often to search for mobs (in seconds)

@export_group("Experience")
@export var base_level: int = 1
@export var base_experience: float = 0.0
@export var experience_to_next_level: float = 100.0
@export var experience_multiplier: float = 1.2

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
	
	update_derived_stats()

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

# Flag to prevent recursive updates during initialization
var _initialization_in_progress: bool = false


func setup_gameplay_systems() -> void:
	# Prevent recursive calls during initialization
	if _initialization_in_progress:
		return
	
	_initialization_in_progress = true
	
	# First let the parent do its setup
	super.setup_gameplay_systems()
	
	# Then add player-specific attributes
	if attribute_map:
		print("[Player] Initializing level attributes")
		print("[Player] Setting level to: " + str(base_level))
		update_attribute("level", base_level)
		print("[Player] Setting experience to: " + str(base_experience))
		update_attribute("experience", base_experience)
		print("[Player] Setting experience_required to: " + str(experience_to_next_level))
		update_attribute("experience_required", experience_to_next_level)
		
		# Vérifier que les valeurs ont été correctement définies
		print("[Player] === DIAGNOSTIC INITIALISATION ===")
		var level_attr = attribute_map.get_attribute_by_name("level")
		var exp_attr = attribute_map.get_attribute_by_name("experience")
		var exp_req_attr = attribute_map.get_attribute_by_name("experience_required")
		
		if level_attr:
			print("[Player] Level attribute exists after init - current: " + str(level_attr.current_value) + ", max: " + str(level_attr.maximum_value))
		else:
			print("[Player] Level attribute NOT FOUND after init!")
		
		if exp_attr:
			print("[Player] Experience attribute exists after init - current: " + str(exp_attr.current_value) + ", max: " + str(exp_attr.maximum_value))
		else:
			print("[Player] Experience attribute NOT FOUND after init!")
		
		if exp_req_attr:
			print("[Player] Experience_required attribute exists after init - current: " + str(exp_req_attr.current_value) + ", max: " + str(exp_req_attr.maximum_value))
		else:
			print("[Player] Experience_required attribute NOT FOUND after init!")
		
		print("[Player] Verification via get_attribute_value() - Level: " + str(get_attribute_value("level")))
		print("[Player] Verification via get_attribute_value() - Experience: " + str(get_attribute_value("experience")))
		print("[Player] Verification via get_attribute_value() - Experience required: " + str(get_attribute_value("experience_required")))
		print("[Player] === FIN DIAGNOSTIC INITIALISATION ===")
	
	# Finally, load player abilities
	if ability_container:
		load_player_abilities()
	
	_initialization_in_progress = false

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

# Remplace la méthode précédente pour être compatible avec le nouveau système
# basé sur GameplayEffect
func update_derived_stats() -> void:
	# Déléguer à la méthode apply_derived_attributes spécifique au joueur
	apply_player_derived_attributes()

# Méthode qui crée et applique des GameplayEffect spécifiques au joueur
func apply_player_derived_attributes() -> void:
	print("[Player] Applying player-specific derived attributes")
	
	if not attribute_map:
		return
	
	# Créer un effet pour les dérivés de Force (attaque, défense) spécifiques au joueur
	var strength_effect = GameplayEffect.new()
	strength_effect.name = "PlayerStrengthDerivedEffect"
	
	# Valeur actuelle de Force
	var str_value = get_attribute_value("strength")
	
	# Effet sur l'attaque (réduire pour équilibrer le jeu)
	var attack_effect = AttributeEffect.new()
	attack_effect.attribute_name = "attack"
	attack_effect.minimum_value = str_value * 0.5 # Multiplicateur réduit pour éviter de tuer les mobs en un coup
	attack_effect.applies_as = 0 # Value modification
	attack_effect.life_time = AttributeEffect.LIFETIME_ONE_SHOT
	strength_effect.attributes_affected.append(attack_effect)
	
	# Effet sur la défense (avec bonus de dextérité)
	var dex_value = get_attribute_value("dexterity")
	var defense_effect = AttributeEffect.new()
	defense_effect.attribute_name = "defense"
	defense_effect.minimum_value = str_value * 0.5 + dex_value * 0.3
	defense_effect.applies_as = 0 # Value modification
	defense_effect.life_time = AttributeEffect.LIFETIME_ONE_SHOT
	strength_effect.attributes_affected.append(defense_effect)
	
	# Appliquer l'effet Force
	attribute_map.apply_effect(strength_effect)
	
	# Effet sur les chances critiques
	var crit_effect = GameplayEffect.new()
	crit_effect.name = "PlayerCritDerivedEffect"
	var crit_attr_effect = AttributeEffect.new()
	crit_attr_effect.attribute_name = "crit_chance"
	crit_attr_effect.minimum_value = dex_value * 0.5 # Bonus spécifique au joueur
	crit_attr_effect.applies_as = 0 # Value modification
	crit_attr_effect.life_time = AttributeEffect.LIFETIME_ONE_SHOT
	crit_effect.attributes_affected.append(crit_attr_effect)
	
	# Appliquer l'effet Critique
	attribute_map.apply_effect(crit_effect)
	
	# Effet sur la vitesse de mouvement
	var movement_effect = GameplayEffect.new()
	movement_effect.name = "PlayerMovementDerivedEffect"
	var movement_attr_effect = AttributeEffect.new()
	movement_attr_effect.attribute_name = "movement_speed"
	movement_attr_effect.minimum_value = movement_speed * (1.0 + dex_value * 0.015) # Bonus légèrement plus grand pour le joueur
	movement_attr_effect.applies_as = 0 # Value modification
	movement_attr_effect.life_time = AttributeEffect.LIFETIME_ONE_SHOT
	movement_effect.attributes_affected.append(movement_attr_effect)
	
	# Appliquer l'effet Mouvement
	attribute_map.apply_effect(movement_effect)
	
	print("[Player] Player-specific derived attributes applied successfully")

func add_experience(exp_amount: float) -> void:
	print("[Player] add_experience called with: " + str(exp_amount))
	
	if attribute_map == null:
		print("[Player] attribute_map is null, returning")
		return
	
	# DIAGNOSTIC : Vérifier l'état de tous les attributs de level AVANT de faire quoi que ce soit
	print("[Player] === DIAGNOSTIC AVANT AJOUT XP ===")
	var level_attr = attribute_map.get_attribute_by_name("level")
	var exp_attr = attribute_map.get_attribute_by_name("experience")
	var exp_req_attr = attribute_map.get_attribute_by_name("experience_required")
	
	if level_attr:
		print("[Player] Level attribute exists - current: " + str(level_attr.current_value) + ", max: " + str(level_attr.maximum_value))
	else:
		print("[Player] Level attribute NOT FOUND!")
	
	if exp_attr:
		print("[Player] Experience attribute exists - current: " + str(exp_attr.current_value) + ", max: " + str(exp_attr.maximum_value))
	else:
		print("[Player] Experience attribute NOT FOUND!")
	
	if exp_req_attr:
		print("[Player] Experience_required attribute exists - current: " + str(exp_req_attr.current_value) + ", max: " + str(exp_req_attr.maximum_value))
	else:
		print("[Player] Experience_required attribute NOT FOUND!")
	
	print("[Player] Via get_attribute_value() - Level: " + str(get_attribute_value("level")))
	print("[Player] Via get_attribute_value() - Experience: " + str(get_attribute_value("experience")))
	print("[Player] Via get_attribute_value() - Experience_required: " + str(get_attribute_value("experience_required")))
	print("[Player] === FIN DIAGNOSTIC ===")
	
	print("[Player] Getting current experience")
	var current_exp = get_attribute_value("experience")
	var new_exp = current_exp + exp_amount
	print("[Player] Current exp: " + str(current_exp) + ", New exp: " + str(new_exp))
	
	print("[Player] Showing floating damage")
	var exp_color = Color(0.5, 0.5, 1.0)  # Couleur bleu clair pour l'XP
	show_floating_damage(exp_amount, false, exp_color)
	print("[Player] Floating damage shown")
	
	print("[Player] Updating experience attribute")
	update_attribute("experience", new_exp)
	print("[Player] Experience attribute updated")
	
	print("[Player] Checking level up")
	check_level_up()
	print("[Player] Level up check completed")

# Drapeau pour éviter la récursion lors des level-ups
var _processing_level_up: bool = false

func check_level_up() -> void:
	print("[Player] check_level_up called")
	
	# Protéger contre la récursion infinie
	if _processing_level_up:
		print("[Player] Already processing level up, returning")
		return
	
	_processing_level_up = true
	print("[Player] Starting level up processing")
	
	# Traiter tous les level-ups dans une boucle au lieu de récursivement
	var leveled_up = true
	var safety_counter = 0  # Protection contre boucle infinie
	
	while leveled_up and safety_counter < 10:  # Max 10 niveaux d'un coup
		safety_counter += 1
		print("[Player] Level up iteration: " + str(safety_counter))
		
		var current_exp = get_attribute_value("experience")
		var exp_required = get_attribute_value("experience_required")
		var current_level = get_attribute_value("level")
		
		print("[Player] Current exp: " + str(current_exp) + ", Required: " + str(exp_required) + ", Level: " + str(current_level))
		
		if current_exp >= exp_required:
			print("[Player] Level up! New level: " + str(current_level + 1))
			current_level += 1
			update_attribute("level", current_level)
			print("[Player] Level attribute updated")
			
			current_exp -= exp_required
			update_attribute("experience", current_exp)
			print("[Player] Experience attribute updated")
			
			var new_exp_required = get_attribute_value("experience_required") * 1.2
			update_attribute("experience_required", new_exp_required)
			print("[Player] Experience required updated")
			
			print("[Player] Applying level up bonuses")
			apply_level_up_bonuses()
			print("[Player] Level up bonuses applied")
				
			var level_color = Color(1.0, 0.8, 0.0)  # Couleur dorée
			show_floating_damage(current_level, true, level_color)
			print("[Player] Level up visual shown")
		else:
			print("[Player] No more level ups needed")
			leveled_up = false
	
	if safety_counter >= 10:
		print("[Player] WARNING: Level up safety counter reached!")
	
	_processing_level_up = false
	print("[Player] Level up processing completed")

# Drapeau pour éviter la récursion lors de l'application des bonus de level-up
var _updating_level_up_bonuses: bool = false

func apply_level_up_bonuses() -> void:
	# Protéger contre la récursion
	if _updating_level_up_bonuses:
		return
	
	_updating_level_up_bonuses = true
	
	var str_value = get_attribute_value("strength") + 1
	var dex_value = get_attribute_value("dexterity") + 1
	var int_value = get_attribute_value("intelligence") + 1
	
	update_attribute("strength", str_value)
	update_attribute("dexterity", dex_value)
	update_attribute("intelligence", int_value)
	
	var health_attr = attribute_map.get_attribute_by_name("health")
	if health_attr:
		health_attr.maximum_value += 10
		health_attr.current_value = health_attr.maximum_value
		
	var mana_attr = attribute_map.get_attribute_by_name("mana")
	if mana_attr:
		mana_attr.maximum_value += 5
		mana_attr.current_value = mana_attr.maximum_value
	
	# Recalculer explicitement les attributs dérivés après le level up
	# (car nous avons désactivé les recalculs automatiques pour éviter les boucles infinies)
	print("[Player] Recalculating derived attributes after level up")
	recalculate_derived_attributes()
	
	# Mettre à jour la barre de santé
	update_health_bar()
	
	_updating_level_up_bonuses = false
	print("[Player] Level up bonuses completed")


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
