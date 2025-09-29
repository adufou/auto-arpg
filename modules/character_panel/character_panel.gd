extends Panel

var player: Node

func _on_upgrade_dexterity_button_pressed() -> void:
	if player:
		player.spend_characteristic_point("dexterity")


func _on_upgrade_force_button_pressed() -> void:
	if player:
		player.spend_characteristic_point("strength")


func _on_upgrade_intelligence_button_pressed() -> void:
	if player:
		player.spend_characteristic_point("intelligence")
