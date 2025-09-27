class_name AIBehaviors extends Node

# Behavior states
enum BehaviorState {
  IDLE,
  PURSUING,
  ATTACKING,
  FLEEING,
  DEAD
}

# Helper function for character to decide behavior based on health and distance
static func decide_behavior(character_stats: Dictionary, target_stats: Dictionary, distance: float) -> int:
  # Get health percentages
  var health_percentage = character_stats.health / character_stats.max_health
  var target_health_percentage = target_stats.health / target_stats.max_health
  
  # If character is dead, no behavior needed
  if character_stats.health <= 0:
    return BehaviorState.DEAD
  
  # Determine behavior based on health and distance
  if health_percentage < 0.3 and target_health_percentage > 0.5:
    # Health is low and target is still strong - flee
    return BehaviorState.FLEEING
  elif distance <= character_stats.attack_range:
    # In attack range - attack
    return BehaviorState.ATTACKING
  elif distance <= character_stats.detection_range:
    # Within detection range - pursue
    return BehaviorState.PURSUING
  else:
    # No target in range - idle
    return BehaviorState.IDLE

# Calculate flee direction (away from target)
static func calculate_flee_direction(character_position: Vector2, target_position: Vector2) -> Vector2:
  return (character_position - target_position).normalized()

# Calculate pursue direction (toward target)
static func calculate_pursue_direction(character_position: Vector2, target_position: Vector2) -> Vector2:
  return (target_position - character_position).normalized()
