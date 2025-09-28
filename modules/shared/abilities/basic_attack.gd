@tool
class_name BasicAttack extends Ability

@export_group("Attack", "attack_")
@export var attack_cooldown: float = 1.0
@export var attack_damage_multiplier: float = 1.0
@export var attack_crit_multiplier: float = 2.0
@export var attack_range: float = 48.0  # Adjusted to approximately 3 tiles (16px per tile)
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
	super.activate(event)
	
	if not event.character:
		return
		
	var character_body = event.character
	
	var target = find_attack_target(character_body)
	if not target:
		return
		
	perform_attack(character_body, target)

func can_activate(event: ActivationEvent) -> bool:
	if not event.character:
		return false
	
	if event.character.has_method("is_within_attack_range") and "target_mob" in event.character:
		var player_target = event.character.target_mob
		if player_target != null and is_instance_valid(player_target):
			if event.character.is_within_attack_range():
				return super.can_activate(event)
			else:
				return false
	
	var target = find_attack_target(event.character)
	if not target:
		return false
	
	return super.can_activate(event)

func find_attack_target(character: CharacterBase) -> CharacterBase:
	if "target_mob" in character:
		var target = character.target_mob
		if target != null and is_instance_valid(target):
			if character.is_within_attack_range():
				return target
	
	var potential_targets = []
	var all_targets = []
	for node in character.get_parent().get_children():
		var is_target = false
		
		if target_group == "player" and node.name.contains("Player"):
			is_target = true
		elif target_group == "mob" and node.name.contains("Mob"):
			is_target = true
		
		if is_target and node != character:
			var is_dead = false
			if node.has_node("AbilityContainer"):
				var target_ability_container = node.get_node("AbilityContainer")
				if target_ability_container.has_tag("dead"):
					is_dead = true
			
			if not is_dead:
				var distance = character.global_position.distance_to(node.global_position)
				all_targets.append({"node": node, "distance": distance})

	all_targets.sort_custom(func(a, b): return a["distance"] < b["distance"])
	
	for target_data in all_targets:
		var node = target_data["node"]
		var distance = target_data["distance"]
		
		if distance <= attack_range:
			potential_targets.append(node)
	
	if potential_targets.size() > 0:
		return potential_targets[0]
	
	return null

func perform_attack(attacker: CharacterBase, defender: CharacterBase) -> void:
	# D'abord essayer d'obtenir les attributs via le script CharacterBase
	var attacker_attr = attacker.get_attribute_map()
	var defender_attr = defender.get_attribute_map()
	
	if not attacker_attr or not defender_attr:
		push_error("ERROR: Couldn't find attribute maps for attack")
		return
	
	var attack = get_attribute_value(attacker_attr, "attack")
	var defense = get_attribute_value(defender_attr, "defense")
	
	var damage = max(1.0, attack * attack_damage_multiplier - defense * 0.5)
	
	var crit_chance = get_attribute_value(attacker_attr, "crit_chance")
	var is_critical = randf() < (crit_chance / 100.0)
	
	if is_critical:
		damage *= attack_crit_multiplier
	
	apply_damage_effect(defender_attr, damage, is_critical)

func apply_damage_effect(defender_attr: GameplayAttributeMap, damage: float, is_critical: bool = false) -> void:
	var effect = GameplayEffect.new()
	var health_effect = AttributeEffect.new()
	health_effect.attribute_name = "health"
	health_effect.minimum_value = -damage
	health_effect.maximum_value = -damage
	
	health_effect.set_meta("critical", is_critical)
	
	health_effect.life_time = AttributeEffect.LIFETIME_ONE_SHOT
	
	effect.attributes_affected.append(health_effect)
	
	defender_attr.apply_effect(effect)
	
func get_attribute_value(attr_map: GameplayAttributeMap, attr_name: String) -> float:
	var attr = attr_map.get_attribute_by_name(attr_name)
	if attr:
		return attr.current_buffed_value
	return 0.0
