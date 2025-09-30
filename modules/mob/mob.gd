extends PhysicalBodyBase

const DISTANCE_TO_SEE_PLAYER = 500.0
const DISTANCE_TO_ATTACK_PLAYER = 100.0

func can_go_to_player():
	var player = PlayerManager.player

	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player > DISTANCE_TO_SEE_PLAYER:
		return false

	if not can_reach(player.global_position):
		return false

	return true

func move_to_player():
	target_pos(PlayerManager.player.global_position)	

func can_attack_player():
	var player = PlayerManager.player

	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player > DISTANCE_TO_ATTACK_PLAYER:
		return false

	if not can_reach(player.global_position):
		return false

	return true

func attack_player():
	print_debug("Mob at pos " + str(global_position) + " attacks player at pos " + str(PlayerManager.player.global_position))
