extends Node2D
class_name FloatingDamage

# Propriétés pour personnaliser l'apparence et le comportement
@export var duration: float = 1.0  # Durée totale d'affichage
@export var float_speed: float = 70.0  # Vitesse de déplacement vers le haut
@export var fade_start: float = 0.5  # Moment où le texte commence à s'effacer (en % de la durée)

# Variables internes
var text: String = "0"
var color: Color = Color.WHITE
var time_elapsed: float = 0.0

func _ready() -> void:
	# Configuration initiale
	modulate.a = 1.0

func _process(delta: float) -> void:
	# Mettre à jour le temps écoulé
	time_elapsed += delta
	
	# Déplacer le texte vers le haut
	position.y -= float_speed * delta
	
	# Ajouter un peu de mouvement horizontal aléatoire pour plus de dynamisme
	position.x += sin(time_elapsed * 5) * 0.5
	
	# Gérer la disparition progressive
	if time_elapsed >= duration * fade_start:
		var fade_progress = (time_elapsed - duration * fade_start) / (duration * (1 - fade_start))
		modulate.a = 1.0 - fade_progress
	
	# Supprimer le nœud quand la durée est écoulée
	if time_elapsed >= duration:
		queue_free()

# Configure les valeurs du dégât flottant
func setup(damage_value: float, is_critical: bool = false, damage_color: Color = Color.WHITE) -> void:
	# Arrondir à une décimale
	text = "%.1f" % damage_value
	color = damage_color
	
	# Si c'est un coup critique, ajouter un effet visuel (taille plus grande)
	if is_critical:
		scale = Vector2(1.5, 1.5)

# Dessiner le texte
func _draw() -> void:
	var font = ThemeDB.fallback_font
	var font_size = 16
	
	# Utiliser une ombre pour améliorer la lisibilité sur tous les fonds
	draw_string(font, Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK.darkened(0.5))
	draw_string(font, Vector2(0, 0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
