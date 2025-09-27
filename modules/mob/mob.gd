extends RigidBody2D

@export var navigation_agent_2d: NavigationAgent2D
@export var mob_attack: Ability
@export var floating_damage_scene: PackedScene
@export var movement_speed: float = 80.0
@export var target_detection_range: float = 300.0
@export var attack_range: float = 30.0  # Distance when we're "close enough"
@export var force_multiplier: float = 15.0  # For movement responsiveness
@export var flee_health_threshold: float = 0.3  # Flee when health below this percentage

@export_group("Base Stats")
@export var base_strength: float = 8.0
@export var base_dexterity: float = 6.0
@export var base_intelligence: float = 4.0
@export var base_health: float = 50.0
@export var base_mana: float = 20.0

var target: Node2D = null
var attribute_map: GameplayAttributeMap
var ability_container: AbilityContainer

func _ready() -> void:
	add_to_group("mob")
	
	setup_gameplay_systems()
	initialize_navigation_agent()
	
	update_health_bar()

func _physics_process(_delta: float) -> void:
	if ability_container and ability_container.has_tag("dead"):
		return
	
	ensure_target_exists()
	
	if target == null:
		return
	
	var distance_to_target = global_position.distance_to(target.global_position)
	var current_stats = get_character_stats()
	var target_stats = get_target_stats()
	
	var behavior = AIBehaviors.decide_behavior(current_stats, target_stats, distance_to_target)
	
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
			pass
		AIBehaviors.BehaviorState.DEAD:
			pass

func setup_gameplay_systems() -> void:
	attribute_map = $GameplayAttributeMap
	ability_container = $AbilityContainer
	
	if attribute_map:
		update_attribute("strength", base_strength)
		update_attribute("dexterity", base_dexterity)
		update_attribute("intelligence", base_intelligence)
		update_attribute("health", base_health)
		update_attribute("mana", base_mana)
		
		update_derived_stats()
		
		attribute_map.attribute_changed.connect(_on_attribute_changed)
		attribute_map.attribute_effect_applied.connect(_on_attribute_effect_applied)
		attribute_map.attribute_effect_removed.connect(_on_attribute_effect_removed)
		attribute_map.effect_applied.connect(_on_effect_applied)
	
	if ability_container:
		load_mob_abilities()
		
		ability_container.add_tag("can_attack")
		ability_container.add_tag("attack_ready")

func initialize_navigation_agent() -> void:
	navigation_agent_2d.path_desired_distance = 5.0
	navigation_agent_2d.target_desired_distance = 5.0
func ensure_target_exists() -> void:
	if target == null:
		find_player()

func set_navigation_target() -> void:
	navigation_agent_2d.target_position = target.global_position

func is_within_attack_range() -> bool:
	var distance_to_target = global_position.distance_to(target.global_position)
	return distance_to_target <= attack_range

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

func find_player() -> void:
	target = null
	var main_node = get_parent()
	
	for node in main_node.get_children():
		if is_valid_player_target(node):
			target = node
			break

func is_valid_player_target(node: Node) -> bool:
	return node.name.contains("Player") and node != self

func update_attribute(attribute_name: String, value: float) -> void:
	var attr = attribute_map.get_attribute_by_name(attribute_name)
	if attr:
		attr.current_value = value

func update_derived_stats() -> void:
	var str_value = get_attribute_value("strength")
	var dex_value = get_attribute_value("dexterity")
	var _int_value = get_attribute_value("intelligence")
	
	update_attribute("attack", str_value * 1.2)
	update_attribute("crit_chance", dex_value * 0.3)
	update_attribute("defense", str_value * 0.7)
	update_attribute("movement_speed", movement_speed * (1.0 + dex_value * 0.005))

func get_attribute_value(attribute_name: String) -> float:
	var attr = attribute_map.get_attribute_by_name(attribute_name)
	if attr:
		return attr.current_buffed_value
	return 0.0

func _on_attribute_changed(attribute: AttributeSpec) -> void:
	if attribute.attribute_name in ["strength", "dexterity", "intelligence"]:
		update_derived_stats()
	
	if attribute.attribute_name == "health":
		update_health_bar()
		
		if attribute.current_buffed_value <= 0 and not ability_container.has_tag("dead"):
			ability_container.add_tag("dead")
			
			modulate = Color(0.0, 0.0, 0.5, 0.5)
			freeze = true
			
			var death_timer = Timer.new()
			death_timer.wait_time = 1.5
			death_timer.one_shot = true
			death_timer.timeout.connect(func(): queue_free())
			add_child(death_timer)
			death_timer.start()

func load_mob_abilities() -> void:
	ability_container.grant(mob_attack)

func _on_attribute_effect_applied(attribute_effect: AttributeEffect, attribute: AttributeSpec) -> void:
	if attribute.attribute_name == "health":
		update_health_bar()
		
		if attribute_effect.minimum_value < 0:
			var damage_value = -attribute_effect.minimum_value
			
			var is_critical = false
			if attribute_effect.has_meta("critical") and attribute_effect.get_meta("critical") == true:
				is_critical = true
				
			var damage_color = Color.WHITE
			if is_critical:
				damage_color = Color(1.0, 1.0, 0.0)  # Yellow for player critical damage
			
			show_floating_damage(damage_value, is_critical, damage_color)
			
		elif attribute_effect.minimum_value > 0:
			pass

func _on_attribute_effect_removed(_attribute_effect: AttributeEffect, _attribute: AttributeSpec) -> void:
	pass
func _on_effect_applied(_effect: GameplayEffect) -> void:
	pass

func get_character_stats() -> Dictionary:
	var health_attr = attribute_map.get_attribute_by_name("health")
	var max_health = 50.0
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

func get_target_stats() -> Dictionary:
	if not target or not target.has_node("GameplayAttributeMap"):
		return {
			"health": 100,
			"max_health": 100,
			"attack": 10,
			"defense": 5
		}
	
	var target_attr = target.get_node("GameplayAttributeMap")
	var health = get_target_attribute_value(target_attr, "health")
	
	var max_health = 100.0
	var health_attribute = target_attr.get_attribute_by_name("health")
	if health_attribute:
		max_health = health_attribute.maximum_value
	
	return {
		"health": health,
		"max_health": max_health,
		"attack": get_target_attribute_value(target_attr, "attack"),
		"defense": get_target_attribute_value(target_attr, "defense")
	}

func get_target_attribute_value(attr_map: GameplayAttributeMap, attr_name: String) -> float:
	var attr = attr_map.get_attribute_by_name(attr_name)
	if attr:
		return attr.current_buffed_value
	return 0.0

func handle_flee_behavior() -> void:
	if target == null:
		return
	
	var flee_direction = AIBehaviors.calculate_flee_direction(global_position, target.global_position)
	var flee_target_point = global_position + flee_direction * 200.0
	
	navigation_agent_2d.target_position = flee_target_point
	
	if not navigation_agent_2d.is_navigation_finished():
		var next_position = navigation_agent_2d.get_next_path_position()
		var nav_direction = calculate_direction_to(next_position)
		apply_movement_force(nav_direction)
	else:
		apply_movement_force(flee_direction)

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
