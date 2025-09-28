# Plan de Refactoring - Auto ARPG

## Contexte

Suite à l'analyse du code, nous avons identifié une **complexité excessive** introduite dans les fichiers `mob.gd`, `player.gd` et `character_base.gd` en essayant de fixer des boucles infinies avec l'addon Godot Gameplay Systems (GGS).

## Problèmes identifiés

### 1. **Gestion complexe des attributs dérivés**
- Double système (GameplayEffect + spécialisé) 
- Code répétitif et difficile à maintenir
- Non conforme aux bonnes pratiques de l'addon GGS

### 2. **Protection excessive contre la récursion**
- Multiples flags : `_initialization_in_progress`, `_processing_level_up`, `_updating_level_up_bonuses`
- Méthodes dupliquées : `update_derived_stats()`, `apply_derived_attributes()`, `recalculate_derived_attributes()`
- Masque les vrais problèmes au lieu de les résoudre

### 3. **Gestion de mort des mobs fragmentée**
- 3 méthodes différentes : `_handle_death()`, `_safe_queue_free()`, `give_experience_to_player()`
- Logique éparpillée et difficile à suivre
- Vérifications redondantes (`is_inside_tree()`, tags "dead", timers)

### 4. **Code de diagnostic mélangé**
- Logs verbeux dans le code de production (lignes 85-108, 300-324 dans `player.gd`)
- Rend le code difficile à lire et maintenir

## Bonnes pratiques de l'addon Godot Gameplay Systems

### Architecture recommandée
- **GameplayAttributeMap** : Node central qui gère tous les attributs
- **AttributeEffect** : Pour toutes les modifications (dégâts, buffs, etc.)
- **GameplayEffect** : Conteneur d'effets multiples (ressources)
- **Signaux automatiques** : `attribute_effect_applied`, `attribute_effect_removed`, `effect_applied`

### Ce qu'il faut éviter
- ❌ Recalcul manuel des attributs dérivés
- ❌ Création de GameplayEffect à la volée dans le code
- ❌ Connexion manuelle excessive aux signaux
- ❌ Modification directe des attributs sans passer par `apply_effect()`

## Plan de refactoring (par priorité)

### ✅ **TÂCHE 1 : Simplifier la gestion des attributs dérivés** - TERMINÉE
**Fichiers concernés** : `character_base.gd`, `player.gd`, `mob.gd`

**Actions réalisées** :
1. ✅ Créé `DerivedStatsCalculator` pour centraliser la logique
2. ✅ Supprimé les méthodes complexes `apply_derived_attributes()`, `apply_player_derived_attributes()`
3. ✅ Simplifié `apply_derived_attributes()` à 6 lignes au lieu de 60+
4. ✅ Supprimé les flags de récursion `_initialization_in_progress`
5. ✅ Nettoyé les logs de debug excessifs
6. ✅ Corrigé l'appel à `update_derived_stats()` dans `mob.gd`

**Résultats** :
- ✅ Code conforme aux bonnes pratiques de l'addon
- ✅ Suppression de la complexité liée aux boucles infinies  
- ✅ Maintenance simplifiée (170+ lignes → 50 lignes)
- ✅ Plus d'erreurs de compilation

### 🟡 **TÂCHE 2 : Simplifier la gestion de mort des mobs**
**Fichiers concernés** : `mob.gd`

**Actions** :
1. Fusionner `_handle_death()`, `_safe_queue_free()`, `give_experience_to_player()` en une seule méthode `handle_death()`
2. Supprimer les vérifications redondantes (`is_inside_tree()`)
3. Simplifier la logique de mort en utilisant les signaux de l'addon
4. Nettoyer les logs de debug

**Bénéfices** :
- Logique de mort claire et centralisée
- Moins de code à maintenir
- Suppression des race conditions

### 🟢 **TÂCHE 3 : Simplifier le système de level-up**
**Fichiers concernés** : `player.gd`

**Actions** :
1. Supprimer les flags `_processing_level_up`, `_updating_level_up_bonuses`
2. Simplifier `check_level_up()` sans boucle while complexe
3. Supprimer les logs de diagnostic excessifs
4. Utiliser les GameplayEffect pour les bonus de level-up

**Bénéfices** :
- Code de level-up plus lisible
- Suppression des protections de récursion inutiles
- Conformité avec l'architecture de l'addon

### 🔵 **TÂCHE 4 : Nettoyage général**
**Fichiers concernés** : Tous

**Actions** :
1. Supprimer les méthodes dépréciées gardées "pour compatibilité"
2. Nettoyer tous les logs de debug du code de production
3. Standardiser les noms de méthodes
4. Ajouter une documentation claire sur l'utilisation de l'addon

**Bénéfices** :
- Codebase plus propre
- Maintenance facilitée
- Documentation à jour

## Ordre d'exécution recommandé

1. **Commencer par la TÂCHE 1** (attributs dérivés) car c'est la source principale des boucles infinies
2. **Puis TÂCHE 2** (mort des mobs) car elle est indépendante
3. **Ensuite TÂCHE 3** (level-up) qui dépend de la TÂCHE 1
4. **Finir par TÂCHE 4** (nettoyage) une fois que tout fonctionne

## Notes importantes

- **Une tâche à la fois** pour éviter d'introduire plus de complexité
- **Tester après chaque tâche** pour s'assurer que tout fonctionne
- **Suivre les bonnes pratiques de l'addon** plutôt que de réinventer la roue
- **Garder les fonctionnalités existantes** tout en simplifiant le code

## Ressources

- Documentation addon : `/addons/godot_gameplay_systems/`
- Fichiers à refactorer : `modules/character_base/`, `modules/player/`, `modules/mob/`
- Tests : Vérifier que le level-up, la mort des mobs et les attributs dérivés fonctionnent toujours
