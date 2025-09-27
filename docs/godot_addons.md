# Addons Godot pour Auto ARPG

Ce document présente une sélection d'addons Godot qui pourraient être utiles pour le développement de notre jeu Auto ARPG. Chaque addon est évalué en fonction de sa pertinence pour les différents systèmes du jeu.

## Génération procédurale

### 1. [Gaea](https://github.com/gaea-godot/gaea) - ADOPTÉ ✓
- **Description** : Addon de génération procédurale pour Godot 4 utilisant un système de graphes.
- **Fonctionnalités** : Système visuel de nœuds, générateurs multiples (Cellular Automata, Heightmap, Walker).
- **Avantages** : Interface visuelle intuitive, support 2D et 3D, extensible avec des nœuds personnalisés.
- **Compatibilité** : Compatible avec Godot 4.4 (version principale) et 4.3 (versions antérieures).
- **Utilité pour notre projet** : ⭐⭐⭐⭐⭐ (Solution choisie pour la génération de maps)

## Inventaire et Équipement

### 1. [Wyvernbox](https://github.com/don-tnowe/godot-wyvernbox-inventory) - ADOPTÉ ✓
- **Description** : Système d'inventaire focalisé ARPG pour Godot 3 et 4
- **Fonctionnalités** : Inventaires flexibles, gestion d'objets, génération de loot, tables de butin
- **Avantages** : Solution complète combinant inventaire et génération d'objets spécialement pour ARPG
- **Utilité pour notre projet** : ⭐⭐⭐⭐⭐ (Solution choisie pour le projet)

## Intelligence Artificielle et Comportement

### 1. [LimboAI](https://github.com/limbonaut/limboai) - ADOPTÉ ✓
- **Description** : Plugin C++ pour Godot 4 combinant arbres de comportement et machines à états hiérarchiques.
- **Fonctionnalités** : 
  - Éditeur d'arbre de comportement visuel intégré
  - Débogueur visuel pour analyser l'exécution des arbres
  - Système de blackboard avancé avec portages multiples
  - Machines à états hiérarchiques (HSM) intégrées
  - Suivi des performances et optimisations C++
  - Documentation intégrée au moteur
- **Avantages** : 
  - Moderne et spécifiquement optimisé pour Godot 4.4
  - Combinaison puissante d'arbres de comportement et machines à états
  - Code C++ pour les performances avec interface complète en GDScript
  - Soutien actif et mises à jour régulières
  - Excellente documentation et exemples
  - Possibilité de réutiliser des sous-arbres pour une modularité maximale
- **Utilité pour notre projet** : ⭐⭐⭐⭐⭐ (Solution choisie pour l'automatisation du personnage)

### 2. [AStar Pathfinding](https://docs.godotengine.org/en/stable/classes/class_astar.html)
- **Description** : Algorithme de pathfinding intégré à Godot.
- **Fonctionnalités** : Navigation optimale des personnages.
- **Avantages** : Performant et déjà inclus dans Godot.
- **Utilité pour notre projet** : ⭐⭐⭐⭐⭐ (Essentiel pour le déplacement automatique)

## Sauvegarde et Gestion de Données

### 1. [Système de sauvegarde intégré à Godot](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html) - ADOPTÉ ✓
- **Description** : Système natif de sérialisation et sauvegarde de Godot.
- **Fonctionnalités** : Conversion en dictionnaires, sauvegarde JSON ou binaire, chargement facilité.
- **Avantages** : Intégré au moteur, pas besoin d'addon externe, simplicité d'utilisation.
- **Utilité pour notre projet** : ⭐⭐⭐⭐⭐ (Solution native parfaitement adaptée au prototype)
- **Utilisation dans notre projet** : Sauvegarde de la progression du joueur, des statistiques et configurations

## Statistiques et Progression

### 1. [Godot Gameplay Systems](https://github.com/OctoD/godot-gameplay-systems) - ADOPTÉ ✓
- **Description** : Suite complète de systèmes de gameplay pour Godot 4
- **Fonctionnalités** : 
  - Système d'attributs et de statistiques
  - Système d'abilités et de compétences
  - Inventaire et équipement
  - Interactions avec objets
  - Effets de caméra et slideshow
  - Système de combat au tour par tour
- **Avantages** : 
  - Solution intégrée et cohérente
  - En GDScript natif (pas de compilation nécessaire)
  - Facile à étendre et personnaliser
  - Conçu spécifiquement pour les RPG
- **Utilité pour notre projet** : ⭐⭐⭐⭐⭐ (Solution choisie pour les mécaniques centrales du jeu)

## Effets Visuels

### 1. [Godot Particle Systems](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html) - INTÉGRÉ AU MOTEUR ✓
- **Description** : Système de particules intégré à Godot.
- **Fonctionnalités** : Effets visuels variés (explosions, magie, etc.).
- **Avantages** : Déjà inclus dans Godot, performant.
- **Utilité pour notre projet** : ⭐⭐⭐⭐ (Important pour le feedback visuel)

### 2. [Godot Shaders Library](https://github.com/GDQuest/godot-shaders) - EN CONSIDÉRATION
- **Description** : Collection de shaders prêts à l'emploi.
- **Fonctionnalités** : Effets visuels avancés.
- **Avantages** : Améliore l'aspect visuel sans effort.
- **Utilité pour notre projet** : ⭐⭐⭐ (Utile pour l'amélioration visuelle)

## Addons de Performance

### 1. [GodotProfiler](https://github.com/deepnight/godotprofiler) - ADOPTÉ ✓
- **Description** : Outil de profilage pour optimiser les performances.
- **Fonctionnalités** : Suivi des performances, détection des goulets d'étranglement.
- **Avantages** : Aide à optimiser le jeu pour des sessions longues.
- **Utilité pour notre projet** : ⭐⭐⭐⭐⭐ (Essentiel pour un jeu idle/automatique)
- **Utilisation dans notre projet** : Optimisation des performances, identification des goulets d'étranglement

### 2. [Object Pooling](https://github.com/godotengine/godot-demo-projects/tree/master/misc/object_pool) - REPORTÉ
- **Description** : Système de pooling d'objets pour optimiser les performances.
- **Fonctionnalités** : Réutilisation d'objets au lieu de création/destruction.
- **Avantages** : Réduit la charge du ramasse-miettes, améliore les performances.
- **Utilité pour notre projet** : ⭐⭐⭐⭐ (Potentiellement utile pour les versions futures)
- **Note** : Mis de côté pour la version prototype, à reconsidérer pour les versions ultérieures

## Addons Sélectionnés

Après évaluation, nous avons choisi les addons suivants pour le développement du prototype:

### 1. [Wyvernbox](https://github.com/don-tnowe/godot-wyvernbox-inventory) - ADOPTÉ ✓
- **Description** : Système d'inventaire focalisé ARPG pour Godot 3 et 4
- **Fonctionnalités** : Inventaires flexibles, gestion d'objets, génération de loot, tables de butin
- **Utilisation dans notre projet** : Système complet pour inventaire, objets et génération procédurale d'équipements

### 2. [Godot Gameplay Systems](https://github.com/OctoD/godot-gameplay-systems) - ADOPTÉ ✓
- **Description** : Suite complète de systèmes de gameplay pour Godot 4
- **Fonctionnalités** : Système d'attributs, d'abilités, d'inventaire et d'interactions
- **Utilisation dans notre projet** : 
  - Gestion des statistiques (STR, DEX, INT, HP, Mana)
  - Automatisation des compétences et des actions du personnage
  - Gestion des effets d'équipement et buffs/debuffs
  - Système d'interaction pour le ramassage d'objets

### 3. [Gaea](https://github.com/gaea-godot/gaea) - ADOPTÉ ✓
- **Description** : Addon de génération procédurale pour Godot 4
- **Fonctionnalités** : Système visuel de nœuds, générateurs multiples
- **Utilisation dans notre projet** : Génération procédurale des maps

### 4. [LimboAI](https://github.com/limbonaut/limboai) - ADOPTÉ ✓
- **Description** : Plugin C++ pour Godot 4 combinant arbres de comportement et machines à états hiérarchiques
- **Fonctionnalités** : Éditeur d'arbre intégré, débogueur visuel, système de blackboard avancé, machines à états hiérarchiques, compatibilité Godot 4.4
- **Utilisation dans notre projet** : 
  - Implémentation des comportements automatiques du joueur et des ennemis
  - Création d'arbres de décision modulaires et réutilisables
  - Gestion des états du personnage (combat, exploration, évitement, récupération)
  - Partage d'informations entre agents via le système de blackboard

### 5. [GodotProfiler](https://github.com/deepnight/godotprofiler) - ADOPTÉ ✓
- **Description** : Outil de profilage pour optimiser les performances
- **Fonctionnalités** : Suivi des performances, détection des goulets d'étranglement
- **Utilisation dans notre projet** : Optimisation des performances pour les sessions de jeu automatiques prolongées

### 6. [Système de sauvegarde intégré à Godot](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html) - ADOPTÉ ✓
- **Description** : Système natif de sérialisation et sauvegarde de Godot
- **Fonctionnalités** : Conversion en dictionnaires, sauvegarde JSON ou binaire
- **Utilisation dans notre projet** : Sauvegarde de la progression du joueur, des statistiques et configurations

Ces addons couvrent les fonctionnalités essentielles pour notre prototype et permettront un développement efficace des mécaniques d'un ARPG automatisé.

## Développement Personnel

Certains systèmes spécifiques à notre jeu, comme la file d'attente des maps et la configuration de l'automatisation, devront probablement être développés sur mesure car ils sont uniques à notre concept.

## Note sur la Compatibilité

Parmi les addons sélectionnés, LimboAI est explicitement compatible avec Godot 4.4, ce qui en fait un excellent choix pour notre projet. Il est important de vérifier la compatibilité des autres addons avec Godot 4.4, car certains peuvent avoir été développés pour des versions antérieures. Dans le cas où un addon n'est pas compatible, il pourrait être nécessaire de l'adapter ou de trouver une alternative.
