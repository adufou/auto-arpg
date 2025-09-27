@tool
class_name BasicAttack extends Ability

@export_group("Attack", "attack_")
@export var attack_cooldown: float = 1.0
@export var attack_damage_multiplier: float = 1.0
@export var attack_crit_multiplier: float = 2.0
@export var attack_range: float = 60.0
@export var target_group: String = ""  # Group to attack ("player" or "enemy")

func _init() -> void:
	# Set base ability properties
	self.cooldown_duration = attack_cooldown
	tags_activation = ["can_attack"]  # Requires this tag to be able to attack
	tags_block = ["attacking", "stunned", "dead"]  # Any of these tags block the attack
	tags_activation.append("attack_ready")  # Adding tag to activation tags
	tags_to_remove_on_activation = ["attack_ready"]  # Remove this tag after attacking
	tags_cooldown_start = ["attacking"]  # Add this tag when ability starts cooldown
	tags_to_remove_on_cooldown_end = ["attacking"]  # Remove this tag when cooldown ends
	tags_cooldown_end = ["attack_ready"]  # Add this tag when cooldown ends

func activate(event: ActivationEvent) -> void:
	# Call parent method first
	super.activate(event)
	
	# Make sure character is valid
	if not event.character:
		return
		
	var character_body = event.character
	
	# Find target with find_attack_target based on target_group
	var target = find_attack_target(character_body)
	if not target:
		return
		
	# Perform attack
	perform_attack(character_body, target)

func can_activate(event: ActivationEvent) -> bool:
	# Checks if we have a valid target in range
	if not event.character:
		return false
		
	var target = find_attack_target(event.character)
	if not target:
		return false
	
	# Continue with parent checks (cooldown, tags, etc)
	return super.can_activate(event)

# Find a valid attack target
func find_attack_target(character: Node) -> Node:
	# Get nodes in the target group
	print_debug("Looking for target in group: %s" % target_group)
	var potential_targets = []
	for node in character.get_parent().get_children():
		var is_target = false
		
		# Check if this is a valid target based on group
		if target_group == "player" and node.name.contains("Player"):
			is_target = true
			print_debug("Found player target: %s" % node.name)
		elif target_group == "mob" and node.name.contains("Mob"):
			is_target = true
			print_debug("Found mob target: %s" % node.name)
		
		# Vérifier si la cible n'est pas morte et est différente du personnage actuel
		if is_target and node != character:
			# Vérifier si la cible a un AbilityContainer et si elle est morte
			var is_dead = false
			if node.has_node("AbilityContainer"):
				var target_ability_container = node.get_node("AbilityContainer")
				if target_ability_container.has_tag("dead"):
					print_debug("%s is dead, ignoring as target" % node.name)
					is_dead = true
			
			# Ne poursuivre que si la cible n'est pas morte
			if not is_dead:
				var distance = character.global_position.distance_to(node.global_position)
				print_debug("Distance to %s: %.1f (max: %.1f)" % [node.name, distance, attack_range])
				if distance <= attack_range:
					print_debug("Target %s is in range!" % node.name)
					potential_targets.append(node)
	
	# Return closest target if any
	if potential_targets.size() > 0:
		return potential_targets[0]
	
	return null

# Perform the attack with damage calculation
func perform_attack(attacker: Node, defender: Node) -> void:
	print_debug("===== %s attacks %s! =====" % [attacker.name, defender.name])
	
	# Calculate damage based on attacker's stats
	var attacker_attr = attacker.get_node("GameplayAttributeMap")
	var defender_attr = defender.get_node("GameplayAttributeMap")
	
	if not attacker_attr or not defender_attr:
		return
	
	# Get attack and defense values
	var attack = get_attribute_value(attacker_attr, "attack")
	var defense = get_attribute_value(defender_attr, "defense")
	
	# Calculate base damage
	var damage = max(1.0, attack * attack_damage_multiplier - defense * 0.5)
	
	# Check for critical hit
	var crit_chance = get_attribute_value(attacker_attr, "crit_chance")
	var is_critical = randf() < (crit_chance / 100.0)
	
	if is_critical:
		damage *= attack_crit_multiplier
		print_debug("CRITICAL HIT! Damage: %s" % damage)
	
	# Apply damage to the defender using GameplayEffect
	apply_damage_effect(defender_attr, damage, is_critical)

# Apply damage to a target using GameplayEffect as recommended by the documentation
func apply_damage_effect(defender_attr: GameplayAttributeMap, damage: float, is_critical: bool = false) -> void:
	# Create a new GameplayEffect for damage
	var effect = GameplayEffect.new()
	
	# Create a new AttributeEffect for health reduction
	var health_effect = AttributeEffect.new()
	
	# Configure the effect to reduce health
	health_effect.attribute_name = "health"
	health_effect.minimum_value = -damage
	health_effect.maximum_value = -damage
	
	# Store critical hit info in effect metadata for floating damage display
	health_effect.set_meta("critical", is_critical)
	
	# Make it a one-shot effect
	health_effect.life_time = AttributeEffect.LIFETIME_ONE_SHOT
	
	# Add the affected attribute to the GameplayEffect
	effect.attributes_affected.append(health_effect)
	
	# Get the parent node name for debug
	var defender_name = "target"
	if defender_attr.get_parent():
		defender_name = defender_attr.get_parent().name
	
	# Apply the effect to the defender's GameplayAttributeMap
	print_debug("Applying %.1f damage to %s" % [damage, defender_name])
	defender_attr.apply_effect(effect)
	
	# Vérifier les valeurs après l'application
	var health_after = get_attribute_value(defender_attr, "health")
	print_debug("%s health after attack: %.1f" % [defender_name, health_after])
	
	# Note: GameplayAttributeMap will automatically emit signals that can be used for visual feedback

# Helper function to get attribute value
func get_attribute_value(attr_map: GameplayAttributeMap, attr_name: String) -> float:
	var attr = attr_map.get_attribute_by_name(attr_name)
	if attr:
		return attr.current_buffed_value
	return 0.0
