extends RigidBody2D
class_name CharacterBase

# Import du calculateur d'attributs dérivés
const DerivedStatsCalculator = preload("res://modules/effects/derived_stats_calculator.gd")

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
	# Get references to nodes
	attribute_map = %GameplayAttributeMap
	ability_container = %AbilityContainer
	
	# Set up attributes and attribute map
	if attribute_map:
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
		update_health_bar()

		# Connecter les signaux pour les effets
		attribute_map.attribute_effect_applied.connect(_on_attribute_effect_applied)
		attribute_map.attribute_effect_removed.connect(_on_attribute_effect_removed)
		attribute_map.effect_applied.connect(_on_effect_applied)
	
	# Setup ability container
	if ability_container and attribute_map:
		# Configure the AbilityContainer to use our GameplayAttributeMap
		if ability_container.gameplay_attribute_map_path.is_empty():
			ability_container.gameplay_attribute_map_path = attribute_map.get_path()
			ability_container.gameplay_attribute_map = attribute_map
			
		# Add tags after initialization is complete
		call_deferred("_add_ability_tags")

# Add ability tags after initialization is complete
func _add_ability_tags() -> void:
	if ability_container:
		ability_container.add_tag("can_attack")
		ability_container.add_tag("attack_ready")

func initialize_navigation_agent() -> void:
	navigation_agent_2d.path_desired_distance = 5.0
	navigation_agent_2d.target_desired_distance = 5.0
# Méthode pour mettre à jour n'importe quel attribut
func update_attribute(attribute_name: String, value: float) -> void:
	var attr = attribute_map.get_attribute_by_name(attribute_name)
	if attr:
		attr.current_value = value

# Méthode simplifiée pour appliquer les attributs dérivés
func apply_derived_attributes() -> void:
	if not attribute_map:
		return
	
	# Utiliser le calculateur pour obtenir les valeurs dérivées
	var derived_values = DerivedStatsCalculator.calculate_base_derived_stats(attribute_map)
	
	# Appliquer via le calculateur
	DerivedStatsCalculator.apply_derived_stats(attribute_map, derived_values, "BaseDerivedStats")

# Méthode publique pour recalculer les attributs dérivés explicitement
# À utiliser lors de level up, changement d'équipement, etc.
func recalculate_derived_attributes() -> void:
	apply_derived_attributes()

func get_attribute_value(attribute_name: String) -> float:
	var attr = attribute_map.get_attribute_by_name(attribute_name)
	if attr:
		return attr.current_buffed_value
	return 0.0

# Méthode appelée lorsqu'un attribut est modifié (pour compatibilité)
func _on_attribute_changed(attribute: AttributeSpec) -> void:
	if attribute.attribute_name == "health":
		update_health_bar()

	if attribute.current_buffed_value <= 0 and ability_container and not ability_container.has_tag("dead"):
		ability_container.add_tag("dead")
		modulate = Color(0.5, 0.0, 0.0, 0.5)
		freeze = true
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
