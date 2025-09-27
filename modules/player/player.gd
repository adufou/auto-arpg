extends RigidBody2D

@export var navigation_agent_2d: NavigationAgent2D
@export var player_attack: Ability
@export var floating_damage_scene: PackedScene
@export var movement_speed: float = 100.0
@export var target_detection_range: float = 500.0
@export var attack_range: float = 48.0  # Adjusted to approximately 3 tiles (16px per tile)
@export var force_multiplier: float = 20.0  # For movement responsiveness
@export var mob_detection_interval: float = 0.5  # How often to search for mobs (in seconds)

# Stats for the character
@export_group("Base Stats")
@export var base_strength: float = 10.0
@export var base_dexterity: float = 10.0
@export var base_intelligence: float = 10.0
@export var base_health: float = 100.0
@export var base_mana: float = 50.0

var target_mob: Node2D = null
var mobs_in_attack_range: Array[Node2D] = []
var detected_mobs: Array[Node2D] = []
var mob_detection_timer: float = 0.0

var attribute_map: GameplayAttributeMap
var ability_container: AbilityContainer

func _ready() -> void:
	add_to_group("player")
	
	setup_gameplay_systems()
	initialize_navigation_agent()
	
	update_health_bar()

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
		load_player_abilities()
		
		ability_container.add_tag("can_attack")
		ability_container.add_tag("attack_ready")

func initialize_navigation_agent() -> void:
	navigation_agent_2d.path_desired_distance = 5.0
	navigation_agent_2d.target_desired_distance = 5.0
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

func stop_movement() -> void:
	apply_central_force(Vector2.ZERO - linear_velocity * 10.0)

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

func calculate_direction_to(target_position: Vector2) -> Vector2:
	return (target_position - global_position).normalized()

func apply_movement_force(direction: Vector2) -> void:
	var desired_velocity = direction * movement_speed
	apply_central_force((desired_velocity - linear_velocity) * force_multiplier)

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

func update_attribute(attribute_name: String, value: float) -> void:
	var attr = attribute_map.get_attribute_by_name(attribute_name)
	if attr:
		attr.current_value = value
func update_derived_stats() -> void:
	var str_value = get_attribute_value("strength")
	var dex_value = get_attribute_value("dexterity")
	var _int_value = get_attribute_value("intelligence")
	
	update_attribute("attack", str_value * 1.5)
	update_attribute("crit_chance", dex_value * 0.5)
	update_attribute("defense", str_value * 0.5 + dex_value * 0.3)
	update_attribute("movement_speed", movement_speed * (1.0 + dex_value * 0.01))


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
			modulate = Color(0.5, 0.0, 0.0, 0.5)
			freeze = true
			
			var death_timer = Timer.new()
			death_timer.wait_time = 1.5
			death_timer.one_shot = true
			death_timer.timeout.connect(func(): queue_free())
			add_child(death_timer)
			death_timer.start()

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

func _on_attribute_effect_removed(_attribute_effect: AttributeEffect, _attribute: AttributeSpec) -> void:
	pass

func _on_effect_applied(_effect: GameplayEffect) -> void:
	pass


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
