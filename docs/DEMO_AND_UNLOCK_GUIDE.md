# คู่มือระบบ Demo / Unlock / Full Game

คู่มือนี้อธิบายวิธีใช้งานระบบ Demo Gate ทั้งหมด สำหรับ **นักพัฒนา**, **แอดมิน**, และ **ทีม QA**

---

## สารบัญ

1. [ภาพรวมระบบ](#1-ภาพรวมระบบ)
2. [โหมด Demo — ค่าเริ่มต้น](#2-โหมด-demo--ค่าเริ่มต้น)
3. [วิธีทดสอบ Demo Mode ใน Editor](#3-วิธีทดสอบ-demo-mode-ใน-editor)
4. [วิธี Unlock ด่านผ่าน Backend (แนะนำ)](#4-วิธี-unlock-ด่านผ่าน-backend-แนะนำ)
5. [วิธี Unlock ด่านผ่านไฟล์ Config (Dev/Local)](#5-วิธี-unlock-ด่านผ่านไฟล์-config-devlocal)
6. [วิธี Unlock ผ่านโค้ด GDScript (Debug Build)](#6-วิธี-unlock-ผ่านโค้ด-gdscript-debug-build)
7. [วิธีเปิด Full Game Mode](#7-วิธีเปิด-full-game-mode)
8. [วิธีรีเซ็ตกลับเป็น Demo](#8-วิธีรีเซ็ตกลับเป็น-demo)
9. [การจัดการผ่าน Admin Web Panel](#9-การจัดการผ่าน-admin-web-panel)
10. [ตาราง Config Fields ทั้งหมด](#10-ตาราง-config-fields-ทั้งหมด)
11. [Flow diagram](#11-flow-diagram)
12. [การทดสอบ Acceptance Tests](#12-การทดสอบ-acceptance-tests)
13. [คำถามที่พบบ่อย](#13-คำถามที่พบบ่อย)

---

## 1. ภาพรวมระบบ

```
ผู้เล่น (Game Client)
    │
    ├── โหลด Default Config (res://data/default_access_config.json)
    ├── โหลด Cache Config   (user://remote_access_config.json)
    └── Fetch จาก Backend   (GET /api/v1/game/access?install_id=...)
            │
            ▼
    LevelAccessService  ← ถามเสมอตัวนี้
    (ไม่มีการ call Remote Config โดยตรงจาก UI)
            │
            ├── can_play_level(n)        → เปิด/ปิดด่าน
            ├── can_play_wave(n, w)      → เปิด/ปิด Wave
            ├── can_submit_leaderboard() → ส่ง Score ได้ไหม
            └── is_demo_enabled()        → อยู่ใน Demo Mode ไหม
```

**กฎหลัก:**
- Demo mode = เล่นได้แค่ด่านที่อยู่ใน `enabled_levels` และ Wave ไม่เกิน `max_demo_wave`
- Full mode = เล่นได้ทุกด่าน ทุก Wave
- Config ดึงมาจาก Backend และ Cache โดยอัตโนมัติ ไม่ต้อง Build ใหม่

---

## 2. โหมด Demo — ค่าเริ่มต้น

ค่าเริ่มต้นที่ติดมากับ Build อยู่ที่:

**`res://data/default_access_config.json`**

```json
{
  "config_version": 1,
  "mode": "demo",
  "demo_enabled": true,
  "max_demo_level": 1,
  "max_demo_wave": 60,
  "enabled_levels": [1],
  "enabled_modes": ["normal"],
  "allow_save_resume": true,
  "allow_leaderboard_submit": false,
  "allow_sandbox": false,
  "maintenance_enabled": false,
  "force_update": false,
  "min_supported_build": 1,
  "announcement": ""
}
```

**ผลลัพธ์ใน Demo Mode:**

| สิ่งที่เกิดขึ้น | รายละเอียด |
|---|---|
| เล่นได้แค่ **ด่าน 1** | ด่าน 2–20 ถูกล็อก แสดงสถานะ "Full Version" |
| Wave สูงสุด **60** | หลังจากจบ Wave 60 จะแสดงหน้า "Demo Complete" |
| ไม่ส่ง Leaderboard | Score ไม่ถูกบันทึกขึ้น Leaderboard จริง |
| Continue ได้ | บันทึกและโหลด Save ได้ภายใน Demo |
| กดการ์ดด่านที่ล็อก | แสดง Modal "Full Version Required" |

---

## 3. วิธีทดสอบ Demo Mode ใน Editor

### ขั้นตอน:

**1.** เปิด Godot Editor และกด **Play (F5)**

**2.** เกมจะ Load Config ตามลำดับ:
   - ถ้ามี `user://remote_access_config.json` → ใช้ Cache
   - ถ้าไม่มี → ใช้ `res://data/default_access_config.json`

**3.** สังเกตที่มุมขวาล่างของหน้า Main Menu:
   ```
   Access Config: Default        ← ไม่มี Backend / Cache
   Access Config: Cached v1      ← ใช้ Cache เก่า
   Access Config: Online v7      ← ดึงจาก Backend สำเร็จ
   ```

**4.** กดปุ่ม **"ID"** มุมล่างซ้ายของ Main Menu เพื่อดูข้อมูล:
   - Runtime ID, Install ID, Build ID
   - Access Mode (demo/full)
   - Config Version, Resolved From, Tags

**5.** กด **Play > Level Select** → เห็นด่าน 2–20 แสดงแถบสี Amber พร้อมข้อความ "Full Version"

---

## 4. วิธี Unlock ด่านผ่าน Backend (แนะนำ)

> วิธีนี้ **ไม่ต้อง Build ใหม่** เหมาะสำหรับ Production และ Tester

### 4.1 Unlock ด่านเดียว (เช่น เปิดด่าน 1–3)

```sql
UPDATE game_remote_config
SET config_json = config_json || '{
  "enabled_levels": [1, 2, 3],
  "max_demo_wave": 60
}',
    version    = version + 1,
    updated_at = NOW()
WHERE config_key = 'global' AND is_active = TRUE;
```

เกมจะรับ Config ใหม่เมื่อ:
- ผู้เล่น restart เกม
- ผู้เล่นกลับมาหน้า Main Menu (Fetch อัตโนมัติ)

### 4.2 Unlock ทุกด่าน (Full Mode ผ่าน Config)

```sql
UPDATE game_remote_config
SET config_json = config_json || '{
  "mode": "full",
  "demo_enabled": false
}',
    version    = version + 1,
    updated_at = NOW()
WHERE config_key = 'global' AND is_active = TRUE;
```

### 4.3 Unlock เฉพาะ Runtime/Install ID (Targeted Override)

ใช้ตาราง `runtime_access_overrides`:

```sql
-- Unlock full game ให้ Install ID นี้เท่านั้น
INSERT INTO runtime_access_overrides
  (target_type, target_value, override_json, priority, is_active)
VALUES
  ('install_id', 'inst_abc123xyz', '{"mode": "full", "demo_enabled": false}', 10, TRUE);
```

**Admin จะหา install_id ได้จาก:**
- ผู้เล่นกดปุ่ม **"ID"** แล้วกด **COPY** ถัดจาก Install ID
- Admin Panel → Runtime List → ค้นหาด้วย player_id หรือ runtime_id

---

## 5. วิธี Unlock ด่านผ่านไฟล์ Config (Dev/Local)

> วิธีนี้ใช้ใน Local Development เท่านั้น ไม่กระทบ Production

### 5.1 แก้ไข Bundled Config

เปิดไฟล์: **`res://data/default_access_config.json`**

เปลี่ยน:
```json
{
  "enabled_levels": [1, 2, 3, 4, 5],
  "max_demo_wave": 60,
  "demo_enabled": true
}
```

หรือเปิดทุกด่านทันที:
```json
{
  "mode": "full",
  "demo_enabled": false
}
```

กด **Play** ใหม่ ระบบจะอ่าน Config ใหม่

> ⚠️ **หมายเหตุ:** ไฟล์นี้ถูก Bundle มากับ Build เมื่อ Export ใหม่จะ Reset ค่านี้

### 5.2 ชี้ไปที่ Dev API

สร้างไฟล์: **`user://remote_access_config_dev.json`**

```json
{ "api_base_url": "http://localhost:8080" }
```

เกมจะ Fetch Config จาก Local Server แทน Production

---

## 6. วิธี Unlock ผ่านโค้ด GDScript (Debug Build)

> ใช้ได้เฉพาะ **Debug Build** (`OS.is_debug_build() == true`) เท่านั้น
> ใน Release Build ฟังก์ชันเหล่านี้เป็น no-op

### วิธีที่ 1: ผ่าน Remote Debugger ใน Godot Editor

เปิด **Debugger Panel > Remote** แล้วรัน:

```gdscript
# Unlock Full Version
var las = get_tree().current_scene.get_node("LevelAccessService")
las.unlock_full_version_for_debug()

# รีเซ็ตกลับเป็น Demo
las.reset_to_demo_for_debug()
```

### วิธีที่ 2: ผ่าน LevelAccessService โดยตรง

```gdscript
# ดึง Service
var las = get_tree().current_scene.get_node("LevelAccessService")
var rac = get_tree().current_scene.get_node("RemoteAccessConfigService")

# Unlock ทันที
las.unlock_full_version_for_debug()

# บังคับ Demo Mode
las.reset_to_demo_for_debug()

# Fetch Config ใหม่จาก Backend
rac.fetch_remote_config()

# ดู Access Mode ปัจจุบัน
print(las.get_access_mode())       # "demo" หรือ "full"
print(las.get_resolved_from())     # "global_default", "install_id_override", ...
print(las.get_tags())              # ["tester", "qa", ...]
print(las.get_config_version())    # เลข version จาก Backend
```

### วิธีที่ 3: ผ่าน RuntimeIdentityService

```gdscript
var ris = get_tree().current_scene.get_node("RuntimeIdentityService")

print(ris.get_install_id())           # inst_xxxxxxxxxxxx
print(ris.get_runtime_id())           # rt_xxxxxxxxxxxx (จาก Backend)
print(ris.get_runtime_session_id())   # sess_xxxxxxxxxxxx (ใหม่ทุก Launch)
print(ris.get_build_id())             # v1.0.0-RC1
```

---

## 7. วิธีเปิด Full Game Mode

### สำหรับ Admin (ผ่าน Backend — ถาวร)

```sql
-- เปิด Full Mode สำหรับทุกคน
UPDATE game_remote_config
SET config_json = config_json || '{"mode": "full", "demo_enabled": false}',
    version    = version + 1,
    updated_at = NOW()
WHERE config_key = 'global';
```

### สำหรับ Tester รายคน (ผ่าน Install ID Override)

**ขั้นตอน:**

1. ผู้ทดสอบเปิดเกม → กดปุ่ม **"ID"** มุมล่างซ้าย
2. กด **COPY** ถัดจาก Install ID → ได้ค่าเช่น `inst_a1b2c3d4e5`
3. ส่งค่านี้ให้แอดมิน
4. แอดมินรัน SQL:

```sql
INSERT INTO runtime_access_overrides
  (target_type, target_value, override_json, priority, is_active)
VALUES
  ('install_id', 'inst_a1b2c3d4e5',
   '{"mode": "full", "demo_enabled": false, "allow_leaderboard_submit": true}',
   10, TRUE);
```

5. ผู้ทดสอบ restart เกม → รับ Config ใหม่อัตโนมัติ → เล่นได้ทุกด่าน

### สำหรับนักพัฒนา (ใน Debug Build)

```gdscript
var las = get_tree().current_scene.get_node("LevelAccessService")
las.unlock_full_version_for_debug()
```

---

## 8. วิธีรีเซ็ตกลับเป็น Demo

### ผ่าน Backend

```sql
-- รีเซ็ต Global Config กลับเป็น Demo
UPDATE game_remote_config
SET config_json = config_json || '{"mode": "demo", "demo_enabled": true, "enabled_levels": [1]}',
    version    = version + 1,
    updated_at = NOW()
WHERE config_key = 'global';

-- ลบ Override ของ Install ID
UPDATE runtime_access_overrides
SET is_active = FALSE
WHERE target_type = 'install_id' AND target_value = 'inst_a1b2c3d4e5';
```

### ใน Debug Build

```gdscript
var las = get_tree().current_scene.get_node("LevelAccessService")
las.reset_to_demo_for_debug()
```

### ลบ Cache (ทดสอบ Offline Fallback)

ลบไฟล์:
```
user://remote_access_config.json
```

ใน Godot Editor ไปที่: **FileSystem > user://** แล้วลบไฟล์
หรือรัน:
```gdscript
DirAccess.remove_absolute(OS.get_user_data_dir() + "/remote_access_config.json")
```

---

## 9. การจัดการผ่าน Admin Web Panel

### หน้า Runtime Access Manager

แสดงรายการ Runtimes ทั้งหมด:

| คอลัมน์ | ความหมาย |
|---|---|
| runtime_id | ID ที่ Backend ออกให้ (rt_xxx) |
| install_id | ID ประจำเครื่อง (inst_xxx) |
| player_id | ชื่อผู้เล่นที่กรอก |
| build_id | เวอร์ชันของ Build |
| platform | windows / web / android / ios |
| access mode | demo / full / custom |
| enabled levels | ด่านที่เล่นได้ |
| max wave | Wave สูงสุด |
| tags | tester, qa, vip, ... |
| last seen | เวลาล่าสุดที่ Online |

### วิธี Tag ผู้ทดสอบ

```sql
-- เพิ่ม tag "tester" ให้ install_id นี้
INSERT INTO runtime_tags (target_type, target_value, tag)
VALUES ('install_id', 'inst_a1b2c3d4e5', 'tester');

-- เปิด Full Access สำหรับทุก runtime ที่มี tag "tester"
INSERT INTO runtime_access_overrides
  (target_type, target_value, override_json, priority, is_active)
VALUES
  ('tag', 'tester', '{"mode": "full", "demo_enabled": false}', 5, TRUE);
```

### ลำดับความสำคัญของ Override

```
player_id override   ← สูงสุด (priority 1)
install_id override
runtime_id override
tag override
build_id override
global default       ← ต่ำสุด
bundled demo fallback  ← เฉพาะ Offline ไม่มี Cache
```

---

## 10. ตาราง Config Fields ทั้งหมด

| Field | Type | Default | ผล |
|---|---|---|---|
| `mode` | `"demo"` / `"full"` | `"demo"` | `"full"` = เปิดทุกอย่าง |
| `demo_enabled` | bool | `true` | `false` = เปิดทุกอย่าง |
| `enabled_levels` | int[] | `[1]` | ด่านที่เล่นได้ใน Demo |
| `max_demo_wave` | int | `60` | Wave สูงสุดใน Demo |
| `allow_leaderboard_submit` | bool | `false` | ส่ง Score ได้ไหม |
| `allow_save_resume` | bool | `true` | Continue ได้ไหม |
| `allow_sandbox` | bool | `false` | สงวนไว้ |
| `maintenance_enabled` | bool | `false` | `true` = บล็อกทุกอย่าง |
| `force_update` | bool | `false` | `true` = บังคับ Update |
| `min_supported_build` | int | `1` | Build เก่ากว่านี้ = Force Update |
| `announcement` | string | `""` | ข้อความใน Maintenance Modal |
| `config_version` | int | `1` | เลข Version สำหรับ Debug |

---

## 11. Flow Diagram

### การ Fetch Config เมื่อเปิดเกม

```
เปิดเกม
    │
    ├─→ โหลด Cache (user://remote_access_config.json)
    │       └─ ถ้าไม่มี → โหลด Default (res://data/default_access_config.json)
    │
    ├─→ Register Runtime (POST /api/v1/game/runtime/register)
    │       └─ ได้ runtime_id กลับมา
    │
    └─→ Fetch Config (GET /api/v1/game/access?install_id=...&runtime_id=...)
            ├─ สำเร็จ → ใช้ Remote Config + บันทึก Cache
            └─ ล้มเหลว → ใช้ Cache หรือ Default ต่อไป
```

### การแสดงผลใน Level Select

```
กดการ์ดด่าน
    │
    ├─ LevelAccessService.can_play_level(n)
    │       ├─ true  → เลือกด่าน เล่นได้
    │       └─ false → แสดง Modal "Full Version Required"
    │
    └─ (ถ้าเล่นอยู่) LevelAccessService.is_demo_wave_cap_reached(wave)
            ├─ false → Wave ถัดไปเริ่มปกติ
            └─ true  → แสดง Modal "Demo Complete"
```

---

## 12. การทดสอบ Acceptance Tests

### ทดสอบ Demo Mode

| Test | วิธีทดสอบ | ผลที่คาดหวัง |
|---|---|---|
| เปิดเกมใหม่ | รัน Build ปกติ | เล่นได้แค่ด่าน 1 |
| กดด่าน 2 | กดการ์ดด่าน 2 | แสดง Modal "Full Version" |
| เล่นจน Wave 60 | เล่นด่าน 1 ถึง Wave 60 | แสดง "Demo Complete" |
| Wave 61 ไม่ขึ้น | ดูหลัง Demo Complete | Wave 61 ไม่ Start |
| Continue ใน Demo | บันทึก → กด Continue | โหลดได้ปกติ |

### ทดสอบ Full Unlock

| Test | วิธีทดสอบ | ผลที่คาดหวัง |
|---|---|---|
| Unlock ด่านทั้งหมด | รัน SQL: mode=full | หลัง Restart ด่าน 2–20 เล่นได้ |
| Config Version เปลี่ยน | ดูปุ่ม ID | แสดง Config Version ใหม่ |
| Wave ไม่มีลิมิต | เล่น Wave 61+ | เล่นได้ปกติ |
| Leaderboard Submit | จบด่านด้วย mode=full | Score ถูกส่งขึ้น Leaderboard |

### ทดสอบ Offline

| Test | วิธีทดสอบ | ผลที่คาดหวัง |
|---|---|---|
| มี Cache | มี `user://remote_access_config.json` ปิด Net | ใช้ Cache config |
| ไม่มี Cache | ลบ Cache ปิด Net | ใช้ Default config |
| Backend Down | ปิด Server | เกมยังเล่นได้ด้วย Cache |

### ทดสอบ Maintenance

| Test | วิธีทดสอบ | ผลที่คาดหวัง |
|---|---|---|
| เปิด Maintenance | SQL: maintenance_enabled=true | แสดง Modal บล็อกทุกอย่าง |
| ESC ไม่ปิด Modal | กด ESC ขณะ Maintenance | Modal ยังอยู่ |
| กด Back to Menu | กดปุ่ม "Back to Menu" | กลับเมนูหลักได้ |

---

## 13. คำถามที่พบบ่อย

**Q: เปลี่ยน Config แล้วเกมไม่อัปเดต?**
> A: ต้อง restart เกมหรือกลับหน้า Main Menu เกมจะ Fetch ใหม่อัตโนมัติ

**Q: ทดสอบ Full Mode แล้วพอ Close Editor กลับไป Demo?**
> A: ฟังก์ชัน `unlock_full_version_for_debug()` ไม่ได้บันทึกถาวร ใช้ Backend Override แทน

**Q: ผู้เล่นจะรู้ Install ID ตัวเองได้อย่างไร?**
> A: กดปุ่ม **"ID"** มุมล่างซ้ายของ Main Menu → กด **COPY** ถัดจาก Install ID

**Q: Save เก่าจาก Full Mode จะ Continue ใน Demo ได้ไหม?**
> A: ไม่ได้ — ระบบบล็อกการ Continue ถ้า Save ชี้ไปด่านที่เกิน Demo Limit แต่ **ไม่ลบ Save** ออก

**Q: Leaderboard ใน Demo บันทึกไหม?**
> A: ถ้า `allow_leaderboard_submit: false` (ค่าเริ่มต้น) → Score จะไม่ถูกส่ง แต่แสดง Result ปกติ

**Q: ปิด Backend ได้ไหมถ้าไม่ต้องการ Remote Config?**
> A: ได้ — ตั้งค่า `BUNDLED_API_URL = ""` ใน `remote_access_config_service.gd` เกมจะใช้แค่ Local Config
