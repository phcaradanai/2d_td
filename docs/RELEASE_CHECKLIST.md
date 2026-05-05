# Release Checklist

Follow these steps to verify a build is ready for release.

## 1. Fresh Launch
- [ ] Game starts directly at the **Main Menu**.
- [ ] No immediate errors in the console/log.
- [ ] Version label `v0.1.0 Prototype` is visible.

## 2. Main Menu & Navigation
- [ ] **Level Select** opens and displays available levels.
- [ ] **Back** button returns to Main Menu.
- [ ] **Quit** button works (Desktop only).

## 3. Gameplay Mechanics
- [ ] Start a level from Level Select.
- [ ] Place one of each tower type (Basic, Rapid, Cannon, Slow).
- [ ] Start Wave 1 and verify enemies spawn and move correctly.
- [ ] Verify towers shoot and deal damage.
- [ ] Upgrade a tower and verify stats change.
- [ ] Change target mode and verify target priority changes.

## 4. Audio
- [ ] Music plays on Main Menu.
- [ ] Music changes on Level Start.
- [ ] SFX triggers on tower place, upgrade, and projectile hit.
- [ ] Test **Settings Panel**:
  - [ ] Mute Master/Music/SFX works.
  - [ ] Volume sliders correctly adjust loudness.

## 5. Session Flow
- [ ] **Pause/Resume** works without breaking enemy movement or projectiles.
- [ ] **Victory**:
  - [ ] Complete all waves.
  - [ ] Summary screen shows correct stats and stars.
  - [ ] **Restart** button resets the level correctly.
- [ ] **Game Over**:
  - [ ] Let enemies reach the base until lives = 0.
  - [ ] Summary screen appears.
  - [ ] **Main Menu** button returns safely.

## 6. Persistence
- [ ] Complete a level with a high score.
- [ ] Return to Level Select and verify the "Best" record updated.
- [ ] Restart the game and verify records are still present.

## 7. Export Validation
- [ ] **Web Build**:
  - [ ] Audio works after clicking "Start".
  - [ ] Save data persists after page refresh.
- [ ] **Desktop Build**:
  - [ ] Windowed/Fullscreen behavior is stable.
  - [ ] No file access errors.

## 8. Final Polish
- [ ] **Debug Panel (F1)** is NOT accessible in the release build.
- [ ] No excessive console spam from AudioManager or GameManager.
