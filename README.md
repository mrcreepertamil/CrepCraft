# CrepCraft

A small Minecraft-inspired 3D sandbox project built with **Godot 4.7** and **GDScript**.

![CrepCraft screenshot](doc/image.png)

## Features

- Seed-based procedural world generation with continental terrain, hills, ridges, caves, biome regions, trees, and vegetation
- Main menu with random or custom world seeds
- Minecraft-inspired binary world saves for each seed (`level.dat`, region files, and player data)
- Region files group many chunks together and store compact block overrides
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

The `GameData` autoload reads these files at startup. Scripts can access definitions with `GameData.get_definition("blocks", "grass")`, list IDs with `GameData.get_ids("blocks")`, or retrieve a full category with `GameData.get_category("items")`. The procedural generator reads its terrain, biome, cave, tree, and foliage settings from `data/worldgen.json`. World saves live in `user://worlds/seed_<seed>/` in a Minecraft-inspired layout: `level.dat` stores the world seed and environment time, `playerdata/<id>.dat` stores each player's transform, and `region/r.<x>.<z>.ccr` stores up to 32×32 chunks per region. Region files contain versioned binary chunk records with compact local block indices and block IDs. Disk access is mutex-protected because chunks load on worker threads, and writes use temporary files before replacement. Block removals are stored as explicit empty-block overrides so removed generated blocks stay removed after reloading. This is CrepCraft's own binary format, not Minecraft's NBT format, and older `world.bin` / per-chunk binary saves are not automatically migrated. Call `GameData.reload()` after changing content JSON files while the game is running.

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


## Global resource packs

Players can install texture packs without modifying the game files. Open **Resource Packs** from the main menu, then choose **Open Resource Packs Folder**. Create one folder per pack inside `user://resource_packs/` and put a replacement `spritesheet.png` inside it:

```text
resource_packs/
  MyTexturePack/
    spritesheet.png
  AnotherPack/
    spritesheet.png
```

The PNG uses the same tile layout as `resources/spritesheet.png`: each tile is 16×16 pixels, and the image width and height must both be multiples of 16. Keep the existing tile positions so block IDs continue to point at the correct textures. Select the pack in the main menu and press **Apply Resource Pack**. The selected pack is saved in the user's settings and is applied globally to opaque blocks, transparent blocks, and sprite blocks. Choosing **Default** restores the built-in textures.
