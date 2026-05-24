# Tower Symmetry / Muzzle VFX Todo

Scope: `scripts/towers/visuals/by_id`.

Goal: keep every tower body readable and symmetrical around its authored firing/emitter axis so attack VFX can be aligned cleanly at the muzzle. The target silhouette is the `neutral_arrow` style: hard-surface body, y-mirrored top/bottom profile, centered forward emitter, and paired detail accents. Visual files stay visual-only: shape, core, accent, idle hints, and static preview-safe VFX only.

## Status Legend

- `[x]` Refined / fixed in this pass.
- `[~]` Delegates to a refined T1 visual, so the visible shape follows that source file.
- `[ ]` Still needs a manual visual pass if a future render/screenshot pass finds a new issue.
- `[bug]` Bug found and fixed in this pass.

## Fixed This Pass

- [x] `[bug]` `mushroom_t1_visual.gd` - centered the fungal nozzle, muzzle ring, and nearby spore markers on the forward axis.
- [~] `mushroom_t2_visual.gd` - wrapper delegates to `mushroom_t1_visual.gd`.
- [~] `mushroom_t3_visual.gd` - wrapper delegates to `mushroom_t1_visual.gd`.
- [x] `[bug]` `hail_t1_visual.gd` - redesigned toward neutral-arrow symmetry: y-mirrored chassis, paired plates/relays, centered forward shard emitter, and chain/circuit traces mirrored directly from the center axis.
- [~] `hail_t2_visual.gd` - wrapper delegates to `hail_t1_visual.gd`.
- [~] `hail_t3_visual.gd` - wrapper delegates to `hail_t1_visual.gd`.
- [x] `[bug]` `corrosion_t1_visual.gd` - redesigned toward neutral-arrow symmetry: hard-surface acid chassis, centered mist diffuser, paired canisters/pods.
- [~] `corrosion_t2_visual.gd` - wrapper delegates to `corrosion_t1_visual.gd`.
- [~] `corrosion_t3_visual.gd` - wrapper delegates to `corrosion_t1_visual.gd`.
- [x] `hydro_t1_visual.gd` - reviewed forward hydro diffuser symmetry and centered the lower Water+Earth token.
- [~] `hydro_t2_visual.gd` - wrapper delegates to `hydro_t1_visual.gd`.
- [~] `hydro_t3_visual.gd` - wrapper delegates to `hydro_t1_visual.gd`.
- [x] `quark_t1_visual.gd` - reviewed particle rail geometry as y-mirrored and clarified the visual note.
- [~] `quark_t2_visual.gd` - wrapper delegates to `quark_t1_visual.gd`.
- [~] `quark_t3_visual.gd` - wrapper delegates to `quark_t1_visual.gd`.
- [x] `vapor_t1_visual.gd` - mirrored the steam cloud at the diffuser tip.
- [~] `vapor_t2_visual.gd` - wrapper delegates to `vapor_t1_visual.gd`.
- [~] `vapor_t3_visual.gd` - wrapper delegates to `vapor_t1_visual.gd`.
- [x] `jinx_t1_visual.gd` - mirrored chain traces, aura arcs, forked curse emitter, and outbound mini-bolts from the center axis.
- [~] `jinx_t2_visual.gd` - wrapper delegates to `jinx_t1_visual.gd`.
- [~] `jinx_t3_visual.gd` - wrapper delegates to `jinx_t1_visual.gd`.
- [x] `impulse_t1_visual.gd` - mirrored outer neon circuit trim and paired side circuit nodes for a cleaner cyber accelerator read.
- [~] `impulse_t2_visual.gd` - wrapper delegates to `impulse_t1_visual.gd`.
- [~] `impulse_t3_visual.gd` - wrapper delegates to `impulse_t1_visual.gd`.
- [x] `trickery_t1_visual.gd` - added y-mirrored cyber circuit traces and paired clone-link detail while keeping the hologram projector model intact.
- [~] `trickery_t2_visual.gd` - wrapper delegates to `trickery_t1_visual.gd`.
- [~] `trickery_t3_visual.gd` - wrapper delegates to `trickery_t1_visual.gd`.
- [x] `zealot_t1_visual.gd` - added mirrored neon circuit trim around the strike core and side blade conduits without changing the blade identity.
- [~] `zealot_t2_visual.gd` - wrapper delegates to `zealot_t1_visual.gd`.
- [~] `zealot_t3_visual.gd` - wrapper delegates to `zealot_t1_visual.gd`.
- [x] `enchantment_t1_visual.gd` - added mirrored ward-circuit traces across the altar base and core for a cleaner sci-fi cyber read.
- [~] `enchantment_t2_visual.gd` - wrapper delegates to `enchantment_t1_visual.gd`.
- [~] `enchantment_t3_visual.gd` - wrapper delegates to `enchantment_t1_visual.gd`.
- [x] `blacksmith_t1_visual.gd` - refined the forge/anvil read with y-mirrored anvil face, paired hammer badges, and mirrored neon forge traces.
- [~] `blacksmith_t2_visual.gd` - wrapper delegates to `blacksmith_t1_visual.gd`.
- [~] `blacksmith_t3_visual.gd` - wrapper delegates to `blacksmith_t1_visual.gd`.
- [x] `poison_t1_visual.gd` - centered the element token and mirrored vial liquid, glass ribs, venom bubbles, injector circuit traces, and tip droplets.
- [~] `poison_t2_visual.gd` - wrapper delegates to `poison_t1_visual.gd`.
- [~] `poison_t3_visual.gd` - wrapper delegates to `poison_t1_visual.gd`.
- [x] `quaker_t1_visual.gd` - y-mirrored the bastion base/inset plates and added paired cyber-stabilizer traces around the seismic drill.
- [~] `quaker_t2_visual.gd` - wrapper delegates to `quaker_t1_visual.gd`.
- [~] `quaker_t3_visual.gd` - wrapper delegates to `quaker_t1_visual.gd`.

## Reviewed Symmetric / No Geometry Change Needed

Note: this section was from the first broad pass. After user clarification, future passes should treat organic/radial silhouettes as needing neutral-arrow-style redesign if they make muzzle VFX alignment unclear.

## Reopened Neutral-Arrow Style Backlog

- [ ] Convert organic/asymmetric emitter towers to neutral-arrow-style hard-surface silhouettes where needed.
- [ ] Re-review aura/support towers and keep them radial only when they have no muzzle VFX origin.
- [ ] Use screenshots/catalog previews to compare every redesigned tower against `basic_tower_t1_visual.gd`.

## Theme Polish Rule

- Circuit/chain/lightning/conduit lines must be mirrored from the tower center axis unless the tower is intentionally radial and has no muzzle origin.
- Organic shapes can stay if they define the tower identity, but add sci-fi circuit/neon framing instead of replacing the whole model.
- Prefer small paired neon strips, circuit traces, hard-surface trims, and centered emitter hints over full redesigns.
- Per user direction, leave `electricity_t1_visual.gd` unchanged for now because its current model already reads well.

- [x] `basic_tower_t1_visual.gd` - reviewed ballista rails and arrow head on forward axis.
- [x] `neutral_cannon_tower_visual.gd` - reviewed mortar barrel, muzzle, and recoil rails on forward axis.
- [x] `blacksmith_t1_visual.gd` - reviewed as support/anvil silhouette; no muzzle axis.
- [~] `blacksmith_t2_visual.gd` - wrapper delegates to `blacksmith_t1_visual.gd`
- [~] `blacksmith_t3_visual.gd` - wrapper delegates to `blacksmith_t1_visual.gd`
- [x] `darkness_t1_visual.gd` - reviewed as radial aura/debuff tower.
- [~] `darkness_t2_visual.gd` - wrapper delegates to `darkness_t1_visual.gd`
- [~] `darkness_t3_visual.gd` - wrapper delegates to `darkness_t1_visual.gd`
- [x] `disease_t1_visual.gd` - reviewed aura ring and four spore emitters.
- [~] `disease_t2_visual.gd` - wrapper delegates to `disease_t1_visual.gd`
- [~] `disease_t3_visual.gd` - wrapper delegates to `disease_t1_visual.gd`
- [x] `drowning_t1_visual.gd` - reviewed harpoon emitter on forward axis.
- [~] `drowning_t2_visual.gd` - wrapper delegates to `drowning_t1_visual.gd`
- [~] `drowning_t3_visual.gd` - wrapper delegates to `drowning_t1_visual.gd`
- [x] `earth_t1_visual.gd` - reviewed heavy impact face and mirrored ground shards.
- [~] `earth_t2_visual.gd` - wrapper delegates to `earth_t1_visual.gd`
- [~] `earth_t3_visual.gd` - wrapper delegates to `earth_t1_visual.gd`
- [~] `pure_earth_visual.gd` - wrapper delegates to `earth_t1_visual.gd`
- [x] `electricity_t1_visual.gd` - reviewed radial capacitor and jump-node layout.
- [~] `electricity_t2_visual.gd` - wrapper delegates to `electricity_t1_visual.gd`
- [~] `electricity_t3_visual.gd` - wrapper delegates to `electricity_t1_visual.gd`
- [x] `enchantment_t1_visual.gd` - reviewed altar/ward symmetry; no muzzle axis.
- [~] `enchantment_t2_visual.gd` - wrapper delegates to `enchantment_t1_visual.gd`
- [~] `enchantment_t3_visual.gd` - wrapper delegates to `enchantment_t1_visual.gd`
- [x] `fire_t1_visual.gd` - reviewed wide splash vent and heat shields on forward axis.
- [~] `fire_t2_visual.gd` - wrapper delegates to `fire_t1_visual.gd`
- [~] `fire_t3_visual.gd` - wrapper delegates to `fire_t1_visual.gd`
- [~] `pure_fire_visual.gd` - wrapper delegates to `fire_t1_visual.gd`
- [x] `flame_t1_visual.gd` - reviewed ember bloom aura symmetry.
- [~] `flame_t2_visual.gd` - wrapper delegates to `flame_t1_visual.gd`
- [~] `flame_t3_visual.gd` - wrapper delegates to `flame_t1_visual.gd`
- [x] `flamethrower_t1_visual.gd` - reviewed twin-nozzle projector symmetry.
- [~] `flamethrower_t2_visual.gd` - wrapper delegates to `flamethrower_t1_visual.gd`
- [~] `flamethrower_t3_visual.gd` - wrapper delegates to `flamethrower_t1_visual.gd`
- [x] `flesh_golem_t1_visual.gd` - reviewed golem-body silhouette as centered/melee-like tower.
- [~] `flesh_golem_t2_visual.gd` - wrapper delegates to `flesh_golem_t1_visual.gd`
- [~] `flesh_golem_t3_visual.gd` - wrapper delegates to `flesh_golem_t1_visual.gd`
- [x] `gold_t1_visual.gd` - reviewed mint-lens emitter on forward axis.
- [~] `gold_t2_visual.gd` - wrapper delegates to `gold_t1_visual.gd`
- [~] `gold_t3_visual.gd` - wrapper delegates to `gold_t1_visual.gd`
- [x] `gunpowder_t1_visual.gd` - reviewed mortar barrel and crown on forward axis.
- [~] `gunpowder_t2_visual.gd` - wrapper delegates to `gunpowder_t1_visual.gd`
- [~] `gunpowder_t3_visual.gd` - wrapper delegates to `gunpowder_t1_visual.gd`
- [x] `ice_t1_visual.gd` - reviewed cryo shard emitter and prism shell.
- [~] `ice_t2_visual.gd` - wrapper delegates to `ice_t1_visual.gd`
- [~] `ice_t3_visual.gd` - wrapper delegates to `ice_t1_visual.gd`
- [x] `impulse_t1_visual.gd` - reviewed impulse rail on forward axis.
- [~] `impulse_t2_visual.gd` - wrapper delegates to `impulse_t1_visual.gd`
- [~] `impulse_t3_visual.gd` - wrapper delegates to `impulse_t1_visual.gd`
- [x] `jinx_t1_visual.gd` - reviewed relay body and lightning crown as centered chain tower.
- [~] `jinx_t2_visual.gd` - wrapper delegates to `jinx_t1_visual.gd`
- [~] `jinx_t3_visual.gd` - wrapper delegates to `jinx_t1_visual.gd`
- [x] `laser_t1_visual.gd` - reviewed rail laser beam wedge and mirrored capacitors.
- [~] `laser_t2_visual.gd` - wrapper delegates to `laser_t1_visual.gd`
- [~] `laser_t3_visual.gd` - wrapper delegates to `laser_t1_visual.gd`
- [x] `life_t1_visual.gd` - reviewed compact forward emitter and mirrored leaf silhouette.
- [~] `life_t2_visual.gd` - wrapper delegates to `life_t1_visual.gd`
- [~] `life_t3_visual.gd` - wrapper delegates to `life_t1_visual.gd`
- [x] `light_t1_visual.gd` - reviewed centered beam channel and prism body.
- [~] `light_t2_visual.gd` - wrapper delegates to `light_t1_visual.gd`
- [~] `light_t3_visual.gd` - wrapper delegates to `light_t1_visual.gd`
- [~] `pure_light_visual.gd` - wrapper delegates to `light_t1_visual.gd`
- [x] `magic_t1_visual.gd` - reviewed chaos reactor as symmetric orb/AoE tower.
- [~] `magic_t2_visual.gd` - wrapper delegates to `magic_t1_visual.gd`
- [~] `magic_t3_visual.gd` - wrapper delegates to `magic_t1_visual.gd`
- [x] `muck_t1_visual.gd` - reviewed quagmire basin and control pylons as centered.
- [~] `muck_t2_visual.gd` - wrapper delegates to `muck_t1_visual.gd`
- [~] `muck_t3_visual.gd` - wrapper delegates to `muck_t1_visual.gd`
- [x] `nature_t1_visual.gd` - reviewed twin bio channels and seed tips on forward axis.
- [~] `nature_t2_visual.gd` - wrapper delegates to `nature_t1_visual.gd`
- [~] `nature_t3_visual.gd` - wrapper delegates to `nature_t1_visual.gd`
- [~] `pure_nature_visual.gd` - wrapper delegates to `nature_t1_visual.gd`
- [x] `nova_t1_visual.gd` - reviewed flare diffuser and bloom petals.
- [~] `nova_t2_visual.gd` - wrapper delegates to `nova_t1_visual.gd`
- [~] `nova_t3_visual.gd` - wrapper delegates to `nova_t1_visual.gd`
- [x] `oblivion_t1_visual.gd` - reviewed void flower/aura reactor; no projectile barrel.
- [~] `oblivion_t2_visual.gd` - wrapper delegates to `oblivion_t1_visual.gd`
- [~] `oblivion_t3_visual.gd` - wrapper delegates to `oblivion_t1_visual.gd`
- [x] `periodic_t1_visual.gd` - reviewed wrapper/simple fallback visual status.
- [x] `poison_t1_visual.gd` - reviewed injector channel and droplet markers on forward axis.
- [~] `poison_t2_visual.gd` - wrapper delegates to `poison_t1_visual.gd`
- [~] `poison_t3_visual.gd` - wrapper delegates to `poison_t1_visual.gd`
- [x] `polar_t1_visual.gd` - reviewed polarity/control-field symmetry.
- [~] `polar_t2_visual.gd` - wrapper delegates to `polar_t1_visual.gd`
- [~] `polar_t3_visual.gd` - wrapper delegates to `polar_t1_visual.gd`
- [x] `pure_darkness_visual.gd` - wrapper delegates to `darkness_t1_visual.gd`.
- [x] `quaker_t1_visual.gd` - reviewed seismic impact/drill read as centered land-splash tower.
- [~] `quaker_t2_visual.gd` - wrapper delegates to `quaker_t1_visual.gd`
- [~] `quaker_t3_visual.gd` - wrapper delegates to `quaker_t1_visual.gd`
- [x] `roots_t1_visual.gd` - reviewed root-cage control silhouette as centered.
- [~] `roots_t2_visual.gd` - wrapper delegates to `roots_t1_visual.gd`
- [~] `roots_t3_visual.gd` - wrapper delegates to `roots_t1_visual.gd`
- [x] `tidal_t1_visual.gd` - reviewed vertical wave diffuser symmetry.
- [~] `tidal_t2_visual.gd` - wrapper delegates to `tidal_t1_visual.gd`
- [~] `tidal_t3_visual.gd` - wrapper delegates to `tidal_t1_visual.gd`
- [x] `trickery_t1_visual.gd` - reviewed clone projector lens and echo bodies.
- [~] `trickery_t2_visual.gd` - wrapper delegates to `trickery_t1_visual.gd`
- [~] `trickery_t3_visual.gd` - wrapper delegates to `trickery_t1_visual.gd`
- [x] `voodoo_t1_visual.gd` - reviewed totem symmetry; no projectile barrel.
- [~] `voodoo_t2_visual.gd` - wrapper delegates to `voodoo_t1_visual.gd`
- [~] `voodoo_t3_visual.gd` - wrapper delegates to `voodoo_t1_visual.gd`
- [x] `water_t1_visual.gd` - reviewed aqua crystal emitter and symmetric silhouette.
- [~] `water_t2_visual.gd` - wrapper delegates to `water_t1_visual.gd`
- [~] `water_t3_visual.gd` - wrapper delegates to `water_t1_visual.gd`
- [~] `pure_water_visual.gd` - wrapper delegates to `water_t1_visual.gd`
- [x] `well_t1_visual.gd` - reviewed support well symmetry; no weapon barrel.
- [~] `well_t2_visual.gd` - wrapper delegates to `well_t1_visual.gd`
- [~] `well_t3_visual.gd` - wrapper delegates to `well_t1_visual.gd`
- [x] `windstorm_t1_visual.gd` - reviewed turbine/field symmetry.
- [~] `windstorm_t2_visual.gd` - wrapper delegates to `windstorm_t1_visual.gd`
- [~] `windstorm_t3_visual.gd` - wrapper delegates to `windstorm_t1_visual.gd`
- [x] `zealot_t1_visual.gd` - reviewed centered holy/mechanical silhouette.
- [~] `zealot_t2_visual.gd` - wrapper delegates to `zealot_t1_visual.gd`
- [~] `zealot_t3_visual.gd` - wrapper delegates to `zealot_t1_visual.gd`

## Notes For Future Polish

- Prioritize towers with explicit forward emitters first: cannon, mortar, laser, rail, injector, nozzle, diffuser, and shard launcher.
- For aura/support towers, symmetry target is silhouette balance around the center, not a fake muzzle.
- When a future render/screenshot pass finds a bug, add it under `Fixed This Pass` or a dated completed section after correcting it, and mark affected T2/T3 wrappers as `[~]`.
