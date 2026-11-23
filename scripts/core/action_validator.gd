class_name ActionValidator
extends RefCounted

## Pure, side-effect-free gameplay action validator.
## Checks strict tool, seed, harvest, water, and indoor rules BEFORE any player animation,
## particle burst, or Vitality drain occurs.

enum ActionKind {
	NONE = 0,
	HARVEST_CROP = 1,
	HARVEST_BERRY = 2,
	TILL = 3,
	WATER_SOIL = 4,
	REFILL_WATER = 5,
	PLANT_SEED = 6,
	HIT_RESOURCE = 7,
	CLEAR_WITHERED = 8,
	CAST_FISHING = 9,
	EAT_ITEM = 10,
	PLACE_OBJECT = 11,
	SWING_SWORD = 12,
}


class ValidationContext:
	extends RefCounted
	var is_indoors: bool = false
	var is_mine: bool = false
	var target_cell: Vector2i = Vector2i.ZERO
	var is_real_water: bool = false
	var is_tillable: bool = false
	var can_place_object: bool = false
	var place_block_reason: String = ""
	var cell_state: GridCellState = null
	var is_crop_mature: bool = false
	var resource_node: ResourceNode = null
	var berry_bush: BerryBush = null
	var slot_charges: int = 0


class ActionResult:
	extends RefCounted
	var valid: bool = false
	var kind: int = ActionKind.NONE
	var reason: String = ""
	var anim_state: int = 0
	var sfx_id: StringName = &""
	var target_cell: Vector2i = Vector2i.ZERO
	var target_resource: ResourceNode = null
	var target_bush: BerryBush = null
	var item: ItemData = null
	var required_tier_blocked: int = 0


static func validate_use(item: ItemData, ctx: ValidationContext) -> ActionResult:
	assert(ctx != null, "ActionValidator.validate_use requires a ValidationContext.")
	var res: ActionResult = ActionResult.new()
	res.target_cell = ctx.target_cell
	res.item = item

	# Priority 1: Smart Harvest ALWAYS harvests mature Stage-5 crops or ripe berry bushes, even while holding a tool!
	if not ctx.is_indoors:
		if ctx.is_crop_mature:
			res.valid = true
			res.kind = ActionKind.HARVEST_CROP
			res.anim_state = 9 # Player.AnimState.DOING
			res.sfx_id = &"harvest"
			return res
		if ctx.berry_bush != null and ctx.berry_bush.is_ripe():
			res.valid = true
			res.kind = ActionKind.HARVEST_BERRY
			res.anim_state = 9 # Player.AnimState.DOING
			res.sfx_id = &"harvest"
			res.target_bush = ctx.berry_bush
			return res

	if item == null:
		res.valid = false
		res.reason = ""
		return res

	# Edible items can be eaten both indoors and outdoors
	if item.is_edible() and item.category != ItemData.Category.TOOL and item.category != ItemData.Category.SEED:
		res.valid = true
		res.kind = ActionKind.EAT_ITEM
		res.anim_state = 9 # Player.AnimState.DOING
		res.sfx_id = &"harvest"
		return res

	# Priority 2: Indoors strictly blocks all farming, foraging, fishing tools, seeds, and outdoor placeables
	if ctx.is_indoors:
		res.valid = false
		if item is ToolData:
			res.reason = "Can't use tools indoors"
		elif item.category == ItemData.Category.SEED:
			res.reason = "Can't plant seeds indoors"
		elif item.is_placeable():
			res.reason = "Can't place objects indoors"
		else:
			res.reason = "Can't use this indoors"
		return res

	# Priority 2b: Subterranean Mine Cave allows Pickaxe (rocks/ores) & Sword (combat), cleanly blocking farming/fishing!
	if ctx.is_mine:
		if item is ToolData:
			var mine_tool: ToolData = item as ToolData
			match mine_tool.tool_kind:
				ToolData.ToolKind.PICKAXE:
					return _validate_harvest_tool(mine_tool, ctx, res, &"pickaxe", "Face a rock or ore vein to mine")
				ToolData.ToolKind.SCYTHE:
					res.valid = true
					res.kind = ActionKind.SWING_SWORD
					res.anim_state = mine_tool.player_anim_state # Player.AnimState.ATTACK
					res.sfx_id = &"scythe"
					return res
				ToolData.ToolKind.HOE:
					res.valid = false
					res.reason = "Can't till stone underground"
					return res
				ToolData.ToolKind.WATERING_CAN:
					res.valid = false
					res.reason = "Can't water inside the mine"
					return res
				ToolData.ToolKind.FISHING_ROD:
					res.valid = false
					res.reason = "Can't fish inside the mine"
					return res
				ToolData.ToolKind.AXE:
					res.valid = false
					res.reason = "No trees underground"
					return res
		elif item.category == ItemData.Category.SEED:
			res.valid = false
			res.reason = "Can't plant seeds underground"
			return res
		elif item.is_placeable():
			res.valid = false
			res.reason = "Can't place objects in the mine"
			return res
		res.valid = false
		res.reason = ""
		return res

	# Priority 3: Strictly validate each ToolKind
	if item is ToolData:
		return _validate_tool(item as ToolData, ctx, res)

	# Priority 4: Seeds ONLY plant on empty tilled soil
	if item.category == ItemData.Category.SEED:
		return _validate_seed(item, ctx, res)

	# Priority 5: Crafted Placeables validate clean outdoor placement
	if item.is_placeable():
		if not ctx.can_place_object:
			res.valid = false
			res.reason = ctx.place_block_reason if not ctx.place_block_reason.is_empty() else "Can't place here"
			return res
		res.valid = true
		res.kind = ActionKind.PLACE_OBJECT
		res.anim_state = 9 # Player.AnimState.DOING
		res.sfx_id = &"place"
		return res

	res.valid = false
	res.reason = ""
	return res


static func _validate_tool(tool: ToolData, ctx: ValidationContext, res: ActionResult) -> ActionResult:
	match tool.tool_kind:
		ToolData.ToolKind.FISHING_ROD:
			if not ctx.is_real_water:
				res.valid = false
				res.reason = "Face the river or pond to fish"
				return res
			res.valid = true
			res.kind = ActionKind.CAST_FISHING
			res.anim_state = tool.player_anim_state
			res.sfx_id = &"fish_cast"
			return res

		ToolData.ToolKind.HOE:
			if ctx.cell_state != null and ctx.cell_state.is_tilled:
				res.valid = false
				res.reason = "Already tilled"
				return res
			if not ctx.is_tillable:
				res.valid = false
				res.reason = "Can't till here"
				return res
			res.valid = true
			res.kind = ActionKind.TILL
			res.anim_state = tool.player_anim_state
			res.sfx_id = &"hoe"
			return res

		ToolData.ToolKind.WATERING_CAN:
			if ctx.is_real_water:
				res.valid = true
				res.kind = ActionKind.REFILL_WATER
				res.anim_state = tool.player_anim_state
				res.sfx_id = &"water"
				return res
			if ctx.cell_state == null or not ctx.cell_state.is_tilled:
				res.valid = false
				res.reason = "Till soil with Hoe first"
				return res
			if ctx.cell_state.is_watered:
				res.valid = false
				res.reason = "Soil is already watered"
				return res
			if ctx.slot_charges <= 0:
				res.valid = false
				res.reason = "Watering Can empty — refill at water"
				return res
			res.valid = true
			res.kind = ActionKind.WATER_SOIL
			res.anim_state = tool.player_anim_state
			res.sfx_id = &"water"
			return res

		ToolData.ToolKind.AXE:
			return _validate_harvest_tool(tool, ctx, res, &"axe", "Nothing to chop here")

		ToolData.ToolKind.PICKAXE:
			return _validate_harvest_tool(tool, ctx, res, &"pickaxe", "Nothing to mine here")

		ToolData.ToolKind.SCYTHE:
			if ctx.cell_state != null and ctx.cell_state.crop_id != &"" and ctx.cell_state.is_withered:
				res.valid = true
				res.kind = ActionKind.CLEAR_WITHERED
				res.anim_state = tool.player_anim_state
				res.sfx_id = &"scythe"
				return res
			return _validate_harvest_tool(tool, ctx, res, &"scythe", "Nothing to cut here")

	res.valid = false
	res.reason = ""
	return res


static func _validate_harvest_tool(
	tool: ToolData,
	ctx: ValidationContext,
	res: ActionResult,
	sfx: StringName,
	empty_msg: String
) -> ActionResult:
	var rn: ResourceNode = ctx.resource_node
	if rn == null or rn.is_destroyed():
		res.valid = false
		res.reason = empty_msg
		return res
	if rn.required_tool != tool.tool_kind:
		res.valid = false
		match rn.required_tool:
			ToolData.ToolKind.PICKAXE:
				res.reason = "Use Pickaxe on rocks"
			ToolData.ToolKind.AXE:
				res.reason = "Use Axe on trees"
			ToolData.ToolKind.SCYTHE:
				res.reason = "Use Scythe on weeds"
			_:
				res.reason = "Wrong tool for this"
		return res
	if int(tool.tier) < int(rn.required_tier):
		res.valid = false
		res.required_tier_blocked = int(rn.required_tier)
		var tier_name: String = "Copper" if int(rn.required_tier) == ToolData.ToolTier.COPPER else "Iron"
		res.reason = "Needs %s %s" % [tier_name, tool.display_name]
		return res
	res.valid = true
	res.kind = ActionKind.HIT_RESOURCE
	res.anim_state = tool.player_anim_state
	res.sfx_id = sfx
	res.target_resource = rn
	return res


static func _validate_seed(item: ItemData, ctx: ValidationContext, res: ActionResult) -> ActionResult:
	if item.crop_id == &"":
		res.valid = false
		res.reason = ""
		return res
	if ctx.cell_state == null or not ctx.cell_state.is_tilled:
		res.valid = false
		res.reason = "Till soil with Hoe first"
		return res
	if ctx.cell_state.crop_id != &"":
		res.valid = false
		res.reason = "Already planted here"
		return res
	res.valid = true
	res.kind = ActionKind.PLANT_SEED
	res.anim_state = 9 # Player.AnimState.DOING
	res.sfx_id = &"plant"
	return res
