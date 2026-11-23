class_name ToolData
extends ItemData

## Tool resource specifying kind, upgrade tier, harvest/chop power, Vitality cost, and charge capacity.

enum ToolKind {
	HOE = 0,
	WATERING_CAN = 1,
	AXE = 2,
	PICKAXE = 3,
	SCYTHE = 4,
	FISHING_ROD = 5,
}

enum ToolTier {
	BASIC = 1,
	COPPER = 2,
	IRON = 3,
}

@export var tool_kind: ToolKind = ToolKind.HOE
@export var tier: ToolTier = ToolTier.BASIC
@export var power: int = 1
@export var vitality_cost: float = 2.0
@export var max_charges: int = 0
@export var player_anim_state: int = 3 # Matches Player.AnimState (HOE=3, WATER=4, AXE=5, MINE=6, ATTACK=7, FISH=8)


func has_charges() -> bool:
	return max_charges > 0
