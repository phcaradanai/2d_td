# Web Release Checklist

Before finalizing a web build, verify the following items in a fresh browser session (Hard Reload/Incognito).

## 1. Browser Security & Gesture
- [ ] Build served via HTTP (e.g. `localhost:8080`), not `file://`.
- [ ] Initial **Audio Unlock Overlay** appears correctly.
- [ ] Clicking "Play" (or equivalent) dismisses the overlay and starts the game.

## 2. Audio Verification
- [ ] Menu music starts automatically after the user gesture.
- [ ] **Test SFX** button in Debug Panel (if enabled) is audible.
- [ ] **Hard Audio Test** (beep) is audible.
- [ ] **Gameplay SFX** are audible:
    - [ ] Tower placement.
    - [ ] Projectile fire.
    - [ ] Enemy impact/death.
    - [ ] Start Wave click.
- [ ] **Music** loops correctly during gameplay.

## 3. UI & Settings
- [ ] **Master Volume** slider affects both Music and SFX.
- [ ] **Mute** toggles work for all channels.
- [ ] Settings persist across browser refreshes (if using SaveManager).
- [ ] UI sliders do not "jump" or overwrite values unexpectedly on startup.

## 4. Stability & Performance
- [ ] No "RED" errors in the browser console (F12).
- [ ] No "stream cannot be sampled" warnings.
- [ ] Game runs at stable 60 FPS (check Debug Panel).
- [ ] Browser does not report "Out of Memory" or "Heavy CPU Usage".

## 5. Release Cleanup
- [ ] `debug_panel_enabled` set to `false` in `Main.tscn` (unless for beta testing).
- [ ] `debug_audio_enabled` set to `false` in `AudioManager`.
- [ ] `index.pck` and `index.wasm` are correctly named in the export directory.
- [ ] Console is free of verbose debug spam.
