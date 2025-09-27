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
- Algorithme de base : Cellular Automata pour un terrain organique
- Points clés :
  1. Génération de la forme de base du terrain
  2. Placement des obstacles
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

## 3. Addons Essentiels

Pour ce prototype, nous recommandons les addons suivants :

### 3.1 Godot Behavior Tree
- **Justification** : Essentiel pour implémenter l'IA du joueur et des mobs
- **Utilisation** : Définir les comportements automatiques (déplacement, combat)

### 3.2 Simple Inventory System
- **Justification** : Base pour le futur système d'inventaire (non implémenté dans le prototype)
- **Utilisation** : Préparation pour les versions futures

### 3.3 Cellular Automata (ou équivalent)
- **Justification** : Génération procédurale de la map
- **Utilisation** : Créer des terrains variés et organiques

### 3.4 Godot RPG Stats (ou équivalent)
- **Justification** : Gestion des statistiques du joueur et des mobs
- **Utilisation** : Implémentation du système de statistiques et de progression

## 4. Implémentation Technique

### 4.1 Système de Statistiques

**Système de Statistiques :**

Conceptions des statistiques du joueur :
- Stats de base : Force (HP), Dextérité (Attaque), Intelligence (Mana)
- Stats dérivées calculées à partir des stats de base
- Système d'expérience avec niveau et points de stat à dépenser
- 3 points de stat par niveau gagné
- Calcul automatique des stats dérivées après changement de stats

### 4.2 Comportement Automatique du Joueur

**Comportement Automatique du Joueur :**

Logique de comportement du joueur :
- Identification de la cible la plus proche
- Maintien d'une distance de sécurité optimale avec la cible
- Rapprochement si trop loin, éloignement si trop proche
- Vérification de la ligne de mire avant d'attaquer
- Attaque automatique quand la cible est en vue et le cooldown terminé

### 4.3 Génération Procédurale de Map

**Génération Procédurale de Map :**

Principe de l'algorithme Cellular Automata pour la génération de map :
- Initialisation avec du bruit aléatoire (murs et sols)
- Application itérative des règles de l'automate cellulaire pour lisser le terrain
- Identification des zones ouvertes pour le placement des spawners de mobs
- Détection des zones suffisamment spacieuses pour les spawns
- Map de taille fixe (par ex. 100x100 tuiles)
- Paramètres ajustables pour la densité des obstacles et le lissage

## 5. Points à Développer par la Suite

- **Système d'objets et d'équipement**
- **Types de maps variés**
- **Compétences et sorts multiples**
- **Interface utilisateur complète pour le hideout**
- **Système de file d'attente de maps**
- **Sauvegarde de progression**

## 6. Estimation de Développement

Pour ce prototype initial, l'estimation de développement est :
- **Mise en place de l'architecture de base** : 2-3 jours
- **Système de génération de map** : 2 jours
- **Système de joueur et mobs** : 3-4 jours
- **Interface utilisateur minimale** : 1-2 jours
- **Tests et équilibrage** : 2 jours

**Total estimé** : 10-13 jours de développement
