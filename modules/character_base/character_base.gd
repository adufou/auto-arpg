extends RigidBody2D
class_name CharacterBase

@export var movement_speed: float = 100
@export var target_detection_range: float = 300
@export var attack_range: float = 24
@export var force_multiplier: float = 10

@export_group("References")
@export var navigation_agent_2d: NavigationAgent2D
@export var floating_damage_scene: PackedScene

@export_group("Base Stats")
@export var base_strength: float = 0.0
@export var base_dexterity: float = 0.0
@export var base_intelligence: float = 0.0
@export var base_health: float = 0.0
@export var base_mana: float = 0.0

# System references
var attribute_map: GameplayAttributeMap
var ability_container: AbilityContainer

# Variables de configuration des attributs

func get_attribute_map() -> GameplayAttributeMap:
	return attribute_map

func get_ability_container() -> AbilityContainer:
	return ability_container

func _ready() -> void:
	# Set up physics properties
	collision_layer = 2
	collision_mask = 3
	mass = 1.5
	gravity_scale = 0.0
	lock_rotation = true
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 5.0

	# Create a PhysicsMaterial with no friction and slight bounce
	var physics_mat = PhysicsMaterial.new()
	physics_mat.friction = 0.0
	physics_mat.bounce = 0.1
	physics_material_override = physics_mat

	# Initialize systems
	setup_gameplay_systems()
	initialize_navigation_agent()

func setup_gameplay_systems() -> void:
	print("[CharacterBase] setup_gameplay_systems started")
	# Get references to nodes
	attribute_map = %GameplayAttributeMap
	ability_container = %AbilityContainer
	
	# PHASE 1: Set up attributes and attribute map first
	if attribute_map:
		print("[CharacterBase] Setting up primary attributes")
		
		# Configure les attributs primaires
		update_attribute("strength", base_strength)
		update_attribute("dexterity", base_dexterity)
		update_attribute("intelligence", base_intelligence)
		update_attribute("health", base_health)
		update_attribute("mana", base_mana)
		
		# Assurer que les valeurs maximales sont correctes
		var health_attr = attribute_map.get_attribute_by_name("health")
		if health_attr:
			health_attr.maximum_value = base_health
			health_attr.current_value = base_health
			
		var mana_attr = attribute_map.get_attribute_by_name("mana")
		if mana_attr:
			mana_attr.maximum_value = base_mana
			mana_attr.current_value = base_mana
		
		# Appliquer les effets pour calculer les attributs dérivés
		apply_derived_attributes()
		print("[CharacterBase] Initial derived stats calculated")
		
		# Mettre à jour explicitement la barre de vie
		update_health_bar()

		# Connecter UNIQUEMENT les signaux pour les effets (plus de attribute_changed)
		print("[CharacterBase] Connecting signals")
		attribute_map.attribute_effect_applied.connect(_on_attribute_effect_applied)
		attribute_map.attribute_effect_removed.connect(_on_attribute_effect_removed)
		attribute_map.effect_applied.connect(_on_effect_applied)
		print("[CharacterBase] Signals connected")
	
	# PHASE 2: Setup ability container after attribute map is ready
	if ability_container and attribute_map:
		print("[CharacterBase] Setting up ability container")
		# Configure the AbilityContainer to use our GameplayAttributeMap
		if ability_container.gameplay_attribute_map_path.is_empty():
			ability_container.gameplay_attribute_map_path = attribute_map.get_path()
			ability_container.gameplay_attribute_map = attribute_map
			print("[CharacterBase] Ability container path set")
			
		# We'll add tags at the end of _ready using a callback
		# This ensures attribute updates have completed
		print("[CharacterBase] Deferring tag addition")
		call_deferred("_add_ability_tags")

	print("[CharacterBase] setup_gameplay_systems completed")

# Separated tag adding to happen after initialization is complete
func _add_ability_tags() -> void:
	print("[CharacterBase] _add_ability_tags called")
	if ability_container:
		print("[CharacterBase] Adding tags to ability container")
		ability_container.add_tag("can_attack")
		ability_container.add_tag("attack_ready")
		print("[CharacterBase] Tags added")

func initialize_navigation_agent() -> void:
	navigation_agent_2d.path_desired_distance = 5.0
	navigation_agent_2d.target_desired_distance = 5.0
# Méthode pour mettre à jour n'importe quel attribut
func update_attribute(attribute_name: String, value: float) -> void:
	var attr = attribute_map.get_attribute_by_name(attribute_name)
	if attr:
		attr.current_value = value
		
		# SUPPRIMÉ : Recalcul automatique qui peut causer des boucles infinies
		# Si c'est un attribut primaire, on met à jour automatiquement les attributs dérivés
		# if attribute_name in ["strength", "dexterity", "intelligence"]:
		#	call_deferred("apply_derived_attributes")
		# 
		# Les attributs dérivés sont maintenant calculés uniquement via GameplayEffect
		# lors de l'initialisation ou d'événements explicites (level up, équipement)

# Méthode pour appliquer des GameplayEffect qui calculent les attributs dérivés
func apply_derived_attributes() -> void:
	print("[CharacterBase] Applying derived attributes using GameplayEffect")
	
	if not attribute_map:
		print("[CharacterBase] Error: No attribute map available")
		return
	
	# Créer un effet pour les dérivés de Force (attaque, défense)
	var strength_effect = GameplayEffect.new()
	strength_effect.name = "StrengthDerivedEffect"
	
	# Valeur actuelle de Force
	var str_value = get_attribute_value("strength")
	
	# Effet sur l'attaque
	var attack_effect = AttributeEffect.new()
	attack_effect.attribute_name = "attack"
	attack_effect.minimum_value = str_value * 1.2
	attack_effect.applies_as = 0 # Value modification
	attack_effect.life_time = AttributeEffect.LIFETIME_ONE_SHOT
	strength_effect.attributes_affected.append(attack_effect)
	
	# Effet sur la défense
	var defense_effect = AttributeEffect.new()
	defense_effect.attribute_name = "defense"
	defense_effect.minimum_value = str_value * 0.7
	defense_effect.applies_as = 0 # Value modification
	defense_effect.life_time = AttributeEffect.LIFETIME_ONE_SHOT
	strength_effect.attributes_affected.append(defense_effect)
	
	# Appliquer l'effet Force
	attribute_map.apply_effect(strength_effect)
	
	# Créer un effet pour les dérivés de Dextérité (crit_chance, mouvement)
	var dex_effect = GameplayEffect.new()
	dex_effect.name = "DexterityDerivedEffect"
	
	# Valeur actuelle de Dextérité
	var dex_value = get_attribute_value("dexterity")
	
	# Effet sur les chances critiques
	var crit_effect = AttributeEffect.new()
	crit_effect.attribute_name = "crit_chance"
	crit_effect.minimum_value = dex_value * 0.3
	crit_effect.applies_as = 0 # Value modification
	crit_effect.life_time = AttributeEffect.LIFETIME_ONE_SHOT
	dex_effect.attributes_affected.append(crit_effect)
	
	# Effet sur la vitesse de mouvement
	var movement_effect = AttributeEffect.new()
	movement_effect.attribute_name = "movement_speed"
	movement_effect.minimum_value = movement_speed * (1.0 + dex_value * 0.005)
	movement_effect.applies_as = 0 # Value modification
	movement_effect.life_time = AttributeEffect.LIFETIME_ONE_SHOT
	dex_effect.attributes_affected.append(movement_effect)
	
	# Appliquer l'effet Dextérité
	attribute_map.apply_effect(dex_effect)
	
	print("[CharacterBase] Derived attributes applied successfully")

# Méthode publique pour recalculer les attributs dérivés explicitement
# À utiliser lors de level up, changement d'équipement, etc.
func recalculate_derived_attributes() -> void:
	print("[CharacterBase] Explicit recalculation of derived attributes")
	apply_derived_attributes()

# Note: Les anciennes méthodes sont gardées pour compatibilité, mais ne sont plus utilisées
# A public method for safely updating derived stats (déprécié)
func safe_update_derived_stats() -> void:
	apply_derived_attributes()

# The actual implementation with the recursion protection (déprécié)
func update_derived_stats() -> void:
	apply_derived_attributes()

func get_attribute_value(attribute_name: String) -> float:
	var attr = attribute_map.get_attribute_by_name(attribute_name)
	if attr:
		return attr.current_buffed_value
	return 0.0

# Cette méthode est appelée lorsqu'un attribut est modifié
# Note: Nous n'y sommes plus connectés pour éviter les cascades,
# mais la fonction reste disponible pour compatibilité
func _on_attribute_changed(attribute: AttributeSpec) -> void:
	print("[CharacterBase] _on_attribute_changed: " + attribute.attribute_name)
	
	# SUPPRIMÉ : Recalcul automatique qui peut causer des boucles infinies
	# Si c'est un attribut primaire, on met à jour les attributs dérivés
	# if attribute.attribute_name in ["strength", "dexterity", "intelligence"]:
	#	print("[CharacterBase] triggering derived stats update for " + attribute.attribute_name)
	#	apply_derived_attributes()
	# 
	# Les attributs dérivés sont calculés uniquement lors de l'initialisation

	if attribute.attribute_name == "health":
		update_health_bar()

	if attribute.current_buffed_value <= 0 and ability_container and not ability_container.has_tag("dead"):
		ability_container.add_tag("dead")

		modulate = Color(0.5, 0.0, 0.0, 0.5)
		freeze = true

		# Disable collision so other characters can pass through
		set_collision_layer(0)
		set_collision_mask(0)

		var death_timer = Timer.new()
		death_timer.wait_time = 1.5
		death_timer.one_shot = true
		death_timer.timeout.connect(func(): queue_free())
		add_child(death_timer)
		death_timer.start()

func _on_attribute_effect_applied(attribute_effect: AttributeEffect, attribute: AttributeSpec) -> void:
	if attribute.attribute_name == "health":
		update_health_bar()

	if attribute_effect.minimum_value < 0:
		var damage_value = -attribute_effect.minimum_value

		var is_critical = false
		if attribute_effect.has_meta("critical") and attribute_effect.get_meta("critical") == true:
			is_critical = true

		show_floating_damage(damage_value, is_critical, Color.WHITE)

	elif attribute_effect.minimum_value > 0:
		pass

func _on_attribute_effect_removed(_attribute_effect: AttributeEffect, _attribute: AttributeSpec) -> void:
	pass

func _on_effect_applied(_effect: GameplayEffect) -> void:
	pass

func handle_attack_range_behavior() -> void:
	stop_movement()

	if ability_container and not ability_container.has_tag("dead"):
		if ability_container.has_tag("attack_ready") and ability_container.has_tag("can_attack"):
			ability_container.activate_many()

func stop_movement() -> void:
	apply_central_force(Vector2.ZERO - linear_velocity * 10.0)

func move_toward_target() -> void:
	if navigation_agent_2d.is_navigation_finished():
		return

	var next_position = navigation_agent_2d.get_next_path_position()
	var direction = calculate_direction_to(next_position)
	apply_movement_force(direction)

func calculate_direction_to(target_position: Vector2) -> Vector2:
	return (target_position - global_position).normalized()

func apply_movement_force(direction: Vector2) -> void:
	var desired_velocity = direction * movement_speed
	apply_central_force((desired_velocity - linear_velocity) * force_multiplier)

func update_health_bar() -> void:
	var health_bar = %ProgressBar
	if health_bar and attribute_map:
		var health_attribute = attribute_map.get_attribute_by_name("health")
		if health_attribute:
			health_bar.max_value = health_attribute.maximum_value
			health_bar.value = health_attribute.current_buffed_value
			var health_percent = health_attribute.current_buffed_value / health_attribute.maximum_value

			if health_percent > 0.7:
				health_bar.modulate = Color(0, 1, 0) # Green
			elif health_percent > 0.3:
				health_bar.modulate = Color(1, 1, 0) # Yellow
			else:
				health_bar.modulate = Color(1, 0, 0) # Red

func show_floating_damage(damage_value: float, is_critical: bool = false, damage_color: Color = Color.WHITE) -> void:
	var floating_damage: FloatingDamage = floating_damage_scene.instantiate()

	get_tree().current_scene.add_child(floating_damage)
	floating_damage.global_position = global_position + Vector2(0, -30)

	floating_damage.global_position.x += randf_range(-15, 15)

	floating_damage.setup(damage_value, is_critical, damage_color)
