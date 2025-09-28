extends Panel

var player: Node

@onready var level_label = %LevelLabel
@onready var characteristics_points_label = %CharacteristicsPointsLabel
@onready var dexterity_value_label = %DexterityValueLabel
@onready var force_value_label = %ForceValueLabel
@onready var intelligence_value_label = %IntelligenceValueLabel

@onready var upgrade_dexterity_button = %UpgradeDexterityButton
@onready var upgrade_force_button = %UpgradeForceButton
@onready var upgrade_intelligence_button = %UpgradeIntelligenceButton

func set_player(player_node: Node) -> void:
	# Disconnect from the old player's attribute map if it exists and is connected
	if is_instance_valid(player) and player.has_node("GameplayAttributeMap"):
		var old_attribute_map = player.get_node("GameplayAttributeMap")
		if old_attribute_map.attribute_changed.is_connected(update_display):
			old_attribute_map.attribute_changed.disconnect(update_display)
	
	player = player_node
	
	# Connect to the new player's attribute map
	if is_instance_valid(player) and player.has_node("GameplayAttributeMap"):
		var attribute_map = player.get_node("GameplayAttributeMap")
		attribute_map.attribute_changed.connect(update_display)
		update_display()
	else:
		# Handle the case where the player or attribute map is not ready
		# You might want to disable the panel or show a message
		pass

func update_display(_attribute = null) -> void:
	if not is_instance_valid(player):
		return
	
	var points = player.get_attribute_value("characteristic_points")
	level_label.text = str(player.get_attribute_value("level"))
	characteristics_points_label.text = str(points)
	dexterity_value_label.text = str(player.get_attribute_value("dexterity"))
	force_value_label.text = str(player.get_attribute_value("strength"))
	intelligence_value_label.text = str(player.get_attribute_value("intelligence"))
	
	var can_upgrade = points > 0
	upgrade_dexterity_button.disabled = not can_upgrade
	upgrade_force_button.disabled = not can_upgrade
	upgrade_intelligence_button.disabled = not can_upgrade



func _on_upgrade_dexterity_button_pressed() -> void:
	if player:
		player.spend_characteristic_point("dexterity")


func _on_upgrade_force_button_pressed() -> void:
	if player:
		player.spend_characteristic_point("strength")


func _on_upgrade_intelligence_button_pressed() -> void:
	if player:
		player.spend_characteristic_point("intelligence")
