extends CanvasLayer

@onready var level_label := %LevelLabel
@onready var exp_bar := %ExperienceProgressBar
@onready var character_panel := $Control/VBoxContainer/Control/PanelsControl/CharacterPanel

func _ready() -> void:
	call_deferred("connect_to_player_signals")

func connect_to_player_signals() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var attribute_map = player.get_attribute_map()
		if attribute_map:
			attribute_map.attribute_changed.connect(_on_player_attribute_changed)
			
		if character_panel:
			character_panel.set_player(player)
			
			update_level_display(attribute_map.get_attribute_by_name("level"))
			update_exp_bar(attribute_map.get_attribute_by_name("experience"), 
						 attribute_map.get_attribute_by_name("experience_required"))

func _on_player_attribute_changed(attribute: AttributeSpec) -> void:
	match attribute.attribute_name:
		"level":
			update_level_display(attribute)
		"experience":
			update_exp_bar(attribute, null)
		"experience_required":
			update_exp_bar(null, attribute)

func update_level_display(level_attribute: AttributeSpec) -> void:
	if level_label and level_attribute:
		level_label.text = "Niveau " + str(int(level_attribute.current_value))

func update_exp_bar(exp_attribute: AttributeSpec = null, exp_required_attribute: AttributeSpec = null) -> void:
	if not exp_bar:
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
		
	var attribute_map = player.get_attribute_map()
	if not attribute_map:
		return
		
	if exp_attribute:
		exp_bar.value = exp_attribute.current_value
		
	if exp_required_attribute:
		exp_bar.max_value = exp_required_attribute.current_value
		
	exp_bar.modulate = Color(0.5, 0.5, 1.0)  # Bleu clair


func _on_chararcter_button_pressed() -> void:
	if character_panel:
		character_panel.visible = not character_panel.visible
