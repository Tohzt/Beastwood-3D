# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Beastwood is a multiplayer first-person physics sandbox game built with Godot 4.5 using GDScript. Players interact with physics-based objects (PNC, darts, dartboard, basketball, etc.) in a shared environment with ENet peer-to-peer networking.

## Architecture

### Entry Point
- Main scene: `world.tscn` with `world.gd` as the central controller
- `world.gd` manages game state: login → color picker → gameplay → pause menu

### Core Systems

**Player System (`Player/`)**
- `Player.gd` extends CharacterBody3D for first-person controls
- Dual camera modes: first-person and third-person (Tab toggle)
- TwistPivot/PitchPivot hierarchy for camera control with SpringArm3D
- Jump charging system with backflip at 90% charge
- Raycast-based interaction system (E key)

**Interactive Objects (`Objects/`)**
- All holdable items inherit from `HoldableClass` (extends RigidBody3D)
- Key methods: `hold(player_id)`, `throw(flip_power)`, `drop()`, `respawn()`
- Objects auto-respawn when falling below y=-500
- Outline shader (`gun.gdshader`) for selection feedback

**Multiplayer**
- ENet peer-to-peer on port 8910
- Default server address: 68.230.70.164 (configurable via @export)
- RPC patterns: `@rpc("any_peer", "call_local")` for state sync
- Authority set in `_enter_tree()` based on peer ID

### Node Groups
- `Players` - All player instances
- `PNC` - Ping pong clicker objects
- `Dartboard` - Dartboard object
- `Darts` - Dart instances
- `Trampoline` - Jump-boost surfaces
- `Other` - General respawnable objects
- `ColorPicker` - Color selection UI

### Input Bindings
- WASD: Movement
- Space: Jump (hold to charge)
- Shift: Sprint
- E: Interact/pickup
- Tab: Toggle camera mode
- Left Click: Throw held item
- Right Click: Drop held item
- Mouse Wheel: Adjust flip power (0-100)

## Key Files

| File | Purpose |
|------|---------|
| `world.gd` | Main game controller, multiplayer setup, UI state |
| `Player/Player.gd` | Player movement, camera, interaction |
| `Objects/holdable_class.gd` | Base class for all interactive objects |
| `Objects/pnc.gd` | PNC object with flip power display |
| `Objects/dartboard.gd` | Triggers 3-on-1 pole mode when PNC touches |

## Addons

**Mirror (`addons/Mirror/`)** - Real-time mirror reflections by Norodix. Requires setting the player camera reference.

## Export

Windows x86_64 export configured to `Exports/WelcomeHome/ForTheBoys.exe`
