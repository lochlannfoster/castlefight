# Castle Fight Autobattler

A multiplayer 2D isometric autobattler game inspired by Warcraft 3's Castle Fight mod. This game is built using the Godot Engine.

## Game Overview

Castle Fight is a lane-based autobattler where players control only their worker unit to build structures, purchase items, and research technology. Units spawn infinitely and automatically from buildings and move toward the enemy headquarters. The objective is to destroy the opposing team's headquarters.

## Project Structure

```
CastleFight/
├── assets/               # Game assets (sprites, audio, etc.)
├── data/                 # Configuration files
│   ├── buildings/        # Building definitions
│   ├── combat/           # Combat system configurations
│   ├── items/            # Item definitions
│   ├── tech_trees/       # Race-specific tech trees
│   └── units/            # Unit definitions
├── scenes/               # Godot scene files
│   ├── game/             # Main game scene
│   ├── lobby/            # Multiplayer lobby
│   └── main_menu/        # Main menu
├── scripts/              # GDScript files
│   ├── building/         # Building-related scripts
│   ├── combat/           # Combat system scripts
│   ├── core/             # Core game systems
│   ├── economy/          # Economy management
│   ├── networking/       # Multiplayer functionality
│   ├── ui/               # User interface scripts
│   ├── unit/             # Unit-related scripts
│   └── worker/           # Worker unit scripts
└── tests/                # Unit tests
```

## Implemented Features

The following features have been implemented according to the master prompt:

### Core Game Framework
- [x] Grid system for building placement
- [x] Worker unit movement and controls
- [x] Building construction mechanics
- [x] Grid highlighting for valid building placement
- [x] Worker auto-repair toggle
- [x] Building construction progress system

### Combat System
- [x] Unit behavior and autonomous pathfinding
- [x] Attack-move functionality toward enemy HQ
- [x] Target acquisition and engagement
- [x] Health and mana regeneration system
- [x] Damage calculation with armor types and attack types
- [x] Buffs and debuffs system
- [x] Ability framework

### Economy System
- [x] Resource tracking (Gold, Wood, Supply)
- [x] Income generation every 10 seconds
- [x] Building costs and purchase system
- [x] Unit kill bounties
- [x] Income bonuses from building construction

### Tech System
- [x] Tech tree configuration system
- [x] Race-specific buildings and units
- [x] Upgrade effects implementation
- [x] Building and unit unlocking system

### Multiplayer System
- [x] Client-server networking model
- [x] Player-hosted servers
- [x] Lobby system for game setup
- [x] Team selection
- [x] Player ready status
- [x] Reconnection system
- [x] Lag compensation and input handling

### Map System
- [x] Lane-based map generation
- [x] Team territories and bases
- [x] Dynamic map generation

### Fog of War
- [x] Visibility system based on unit line of sight
- [x] Previously seen areas vs. currently visible
- [x] Fog of war updates with unit movement

### User Interface
- [x] Main menu
- [x] Multiplayer lobby interface
- [x] In-game resource display
- [x] Building menu
- [x] Unit information panel
- [x] Income and bounty notifications

## Remaining Tasks

The following features still need to be implemented:

### Art Assets
- [ ] Unit sprites and animations
- [ ] Building sprites and animations
- [ ] UI elements and icons
- [ ] Effect animations

### Audio
- [ ] Unit sound effects
- [ ] Building sound effects
- [ ] Combat sound effects
- [ ] Background music

### Gameplay Features
- [ ] Complete implementation of all races
- [ ] Item system finalization
- [ ] Special abilities for units
- [ ] Late-game power-ups

### Technical Features
- [ ] Complete netcode optimization
- [ ] Additional unit tests
- [ ] Performance optimization
- [ ] Map editor (optional)

### UI Enhancements
- [ ] Minimap implementation
- [ ] Unit selection interface
- [ ] Tech tree visualization
- [ ] Game statistics tracking
- [ ] Post-game summary screen

## How to Run the Project

1. Install Godot Engine (version 3.5 or later)
2. Clone this repository
3. Open the project in Godot
4. Run the main scene to start the game

## Testing

Unit tests are available in the `tests/` directory. To run them:

1. Install the GUT addon for Godot
2. Open the project in Godot
3. Run the test scene or individual test scripts

## Development Setup

For local development and testing, you can:

1. Run the game in editor
2. Join a local multiplayer game to test both teams (127.0.0.1 as server IP)
3. Use the network multiplayer view in Godot to debug network traffic

## License

This project is developed for educational and personal use.

## Credits

Based on the concept of Warcraft 3's Castle Fight mod.