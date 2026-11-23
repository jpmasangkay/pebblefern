@tool
class_name ResourceNode
extends StaticBody2D

## Unified destructible world resource node (Trees, 3 Stump sizes, Rocks/Boulders, Weeds).
## Supports live @tool editor texture preview, tiered hits, hit-shake, real-PNG particles, and pooled drops.

const AP := preload("res://scripts/core/asset_paths.gd")

enum NodeKind {
	TREE_DECIDUOUS = 0,
	TREE_PINE = 1,
	STUMP_SMALL = 2,
	STUMP_MEDIUM = 3,
	STUMP_LARGE = 4,
	ROCK_SMALL = 5,
	BOULDER_MEDIUM = 6,
	BOULDER_LARGE = 7,
	WEED_TUFT = 8,
	MINE_ROCK = 9,
	ORE_COPPER = 10,
	ORE_IRON = 11,
	CRYSTAL_VEIN = 12,
}

signal node_depleted(node: ResourceNode)

const TILE_SIZE: float = 16.0

@export var node_kind: NodeKind = NodeKind.STUMP_MEDIUM:
	set(value):
		node_kind = value
		if is_inside_tree() and sprite != null:
			_configure_for_kind()
@export var persist_scene_id: StringName = &"farm_sanctuary"
@export var override_drop_item_id: StringName = &""
@export var hides_ladder: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hit_particles: CPUParticles2D = $HitParticles

var max_hp: int = 3
var current_hp: int = 3
var required_tool: ToolData.ToolKind = ToolData.ToolKind.AXE
var required_tier: ToolData.ToolTier = ToolData.ToolTier.BASIC
var drop_item_id: StringName = &"wood"
var drop_count: int = 3
var converts_to_stump: bool = false
var converted_stump_kind: NodeKind = NodeKind.STUMP_MEDIUM

var _anim_frames: int = 1
var _anim_fps: float = 3.2
var _anim_elapsed: float = 0.0
var _shake_tween: Tween = null
var _flash_tween: Tween = null
var _destroyed: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(&"resource_nodes")
	if sprite == null or collision_shape == null or hit_particles == null:
		return
	_configure_for_kind()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _anim_frames <= 1 or _destroyed:
		return
	var frame_dur: float = 1.0 / _anim_fps
	_anim_elapsed += minf(delta, 0.1)
	if _anim_elapsed >= frame_dur:
		var adv: int = int(_anim_elapsed / frame_dur)
		_anim_elapsed -= float(adv) * frame_dur
		sprite.frame = (sprite.frame + adv) % _anim_frames


func get_grid_cell() -> Vector2i:
	return Vector2i(floori(global_position.x / TILE_SIZE), floori(global_position.y / TILE_SIZE))


func is_destroyed() -> bool:
	return _destroyed


## Applies a tool hit. Returns true if the node took damage or was destroyed.
func apply_tool_hit(tool: ToolData, drop_pool: DroppedItemPool, player_ref: Node2D) -> bool:
	if _destroyed or tool == null:
		return false

	if tool.tool_kind != required_tool:
		_play_shake(1.0)
		return false

	if int(tool.tier) < int(required_tier):
		_play_shake(1.6)
		EventBus.tool_tier_insufficient.emit(int(required_tier), get_grid_cell())
		return false

	var damage: int = maxi(1, tool.power)
	current_hp = maxi(0, current_hp - damage)
	_play_shake(2.6)
	_play_flash()
	_emit_hit_particles()

	if current_hp <= 0:
		_handle_depleted(drop_pool, player_ref)
	return true


func _handle_depleted(drop_pool: DroppedItemPool, player_ref: Node2D) -> void:
	var cell: Vector2i = get_grid_cell()
	var kind_name: StringName = _kind_to_name(node_kind)

	var actual_drop_id: StringName = override_drop_item_id if override_drop_item_id != &"" else drop_item_id
	if drop_pool != null and drop_count > 0:
		drop_pool.spawn_scatter_drops(global_position, actual_drop_id, drop_count, player_ref)

	if converts_to_stump:
		# Authentic Stardew-style felling: trees drop timber and leave a choppable stump behind!
		converts_to_stump = false
		node_kind = converted_stump_kind
		_configure_for_kind()
		EventBus.resource_node_destroyed.emit(kind_name, cell)
		return

	_destroyed = true
	collision_shape.set_deferred("disabled", true)
	sprite.visible = false
	if persist_scene_id != &"":
		GridStateManager.mark_resource_destroyed(persist_scene_id, cell)
	node_depleted.emit(self)
	EventBus.resource_node_destroyed.emit(kind_name, cell)
	# Allow final particle burst to finish before freeing node
	var timer: SceneTreeTimer = get_tree().create_timer(0.45)
	timer.timeout.connect(queue_free)


func _configure_for_kind() -> void:
	var tileset_tex: Texture2D = load(AP.TILESET_16PX) as Texture2D
	assert(tileset_tex != null, "Missing main tileset texture.")

	_anim_frames = 1
	_anim_elapsed = 0.0
	converts_to_stump = false
	collision_layer = 1
	collision_mask = 0
	collision_shape.disabled = false

	var rect: RectangleShape2D = RectangleShape2D.new()
	var chip_tex: Texture2D = load(AP.ITEM_WOOD) as Texture2D

	match node_kind:
		NodeKind.TREE_DECIDUOUS:
			sprite.texture = load(AP.TREE_DECIDUOUS_STRIP4) as Texture2D
			sprite.hframes = 4
			sprite.vframes = 1
			sprite.offset = Vector2(0.0, -14.0)
			_anim_frames = 4
			_anim_fps = 3.5
			max_hp = 4
			required_tool = ToolData.ToolKind.AXE
			required_tier = ToolData.ToolTier.BASIC
			drop_item_id = &"wood"
			drop_count = 4
			converts_to_stump = true
			converted_stump_kind = NodeKind.STUMP_MEDIUM
			rect.size = Vector2(12.0, 8.0)
			collision_shape.position = Vector2(0.0, -3.0)
			chip_tex = load(AP.ITEM_WOOD) as Texture2D

		NodeKind.TREE_PINE:
			sprite.texture = load(AP.TREE_PINE_STRIP4) as Texture2D
			sprite.hframes = 4
			sprite.vframes = 1
			sprite.offset = Vector2(0.0, -17.0)
			_anim_frames = 4
			_anim_fps = 3.0
			max_hp = 4
			required_tool = ToolData.ToolKind.AXE
			required_tier = ToolData.ToolTier.BASIC
			drop_item_id = &"wood"
			drop_count = 4
			converts_to_stump = true
			converted_stump_kind = NodeKind.STUMP_SMALL
			rect.size = Vector2(10.0, 8.0)
			collision_shape.position = Vector2(0.0, -3.0)
			chip_tex = load(AP.ITEM_WOOD) as Texture2D

		NodeKind.STUMP_SMALL:
			sprite.texture = _atlas_region(tileset_tex, AP.TILE_STUMP_SMALL, 1, 1)
			sprite.hframes = 1
			sprite.offset = Vector2(0.0, -5.0)
			max_hp = 2
			required_tool = ToolData.ToolKind.AXE
			required_tier = ToolData.ToolTier.BASIC
			drop_item_id = &"wood"
			drop_count = 2
			rect.size = Vector2(10.0, 7.0)
			collision_shape.position = Vector2(0.0, -2.0)
			chip_tex = load(AP.ITEM_WOOD) as Texture2D

		NodeKind.STUMP_MEDIUM:
			sprite.texture = _atlas_region(tileset_tex, AP.TILE_STUMP_MEDIUM, 1, 1)
			sprite.hframes = 1
			sprite.offset = Vector2(0.0, -5.0)
			max_hp = 3
			required_tool = ToolData.ToolKind.AXE
			required_tier = ToolData.ToolTier.BASIC
			drop_item_id = &"wood"
			drop_count = 3
			rect.size = Vector2(12.0, 8.0)
			collision_shape.position = Vector2(0.0, -2.0)
			chip_tex = load(AP.ITEM_WOOD) as Texture2D

		NodeKind.STUMP_LARGE:
			sprite.texture = _atlas_region(tileset_tex, AP.TILE_STUMP_LARGE, 1, 1)
			sprite.hframes = 1
			sprite.offset = Vector2(0.0, -5.0)
			max_hp = 5
			required_tool = ToolData.ToolKind.AXE
			required_tier = ToolData.ToolTier.COPPER
			drop_item_id = &"wood"
			drop_count = 6
			rect.size = Vector2(14.0, 8.0)
			collision_shape.position = Vector2(0.0, -2.0)
			chip_tex = load(AP.ITEM_WOOD) as Texture2D

		NodeKind.ROCK_SMALL:
			sprite.texture = _atlas_region(tileset_tex, AP.TILE_PEBBLE_LARGE, 1, 1)
			sprite.hframes = 1
			sprite.offset = Vector2(0.0, -4.0)
			max_hp = 2
			required_tool = ToolData.ToolKind.PICKAXE
			required_tier = ToolData.ToolTier.BASIC
			drop_item_id = &"stone"
			drop_count = 2
			rect.size = Vector2(12.0, 8.0)
			collision_shape.position = Vector2(0.0, -2.0)
			chip_tex = load(AP.ITEM_ROCK) as Texture2D

		NodeKind.BOULDER_MEDIUM:
			# Verified 32x32 medium grey quarry boulder at (53,29)..(54,30)
			sprite.texture = _atlas_region(tileset_tex, Vector2i(53, 29), 2, 2)
			sprite.hframes = 1
			sprite.offset = Vector2(0.0, -10.0)
			max_hp = 3
			required_tool = ToolData.ToolKind.PICKAXE
			required_tier = ToolData.ToolTier.BASIC
			drop_item_id = &"stone"
			drop_count = 4
			rect.size = Vector2(18.0, 12.0)
			collision_shape.position = Vector2(0.0, -4.0)
			chip_tex = load(AP.ITEM_ROCK) as Texture2D

		NodeKind.BOULDER_LARGE:
			# Verified 32x32 large grey quarry boulder at (49,29)..(50,30) — requires Copper Pickaxe (Tier 2)!
			sprite.texture = _atlas_region(tileset_tex, Vector2i(49, 29), 2, 2)
			sprite.hframes = 1
			sprite.offset = Vector2(0.0, -12.0)
			max_hp = 6
			required_tool = ToolData.ToolKind.PICKAXE
			required_tier = ToolData.ToolTier.COPPER
			drop_item_id = &"stone"
			drop_count = 8
			rect.size = Vector2(22.0, 14.0)
			collision_shape.position = Vector2(0.0, -4.0)
			chip_tex = load(AP.ITEM_ROCK) as Texture2D

		NodeKind.WEED_TUFT:
			sprite.texture = _atlas_region(tileset_tex, AP.TILE_GRASS_TUFT_A, 1, 1)
			sprite.hframes = 1
			sprite.offset = Vector2(0.0, -4.0)
			max_hp = 1
			required_tool = ToolData.ToolKind.SCYTHE
			required_tier = ToolData.ToolTier.BASIC
			drop_item_id = &"fiber"
			drop_count = 1
			collision_layer = 0 # Walkable meadow weed
			collision_shape.disabled = true
			rect.size = Vector2(10.0, 6.0)
			chip_tex = load(AP.ICON_PLANT) as Texture2D

		NodeKind.MINE_ROCK:
			sprite.texture = _atlas_region(tileset_tex, AP.TILE_PEBBLE_LARGE, 1, 1)
			sprite.hframes = 1
			sprite.modulate = Color(0.86, 0.88, 0.94, 1.0)
			sprite.offset = Vector2(0.0, -4.0)
			max_hp = 2
			required_tool = ToolData.ToolKind.PICKAXE
			required_tier = ToolData.ToolTier.BASIC
			drop_item_id = &"stone"
			drop_count = 2
			rect.size = Vector2(12.0, 9.0)
			collision_shape.position = Vector2(0.0, -2.0)
			chip_tex = load(AP.ITEM_ROCK) as Texture2D

		NodeKind.ORE_COPPER:
			sprite.texture = _atlas_region(tileset_tex, AP.TILE_ORE_VEIN_COPPER, 2, 2)
			sprite.hframes = 1
			sprite.modulate = Color.WHITE
			sprite.offset = Vector2(0.0, -9.0)
			max_hp = 2
			required_tool = ToolData.ToolKind.PICKAXE
			required_tier = ToolData.ToolTier.BASIC
			drop_item_id = &"copper_ore"
			drop_count = 2
			rect.size = Vector2(16.0, 11.0)
			collision_shape.position = Vector2(0.0, -3.0)
			chip_tex = _atlas_region(tileset_tex, AP.TILE_COPPER_ORE, 1, 1)

		NodeKind.ORE_IRON:
			sprite.texture = _atlas_region(tileset_tex, AP.TILE_ORE_VEIN_GOLD, 2, 2)
			sprite.hframes = 1
			sprite.modulate = Color(0.84, 0.90, 1.0, 1.0)
			sprite.offset = Vector2(0.0, -9.0)
			max_hp = 3
			required_tool = ToolData.ToolKind.PICKAXE
			required_tier = ToolData.ToolTier.BASIC
			drop_item_id = &"iron_ore"
			drop_count = 2
			rect.size = Vector2(16.0, 11.0)
			collision_shape.position = Vector2(0.0, -3.0)
			chip_tex = _atlas_region(tileset_tex, AP.TILE_IRON_ORE, 1, 1)

		NodeKind.CRYSTAL_VEIN:
			sprite.texture = _atlas_region(tileset_tex, AP.TILE_ORE_VEIN_CRYSTAL, 2, 2)
			sprite.hframes = 1
			sprite.modulate = Color.WHITE
			sprite.offset = Vector2(0.0, -9.0)
			max_hp = 3
			required_tool = ToolData.ToolKind.PICKAXE
			required_tier = ToolData.ToolTier.BASIC
			drop_item_id = &"cave_crystal"
			drop_count = 1
			rect.size = Vector2(16.0, 11.0)
			collision_shape.position = Vector2(0.0, -3.0)
			chip_tex = _atlas_region(tileset_tex, AP.TILE_CAVE_CRYSTAL, 1, 1)

	current_hp = max_hp
	collision_shape.shape = rect
	hit_particles.texture = chip_tex
	if _anim_frames > 1:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(global_position.x * 53.0 + global_position.y * 131.0)
		sprite.frame = rng.randi_range(0, _anim_frames - 1)


func _atlas_region(atlas: Texture2D, coords: Vector2i, w_tiles: int, h_tiles: int) -> AtlasTexture:
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = atlas
	at.region = Rect2(coords.x * 16, coords.y * 16, w_tiles * 16, h_tiles * 16)
	return at


func _play_shake(amp: float) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	sprite.position.x = 0.0
	_shake_tween = create_tween()
	_shake_tween.tween_property(sprite, "position:x", -amp, 0.035)
	_shake_tween.tween_property(sprite, "position:x", amp, 0.045)
	_shake_tween.tween_property(sprite, "position:x", -amp * 0.5, 0.035)
	_shake_tween.tween_property(sprite, "position:x", 0.0, 0.035)


func _play_flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	sprite.modulate = Color(1.45, 1.45, 1.45, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.10)


func _emit_hit_particles() -> void:
	hit_particles.restart()
	hit_particles.emitting = true


func _kind_to_name(kind: NodeKind) -> StringName:
	match kind:
		NodeKind.TREE_DECIDUOUS:
			return &"tree_deciduous"
		NodeKind.TREE_PINE:
			return &"tree_pine"
		NodeKind.STUMP_SMALL:
			return &"stump_small"
		NodeKind.STUMP_MEDIUM:
			return &"stump_medium"
		NodeKind.STUMP_LARGE:
			return &"stump_large"
		NodeKind.ROCK_SMALL:
			return &"rock_small"
		NodeKind.BOULDER_MEDIUM:
			return &"boulder_medium"
		NodeKind.BOULDER_LARGE:
			return &"boulder_large"
		NodeKind.WEED_TUFT:
			return &"weed_tuft"
		NodeKind.MINE_ROCK:
			return &"mine_rock"
		NodeKind.ORE_COPPER:
			return &"ore_copper"
		NodeKind.ORE_IRON:
			return &"ore_iron"
		NodeKind.CRYSTAL_VEIN:
			return &"crystal_vein"
		_:
			return &"resource"
