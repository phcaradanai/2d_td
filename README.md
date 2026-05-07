# Clone Tower Defense

A high-fidelity, industrial sci-fi Tower Defense experience built with **Godot 4.6.2**. This prototype features modular procedural visuals, advanced wave previews, and a campaign progression system.

## Current Build Scope
- **Levels**: 20 Playable missions across 4 distinct thematic areas.
- **Towers**: 7 Unique tower types (Basic, Rapid, Cannon, Slow, Sniper, Lightning, Sawblade).
- **Environment**: Modular industrial "dark mode" aesthetic with glowing circuit paths.
- **Hero System**: Guardian deployment available starting from Level 11.
- **Map Mechanics**: Transition from "Free Build" to "Restricted Foundations" starting at Level 12.
- **Progression**: Local save system, score/star ratings, and leaderboard scaffolding.
- **Platform**: Optimized for high-performance Web (WASM/WebGL) and Desktop.

## Features
- **Wave Preview UI**: Authorization-style holographic energy walls and triple-chevron flow indicators.
- **Procedural Graphics**: All towers and environments use high-performance vector-style drawing for maximum clarity.
- **Area Themes**: Distinct color palettes and decorative layers (Vents, Cables, Circuitry) for different facility sectors.
- **Release Hygiene**: Gated debug/dev tools and optimized console logging for a clean production experience.

## How to Play
- **Build**: Select a tower from the left sidebar and click on a valid grid cell (highlighted in cyan).
- **Hero (Level 11+)**: Click the Guardian icon in the bottom-left to deploy your hero when gold and cooldown allow.
- **Select/Upgrade**: Click an existing tower to view advanced stats and upgrade levels.
- **Cancel**: Right-click or press `Esc` to exit build mode or deselect units.
- **Start Wave**: Press the "Start Wave" button or hit `F3` (Debug only).
- **Pause**: Press `Space` or the Pause button to toggle game speed.

## Development Status

### [x] Implemented
- Modular Map Visual Layer (Procedural walls/trench look).
- Hero Guardian logic and manual deployment system.
- Foundation-restricted build mode for advanced levels.
- 20-level campaign data structure and area theme engine.
- Web-optimized audio manager with unlock-on-gesture.
- Score/Star calculation based on health, gold, and time.

### [/] In Progress
- Enemy Type Foundation (Land / Air logic refinement).
- Tower Loadout Constraints (Selecting specific towers per mission).
- Tactical Wave Intel (Detailed composition reports in HUD).

### [ ] Backlog
- Anti-Air specific towers and targeting rules.
- Consumable Skill System (One-time use active abilities).
- Persistent Global Leaderboard integration.

## Technical Setup
- **Engine**: Godot 4.6.2 (Stable).
- **Running in Editor**: Open `project.godot` and press `F5`.
- **Web Testing**: Use a local server to handle SharedArrayBuffer headers:
  ```bash
  python3 -m http.server 8080
  ```
  Then visit `http://localhost:8080`.

## Credits
- **Developed by**: Antigravity AI
- **Assets**: Procedural generation and curated open-source sound effects.