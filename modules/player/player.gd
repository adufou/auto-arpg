extends RigidBody2D

@export var navigation_agent_2d: NavigationAgent2D
@export var player_attack: Ability
@export var floating_damage_scene: PackedScene
@export var movement_speed: float = 100.0
@export var target_detection_range: float = 500.0
@export var attack_range: float = 50.0  # Distance when we're "close enough"
@export var force_multiplier: float = 20.0  # For movement responsiveness
@export var mob_detection_interval: float = 0.5  # How often to search for mobs (in seconds)

# Stats for the character
@export_group("Base Stats")
@export var base_strength: float = 10.0
@export var base_dexterity: float = 10.0
@export var base_intelligence: float = 10.0
@export var base_health: float = 100.0
@export var base_mana: float = 50.0

# Reference to the current target mob
var target_mob: Node2D = null
# Store a list of mobs in attack range
var mobs_in_attack_range: Array[Node2D] = []
# Store a list of detected mobs
var detected_mobs: Array[Node2D] = []
# Timer for mob detection optimization
var mob_detection_timer: float = 0.0

# References to gameplay systems
var attribute_map: GameplayAttributeMap
var ability_container: AbilityContainer

func _ready() -> void:
	setup_gameplay_systems()
	initialize_navigation_agent()
	
	# Initialize the health bar
	update_health_bar()

# Main physics process - manages the core gameplay loop
func _physics_process(delta: float) -> void:
	# Ne rien faire si nous sommes morts
	if ability_container and ability_container.has_tag("dead"):
		return
	
	# Update mob detection timer
	mob_detection_timer -= delta
	
	# Update our knowledge of mobs in the scene (only every mob_detection_interval seconds)
	if mob_detection_timer <= 0:
		find_all_mobs()
		mob_detection_timer = mob_detection_interval
	
	# Find mobs within attack range first (this is cheap, so we do it every frame)
	find_mobs_in_attack_range()
	
	# If we have mobs in attack range, target the closest one
	if not mobs_in_attack_range.is_empty():
		target_closest_mob_in_range()
		handle_attack_range_behavior()
		return
	
	# If no mobs in attack range, ensure we have a target to navigate to
	if target_mob == null or !is_instance_valid(target_mob):
		find_closest_mob()
	
	# If still no target, there are no mobs at all
	if target_mob == null:
		return
		
	# Set navigation target and move toward it
	set_navigation_target()
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

# Find all mobs in the scene and store them in detected_mobs
func find_all_mobs() -> void:
	detected_mobs.clear()
	
	# Get all nodes in the "mob" group directly
	var mob_nodes = get_tree().get_nodes_in_group("mob")
	
	# Filter out invalid targets (e.g., dead mobs)
	for mob in mob_nodes:
		if mob != self and is_valid_mob_target(mob):
			detected_mobs.append(mob)

# Find mobs within attack range and store them in mobs_in_attack_range
func find_mobs_in_attack_range() -> void:
	mobs_in_attack_range.clear()
	
	for mob in detected_mobs:
		if global_position.distance_to(mob.global_position) <= attack_range:
			mobs_in_attack_range.append(mob)

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
		# Vérifier les tags avant d'attaquer
		var has_attack_ready = ability_container.has_tag("attack_ready")
		var has_can_attack = ability_container.has_tag("can_attack")
		
		print_debug("Vérification des tags d'attaque - attack_ready: %s, can_attack: %s" % [has_attack_ready, has_can_attack])
		
		if has_attack_ready and has_can_attack:
			print_debug("Player trying to attack mob: %s!" % target_mob.name)
			ability_container.activate_many()
		else:
			print_debug("Player ne peut pas attaquer: tags manquants")

# Stop the player's movement
func stop_movement() -> void:
	apply_central_force(Vector2.ZERO - linear_velocity * 10.0)

# Move the player toward the current navigation target
func move_toward_target() -> void:
	if navigation_agent_2d.is_navigation_finished():
		return
	
	# Check if we've been stuck at the same position for too long
	check_navigation_stuck()
	
	var next_position = navigation_agent_2d.get_next_path_position()
	var direction = calculate_direction_to(next_position)
	apply_movement_force(direction)

# Variables to detect when player gets stuck
var last_position: Vector2 = Vector2.ZERO
var stuck_time: float = 0.0
var recalculation_timeout: float = 0.0

# Check if player is stuck and handle it
func check_navigation_stuck() -> void:
	if recalculation_timeout > 0:
		recalculation_timeout -= get_process_delta_time()
		return
	
	if last_position.distance_to(global_position) < 1.0:
		# We haven't moved much
		stuck_time += get_process_delta_time()
		if stuck_time > 1.0: # Stuck for more than 1 second
			# Try to recalculate path
			if target_mob and is_instance_valid(target_mob):
				navigation_agent_2d.target_position = target_mob.global_position
				
			# Apply a small random movement to try to get unstuck
			var random_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			apply_central_force(random_direction * movement_speed * 2)
			
			# Reset stuck timer and set timeout before next check
			stuck_time = 0.0
			recalculation_timeout = 0.5
	else:
		# We're moving, reset stuck timer
		stuck_time = 0.0
	
	# Update last position
	last_position = global_position

# Calculate direction vector to a target position
func calculate_direction_to(target_position: Vector2) -> Vector2:
	return (target_position - global_position).normalized()

# Apply physics force for movement in a direction
func apply_movement_force(direction: Vector2) -> void:
	var desired_velocity = direction * movement_speed
	apply_central_force((desired_velocity - linear_velocity) * force_multiplier)

# Find the closest mob as a target from all detected mobs
func find_closest_mob() -> void:
	if detected_mobs.is_empty():
		target_mob = null
		return
	
	var closest_distance = target_detection_range
	target_mob = null
	
	for mob in detected_mobs:
		var distance = global_position.distance_to(mob.global_position)
		if distance < closest_distance:
			closest_distance = distance
			target_mob = mob
	
	if target_mob:
		# Set the navigation target immediately
		navigation_agent_2d.target_position = target_mob.global_position

# Target the closest mob in attack range
func target_closest_mob_in_range() -> void:
	if mobs_in_attack_range.is_empty():
		return
	
	var closest_distance = attack_range
	var closest_mob = null
	
	for mob in mobs_in_attack_range:
		var distance = global_position.distance_to(mob.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_mob = mob
	
	if closest_mob:
		target_mob = closest_mob

# Check if a mob is a valid target (not dead)
func is_valid_mob_target(mob: Node) -> bool:
	# Check if the mob is alive
	if mob.has_node("AbilityContainer"):
		var mob_ability_container = mob.get_node("AbilityContainer")
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
		# Update health bar
		update_health_bar()
		
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
	ability_container.grant(player_attack)

# Called when an attribute effect is applied to this character
func _on_attribute_effect_applied(attribute_effect: AttributeEffect, attribute: AttributeSpec) -> void:
	if attribute.attribute_name == "health":
		# Update health bar
		update_health_bar()
		
		if attribute_effect.minimum_value < 0:
			# Player took damage
			var damage_value = -attribute_effect.minimum_value
			print_debug("Player took %.1f damage!" % damage_value)
			
			# Create floating damage - Red for player damage as requested
			show_floating_damage(damage_value, false, Color(1.0, 0.0, 0.0)) # Rouge pour les dégâts pris par le joueur
			
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

# Updates the health progress bar with current health value
func update_health_bar() -> void:
	var health_bar = %ProgressBar
	if health_bar and attribute_map:
		var health_attribute = attribute_map.get_attribute_by_name("health")
		if health_attribute:
			# Set the max value
			health_bar.max_value = health_attribute.maximum_value
			# Set the current value
			health_bar.value = health_attribute.current_buffed_value
			# Change color based on health percentage
			var health_percent = health_attribute.current_buffed_value / health_attribute.maximum_value
			if health_percent > 0.7:
				health_bar.modulate = Color(0, 1, 0) # Green
			elif health_percent > 0.3:
				health_bar.modulate = Color(1, 1, 0) # Yellow
			else:
				health_bar.modulate = Color(1, 0, 0) # Red

# Shows floating damage numbers above the character
func show_floating_damage(damage_value: float, is_critical: bool = false, damage_color: Color = Color.WHITE) -> void:
	# Instance the scene
	var floating_damage: FloatingDamage = floating_damage_scene.instantiate()
		
	# Add it to the scene tree at a position above the character
	get_tree().current_scene.add_child(floating_damage)
	floating_damage.global_position = global_position + Vector2(0, -30)
	
	# Apply random horizontal offset for better visibility with multiple hits
	floating_damage.global_position.x += randf_range(-15, 15)
	
	# Configure the floating damage
	floating_damage.setup(damage_value, is_critical, damage_color)
