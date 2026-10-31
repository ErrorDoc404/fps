class_name PlayerHealth
extends RefCounted
## Server-authoritative health, armor, downed and elimination state for one operator.

signal downed
signal eliminated
signal revived

var max_health: float
var max_armor: float
var health: float
var armor: float
var is_downed := false
var is_eliminated := false
var bleedout := 0.0

func _init(armor_bonus := 0.0) -> void:
	var r := GameData.player_rules
	max_health = r["max_health"]
	max_armor = float(r["max_armor"]) + armor_bonus
	health = max_health
	armor = max_armor

func alive() -> bool:
	return not is_downed and not is_eliminated

## Returns the health damage actually applied. Armor absorbs a share of incoming damage until depleted.
func apply_damage(amount: float) -> float:
	if is_eliminated or amount <= 0.0:
		return 0.0
	if is_downed:
		bleedout = max(0.0, bleedout - amount * 0.1)  # damage while downed shortens the bleed-out window
		return 0.0
	var absorb_share: float = GameData.player_rules["armor_absorb"]
	var to_armor: float = min(armor, amount * absorb_share)
	armor -= to_armor
	var to_health := amount - to_armor
	health = max(0.0, health - to_health)
	if health <= 0.0:
		is_downed = true
		bleedout = GameData.player_rules["downed_bleedout"]
		downed.emit()
	return to_health

func heal(amount: float) -> void:
	if alive():
		health = min(max_health, health + amount)

func tick(dt: float) -> void:
	if is_downed and not is_eliminated:
		bleedout -= dt
		if bleedout <= 0.0:
			is_eliminated = true
			is_downed = false
			eliminated.emit()

func revive(hp: float) -> void:
	if not is_downed:
		return
	is_downed = false
	health = clampf(hp, 1.0, max_health)
	revived.emit()

func restore_full() -> void:
	is_downed = false
	is_eliminated = false
	health = max_health
	armor = max_armor
