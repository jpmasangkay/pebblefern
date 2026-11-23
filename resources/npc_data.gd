class_name NpcData
extends Resource

## Structured resident profile for Pebblefern Island villagers (Phase 5: Living Town).
## Holds visual portrait specs, gift preference tables, contextual dialogue pools, and schedule windows.

@export var npc_id: StringName = &""
@export var display_name: String = ""
@export var role_title: String = ""
@export var bio: String = ""
@export var hair_style: StringName = &"shorthair"
@export var hair_tint: Color = Color.WHITE
@export var home_building_id: StringName = &""
@export var shop_id: StringName = &""

# Gift preferences (checked in priority order: loved -> liked -> disliked -> liked_categories -> neutral)
@export var loved_items: Array[StringName] = []
@export var liked_items: Array[StringName] = []
@export var disliked_items: Array[StringName] = []
@export var liked_categories: PackedInt32Array = PackedInt32Array()

# Contextual dialogue pools
@export var morning_lines: PackedStringArray = PackedStringArray()
@export var afternoon_lines: PackedStringArray = PackedStringArray()
@export var evening_lines: PackedStringArray = PackedStringArray()
@export var season_lines: PackedStringArray = PackedStringArray() # Index 0=Bloom, 1=Sun, 2=Harvest, 3=Frost
@export var heart3_lines: PackedStringArray = PackedStringArray()
@export var heart6_lines: PackedStringArray = PackedStringArray()

# Tailored gift reaction lines
@export var gift_loved_line: String = "Oh! You remembered my absolute favorite! Thank you so much!"
@export var gift_liked_line: String = "Why thank you! That is very thoughtful of you."
@export var gift_neutral_line: String = "Thanks for thinking of me."
@export var gift_disliked_line: String = "Oh... um, I appreciate the thought, I suppose."

# Daily schedule window bounds (24-hour float clock)
@export var work_start_hour: float = 8.0
@export var work_end_hour: float = 17.0
@export var plaza_end_hour: float = 21.0
