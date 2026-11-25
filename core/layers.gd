class_name Layers
extends RefCounted
## Physics layer numbers (1-based, as shown in Project Settings) used by the combat components (DESIGN §9 M14).
## Layer n is bit (n - 1) of a collision mask. Use `mask()` to build a mask from layer numbers.

const WORLD: int = 1
const PLAYER: int = 2
const ENEMY: int = 3
const PLAYER_HIT: int = 4
const ENEMY_HIT: int = 5
const INTERACT: int = 6
const FIRE: int = 7

const _TEAM_PLAYER: StringName = &"player"
const _TEAM_ENEMY: StringName = &"enemy"
const _TEAM_FIRE: StringName = &"fire"
const _TEAMS: Array[StringName] = [&"player", &"enemy", &"fire"]


## Builds a collision mask (bit set) from a list of 1-based layer numbers.
static func mask(layers: Array[int]) -> int:
	var result: int = 0
	for layer: int in layers:
		if layer >= 1:
			result |= 1 << (layer - 1)
	return result


## The layer a hitbox of `team` sits on. Returns 0 for an unknown team.
static func hit_layer_for_team(team: StringName) -> int:
	if team == _TEAM_PLAYER:
		return PLAYER_HIT
	if team == _TEAM_ENEMY:
		return ENEMY_HIT
	if team == _TEAM_FIRE:
		return FIRE
	return 0


## The layer a hurtbox of `team` sits on. Returns 0 for an unknown team.
static func body_layer_for_team(team: StringName) -> int:
	if team == _TEAM_PLAYER:
		return PLAYER
	if team == _TEAM_ENEMY:
		return ENEMY
	if team == _TEAM_FIRE:
		return FIRE
	return 0


## The mask a hurtbox of `team` uses: the hit layers of every other team, so it never registers its own team's hits.
static func hurt_mask_for_team(team: StringName) -> int:
	var result: int = 0
	for other: StringName in _TEAMS:
		if other != team:
			result |= mask([hit_layer_for_team(other)])
	return result
