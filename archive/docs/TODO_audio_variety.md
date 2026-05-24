# Audio & Variety Improvements

## Phase 1: Element-based Tower SFX
ให้แต่ละ element มีเสียงยิงที่ต่างกัน แทนที่จะแชร์เสียง generic

**Asset mapping (kenney → assets/audio/sfx/):**
- `tower_shoot_fire.ogg`        ← kenney_sci-fi-sounds/thrusterFire_001.ogg
- `tower_shoot_ice.ogg`         ← kenney_sci-fi-sounds/forceField_001.ogg
- `tower_shoot_electricity.ogg` ← kenney_sci-fi-sounds/laserSmall_002.ogg
- `tower_shoot_water.ogg`       ← kenney_sci-fi-sounds/forceField_000.ogg
- `tower_shoot_earth.ogg`       ← kenney_sci-fi-sounds/explosionCrunch_002.ogg
- `tower_shoot_darkness.ogg`    ← kenney_sci-fi-sounds/laserRetro_001.ogg
- `tower_shoot_light.ogg`       ← kenney_sci-fi-sounds/laserLarge_002.ogg
- `tower_shoot_nature.ogg`      ← kenney_sci-fi-sounds/computerNoise_001.ogg
- `tower_shoot_life.ogg`        ← kenney_sci-fi-sounds/forceField_003.ogg
- `tower_shoot_quark.ogg`       ← kenney_sci-fi-sounds/computerNoise_003.ogg
- `tower_shoot_trickery.ogg`    ← kenney_sci-fi-sounds/laserRetro_003.ogg

**Code changes:**
- [x] Copy asset files
- [x] `audio_manager.gd`: add sfx_paths entries for element keys
- [x] `tower.gd`: pick SFX by `elements[0]` after visual_type (override)

## Phase 2: Boss Wave Tension
สร้าง tension เมื่อ boss wave เริ่ม

**Asset mapping:**
- `boss_alert.ogg` ← kenney_sci-fi-sounds/lowFrequency_explosion_000.ogg

**Code changes:**
- [x] `wave_manager.gd`: emit `boss_wave_started` signal when wave has boss-type enemy
- [x] `audio_manager.gd`: add `boss_alert` sfx_path + `set_music_pitch(scale)` method
- [x] `main.gd`: connect `boss_wave_started` → play boss_alert + pitch music to 1.18 + camera shake
- [x] `main.gd`: on `wave_completed` → restore pitch to 1.0

## Phase 3: Wave Clear Fanfare
เพิ่มเสียง fanfare เมื่อ wave จบ

**Asset mapping:**
- `wave_clear.ogg` ← kenney_interface-sounds/confirmation_001.ogg

**Code changes:**
- [x] Copy asset file
- [x] `audio_manager.gd`: add `wave_clear` sfx_path
- [x] `main.gd` `_on_wave_completed`: play `wave_clear` + restore music pitch

## Phase 4: Damage Number Element Colors
ตัวเลข damage สีตาม element ที่ยิง

**Code changes:**
- [x] `enemy_damage_pipeline.gd`: static `_element_color_from_source(source_id)` → map prefix to color
  - pattern: `fire_t1` → `fire` → orange, `ice_t2` → ice → cyan, etc.
  - handles `pure_fire`, `pure_ice` etc via second split
