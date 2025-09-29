extends PhysicalBodyBase

const DISTANCE_TO_SEE_PLAYER = 500.0

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
	
