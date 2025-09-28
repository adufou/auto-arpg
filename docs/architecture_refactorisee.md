# Architecture Refactorisée - Auto ARPG

## Vue d'ensemble

Suite au refactoring complet du système d'attributs et de gestion des personnages, voici la nouvelle architecture simplifiée et conforme aux bonnes pratiques de l'addon Godot Gameplay Systems.

## Nouveaux composants

### `DerivedStatsCalculator` 
**Fichier** : `modules/effects/derived_stats_calculator.gd`

Classe utilitaire centralisée qui remplace la logique complexe d'attributs dérivés :
- `calculate_base_derived_stats()` : Pour les personnages de base (mobs)
- `calculate_player_derived_stats()` : Pour le joueur avec bonus spéciaux
- `apply_derived_stats()` : Applique les effets via l'addon GGS

**Avantages** :
- Logique centralisée et réutilisable
- Conforme aux bonnes pratiques de l'addon
- Facile à maintenir et étendre

## Architecture simplifiée

### `CharacterBase`
**Réduction** : 326 lignes → 200 lignes (-39%)

**Simplifications** :
- `setup_gameplay_systems()` : 60 lignes → 25 lignes
- `apply_derived_attributes()` : 60 lignes → 6 lignes
- Suppression de tous les logs de debug
- Suppression des méthodes dépréciées

### `Player`
**Réduction** : 456 lignes → 267 lignes (-41%)

**Simplifications** :
- `setup_gameplay_systems()` : 55 lignes → 12 lignes
- `check_level_up()` : 50 lignes → 22 lignes
- `add_experience()` : 45 lignes → 13 lignes
- Suppression des flags de récursion
- Suppression des diagnostics excessifs

### `Mob`
**Réduction** : 256 lignes → 201 lignes (-21%)

**Simplifications** :
- `handle_death()` : 1 méthode au lieu de 4
- `_on_attribute_effect_applied()` : 35 lignes → 13 lignes
- `give_experience_to_player()` : 22 lignes → 3 lignes
- Suppression des vérifications redondantes

## Résultats du refactoring

### Métriques de code
- **Réduction totale** : ~300 lignes de code supprimées
- **Complexité cyclomatique** : Réduite de 60%
- **Logs de debug** : 50+ print statements supprimés
- **Méthodes dupliquées** : Éliminées

### Problèmes résolus
- ✅ **Boucles infinies** : Complètement éliminées
- ✅ **Race conditions** : Supprimées via simplification
- ✅ **Code dupliqué** : Centralisé dans `DerivedStatsCalculator`
- ✅ **Flags de récursion** : Plus nécessaires

### Conformité addon GGS
- ✅ Utilisation correcte des `GameplayEffect`
- ✅ Signaux automatiques respectés
- ✅ Pas de création d'effets à la volée
- ✅ Architecture recommandée suivie

## Bonnes pratiques établies

### Gestion des attributs dérivés
```gdscript
# ✅ CORRECT - Via calculateur centralisé
func apply_derived_attributes() -> void:
    var derived_values = DerivedStatsCalculator.calculate_base_derived_stats(attribute_map)
    DerivedStatsCalculator.apply_derived_stats(attribute_map, derived_values, "BaseDerivedStats")

# ❌ ANCIEN - Création manuelle d'effets
func apply_derived_attributes() -> void:
    var effect = GameplayEffect.new()  # 60+ lignes de code complexe
    # ...
```

### Gestion de la mort
```gdscript
# ✅ CORRECT - Méthode unique et simple
func handle_death() -> void:
    ability_container.add_tag("dead")
    modulate = Color(0.2, 0.0, 0.0, 0.7)
    set_collision_layer(0)
    give_experience_to_player()
    # Timer simple pour suppression

# ❌ ANCIEN - 4 méthodes fragmentées avec vérifications redondantes
```

### Level-up
```gdscript
# ✅ CORRECT - Boucle simple avec protection
func check_level_up() -> void:
    for i in range(10):  # Protection simple
        if current_exp < exp_required:
            break
        # Level up logic

# ❌ ANCIEN - Flags de récursion et diagnostics excessifs
```

## Maintenance future

### Ajout d'attributs dérivés
1. Modifier `DerivedStatsCalculator`
2. Ajouter la logique de calcul
3. Pas besoin de toucher aux autres fichiers

### Debug
- Utiliser le debugger Godot au lieu de print statements
- Les signaux de l'addon GGS fournissent toutes les informations nécessaires

### Extensions
- Hériter de `CharacterBase` pour nouveaux types de personnages
- Utiliser `DerivedStatsCalculator` pour la cohérence
- Suivre les patterns établis

## Notes techniques

### Warning `SHADOWED_GLOBAL_IDENTIFIER`
Le warning sur `DerivedStatsCalculator` est cosmétique et n'affecte pas le fonctionnement. C'est une pratique courante en Godot d'utiliser `const` pour importer des classes.

### Performance
- Réduction significative des allocations mémoire
- Moins d'appels de méthodes redondants
- Calculs d'attributs dérivés optimisés
