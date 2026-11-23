class_name QuestData
extends Resource

## Structured villager Community Board request for Pebblefern (Phase 5: Living Town).
## Supports either an exact required_item_id OR a logical group (e.g., &"ocean_fish", &"river_fish").

enum Status {
	AVAILABLE = 0,
	ACTIVE = 1,
	COMPLETED = 2,
}

@export var quest_id: StringName = &""
@export var npc_id: StringName = &""
@export var title: String = ""
@export var description: String = ""
@export var required_item_id: StringName = &""
@export var required_item_group: StringName = &""
@export var required_label: String = ""
@export var preview_item_id: StringName = &""
@export var required_count: int = 1
@export var reward_gold: int = 100
@export var reward_friendship: int = 150
@export var day_issued: int = 1
@export var status: Status = Status.AVAILABLE
