extends RigidBody2D

@export var navigation_agent_2d: NavigationAgent2D
@export var movement_speed: float = 80.0
@export var target_detection_range: float = 300.0
@export var attack_range: float = 30.0  # Distance when we're "close enough"
@export var force_multiplier: float = 15.0  # For movement responsiveness
@export var flee_health_threshold: float = 0.3  # Flee when health below this percentage

# Stats for the mob
@export_group("Base Stats")
@export var base_strength: float = 8.0
@export var base_dexterity: float = 6.0
@export var base_intelligence: float = 4.0
@export var base_health: float = 50.0
@export var base_mana: float = 20.0

# Reference to the current target (usually the player)
var target: Node2D = null

# References to gameplay systems
var attribute_map: GameplayAttributeMap
var ability_container: AbilityContainer

func _ready() -> void:
	setup_gameplay_systems()
	initialize_navigation_agent()

# Main physics process - manages the core gameplay loop
func _physics_process(_delta: float) -> void:
	if ability_container and ability_container.has_tag("dead"):
		return
	
	ensure_target_exists()
	
	if target == null:
		return
	
	# Get current state data
	var distance_to_target = global_position.distance_to(target.global_position)
	var current_stats = get_character_stats()
	var target_stats = get_target_stats()
	
	# Decide behavior using AI helper
	var behavior = AIBehaviors.decide_behavior(current_stats, target_stats, distance_to_target)
	
	# Execute behavior based on state
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
			pass  # Do nothing
		AIBehaviors.BehaviorState.DEAD:
			pass  # Already handled with dead tag

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
		load_mob_abilities()
		
		# Add initial tags
		ability_container.add_tag("can_attack")
		ability_container.add_tag("attack_ready")

# Initialize navigation agent with default settings
func initialize_navigation_agent() -> void:
	navigation_agent_2d.path_desired_distance = 5.0
	navigation_agent_2d.target_desired_distance = 5.0

# Make sure we have a valid target
func ensure_target_exists() -> void:
	if target == null:
		find_player()

# Update navigation agent with target position
func set_navigation_target() -> void:
	navigation_agent_2d.target_position = target.global_position

# Check if mob is within attack range of the target
func is_within_attack_range() -> bool:
	var distance_to_target = global_position.distance_to(target.global_position)
	return distance_to_target <= attack_range

# Handle behavior when within attack range
func handle_attack_range_behavior() -> void:
	stop_movement()
	
	# Try to perform attack
	if ability_container and not ability_container.has_tag("dead"):
		if ability_container.has_tag("attack_ready") and ability_container.has_tag("can_attack"):
			print_debug("Mob trying to attack!")
			ability_container.activate_many()

# Stop the mob's movement
func stop_movement() -> void:
	apply_central_force(Vector2.ZERO - linear_velocity * 10.0)

# Move the mob toward the current navigation target
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

# Find the player as a target
func find_player() -> void:
	target = null
	var main_node = get_parent()
	
	for node in main_node.get_children():
		if is_valid_player_target(node):
			target = node
			break

# Check if a node is a valid player target
func is_valid_player_target(node: Node) -> bool:
	return node.name.contains("Player") and node != self

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
	update_attribute("attack", str_value * 1.2)
	update_attribute("crit_chance", dex_value * 0.3)
	update_attribute("defense", str_value * 0.7)
	update_attribute("movement_speed", movement_speed * (1.0 + dex_value * 0.005))

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
			# Mob is dead
			ability_container.add_tag("dead")
			print_debug("Mob died!")
			
			# Traitement visuel pour la mort
			modulate = Color(0.0, 0.0, 0.5, 0.5) # Bleu semi-transparent
			freeze = true # Arrêter la physique
			
			# Supprimer le mob après un court délai (pour montrer l'effet visuel)
			var death_timer = Timer.new()
			death_timer.wait_time = 1.5
			death_timer.one_shot = true
			death_timer.timeout.connect(func(): queue_free())
			add_child(death_timer)
			death_timer.start()

# Load and grant mob abilities
func load_mob_abilities() -> void:
	var mob_attack = load("res://modules/shared/abilities/instances/mob_attack.tres")
	if mob_attack:
		ability_container.grant(mob_attack)

# Called when an attribute effect is applied to this character
func _on_attribute_effect_applied(attribute_effect: AttributeEffect, attribute: AttributeSpec) -> void:
	if attribute.attribute_name == "health":
		if attribute_effect.minimum_value < 0:
			# Mob took damage
			print_debug("Mob took %.1f damage!" % -attribute_effect.minimum_value)
			# Here you could play damage animation, sound, etc.
		elif attribute_effect.minimum_value > 0:
			# Mob healed
			print_debug("Mob healed for %.1f health!" % attribute_effect.minimum_value)

# Called when an attribute effect is removed from this character
func _on_attribute_effect_removed(_attribute_effect: AttributeEffect, _attribute: AttributeSpec) -> void:
	# Called when an effect ends - useful for time-based effects
	pass

# Called when any gameplay effect is applied to this character
func _on_effect_applied(effect: GameplayEffect) -> void:
	# You can check the whole effect here
	print_debug("Effect applied to mob with %d attributes affected" % effect.attributes_affected.size())

# Get current character stats dictionary
func get_character_stats() -> Dictionary:
	# Get health attribute and check if it exists
	var health_attr = attribute_map.get_attribute_by_name("health")
	var max_health = 50.0 # Default value
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

# Get target stats dictionary
func get_target_stats() -> Dictionary:
	# Default values if target doesn't exist or doesn't have attributes
	if not target or not target.has_node("GameplayAttributeMap"):
		return {
			"health": 100,
			"max_health": 100,
			"attack": 10,
			"defense": 5
		}
	
	var target_attr = target.get_node("GameplayAttributeMap")
	var health = get_target_attribute_value(target_attr, "health")
	
	# Get max health safely
	var max_health = 100.0 # Default value
	var health_attribute = target_attr.get_attribute_by_name("health")
	if health_attribute:
		max_health = health_attribute.maximum_value
	
	return {
		"health": health,
		"max_health": max_health,
		"attack": get_target_attribute_value(target_attr, "attack"),
		"defense": get_target_attribute_value(target_attr, "defense")
	}

# Get attribute value from target
func get_target_attribute_value(attr_map: GameplayAttributeMap, attr_name: String) -> float:
	var attr = attr_map.get_attribute_by_name(attr_name)
	if attr:
		return attr.current_buffed_value
	return 0.0

# Handle fleeing behavior
func handle_flee_behavior() -> void:
	if target == null:
		return
	
	var flee_direction = AIBehaviors.calculate_flee_direction(global_position, target.global_position)
	
	# Apply force to flee
	apply_movement_force(flee_direction)
