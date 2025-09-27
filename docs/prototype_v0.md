# Prototype V0 - Auto ARPG

Ce document définit les spécifications et l'architecture de base pour la première version prototype (V0) de notre jeu Auto ARPG.

## 1. Composants du Prototype

### 1.1 Système de Map

#### Caractéristiques
- Une seule map/type de map pour le prototype
- Génération procédurale simple
- Condition spéciale : spawn du boss quand 75% des mobs sont éliminés

#### Structure Technique
- **Représentation de la map** : Tilemap 2D avec plusieurs couches (sol, obstacles, décor)
- **Stockage au runtime** : 
  - Utilisation de `TileMap` pour la représentation visuelle
  - Structure de données séparée (`Array2D` ou dictionnaire) pour stocker les informations logiques
  - Classe `MapData` pour encapsuler les données de la map

#### Génération Procédurale
- Outil : Addon Gaea pour Godot 4
- Algorithme de base : Cellular Automata via l'interface de Gaea
- Points clés :
  1. Génération de la forme de base du terrain via graphe Gaea
  2. Placement des obstacles avec paramètres ajustables
  3. Placement des spawners de mobs (avec densité configurable)
  4. Définition du point de spawn du boss


### 1.2 Système de Joueur

#### Caractéristiques
- Statistiques de base : Attack, HP, Mana
- Système d'expérience et de niveaux
- Points par niveau à distribuer entre Force (HP), Dextérité (Attack), Intelligence (Mana)
- Attaque à distance uniquement
- Comportement automatisé

#### Comportement Automatique
- Déplacement vers le mob le plus proche, avec distance de sécurité
- Tir sur le mob en ligne de mire le plus proche

#### Structure Technique
- Classe `Player` héritant de `CharacterBody2D`
- Composant `StatSystem` pour gérer les statistiques
- Composant `BehaviorController` pour l'IA


### 1.3 Système de Mobs

#### Types de Mobs
- **Mob Melee** : Attaque au corps à corps
- **Mob Distance** : Attaque à distance

#### Caractéristiques Communes
- HP
- Dégâts d'attaque
- XP donnée à la mort

#### Structure Technique
- Classe de base `Mob` héritant de `CharacterBody2D`
- Sous-classes `MeleeMob` et `RangedMob`
- Système de spawn basé sur les "spawners" placés sur la map


### 1.4 Système de Boss

#### Caractéristiques
- 10x vie par rapport aux mobs normaux
- 2x dégâts par rapport aux mobs normaux
- 5x XP par rapport aux mobs normaux
- Apparaît quand 75% des mobs sont éliminés

#### Structure Technique
- Classe `Boss` héritant de `Mob` avec modificateurs
- Événement spécial pour l'apparition


### 1.5 Système de Hideout/UI

#### Interface minimale
- Écran de stats du joueur
- Distribution des points de caractéristiques
- Bouton pour lancer une nouvelle map

#### Structure Technique
- Scène `Hideout` avec UI de base
- Système de transition entre hideout et map
## 2. Architecture Globale

### 2.1 Structure des Dossiers

Structure de dossiers :

### 2.2 Composants principaux

#### GameManager (Singleton)
- Point d'entrée central du jeu
- Coordonne les systèmes principaux

#### MapManager
- Gère la génération et le cycle de vie des maps
- Suit la progression (% de mobs tués) pour déclencher le boss

#### EntityManager
- Gère le spawn et le suivi des entités (joueur, mobs)
- Fournit des méthodes pour trouver des cibles (ex: mob le plus proche)

#### StatSystem
- Système générique pour gérer les statistiques
- Utilisé par le joueur et les mobs

#### BehaviorSystem
- Gère les comportements automatiques
- Implémente différentes stratégies de déplacement et d'attaque

### 2.3 Flow du Gameplay

1. Joueur commence dans le hideout
2. Joueur lance une map (bouton dans l'UI)
3. Map est générée procéduralement
4. Joueur apparaît et commence à combattre automatiquement
5. Mobs apparaissent à partir des spawners
6. Quand 75% des mobs sont éliminés, le boss apparaît
7. Si le joueur meurt : retour au hideout
8. Si le boss est vaincu : retour au hideout avec récompenses

## 3. Addons Sélectionnés

Pour ce prototype, nous utiliserons les addons suivants :

### 3.1 Wyvernbox
- **Justification** : Système d'inventaire spécifique aux ARPG avec génération de loot intégrée
- **Utilisation** : Gestion des objets, inventaire et génération procédurale d'équipements
- **Source** : https://github.com/don-tnowe/godot-wyvernbox-inventory

### 3.2 Godot Gameplay Attributes
- **Justification** : Système flexible de gestion d'attributs pour les statistiques
- **Utilisation** : Implémentation des attributs (Force, Dextérité, Intelligence) et stats dérivées
- **Source** : https://github.com/OctoD/godot_gameplay_attributes

### 3.3 Godot Gameplay Abilities
- **Justification** : Système pour créer et gérer les compétences et actions automatiques
- **Utilisation** : Définition des comportements automatiques d'attaque et de compétences
- **Source** : https://github.com/OctoD/godot-gameplay-abilities

### 3.4 LimboAI
- **Justification** : Solution moderne et puissante pour implémenter l'IA du joueur et des mobs
- **Utilisation** : Définir les comportements automatiques (déplacement, sélection de cibles) avec arbres de comportement et machines à états hiérarchiques
- **Source** : https://github.com/limbonaut/limboai

### 3.5 Gaea
- **Justification** : Addon de génération procédurale pour Godot 4
- **Utilisation** : Création de maps procédurales via système de graphes
- **Source** : https://github.com/gaea-godot/gaea

## 4. Implémentation Technique

### 4.1 Système de Statistiques avec Gameplay Attributes

**Système de Statistiques :**

Implémentation des statistiques avec Godot Gameplay Attributes :
- Conteneur d'attributs (`AttributeContainer`) attaché au joueur et aux mobs
- Stats primaires : Force (HP), Dextérité (Attaque), Intelligence (Mana)
- Stats dérivées calculées automatiquement à partir des stats de base
- Système de buffs pour les modifications temporaires (équipements, potions)
- 3 points d'attributs à distribuer par niveau gagné
- Système d'expérience intégré avec événements sur niveau supérieur

### 4.2 Comportement Automatique avec Gameplay Abilities et LimboAI

**Comportement Automatique du Joueur :**

Tirer parti des capacités avancées de LimboAI et les combiner avec Godot Gameplay Abilities :

#### LimboAI pour la prise de décision

- **Arbres de comportement (BT)** pour la logique de haut niveau :
  - Identification de la cible la plus proche via le système de Blackboard
  - Maintien d'une distance de sécurité optimale avec décorateurs de distance
  - Rapprochement si trop loin, éloignement si trop proche via actions spécifiques
  - Vérification de la ligne de mire avec conditions intégrées
  - Utilisation de BTPlayer pour exécuter les arbres de comportement

- **Machines à états hiérarchiques (HSM)** pour la gestion des états :
  - État d'exploration (recherche d'ennemis)
  - État de combat (engagement avec un ou plusieurs ennemis)
  - État d'évitement (esquive des attaques ou zones dangereuses)
  - État de récupération (régénération, consommation d'objets)
  - Utilisation du noeud LimboHSM pour gérer les transitions entre états

- **Système de Blackboard** pour le partage de données :
  - Stockage des cibles actuelles et potentielles
  - Partage d'informations entre plusieurs agents (joueur, alliés)
  - Variables de configuration pour ajuster le comportement en temps réel

#### Gameplay Abilities pour les actions spécifiques

- **Abilities** pour les actions concrètes :
  - Ability d'attaque à distance avec cooldown
  - Abilities défensives déclenchées automatiquement selon conditions
  - Abilities de déplacement et d'évitement
  - Abilities de support et consommation d'objets

#### Intégration entre les deux systèmes

- LimboAI pour la **décision** et Gameplay Abilities pour **l'exécution** :
  - Les arbres de comportement et machines à états de LimboAI décident quand octroyer/révoquer les abilities
  - Les abilities utilisent les attributs pour les calculs de dégâts
  - Communication bidirectionnelle : LimboAI peut réagir aux résultats des abilities

#### Avantages de l'architecture LimboAI

- **Modularité** : Création et réutilisation faciles de sous-comportements
- **Débogage visuel** : Inspection des arbres de comportement en temps réel
- **Performances optimisées** grâce à l'implémentation C++ avec interface GDScript
- **Compatibilité Godot 4.x** garantie pour le développement futur

### 4.3 Génération Procédurale de Map

**Génération Procédurale de Map avec Gaea :**

Utilisation de Gaea pour la génération procédurale :
- Création d'un graphe de génération dans l'interface de Gaea
- Utilisation du générateur Cellular Automata de Gaea pour un terrain organique
- Configuration des paramètres de génération via l'interface visuelle
- Post-traitement pour l'identification des zones ouvertes et le placement des spawners
- Map de taille fixe (par ex. 100x100 tuiles)
- Intégration du résultat dans un TileMap pour la représentation visuelle
- Scripts personnalisés pour ajouter la logique spécifique au jeu (spawners, boss, etc.)

## 5. Points à Développer par la Suite

- **Objets et équipement avancés** : Étendre Wyvernbox avec plus de types d'objets, d'affixes et de statistiques
- **Types de maps variés** : Différents biomes, structures et modèles de génération
- **Compétences et sorts multiples** : Étoffer les Gameplay Abilities avec plus d'options et d'effets
- **Interface utilisateur complète pour le hideout** : Gestion d'équipe, statistiques détaillées
- **Système de file d'attente de maps** : Automatisation de séquences de maps
- **Target farming** : Spécialisation dans certains types de ressources/équipements
- **Sauvegarde de progression**

## 6. Estimation de Développement

Pour ce prototype initial, l'estimation de développement est :
- **Mise en place de l'architecture de base** : 2-3 jours
- **Système de génération de map** : 2 jours
- **Système de joueur et mobs** : 3-4 jours
- **Interface utilisateur minimale** : 1-2 jours
- **Tests et équilibrage** : 2 jours

**Total estimé** : 10-13 jours de développement
