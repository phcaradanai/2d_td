extends SceneTree

var main_scene = load("res://scenes/main/Main.tscn")
var main_instance
var variant_idx = 0
var variants = [
    [ {"type": "sniper_tower", "cell": Vector2i(9,4)}, {"type": "lightning_tower", "cell": Vector2i(9,8)}, {"type": "cannon_tower", "cell": Vector2i(10,5)} ],
    [ {"type": "sniper_tower", "cell": Vector2i(13,5)}, {"type": "lightning_tower", "cell": Vector2i(10,7)}, {"type": "cannon_tower", "cell": Vector2i(9,4)} ],
    [ {"type": "sniper_tower", "cell": Vector2i(16,5)}, {"type": "lightning_tower", "cell": Vector2i(10,5)}, {"type": "cannon_tower", "cell": Vector2i(9,8)} ]
]

func _init():
    main_instance = main_scene.instantiate()
    root.add_child(main_instance)
    call_deferred("run_next_variant")

func run_next_variant():
    if variant_idx >= variants.size():
        print("SIMULATION COMPLETE")
        quit()
        return
    print("--- RUNNING VARIANT ", variant_idx, " ---")
    var towers = variants[variant_idx]
    main_instance.start_level("res://data/levels/level_20.json")
    await self.process_frame
    await self.process_frame
    
    var build_mgr = main_instance.get_node_or_null("BuildManager")
    var game_mgr = main_instance.get_node_or_null("GameManager")
    game_mgr.gold = 1000 # give enough gold to place
    for t in towers:
        build_mgr.set_selected_tower(t.type)
        var val = build_mgr.validate_placement(t.cell)
        if val.is_valid:
            build_mgr.place_tower(t.cell, val.config)
            print("Placed ", t.type, " at ", t.cell)
        else:
            print("Failed to place ", t.type, " at ", t.cell, ": ", val.reason)
            
    var wave_mgr = main_instance.get_node("WaveManager")
    wave_mgr.start_next_wave()
    
    var enemies_grp = get_nodes_in_group("enemies")
    while wave_mgr.is_wave_running or wave_mgr.active_enemy_count > 0 or enemies_grp.size() > 0:
        await self.create_timer(0.5).timeout
        enemies_grp = get_nodes_in_group("enemies")
        
    print("Variant ", variant_idx, " HP lost: ", 20 - game_mgr.lives)
    
    # cleanup towers
    var tower_container = main_instance.get_node("WorldRoot/MapRoot/TowerContainer")
    for t in tower_container.get_children():
        t.queue_free()
    await self.process_frame
    
    variant_idx += 1
    run_next_variant()
