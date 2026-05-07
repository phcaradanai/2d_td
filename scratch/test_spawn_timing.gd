extends SceneTree

func _init():
    var waves = preload("res://data/waves/waves_20.json")
    var file = FileAccess.open(waves.resource_path, FileAccess.READ)
    var json = JSON.parse_string(file.get_as_text())
    var groups = json[0]["groups"]
    
    # 1. Start from base W1 timing (no spawn_delay on flyers)
    if groups[4].has("spawn_delay"):
        groups[4].erase("spawn_delay")
        
    var t = 0.0
    print("--- OLD TIMING ---")
    for group in groups:
        var count = group.get("count", 0)
        var interval = group.get("spawn_delay", group.get("interval", 1.0))
        for i in range(count):
            print("t=%5.1fs | Spawning %s (lane: %s)" % [t, group["type"], group["path"]])
            t += interval
            
    # 2. Apply user requested W1 changes
    groups[4]["count"] = 3
    groups[4]["interval"] = 1.3
    # Wait, the user said "flyer spawn_delay 8.0". But spawn_delay OVERRIDES interval!
    # If I set "spawn_delay": 8.0, then interval becomes 8.0!
    # If the user meant "start_delay: 8.0", the engine doesn't support it!
    # If I just use "interval": 1.3 for flyer, let's see when they spawn.
    groups[4].erase("spawn_delay")
    groups[5]["count"] = 1
    groups[5]["interval"] = 1.6
    if groups[5].has("spawn_delay"): groups[5].erase("spawn_delay")

    t = 0.0
    print("\n--- NEW RECOMMENDED TIMING (No spawn_delay) ---")
    for group in groups:
        var count = group.get("count", 0)
        var interval = group.get("spawn_delay", group.get("interval", 1.0))
        for i in range(count):
            print("t=%5.1fs | Spawning %s (lane: %s)" % [t, group["type"], group["path"]])
            t += interval
            
    quit()
