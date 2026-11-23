# 🌿 Pebblefern

[![Godot](https://img.shields.io/badge/Godot-4.7-478CBF.svg?style=flat&logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![Renderer](https://img.shields.io/badge/Renderer-GL%20Compatibility-purple.svg)](https://godotengine.org/)
[![Git LFS](https://img.shields.io/badge/Git%20LFS-Enabled-orange.svg)](https://git-lfs.github.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Pebblefern** is a cozy 2D pixel-art farming and island life-sim RPG created in **Godot 4.7** featuring persistent multi-season crop cultivation, a handcrafted 96×60 archipelago island, villager relationships & seasonal festivals, a 3-floor subterranean mine with real-time sword combat, placeable farm crafting & ore smelting, procedural retro PCM audio synthesis, 3-slot atomic JSON saves, and seamless Keyboard/Mouse, Gamepad, and Multi-Touch Mobile controls.

---

## 🚀 Key Features

* **🌱 Persistent Farming, Foraging & Multi-Biome Fishing**: Till, water, plant, and harvest 11 distinct crops across 4 seasons (`GridStateManager`, `ActionValidator`), forage wild berries, chop island timber and quarry boulders, and cast a 4-state fishing loop (`CASTING → WAITING → BITE_WINDOW → REELING`) across river, spring, and ocean biomes for 9 fish species.
* **🏝️ Handcrafted Archipelago World & Cozy Interiors**: Explore Solstice Sanctuary Farm and Bramblebrook Village across a 96×60 tile island (`IslandWorldBuilder`) with multi-tier cliffs, waterfalls, bridged offshore islets, a cozy Farmhouse (`FarmhouseInterior`), and 5 uniquely furnished villager interiors (`NpcInterior`) linked by smooth door portals (`SceneTransition`).
* **⛏️ Subterranean Mine Cave & Real-Time Combat**: Descend a 3-floor cavern (`MineFloor`) lit by flickering `PointLight2D` wall torches and a player lantern aura, mining depth-scaled copper/iron ore and crystal/ruby veins, uncovering hidden descending ladders, and battling animated Skeleton enemies (`MineEnemy`) with directional sword swings, knockback, hitstop, and safe farmhouse rescue at 0 Vitality (`VitalitySystem`).
* **🔨 Economy, Crafting, Smelting & Tool Upgrades**: Earn Sunbursts (`EconomyManager`) through the overnight Sanctuary Shipping Chest (with undo-last support) or Maren's Seed Shop, smelt copper and iron bars in a placeable Furnace, craft 6 placeable farm structures (16-slot Chest, Furnace, Outdoor Torch, Wooden Fence, Stone Path, Scarecrow), and upgrade tools at Kaelen's Blacksmith.
* **💛 Living Village, Quests & Seasonal Festivals**: Befriend 5 Bramblebrook residents — Maren, Kaelen, Mayor Aldric, Bram, and Lyra (`SocialManager`) — with 0–10 heart tracking, daily conversations, weekly gift preferences, rotating Community Board quests (`QuestManager`), and the annual Bloom Blossom Festival (`FestivalManager`) with Mayor Aldric's Harvest Showcase judging.
* **🌦️ Dynamic Atmosphere, Retro Audio & Cross-Platform Controls**: Experience a 06:00 AM–02:00 AM clock and 28-day 4-season calendar (`Bloom`, `Sun`, `Harvest`, `Frost`) with custom seasonal foliage shading (`season_tint.gdshader`), day/night `CanvasModulate` lighting, rain/snow particle weather (`WorldAtmosphere`), a pre-baked 20-sound procedural PCM SFX synth (`AudioManager`), lossless 3-slot JSON saves (`SaveManager`), and auto-switching Keyboard/Mouse, Xbox/PlayStation/Switch Gamepad, and Multi-Touch Mobile controls (`InputModeManager`, `MobileControls`).

---

## 🛠️ Tech Stack & Requirements

* **Engine**: Godot `4.7` (GDScript)
* **Renderer**: GL Compatibility (`gl_compatibility`, pixel-snapped `320×180` virtual viewport scaled cleanly to `1280×720`)
* **Input System**: Auto-switching Keyboard/Mouse, Gamepad (Xbox / PlayStation / Switch glyphs via `InputModeManager`), and Multi-Touch Mobile Controls (`MobileControls`)
* **Audio**: Procedural 8-voice `AudioStreamGenerator` PCM retro SFX synthesizer (`AudioManager`)
* **Large File Storage**: **Git LFS** (tracks pixel-art spritesheets, tilesets, UI sprites, `.aseprite` source animations, `.gif` previews, and `.svg` icons)

---

## 📦 Cloning & Git LFS Setup

This repository uses **Git LFS** to manage pixel-art tilesets, character & UI spritesheets (`.png`, `.svg`), animation previews (`.gif`), and Aseprite source files (`.aseprite`).

### Prerequisites
Make sure you have [Git LFS](https://git-lfs.github.com/) installed before cloning:
```bash
git lfs install
```

### Cloning the Repository
Clone the repository using Git:
```bash
git clone https://github.com/jpmasangkay/pebblefern.git
cd pebblefern
git lfs pull
```

### Opening in Godot
Open `project.godot` in **Godot 4.7+** and press **F5** to launch from `res://scenes/ui/title_screen.tscn`.

---

## 📂 Project Architecture

```
pebblefern/
├── project.godot                       # Engine Config, 13 Autoloads, InputMap & Pixel Rendering Setup
├── assets/                             # Art Packs (Managed via Git LFS)
│   ├── Controllers and Keyboard/       # Vryell 16x16 Keyboard, Mouse, Xbox, PS & Switch Glyph Sheets
│   └── Sunnyside_World_ASSET_PACK_V2.1/# Sunnyside World Tilesets, Character Strips, Crops & UI Art
├── autoload/                           # 13 Global Singletons in Topological Dependency Order
│   ├── event_bus.gd                    # Decoupled Signal Hub for World, UI, Audio & Progression
│   ├── input_mode_manager.gd           # Live Device Switching, Vendor Detection & Settings Persistence
│   ├── vitality_system.gd              # Stamina/Vitality Economy, Exhaustion & Cave Rescue Logic
│   ├── inventory_manager.gd            # 24-Slot SoA Backpack, 8-Slot Hotbar & O(1) Resource Lookups
│   ├── grid_state_manager.gd           # Persistent Cross-Scene Soil, Crop Growth & Placed Objects
│   ├── time_manager.gd                 # 06:00 AM–02:00 AM Clock, 4-Season Calendar & Weather RNG
│   ├── audio_manager.gd                # 8-Voice Pre-Baked Procedural Retro PCM SFX Synthesizer
│   ├── scene_transition.gd             # Smooth Fade Transitions & Doorstep Return Metadata
│   ├── economy_manager.gd              # Sunbursts (G), Overnight Shipping Ledger & Tool Upgrades
│   ├── social_manager.gd               # 5 Villager Profiles, Hearts (0–10), Gifts & Dialogue
│   ├── quest_manager.gd                # Daily Rotating Community Board Quests & Turn-Ins
│   ├── festival_manager.gd             # Bloom Blossom Festival Lifecycle & Harvest Showcase
│   └── save_manager.gd                 # Lossless 3-Slot Atomic JSON Save/Load Persistence
├── resources/                          # Typed Custom Resource Schemas & .tres Game Database
│   ├── crops/                          # 11 Seasonal CropData Definitions (Beetroot to Wheat)
│   ├── items/                          # 48 ItemData Definitions (Seeds, Produce, Fish, Ores, Placeables)
│   ├── npcs/                           # 5 NpcData Resident Profiles (Aldric, Bram, Kaelen, Lyra, Maren)
│   ├── recipes/                        # 6 Craftable RecipeData Definitions (Chest, Furnace, Torch, etc.)
│   ├── tools/                          # 6 Upgradeable ToolData Definitions (Hoe, Axe, Rod, etc.)
│   └── sunnyside_tileset.tres          # Master 16px Pixel-Art TileSet Resource
├── scenes/                             # Packed Godot Scenes
│   ├── entities/                       # Player, CropNode, ResourceNode & DroppedItem
│   ├── props/                          # Houses, Bridges, Market Stall, Shipping Bin, Trees & Landmarks
│   ├── tools/                          # Scene Builders & Headless Automated Verification Runners
│   ├── ui/                             # Title Screen, HUD, Inventory, Shop, Pause & Mobile Touch UI
│   └── world/                          # FarmSanctuary, FarmhouseInterior, NpcInterior & MineFloor
├── scripts/                            # GDScript Gameplay, UI, World & Tooling Systems
│   ├── core/                           # ActionValidator, AssetPaths & ControlIcons Atlas Resolver
│   ├── entities/                       # 3-Layer Synchronized Player, MineEnemy & DroppedItemPool
│   ├── tools/                          # Procedural Scene Compilers & Phase 1–6 Verification Suites
│   ├── ui/                             # 9-Slice Sunnyside Modals, Prompt Badges & Focus Navigation
│   └── world/                          # IslandWorldBuilder, WorldAtmosphere, MineFloor & Interactables
└── shaders/                            # Custom 2D Shaders
    └── season_tint.gdshader            # Selective Seasonal Foliage Tinting (Bloom/Sun/Harvest/Frost)
```

---

## 🎮 Controls

| Action | Keyboard / Mouse | Gamepad |
| :--- | :--- | :--- |
| **Movement** | `W`, `A`, `S`, `D` / `Arrow Keys` | `Left Stick` / `D-Pad` |
| **Sprint** | `Shift` (hold while moving) | — |
| **Use Tool / Sword / Fish** | `Left Click` / `Space` / `C` | `X` / `Square` / `Y` (West) |
| **Interact / Talk / Harvest** | `Right Click` / `E` | `A` / `Cross` / `B` (South) |
| **Select Hotbar Slot** | `1`–`8` | — |
| **Cycle Hotbar / Menu Tabs** | `Mouse Wheel` | `LB` / `RB` (`L1` / `R1`) |
| **Backpack / Craft / Tools / People** | `Tab` / `I` | `Y` / `Triangle` / `X` (North) |
| **Toggle Quest Tracker** | `Q` | `Back` / `Select` / `Minus` |
| **Pause & Save Menu / Back** | `Escape` | `Start` / `Options` / `B` |

*Note: On touchscreen devices — or when Touch Controls are set to **On** in the Pause Menu — the multi-touch overlay (`MobileControls`) with an analog virtual thumbstick, dedicated Use Tool / Interact buttons, and quick Pack / Pause buttons is automatically enabled.*

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
