class_name AssetPaths
extends RefCounted

## Verified read-only paths and atlas coordinates for Sunnyside World V2.1 and Vryell Icons.
## Every tile coordinate here was visually verified against spr_tileset_sunnysideworld_16px.png.

const SUNNYSIDE_ROOT: String = "res://assets/Sunnyside_World_ASSET_PACK_V2.1/Sunnyside_World_ASSET_PACK_V2.1/Sunnyside_World_Assets"
const VRYELL_ROOT: String = "res://assets/Controllers and Keyboard/Controllers and Keyboard"

# Verified Vryell Controllers and Keyboard 16x16 Grid Spritesheets
const VRYELL_KB_LIGHT: String = VRYELL_ROOT + "/kb_light_all.png"
const VRYELL_KB_DARK: String = VRYELL_ROOT + "/kb_dark_all.png"
const VRYELL_MOUSE: String = VRYELL_ROOT + "/mouse.png"
const VRYELL_STICKS: String = VRYELL_ROOT + "/sticks.png"
const VRYELL_XBOX: String = VRYELL_ROOT + "/controller_xbox.png"
const VRYELL_PS: String = VRYELL_ROOT + "/controller_ps.png"
const VRYELL_SWITCH: String = VRYELL_ROOT + "/controller_switch.png"
const VRYELL_MINIMAL: String = VRYELL_ROOT + "/controller_minimal.png"

const TILESET_16PX: String = SUNNYSIDE_ROOT + "/Tileset/spr_tileset_sunnysideworld_16px.png"
const TILESET_RESOURCE: String = "res://resources/sunnyside_tileset.tres"

# Standalone Soil, Crops & Resource sprites
const CROPS_ROOT: String = SUNNYSIDE_ROOT + "/Elements/Crops"
const UI_ROOT: String = SUNNYSIDE_ROOT + "/UI"
const SOIL_DRY: String = CROPS_ROOT + "/soil_04.png"
const SOIL_WATERED: String = CROPS_ROOT + "/soil_04.png"
const CRATE_BASE: String = CROPS_ROOT + "/crate_base.png"
const CRATE_TOP: String = CROPS_ROOT + "/crate_top.png"
const ITEM_WOOD: String = CROPS_ROOT + "/wood.png"
const ITEM_ROCK: String = CROPS_ROOT + "/rock.png"
const ITEM_SEEDS_GENERIC: String = CROPS_ROOT + "/seeds_generic.png"
const ITEM_FISH: String = CROPS_ROOT + "/fish.png"
const ITEM_MILK: String = CROPS_ROOT + "/milk.png"
const ITEM_EGG: String = CROPS_ROOT + "/egg.png"

# Standalone UI Tool Icons & HUD/Modal Assets
const UI_9SLICE_DIR: String = UI_ROOT + "/9slice_box_white"
const ICON_HOE: String = UI_ROOT + "/shovel.png"
const ICON_WATERING_CAN: String = UI_ROOT + "/water.png"
const ICON_AXE: String = UI_ROOT + "/axe.png"
const ICON_PICKAXE: String = UI_ROOT + "/pickaxe.png"
const ICON_SCYTHE: String = UI_ROOT + "/sword.png"
const ICON_FISHING_ROD: String = UI_ROOT + "/rod.png"
const ICON_PLANT: String = UI_ROOT + "/plant.png"
const ICON_ITEM_DISC: String = UI_ROOT + "/itemdisc_01.png"
const ICON_ITEM_DISC_ALT: String = UI_ROOT + "/itemdisc_02.png"
const UI_STOPWATCH: String = UI_ROOT + "/stopwatch.png"
const UI_SANDTIMER: String = UI_ROOT + "/sandtimer.png"
const UI_BASKET: String = UI_ROOT + "/basket.png"
const UI_HAND_OPEN: String = UI_ROOT + "/hand_open_01.png"
const UI_PLAYERCOUNT: String = UI_ROOT + "/playercount.png"
const UI_CONFIRM: String = UI_ROOT + "/confirm.png"
const UI_CANCEL: String = UI_ROOT + "/cancel.png"
const UI_ARROW_LEFT: String = UI_ROOT + "/arrow_left.png"
const UI_ARROW_RIGHT: String = UI_ROOT + "/arrow_right.png"
const UI_ARROW_UP: String = UI_ROOT + "/arrow_up.png"
const UI_ARROW_DOWN: String = UI_ROOT + "/arrow_up-1.png"
const UI_HAMMER: String = UI_ROOT + "/hammer.png"
const UI_EXPRESSION_WORKING: String = UI_ROOT + "/expression_working.png"
const UI_INDICATOR: String = UI_ROOT + "/indicator.png"
const UI_HEART: String = UI_ROOT + "/expression_love.png"
const UI_EXPRESSION_LOVE: String = UI_ROOT + "/expression_love.png"
const UI_EXPRESSION_HAPPY: String = UI_ROOT + "/happiness_04.png"
const UI_EXPRESSION_CONFUSED: String = UI_ROOT + "/expression_confused.png"
const UI_EXPRESSION_CHAT: String = UI_ROOT + "/expression_chat.png"
const UI_STRESS: String = UI_ROOT + "/expression_stress.png"
const UI_EXPRESSION_ALERTED: String = UI_ROOT + "/expression_alerted.png"
const UI_LABEL_LEFT: String = UI_ROOT + "/label_left.png"
const UI_LABEL_MIDDLE: String = UI_ROOT + "/label_middle.png"
const UI_LABEL_RIGHT: String = UI_ROOT + "/label_right.png"
const FIRE_01_STRIP4: String = SUNNYSIDE_ROOT + "/Elements/VFX/Fire/spr_deco_fire_01_strip4.png"
const FIRE_02_STRIP4: String = SUNNYSIDE_ROOT + "/Elements/VFX/Fire/spr_deco_fire_02_strip4.png"

# Verified NPC 3-Layer IDLE Strips (9 frames, 96x64)
const NPC_IDLE_BODY: String = SUNNYSIDE_ROOT + "/Characters/Human/IDLE/base_idle_strip9.png"
const NPC_IDLE_TOOLS: String = SUNNYSIDE_ROOT + "/Characters/Human/IDLE/tools_idle_strip9.png"
const MAREN_IDLE_BODY: String = NPC_IDLE_BODY
const MAREN_IDLE_HAIR: String = SUNNYSIDE_ROOT + "/Characters/Human/IDLE/curlyhair_idle_strip9.png"
const MAREN_IDLE_TOOLS: String = NPC_IDLE_TOOLS
const KAELEN_IDLE_HAIR: String = SUNNYSIDE_ROOT + "/Characters/Human/IDLE/spikeyhair_idle_strip9.png"
const ALDRIC_IDLE_HAIR: String = SUNNYSIDE_ROOT + "/Characters/Human/IDLE/bowlhair_idle_strip9.png"
const LYRA_IDLE_HAIR: String = SUNNYSIDE_ROOT + "/Characters/Human/IDLE/longhair_idle_strip9.png"
const BRAM_IDLE_HAIR: String = SUNNYSIDE_ROOT + "/Characters/Human/IDLE/mophair_idle_strip9.png"

# Verified NPC 3-Layer WALKING Strips (8 frames, 96x64 — includes tools_walk_strip8 so BOTH arms animate!)
const NPC_WALK_BODY: String = SUNNYSIDE_ROOT + "/Characters/Human/WALKING/base_walk_strip8.png"
const NPC_WALK_TOOLS: String = SUNNYSIDE_ROOT + "/Characters/Human/WALKING/tools_walk_strip8.png"
const MAREN_WALK_HAIR: String = SUNNYSIDE_ROOT + "/Characters/Human/WALKING/curlyhair_walk_strip8.png"
const KAELEN_WALK_HAIR: String = SUNNYSIDE_ROOT + "/Characters/Human/WALKING/spikeyhair_walk_strip8.png"
const ALDRIC_WALK_HAIR: String = SUNNYSIDE_ROOT + "/Characters/Human/WALKING/bowlhair_walk_strip8.png"
const LYRA_WALK_HAIR: String = SUNNYSIDE_ROOT + "/Characters/Human/WALKING/longhair_walk_strip8.png"
const BRAM_WALK_HAIR: String = SUNNYSIDE_ROOT + "/Characters/Human/WALKING/mophair_walk_strip8.png"

# Verified Phase 6 Cave Enemy Strips (Skeleton: exact 96x64 integer frame width across all 5 states)
const SKELETON_ROOT: String = SUNNYSIDE_ROOT + "/Characters/Skeleton/PNG"
const SKELETON_IDLE_STRIP6: String = SKELETON_ROOT + "/skeleton_idle_strip6.png"
const SKELETON_WALK_STRIP8: String = SKELETON_ROOT + "/skeleton_walk_strip8.png"
const SKELETON_ATTACK_STRIP7: String = SKELETON_ROOT + "/skeleton_attack_strip7.png"
const SKELETON_HURT_STRIP7: String = SKELETON_ROOT + "/skeleton_hurt_strip7.png"
const SKELETON_DEATH_STRIP10: String = SKELETON_ROOT + "/skeleton_death_strip10.png"
const GLINT_01_STRIP6: String = SUNNYSIDE_ROOT + "/Elements/VFX/Glint/spr_deco_glint_01_strip6.png"
const GLINT_02_STRIP4: String = SUNNYSIDE_ROOT + "/Elements/VFX/Glint/spr_deco_glint_02_strip4.png"
const CORACLE_LAND_TEX: String = SUNNYSIDE_ROOT + "/Elements/Other/spr_deco_coracle_land.png"

const GREENBAR_PATHS: PackedStringArray = [
	UI_ROOT + "/greenbar_00.png",
	UI_ROOT + "/greenbar_01.png",
	UI_ROOT + "/greenbar_02.png",
	UI_ROOT + "/greenbar_03.png",
	UI_ROOT + "/greenbar_04.png",
	UI_ROOT + "/greenbar_05.png",
	UI_ROOT + "/greenbar_06.png",
]
const REDBAR_PATHS: PackedStringArray = [
	UI_ROOT + "/redbar_00.png",
	UI_ROOT + "/redbar_01.png",
	UI_ROOT + "/redbar_02.png",
	UI_ROOT + "/redbar_03.png",
	UI_ROOT + "/redbar_04.png",
	UI_ROOT + "/redbar_05.png",
	UI_ROOT + "/redbar_06.png",
]
const BLUEBAR_PATHS: PackedStringArray = [
	UI_ROOT + "/bluebar_00.png",
	UI_ROOT + "/bluebar_01.png",
	UI_ROOT + "/bluebar_02.png",
	UI_ROOT + "/bluebar_03.png",
	UI_ROOT + "/bluebar_04.png",
	UI_ROOT + "/bluebar_05.png",
]

# All 11 Verified Sunnyside Crop Stems (each has _00.._04 stages + _05 harvest icon)
const CROP_STEMS: PackedStringArray = [
	"parsnip",
	"carrot",
	"potato",
	"cauliflower",
	"kale",
	"radish",
	"sunflower",
	"wheat",
	"cabbage",
	"beetroot",
	"pumpkin",
]

# Standalone Animated Nature & Water Props
const TREE_DECIDUOUS_STRIP4: String = SUNNYSIDE_ROOT + "/Elements/Plants/spr_deco_tree_01_strip4.png"
const TREE_PINE_STRIP4: String = SUNNYSIDE_ROOT + "/Elements/Plants/spr_deco_tree_02_strip4.png"
const MUSHROOM_RED_STRIP4: String = SUNNYSIDE_ROOT + "/Elements/Plants/spr_deco_mushroom_red_01_strip4.png"
const MUSHROOM_BLUE_STRIP4: String = SUNNYSIDE_ROOT + "/Elements/Plants/spr_deco_mushroom_blue_01_strip4.png"
const CORACLE_WATER_STRIP4: String = SUNNYSIDE_ROOT + "/Elements/Other/spr_deco_coracle_strip4.png"
const DUCK_STRIP4: String = SUNNYSIDE_ROOT + "/Elements/Animals/spr_deco_duck_01_strip4.png"
const CHIMNEY_SMOKE_STRIP30: String = SUNNYSIDE_ROOT + "/Elements/VFX/Chimney Smoke/chimneysmoke_01_strip30.png"

# Standalone UI Selection Brackets (for 16x16 Target Tile Cursor)
const SELECTBOX_TL: String = SUNNYSIDE_ROOT + "/UI/selectbox_tl.png"
const SELECTBOX_TR: String = SUNNYSIDE_ROOT + "/UI/selectbox_tr.png"
const SELECTBOX_BL: String = SUNNYSIDE_ROOT + "/UI/selectbox_bl.png"
const SELECTBOX_BR: String = SUNNYSIDE_ROOT + "/UI/selectbox_br.png"

# Human Character Animation Strips (96x64 per frame, feet aligned at y=38 -> offset Vector2(0, -6))
const HUMAN_ROOT: String = SUNNYSIDE_ROOT + "/Characters/Human"

# Verified TileSet Physics Layer Indices
const PHYSICS_LAYER_WORLD_SOLID: int = 0
const PHYSICS_LAYER_WATER: int = 1

# Verified TileSet Terrain Set & Terrain IDs in res://resources/sunnyside_tileset.tres
const TERRAIN_SET_RIVER: int = 0
const TERRAIN_GRASS_BASE: int = 0
const TERRAIN_RIVER: int = 1

const TERRAIN_SET_PATHS: int = 1
const TERRAIN_PATH_EMPTY: int = 0
const TERRAIN_PATH_ROAD: int = 1

const TERRAIN_SET_GARDEN: int = 2
const TERRAIN_GARDEN_EMPTY: int = 0
const TERRAIN_GARDEN_BED: int = 1

const TERRAIN_SET_CLIFF: int = 3
const TERRAIN_CLIFF_EMPTY: int = 0
const TERRAIN_CLIFF: int = 1

const TERRAIN_SET_SAND: int = 4
const TERRAIN_SAND_EMPTY: int = 0
const TERRAIN_SAND: int = 1

# Atlas Source IDs inside sunnyside_tileset.tres
const SOURCE_MAIN_16PX: int = 0
const SOURCE_SOIL_DRY: int = 1
const SOURCE_SOIL_WATERED: int = 2

# Verified Atlas Coordinates on Source 0 (spr_tileset_sunnysideworld_16px.png)
const TILE_TRANSPARENT: Vector2i = Vector2i(0, 0)
const TILE_GRASS_LIGHT: Vector2i = Vector2i(1, 1)
const TILE_GRASS_ALT: Vector2i = Vector2i(2, 1)
const TILE_GRASS_DETAIL_A: Vector2i = Vector2i(2, 2)
const TILE_GRASS_DETAIL_B: Vector2i = Vector2i(4, 2)
const TILE_GRASS_DETAIL_C: Vector2i = Vector2i(5, 2)
const TILE_GRASS_DARK_MAT_L: Vector2i = Vector2i(14, 4)
const TILE_GRASS_DARK_MAT_M: Vector2i = Vector2i(15, 4)
const TILE_GRASS_DARK_MAT_R: Vector2i = Vector2i(17, 4)

# Animated Water (4 horizontal frames each at cols 30..33)
const TILE_WATER_FOAM_ANIM: Vector2i = Vector2i(30, 6)
const TILE_WATER_FLOW_ANIM: Vector2i = Vector2i(30, 7)
const TILE_WATER_RIVER_ANIM: Vector2i = Vector2i(30, 8)
const TILE_WATER_SOLID: Vector2i = Vector2i(22, 7)
const TILE_WATER_GLINT_ANIM: Vector2i = Vector2i(11, 22)

# Verified Wildflowers & Pebbles (04_Decorations)
const TILE_FLOWER_WHITE_SINGLE: Vector2i = Vector2i(31, 3)
const TILE_FLOWER_WHITE_CLUSTER: Vector2i = Vector2i(33, 3)
const TILE_FLOWER_WHITE_LARGE: Vector2i = Vector2i(34, 3)
const TILE_FLOWER_BLUE_SINGLE: Vector2i = Vector2i(31, 1)
const TILE_FLOWER_RED_SINGLE: Vector2i = Vector2i(31, 2)
const TILE_PEBBLE_LARGE: Vector2i = Vector2i(31, 4)
const TILE_PEBBLE_DOUBLE: Vector2i = Vector2i(32, 4)
const TILE_PEBBLE_SMALL: Vector2i = Vector2i(33, 4)
const TILE_PEBBLE_TINY: Vector2i = Vector2i(34, 4)
const TILE_GRASS_TUFT_A: Vector2i = Vector2i(27, 2)
const TILE_GRASS_TUFT_B: Vector2i = Vector2i(28, 2)
const TILE_GRASS_TUFT_C: Vector2i = Vector2i(27, 4)

# Verified Fence Tiles
const TILE_FENCE_H_LEFT: Vector2i = Vector2i(38, 2)
const TILE_FENCE_H_MID: Vector2i = Vector2i(39, 2)
const TILE_FENCE_H_MID_ALT: Vector2i = Vector2i(41, 2)
const TILE_FENCE_H_RIGHT: Vector2i = Vector2i(42, 2)
const TILE_FENCE_CROSS: Vector2i = Vector2i(40, 2)
const TILE_FENCE_V_TOP: Vector2i = Vector2i(40, 1)
const TILE_FENCE_V_MID: Vector2i = Vector2i(40, 3)
const TILE_FENCE_V_BOTTOM: Vector2i = Vector2i(40, 4)
const TILE_FENCE_CORNER_BR: Vector2i = Vector2i(38, 1)
const TILE_FENCE_CORNER_BL: Vector2i = Vector2i(39, 1)
const TILE_FENCE_CORNER_TR: Vector2i = Vector2i(41, 1)
const TILE_FENCE_CORNER_TL: Vector2i = Vector2i(42, 1)
const TILE_FENCE_POST_SINGLE: Vector2i = Vector2i(39, 3)

# Verified Stump Tiles (3 sizes)
const TILE_STUMP_SMALL: Vector2i = Vector2i(39, 3)
const TILE_STUMP_MEDIUM: Vector2i = Vector2i(31, 5)
const TILE_STUMP_LARGE: Vector2i = Vector2i(32, 5)

# Verified Stone Wall & Gate Tiles
const TILE_STONE_WALL_TL: Vector2i = Vector2i(44, 1)
const TILE_STONE_WALL_H1: Vector2i = Vector2i(45, 1)
const TILE_STONE_WALL_H2: Vector2i = Vector2i(46, 1)
const TILE_STONE_WALL_TR: Vector2i = Vector2i(47, 1)
const TILE_STONE_WALL_V1: Vector2i = Vector2i(44, 2)
const TILE_STONE_WALL_V2: Vector2i = Vector2i(44, 3)
const TILE_STONE_WALL_V3: Vector2i = Vector2i(44, 4)
const TILE_STONE_WALL_VB: Vector2i = Vector2i(44, 5)
const TILE_STONE_GATE_LEFT: Vector2i = Vector2i(45, 2)
const TILE_STONE_GATE_WOOD: Vector2i = Vector2i(46, 2)
const TILE_STONE_GATE_RIGHT: Vector2i = Vector2i(47, 2)

# Verified Cliff Tiles
const TILE_CLIFF_TOP_L: Vector2i = Vector2i(6, 4)
const TILE_CLIFF_TOP_R: Vector2i = Vector2i(7, 4)
const TILE_CLIFF_FACE_TL: Vector2i = Vector2i(10, 3)
const TILE_CLIFF_FACE_TM: Vector2i = Vector2i(11, 3)
const TILE_CLIFF_FACE_TR: Vector2i = Vector2i(12, 3)
const TILE_CLIFF_FACE_ML: Vector2i = Vector2i(10, 4)
const TILE_CLIFF_FACE_MM: Vector2i = Vector2i(11, 4)
const TILE_CLIFF_FACE_MR: Vector2i = Vector2i(12, 4)
const TILE_CLIFF_BASE_L: Vector2i = Vector2i(10, 6)
const TILE_CLIFF_BASE_R: Vector2i = Vector2i(12, 6)

# Verified Phase 4 Economy, Blacksmith & Craftable Placeable Atlas Coordinates
const TILE_CHEST_CLOSED: Vector2i = Vector2i(38, 30)
const TILE_CHEST_OPEN: Vector2i = Vector2i(39, 30)
const TILE_COIN_PILE: Vector2i = Vector2i(40, 30)
const TILE_STONE_PATH: Vector2i = Vector2i(1, 15)
const TILE_ANVIL_L: Vector2i = Vector2i(37, 18)
const TILE_WATER_TROUGH_L: Vector2i = Vector2i(37, 17)
const TILE_FURNACE_BASE: Vector2i = Vector2i(39, 17)
const TILE_COPPER_ORE: Vector2i = Vector2i(55, 28)
const TILE_IRON_ORE: Vector2i = Vector2i(55, 22)
const TILE_CAVE_DARK_ORE: Vector2i = Vector2i(55, 24)
const TILE_CAVE_CRYSTAL: Vector2i = Vector2i(55, 26)
const TILE_METAL_BAR: Vector2i = Vector2i(55, 30)
const TILE_ORE_VEIN_GOLD: Vector2i = Vector2i(49, 27)
const TILE_ORE_VEIN_COPPER: Vector2i = Vector2i(51, 27)
const TILE_ORE_VEIN_CRYSTAL: Vector2i = Vector2i(51, 25)

# Verified World Expansion (Room1.yy) Elevation, Coastline, Waterfall, Ladder, Pier & Mine Coordinates
const TILE_GRASS_SOLID: Vector2i = Vector2i(1, 3)
const TILE_GRASS_DETAIL_D: Vector2i = Vector2i(1, 2)
const TILE_GRASS_DETAIL_E: Vector2i = Vector2i(3, 2)
const TILE_GRASS_DETAIL_F: Vector2i = Vector2i(6, 2)
const TILE_LAND_TOP: Vector2i = Vector2i(4, 3)
const TILE_LAND_LEFT: Vector2i = Vector2i(6, 3)
const TILE_LAND_RIGHT: Vector2i = Vector2i(3, 4)
const TILE_LAND_CORNER_TL: Vector2i = Vector2i(8, 3)
const TILE_LAND_CORNER_TR: Vector2i = Vector2i(4, 4)
const TILE_LAND_INNER_TL: Vector2i = Vector2i(2, 3)
const TILE_LAND_INNER_TR: Vector2i = Vector2i(3, 3)
const TILE_LAND_INNER_BL: Vector2i = Vector2i(5, 3)
const TILE_LAND_INNER_BR: Vector2i = Vector2i(1, 4)

const TILE_SURF_CLIFF_S: Vector2i = Vector2i(20, 2)
const TILE_SURF_CLIFF_SE: Vector2i = Vector2i(19, 2)
const TILE_SURF_CLIFF_SW: Vector2i = Vector2i(21, 2)
const TILE_SURF_OCEAN_E: Vector2i = Vector2i(19, 3)
const TILE_SURF_OCEAN_W: Vector2i = Vector2i(21, 3)
const TILE_SURF_OCEAN_N: Vector2i = Vector2i(20, 4)
const TILE_SURF_GRASS_NE: Vector2i = Vector2i(19, 4)
const TILE_SURF_GRASS_NW: Vector2i = Vector2i(21, 4)
const TILE_SURF_SAND_S: Vector2i = Vector2i(20, 5)
const TILE_SURF_SAND_SE: Vector2i = Vector2i(19, 5)
const TILE_SURF_SAND_SW: Vector2i = Vector2i(21, 5)
const TILE_SURF_FOAM_TIP: Vector2i = Vector2i(19, 6)
const TILE_SURF_FOAM_TIP_ALT: Vector2i = Vector2i(21, 6)

const TILE_SAND_SOLID: Vector2i = Vector2i(5, 1)
const TILE_SAND_ALT_A: Vector2i = Vector2i(7, 1)
const TILE_SAND_ALT_B: Vector2i = Vector2i(8, 1)
const TILE_SAND_ALT_C: Vector2i = Vector2i(9, 1)
const TILE_CLIFF_LIP_M: Vector2i = Vector2i(5, 4)
const TILE_CLIFF_LIP_L: Vector2i = Vector2i(6, 4)
const TILE_CLIFF_LIP_R: Vector2i = Vector2i(7, 4)
const TILE_CLIFF_WATERFALL_SIDE: Vector2i = Vector2i(34, 6)
const TILE_WATERFALL_CREST_ANIM: Vector2i = Vector2i(26, 6)
const TILE_LADDER_TOP: Vector2i = Vector2i(42, 11)
const TILE_LADDER_MID: Vector2i = Vector2i(42, 12)
const TILE_LADDER_BOT: Vector2i = Vector2i(42, 13)
const TILE_CAVE_ARCH_L: Vector2i = Vector2i(11, 2)
const TILE_CAVE_ARCH_R: Vector2i = Vector2i(12, 2)

# Dark-Earth Carved Quarry Basin (Room1.yy bottom-left, cols 9..13, rows 28..33)
const TILE_QUARRY_CLIFF_TL: Vector2i = Vector2i(10, 28)
const TILE_QUARRY_CLIFF_M: Vector2i = Vector2i(11, 28)
const TILE_QUARRY_CLIFF_TR: Vector2i = Vector2i(12, 28)
const TILE_QUARRY_CLIFF_WL: Vector2i = Vector2i(9, 29)
const TILE_QUARRY_CLIFF_WR: Vector2i = Vector2i(13, 29)
const TILE_QUARRY_EARTH_A: Vector2i = Vector2i(11, 29)
const TILE_QUARRY_EARTH_B: Vector2i = Vector2i(11, 30)
const TILE_QUARRY_EARTH_C: Vector2i = Vector2i(11, 31)
const TILE_QUARRY_EARTH_L: Vector2i = Vector2i(10, 30)
const TILE_QUARRY_EARTH_R: Vector2i = Vector2i(12, 30)
const TILE_QUARRY_EARTH_TL: Vector2i = Vector2i(10, 29)
const TILE_QUARRY_EARTH_TR: Vector2i = Vector2i(12, 29)
const TILE_QUARRY_EARTH_BL: Vector2i = Vector2i(10, 31)
const TILE_QUARRY_EARTH_BR: Vector2i = Vector2i(12, 31)
const TILE_QUARRY_DARK_A: Vector2i = Vector2i(10, 32)
const TILE_QUARRY_DARK_B: Vector2i = Vector2i(11, 32)
const TILE_QUARRY_DARK_C: Vector2i = Vector2i(12, 32)
const TILE_QUARRY_DARK_SOLID: Vector2i = Vector2i(13, 30)
const TILE_QUARRY_GRASS_DIAG: Vector2i = Vector2i(12, 33)

const TILE_MINECART_TOP: Vector2i = Vector2i(44, 6)
const TILE_MINECART: Vector2i = Vector2i(44, 7)
const TILE_RAIL_H: Vector2i = Vector2i(47, 7)
const TILE_RAIL_V: Vector2i = Vector2i(48, 8)
const TILE_RAIL_CURVE: Vector2i = Vector2i(48, 7)
const TILE_RAIL_DIAG: Vector2i = Vector2i(45, 7)
const TILE_RAIL_DIAG_R: Vector2i = Vector2i(46, 7)
const TILE_RAIL_JUNCTION: Vector2i = Vector2i(46, 8)

const TILE_DIRT_SCATTER_A: Vector2i = Vector2i(14, 2)
const TILE_DIRT_SCATTER_B: Vector2i = Vector2i(14, 3)
const TILE_DIRT_SCATTER_C: Vector2i = Vector2i(14, 5)
const TILE_DIRT_SCATTER_D: Vector2i = Vector2i(14, 6)
const TILE_FLOWER_BLUE_CLUSTER: Vector2i = Vector2i(33, 1)
const TILE_FLOWER_BLUE_BIG: Vector2i = Vector2i(34, 1)
const TILE_FLOWER_RED_CLUSTER: Vector2i = Vector2i(33, 2)
const TILE_FLOWER_RED_BIG: Vector2i = Vector2i(34, 2)
const TILE_FLOWER_WHITE_BIG: Vector2i = Vector2i(35, 3)
const TILE_BUSH_SMALL_A: Vector2i = Vector2i(27, 1)
const TILE_BUSH_SMALL_B: Vector2i = Vector2i(28, 1)
const TILE_BUSH_SMALL_C: Vector2i = Vector2i(29, 1)
const TILE_BUSH_SMALL_D: Vector2i = Vector2i(30, 1)
const TILE_BENCH_H: Vector2i = Vector2i(45, 10)
const TILE_BENCH_V: Vector2i = Vector2i(43, 10)
const TILE_SIGN_POST: Vector2i = Vector2i(46, 13)
const TILE_SIGN_WIDE: Vector2i = Vector2i(47, 13)
const TILE_LOG_PILE: Vector2i = Vector2i(40, 30)
const TILE_SACK_SINGLE: Vector2i = Vector2i(50, 19)
const TILE_SACK_CLUSTER: Vector2i = Vector2i(52, 19)
const TILE_BARREL_WOOD: Vector2i = Vector2i(40, 16)
const TILE_BARREL_WEAPONS: Vector2i = Vector2i(41, 16)
const TILE_SHELL_PINK: Vector2i = Vector2i(57, 19)
const TILE_STARFISH: Vector2i = Vector2i(58, 19)
const TILE_SHELL_TAN: Vector2i = Vector2i(59, 19)
const TILE_CRAB: Vector2i = Vector2i(60, 19)
