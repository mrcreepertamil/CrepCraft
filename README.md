# CrepCraft

A small Minecraft-inspired 3D sandbox project built with **Godot 4.7** and **GDScript**.

![CrepCraft screenshot](doc/image.png)

## Features

- Seed-based procedural world generation with continental terrain, hills, ridges, caves, biome regions, trees, and vegetation
- Main menu with random or custom world seeds
- Separate compact binary world saves for each seed
- Binary chunk files store block overrides; one binary world file stores player and environment state
- Periodic autosaving and temporary-file binary saves
- Asynchronous chunk loading
- Blocks and plants
- Persistent worlds with compact binary save files
- Day-and-night cycle
- Dynamic lighting
- On-screen touch controls for Android and iOS

## JSON content data

CrepCraft includes a Minecraft-inspired JSON content registry. Definitions are stored in `data/`:

- `blocks.json` — block names, hardness, transparency, sprite flags, texture coordinates, and tool tags
- `items.json` — item names, stack sizes, and block/tool references
- `biomes.json` — biome climate and vegetation settings
- `recipes.json` — example shaped, shapeless, and smelting recipe definitions
- `mobs.json` — example mob attributes and drops
- `worldgen.json` — default terrain-generation settings

The `GameData` autoload reads these files at startup. Scripts can access definitions with `GameData.get_definition("blocks", "grass")`, list IDs with `GameData.get_ids("blocks")`, or retrieve a full category with `GameData.get_category("items")`. The procedural generator reads its terrain, biome, cave, tree, and foliage settings from `data/worldgen.json`. World saves live in `user://worlds/seed_<seed>/`: `world.bin` stores the seed, player transform and time of day; each chunk has a compact `chunk_x_y_z.bin` file containing packed local block indices and block IDs. Files use a versioned binary header, and disk access is mutex-protected because chunks load on worker threads. Block removals are stored as explicit empty-block overrides so removed generated blocks stay removed after reloading. Earlier JSON world saves are not automatically migrated. Call `GameData.reload()` after changing content JSON files while the game is running.

These files establish the data-definition system. Existing block rendering, inventory, crafting, biome selection, and mob gameplay are not yet fully driven by these definitions.

## Controls

### Desktop

| Action | Input |
| --- | --- |
| Move forward | W |
| Move backward | S |
| Move left | A |
| Move right | D |
| Jump | Space or E |
| Crouch | Q or Ctrl |
| Sprint | F or Shift |
| Break a block | Left mouse button |
| Place a block | Right mouse button |
| Unfocus the game window | Esc |

### Mobile

- **Move:** Drag the virtual joystick in the lower-left corner.
- **Look around:** Drag on the right side of the screen, above the action buttons.
- **Break / Place:** Use the on-screen buttons on the right.
- **Jump / Crouch:** Use the lower-right buttons.

Touch controls appear automatically in Android and iOS builds. Desktop controls remain unchanged.

## Getting started

1. Install **Godot 4.7**.
2. Clone or download this repository.
3. Open the project in Godot by importing the `project.godot` file.
4. Press **F5** to run the main scene, or **F6** to run the currently open scene.

## Exporting for mobile

1. Install the export templates for your Godot version.
2. In Godot, open **Project → Export** and add an **Android** preset.
3. Configure the Android SDK and required build tools in **Editor Settings → Export → Android**.
4. Export an APK for testing or an AAB for publishing.

An iOS export requires a macOS computer with Xcode configured. Mobile controls are included, but device performance and export settings still need to be tested on the target devices.

## Built with

- [Godot Engine](https://godotengine.org/) 4.7
- GDScript
- Godot's built-in FileAccess binary APIs for world persistence

## Project structure

- `scenes/` — Godot scenes
- `scripts/` — GDScript source files
- `resources/` — project resources
- `addons/` — editor add-ons
- `doc/` — documentation and images

## About

CrepCraft is a learning and development project: a Minecraft-inspired sandbox built from the ground up in Godot. Features and details may change as development continues.
