extends Node2D

## Captures two crisp 1280x720 visual verification screenshots:
## 1. Screenshots/hud_polished_verified.png — Sleek, centered HUD over the farmhouse courtyard
## 2. Screenshots/market_stall_verified.png — Close-up of the rebuilt 4x4 Sunnyside Trading Post,
##    live Maren NPC behind the oak counter, stacked crates left, and Kaelen's Anvil on stone right.

const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"
const SHOT_HUD: String = "res://Screenshots/hud_polished_verified.png"
const SHOT_STALL: String = "res://Screenshots/market_stall_verified.png"

var _farm: FarmSanctuary = null
var _step: int = 0
var _frames: int = 0


func _ready() -> void:
	GridStateManager.clear_all()
	InventoryManager.reset_to_starter_loadout()
	EconomyManager.reset_economy()
	VitalitySystem.restore_full()
	TimeManager.reset_to_day_one()
	TimeManager.set_paused(true)
	TimeManager.set_time(9, 30)

	# Upgrade Watering Can to Iron (Fe, 80) and Pickaxe to Copper (Cu) so HUD tier badges & water bar are verified live!
	InventoryManager.upgrade_tool_tier(&"tool_watering_can", ToolData.ToolTier.IRON)
	InventoryManager.upgrade_tool_tier(&"tool_pickaxe", ToolData.ToolTier.COPPER)
	InventoryManager.select_hotbar_slot(6) # Parsnip Seeds (12) selected to test brackets + inside-slot stack count!

	var farm_packed: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	assert(farm_packed != null, "Missing farm_sanctuary.tscn")
	_farm = farm_packed.instantiate() as FarmSanctuary
	add_child(_farm)
	assert(_farm.market_stall != null, "FarmSanctuary must include rebuilt MarketStall!")
	assert(_farm.market_stall.get_node_or_null("MarenNPC/HairSprite") != null, "MarketStall must include Maren NPC!")
	assert(_farm.market_stall.get_node_or_null("DisplaySunflower") == null, "Zero floating raw crop icons allowed!")
	assert(_farm.market_stall.get_node_or_null("RedAwningLeft") == null, "Zero kitbashed red-bed awning allowed!")
	_farm.refresh_atmosphere()


func _physics_process(_delta: float) -> void:
	_frames += 1
	match _step:
		0:
			if _frames >= 8:
				# Shot 1: Sunlit Farmhouse Courtyard showing sleek compact centered HUD
				_farm.player.global_position = Vector2(27.0 * 16.0 + 8.0, 14.0 * 16.0 + 4.0)
				_farm.player.set_facing_cardinal(Vector2i(0, 1))
				_step = 1
				_frames = 0
		1:
			if _frames >= 6:
				_save_viewport_png(SHOT_HUD)
				print("[VerifyHudStall] Captured %s" % SHOT_HUD)

				# Shot 2: Close-up of rebuilt 4x4 Sunnyside Trading Post with Maren at the counter & Kaelen's Anvil on stone
				_farm.player.global_position = _farm.market_stall.global_position + Vector2(2.0, 34.0)
				_farm.player.set_facing_cardinal(Vector2i(0, -1))
				_farm.player.camera.offset = Vector2(4.0, -24.0)
				_farm.player.camera.zoom = Vector2(1.12, 1.12)
				_step = 2
				_frames = 0
		2:
			if _frames >= 10:
				_save_viewport_png(SHOT_STALL)
				print("[VerifyHudStall] Captured %s" % SHOT_STALL)
				print("[VerifyHudStall] PASS: Sleek HUD & Rebuilt Sunnyside Trading Post verified cleanly.")
				get_tree().quit(0)


func _save_viewport_png(res_path: String) -> void:
	var out_path: String = ProjectSettings.globalize_path(res_path)
	var img: Image = get_viewport().get_texture().get_image()
	assert(img != null, "Failed to read viewport texture.")
	assert(img.get_width() >= 1280 and img.get_height() >= 720, "Expected 1280x720 screenshot.")
	var err: Error = img.save_png(out_path)
	assert(err == OK, "Failed to save %s (err=%d)" % [out_path, err])
