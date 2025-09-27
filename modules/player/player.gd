extends RigidBody2D

@export var navigation_agent_2d: NavigationAgent2D
@export var movement_speed: float = 100.0
@export var target_detection_range: float = 500.0
@export var attack_range: float = 50.0  # Distance when we're "close enough"
@export var force_multiplier: float = 20.0  # For movement responsiveness

# Stats for the character
@export_group("Base Stats")
@export var base_strength: float = 10.0
@export var base_dexterity: float = 10.0
@export var base_intelligence: float = 10.0
@export var base_health: float = 100.0
@export var base_mana: float = 50.0

# Reference to the current target mob
var target_mob: Node2D = null

# References to gameplay systems
var attribute_map: GameplayAttributeMap
var ability_container: AbilityContainer

func _ready() -> void:
	setup_gameplay_systems()
	initialize_navigation_agent()

# Main physics process - manages the core gameplay loop
func _physics_process(_delta: float) -> void:
	# Ne rien faire si nous sommes morts
	if ability_container and ability_container.has_tag("dead"):
		return
	
	# Vérifier si nous avons une cible valide
	ensure_target_exists()
	
	# Si aucune cible n'est trouvée, rester immobile
	if target_mob == null:
		# On pourrait ajouter ici un comportement d'exploration ou d'attente
		return
		
	# Définir la position cible pour la navigation
	set_navigation_target()
	
	# Si nous sommes assez près pour attaquer
	if is_within_attack_range():
		handle_attack_range_behavior()
		return
	
	# Sinon, se déplacer vers la cible
	move_toward_target()

# Setup the gameplay systems with initial values
func setup_gameplay_systems() -> void:
	attribute_map = $GameplayAttributeMap
	ability_container = $AbilityContainer
	
	# Initialize base attributes
	if attribute_map:
		# Primary stats
		update_attribute("strength", base_strength)
		update_attribute("dexterity", base_dexterity)
		update_attribute("intelligence", base_intelligence)
		update_attribute("health", base_health)
		update_attribute("mana", base_mana)
		
		# Derived stats
		update_derived_stats()
		
		# Connect signals
		attribute_map.attribute_changed.connect(_on_attribute_changed)
		attribute_map.attribute_effect_applied.connect(_on_attribute_effect_applied)
		attribute_map.attribute_effect_removed.connect(_on_attribute_effect_removed)
		attribute_map.effect_applied.connect(_on_effect_applied)
	
	# Setup attack ability
	if ability_container:
		# Add basic attack ability
		load_player_abilities()
		
		# Add initial tags
		ability_container.add_tag("can_attack")
		ability_container.add_tag("attack_ready")

# Initialize navigation agent with default settings
func initialize_navigation_agent() -> void:
	navigation_agent_2d.path_desired_distance = 5.0
	navigation_agent_2d.target_desired_distance = 5.0

# Make sure we have a valid target
func ensure_target_exists() -> void:
	# Vérifier si la cible n'existe plus ou est morte
	if target_mob == null or !is_instance_valid(target_mob) or (target_mob.has_node("AbilityContainer") and target_mob.get_node("AbilityContainer").has_tag("dead")):
		# Réinitialiser la référence
		target_mob = null
		# Chercher une nouvelle cible
		find_closest_mob()
		
		# Si aucune cible n'est trouvée, arrêter le mouvement
		if target_mob == null:
			stop_movement()
			print_debug("Aucune cible trouvée, le joueur s'arrête")

# Update navigation agent with target position
func set_navigation_target() -> void:
	# Vérifier si la cible existe avant de définir la position
	if target_mob and is_instance_valid(target_mob):
		navigation_agent_2d.target_position = target_mob.global_position

# Check if player is within attack range of the target
func is_within_attack_range() -> bool:
	# S'assurer que la cible existe
	if not target_mob or not is_instance_valid(target_mob):
		return false
		
	var distance_to_target = global_position.distance_to(target_mob.global_position)
	return distance_to_target <= attack_range

# Handle behavior when within attack range
func handle_attack_range_behavior() -> void:
	stop_movement()
	
	# Try to perform attack
	if ability_container and not ability_container.has_tag("dead"):
		if ability_container.has_tag("attack_ready") and ability_container.has_tag("can_attack"):
			print_debug("Player trying to attack!")
			ability_container.activate_many()

# Stop the player's movement
func stop_movement() -> void:
	apply_central_force(Vector2.ZERO - linear_velocity * 10.0)

# Move the player toward the current navigation target
func move_toward_target() -> void:
	if navigation_agent_2d.is_navigation_finished():
		return
		
	var next_position = navigation_agent_2d.get_next_path_position()
	var direction = calculate_direction_to(next_position)
	apply_movement_force(direction)

# Calculate direction vector to a target position
func calculate_direction_to(target_position: Vector2) -> Vector2:
	return (target_position - global_position).normalized()

# Apply physics force for movement in a direction
func apply_movement_force(direction: Vector2) -> void:
	var desired_velocity = direction * movement_speed
	apply_central_force((desired_velocity - linear_velocity) * force_multiplier)

# Find the closest mob as a target
func find_closest_mob() -> void:
	target_mob = null
	var main_node = get_parent()
	var closest_distance = target_detection_range
	
	for node in main_node.get_children():
		if is_valid_mob_target(node):
			var distance = global_position.distance_to(node.global_position)
			if distance < closest_distance:
				closest_distance = distance
				target_mob = node
	
	if target_mob:
		navigation_agent_2d.target_position = target_mob.global_position

# Check if a node is a valid mob target
func is_valid_mob_target(node: Node) -> bool:
	# Vérifier si c'est un mob et pas nous-même
	if node.name.contains("Mob") and node != self:
		# Vérifier si le mob n'est pas mort
		if node.has_node("AbilityContainer"):
			var mob_ability_container = node.get_node("AbilityContainer")
			return not mob_ability_container.has_tag("dead")
	return false

# Helper function to update an attribute value
func update_attribute(attribute_name: String, value: float) -> void:
	var attr = attribute_map.get_attribute_by_name(attribute_name)
	if attr:
		attr.current_value = value

# Update derived stats based on primary attributes
func update_derived_stats() -> void:
	var str_value = get_attribute_value("strength")
	var dex_value = get_attribute_value("dexterity")
	var _int_value = get_attribute_value("intelligence")
	
	# Calculate derived stats
	update_attribute("attack", str_value * 1.5)
	update_attribute("crit_chance", dex_value * 0.5)
	update_attribute("defense", str_value * 0.5 + dex_value * 0.3)
	update_attribute("movement_speed", movement_speed * (1.0 + dex_value * 0.01))

# Get the current value of an attribute
func get_attribute_value(attribute_name: String) -> float:
	var attr = attribute_map.get_attribute_by_name(attribute_name)
	if attr:
		return attr.current_buffed_value
	return 0.0

# Called when an attribute changes
func _on_attribute_changed(attribute: AttributeSpec) -> void:
	# Update derived stats if a primary stat changes
	if attribute.attribute_name in ["strength", "dexterity", "intelligence"]:
		update_derived_stats()
	
	# Handle special cases
	if attribute.attribute_name == "health":
		if attribute.current_buffed_value <= 0 and not ability_container.has_tag("dead"):
			# Player is dead
			ability_container.add_tag("dead")
			print_debug("Player died!")
			
			# Traitement visuel pour la mort
			modulate = Color(0.5, 0.0, 0.0, 0.5) # Rouge semi-transparent
			freeze = true # Arrêter la physique
			
			# Supprimer le joueur après un court délai (pour montrer l'effet visuel)
			var death_timer = Timer.new()
			death_timer.wait_time = 1.5
			death_timer.one_shot = true
			death_timer.timeout.connect(func(): queue_free())
			add_child(death_timer)
			death_timer.start()

# Load and grant player abilities
func load_player_abilities() -> void:
	var player_attack = load("res://modules/shared/abilities/instances/player_attack.tres")
	if player_attack:
		ability_container.grant(player_attack)

# Called when an attribute effect is applied to this character
func _on_attribute_effect_applied(attribute_effect: AttributeEffect, attribute: AttributeSpec) -> void:
	if attribute.attribute_name == "health":
		if attribute_effect.minimum_value < 0:
			# Player took damage
			print_debug("Player took %.1f damage!" % -attribute_effect.minimum_value)
			# Here you could play damage animation, sound, etc.
		elif attribute_effect.minimum_value > 0:
			# Player healed
			print_debug("Player healed for %.1f health!" % attribute_effect.minimum_value)
			# Here you could play heal animation, sound, etc.

# Called when an attribute effect is removed from this character
func _on_attribute_effect_removed(_attribute_effect: AttributeEffect, _attribute: AttributeSpec) -> void:
	# Called when an effect ends - useful for time-based effects
	# Paramètres préfixés avec underscore car non utilisés pour l'instant
	pass

# Called when any gameplay effect is applied to this character
func _on_effect_applied(effect: GameplayEffect) -> void:
	# You can check the whole effect here
	print_debug("Effect applied to player with %d attributes affected" % effect.attributes_affected.size())
