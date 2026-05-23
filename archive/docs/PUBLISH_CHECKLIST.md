# Tower Defense Publish Checklist

Use this checklist before every production release to itch.io, GitHub Pages, or other platforms.

## 1. Export Preparation
- [ ] Set `debug_panel_enabled = false` in `Main.tscn`.
- [ ] Set `debug_coordinates = false` in `Main.tscn`.
- [ ] Verify `VERSION` constant in `Main.gd` is updated (e.g., `v0.1.0 Prototype`).
- [ ] Run a final test in the Godot Editor.

## 2. Web Export
- [ ] Export using the "Web" preset.
- [ ] Use clean naming: `index.html`.
- [ ] Ensure "VRAM Compression" is compatible with web.
- [ ] Ensure "Audio Worklet" files are included in the export directory.

## 3. Local Verification
- [ ] Start a local server: `python3 -m http.server 8080`.
- [ ] Open `http://localhost:8080` in a private/incognito window.
- [ ] **Audio Test**: Click anywhere to unlock audio. Verify menu music plays.
- [ ] **Gameplay Test**:
    - [ ] Load Level 1.
    - [ ] Place a tower.
    - [ ] Start a wave.
    - [ ] Verify SFX (shoot, hit, death).
    - [ ] Reach Victory/Game Over.
- [ ] **UI Test**:
    - [ ] Open Settings.
    - [ ] Adjust volumes.
    - [ ] Open Credits.
    - [ ] Return to Main Menu.
- [ ] **Save Test**: Verify "Best Score" persists after a refresh (if local storage is working).

## 4. Console Audit
- [ ] Open Browser DevTools (F12).
- [ ] Verify there are NO red errors.
- [ ] Verify there is NO excessive logging (spamming per frame/hit).

## 5. Packaging (itch.io)
- [ ] Zip all files in the export folder (do not zip the parent folder itself).
- [ ] Name the zip: `tower-defense-web-[version].zip`.
- [ ] Upload to itch.io and select "This file will be played in the browser".
- [ ] Check "SharedArrayBuffer" support if using Godot 4.x threads/worklets.

## 6. Smoke Test (Live)
- [ ] Open the live itch.io/GitHub Pages URL.
- [ ] Verify audio and gameplay one last time.
