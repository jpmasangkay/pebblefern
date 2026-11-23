extends Node2D

## Verifies cleaned farmhouse architecture, grounded ShippingBin, symmetrical front-yard torches,
## and open-front MarketStall + tightened InteractArea, then captures Screenshots/exterior_cleaned_verified.png (1280x720).

const FARM_SCENE_PATH: String = "res://scenes/world/farm_sanctuary.tscn"
const SHOT_EXTERIOR: String = "res://Screenshots/exterior_cleaned_verified.png"
const SHOT_FARMHOUSE_ROOF: String = "res://Screenshots/farmhouse_roof_fixed.png"

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
	TimeManager.set_time(10, 30)

	var farm_packed: PackedScene = load(FARM_SCENE_PATH) as PackedScene
	assert(farm_packed != null, "Missing farm_sanctuary.tscn")
	_farm = farm_packed.instantiate() as FarmSanctuary
	add_child(_farm)
	_farm.refresh_atmosphere()

	# Structural assertions on verbatim Room1.yy farmhouse & open-front market stall
	var fh: Node2D = _farm.farmhouse
	assert(fh.get_node_or_null("InteriorFloor") == null, "Leftover InteriorFloor must be deleted from exterior farmhouse!")
	assert(fh.get_node_or_null("InteriorFurniture") == null, "Leftover InteriorFurniture must be deleted from exterior farmhouse!")
	assert(fh.get_node_or_null("InteriorRugs") == null, "Leftover InteriorRugs must be deleted from exterior farmhouse!")
	assert(fh.get_node_or_null("InteriorDetails") == null, "Leftover InteriorDetails must be deleted from exterior farmhouse!")
	assert(fh.get_node_or_null("RoofLayer/Room1BuildingLayer") != null, "Farmhouse must include verbatim Room1BuildingLayer!")
	assert(fh.get_node_or_null("RoofLayer/Room1Decoration02Layer") != null, "Farmhouse must include verbatim Room1Decoration02Layer!")
	assert(fh.get_node_or_null("RoofLayer/ChimneySmoke") != null, "Farmhouse must include ChimneySmoke anchored to chimney!")

	var ms: MarketStall = _farm.market_stall
	assert(ms != null, "FarmSanctuary missing MarketStall!")
	assert(ms.get_node_or_null("RoofDormerCap") == null, "MarketStall stray blue roof fin must be removed!")
	assert(ms.get_node_or_null("FacadeDetails/ShopSideDoor") == null, "MarketStall closed house door must be removed!")
	assert(ms.get_node_or_null("BoothShelves/SeedPacketShelf") != null, "MarketStall must have open-booth shelves behind Maren!")
	assert(ms.get_node_or_null("MarenNPC/HairSprite") != null, "MarketStall must include live Maren NPC!")


func _physics_process(_delta: float) -> void:
	_frames += 1
	match _step:
		0:
			# Test 1: Walking along the middle of the horizontal east road must NOT trigger MarketStall InteractArea!
			if _frames == 1:
				_farm.player.global_position = Vector2(_farm.market_stall.global_position.x, 15.6 * 16.0)
			elif _frames >= 5:
				assert(not _farm.market_stall.is_player_nearby(), "Tightened MarketStall InteractArea must NOT trigger out in the road!")
				_step = 1
				_frames = 0
		1:
			# Test 2: Standing right in front of Maren's counter MUST trigger MarketStall InteractArea!
			if _frames == 1:
				_farm.player.global_position = _farm.market_stall.global_position + Vector2(0.0, 23.0)
			elif _frames >= 5:
				assert(_farm.market_stall.is_player_nearby(), "MarketStall InteractArea must trigger right in front of Maren's counter!")
				print("[VerifyExt] PASS: Farmhouse roof cleanup, open-front MarketStall & tightened InteractArea verified.")
				# Stage cohesive panoramic exterior capture showing Verbatim Farmhouse + Torches + ShippingBin + MarketStall!
				_farm.player.global_position = Vector2(27.0 * 16.0, 14.2 * 16.0)
				_farm.player.set_facing_cardinal(Vector2i(0, 1))
				_farm.set_hud_visible(false)
				_farm.player.camera.position_smoothing_enabled = false
				_farm.player.camera.top_level = true
				_farm.player.camera.global_position = Vector2(536.0, 178.0)
				_farm.player.camera.zoom = Vector2(0.66, 0.66)
				_step = 2
				_frames = 0
		2:
			if _frames >= 8:
				_save_viewport_png(SHOT_EXTERIOR)
				print("[VerifyExt] Captured %s" % SHOT_EXTERIOR)
				# Stage tight zoomed close-up dead-centered on the verbatim Room1.yy Farmhouse, chimney, benches & yard props!
				_farm.player.camera.global_position = Vector2(432.0, 158.0)
				_farm.player.camera.zoom = Vector2(1.25, 1.25)
				_step = 3
				_frames = 0
		3:
			if _frames >= 8:
				_save_viewport_png(SHOT_FARMHOUSE_ROOF)
				print("[VerifyExt] Captured %s" % SHOT_FARMHOUSE_ROOF)
				get_tree().quit(0)


func _save_viewport_png(res_path: String) -> void:
	var out_path: String = ProjectSettings.globalize_path(res_path)
	var img: Image = get_viewport().get_texture().get_image()
	assert(img != null, "Failed to read viewport texture.")
	assert(img.get_width() >= 1280 and img.get_height() >= 720, "Expected 1280x720 screenshot.")
	var err: Error = img.save_png(out_path)
	assert(err == OK, "Failed to save %s (err=%d)" % [out_path, err])
