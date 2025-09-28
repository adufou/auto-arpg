class_name DerivedStatsCalculator
extends RefCounted

## Calculateur simple pour les attributs dérivés
## Remplace la logique complexe dans character_base.gd et player.gd

## Calcule les attributs dérivés pour un personnage de base
static func calculate_base_derived_stats(attribute_map: GameplayAttributeMap) -> Dictionary:
	var str_value = get_attribute_value(attribute_map, "strength")
	var dex_value = get_attribute_value(attribute_map, "dexterity")
	
	return {
		"attack": str_value * 1.2,
		"defense": str_value * 0.7,
		"crit_chance": dex_value * 0.3,
		"movement_speed": 0.0  # Pas de bonus de mouvement pour la base
	}

## Calcule les attributs dérivés spécifiques au joueur
static func calculate_player_derived_stats(attribute_map: GameplayAttributeMap, base_movement_speed: float) -> Dictionary:
	var str_value = get_attribute_value(attribute_map, "strength")
	var dex_value = get_attribute_value(attribute_map, "dexterity")
	
	return {
		"attack": str_value * 0.5,  # Multiplicateur réduit pour équilibrer
		"defense": str_value * 0.5 + dex_value * 0.3,
		"crit_chance": dex_value * 0.5,  # Bonus spécifique au joueur
		"movement_speed": base_movement_speed * (dex_value * 0.015)  # Bonus de mouvement
	}

## Applique les attributs dérivés via GameplayEffect
static func apply_derived_stats(attribute_map: GameplayAttributeMap, derived_values: Dictionary, effect_name: String) -> void:
	var effect = GameplayEffect.new()
	effect.name = effect_name
	
	for attr_name in derived_values:
		var value = derived_values[attr_name]
		if value != 0.0:  # Ne pas appliquer les valeurs nulles
			var attr_effect = AttributeEffect.new()
			attr_effect.attribute_name = attr_name
			attr_effect.minimum_value = value
			attr_effect.applies_as = 0  # Value modification
			attr_effect.life_time = AttributeEffect.LIFETIME_ONE_SHOT
			effect.attributes_affected.append(attr_effect)
	
	attribute_map.apply_effect(effect)

## Helper pour récupérer une valeur d'attribut
static func get_attribute_value(attribute_map: GameplayAttributeMap, attribute_name: String) -> float:
	var attr = attribute_map.get_attribute_by_name(attribute_name)
	if attr:
		return attr.current_buffed_value
	return 0.0
