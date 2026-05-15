# Tower Ability Parity Audit

Reference SHA: `1c06d3a9c30c41844b82765f8726c756813af56d`

Scope: documentation-only audit of `res://data/towers.json`, `res://data/towers_tree.json`, `scripts/towers/tower.gd`, `scripts/projectiles/projectile.gd`, and related economy/status code. This report does not add, remove, rename, or rebalance tower IDs.

## Guardrails

- Do not change tower count, tower IDs, tower names, tree shape, visuals, HUD, wave logic, enemy logic, or balance numbers as part of parity planning.
- Treat Element TD WC3 as a gameplay identity reference only. Keep original names, visuals, code, and data.
- Patch ability parity in small stages, with runtime verification after behavior changes.

## Implemented Mechanic Surface

The current complete tower tree is backed by a much smaller runtime mechanic set:

- `single`: generic single-target projectile damage.
- `splash`: projectile impact area damage with distance falloff.
- `slow`: projectile impact area damage plus `Enemy.apply_slow`.
- `chain`: projectile jumps to nearby enemies with falloff.
- `aura`: tower-centered periodic area damage, optionally applying `Enemy.apply_vulnerability`.
- `support_aura`: Well attack-speed support and Blacksmith damage support, each targeting up to 4 nearby non-support towers.
- `clone_support`: Trickery applies temporary clone damage to one nearby non-support tower.
- Economy kill effects: Gold gives bonus bounty on own kills; Life gives +1 life after an own-kill threshold.
- Elemental damage multiplier: projectiles derive tower elements from `towers_tree.json` and compare against enemy armor element.

Important implementation notes:

- `tower.gd` forwards only `attack_type`, area radius, slow values, target categories, and source ID into projectiles. Vulnerability values are not currently passed through the normal projectile setup path.
- `projectile.gd` only applies slow from the `slow` attack type. Splash towers with configured slow fields do not currently apply slow.
- `chain` uses the normal non-area damage path, so chain towers can deal damage and jump, but status identity depends on what is explicitly forwarded into projectiles.
- `aura` towers can apply vulnerability, but this is a generic damage amplification status, not a distinct armor-reduction mechanic.
- Life and Gold economy values are hardcoded in `wave_manager.gd`, even though tower config declares economy identity.

## Gap Matrix

| Family | Current behavior | Expected Element TD-like role | Missing mechanic | Safe implementation plan |
|---|---|---|---|---|
| Neutral Arrow | `single`, land + air | Starter composite arrow | None urgent | Keep stable. |
| Neutral Cannon | `splash`, land only | Starter composite cannon | None urgent | Keep stable. |
| Light / Pure Light | Generic `single` | Long-range precision damage | No precision identity beyond stats | Add optional precision/reveal/priority module later. |
| Darkness / Pure Darkness | `aura` damage + vulnerability | Darkness damage / damage amplifier depending chosen clone identity | Current identity differs from classic long-range damage references | Decide in a design patch whether to keep current original aura role or migrate. |
| Water / Pure Water | `slow` area projectile | Slow/control | Mostly present, generic | Add regression coverage for slow application. |
| Fire / Pure Fire | `splash` projectile | AoE fire damage | No burn/DoT | Add DoT status after shared status layer. |
| Nature / Pure Nature | Generic `single` | Rapid organic damage | No growth/ramp identity | Add optional ramping fire-rate module later. |
| Earth / Pure Earth | `splash` projectile | Heavy AoE impact | Mostly present, generic | Keep; later add impact identity if needed. |
| Trickery | `clone_support` damage modifier | Clone non-support towers | Clone is stat projection, not an independent duplicate/source | Keep first; later improve telemetry/source attribution. |
| Ice | `slow` area projectile | Slow/control | Mostly present, generic | Keep. |
| Electricity | `chain` projectile | Chain lightning | Mostly present, generic | Add chain regression coverage. |
| Life | `single` + own-kill life economy | Life economy damage tower | Values hardcoded in manager | Move thresholds to config after behavior tests. |
| Quark | Generic `single` | Charged/periodic burst | No charge or burst mechanic | Add charged-shot module. |
| Poison | `slow` area projectile | Poison slow + damage over time | No poison DoT | Add enemy DoT status, then wire poison. |
| Magic | `splash` projectile | Magic AoE | Generic splash only | Add spell-burst flavor only after splash tests. |
| Disease | `aura` damage + damage-amp status payload | Plague/damage amplification | No disease DoT/sickness identity | Add plague DoT later only after replay proves it is needed. |
| Gunpowder | `splash` projectile | Large ordnance AoE | Generic splash only | Add wide-blast/fuse module later. |
| Vapor | `splash`, has slow config fields | AoE steam damage + slow | Slow fields inert because splash does not apply slow | Add hybrid splash + slow support without changing numbers. |
| Well | `support_aura` attack speed, 4 targets | Tower attack-speed amp | Mostly present | Keep stable. |
| Hydro | `splash`, has slow config fields | Splash control | Slow fields inert because splash does not apply slow | Use same hybrid splash + slow support. |
| Flame | `aura` damage + vulnerability | Flame aura / burn | No burn DoT | Add burn DoT after status layer. |
| Blacksmith | `support_aura` damage, 4 targets | Tower damage amp | Mostly present | Keep stable. |
| Mushroom | `splash` projectile | Spore AoE | No spore/DoT identity | Add spore DoT or delayed burst later. |
| Hail | `chain` projectile | Chain frost/slow | Chain slow identity depends on explicit config/forwarding | Add chain status support after projectile forwarding tests. |
| Jinx | `chain` projectile | Chain curse/amplify | No curse amplification in projectile path | Pass vulnerability into projectile setup, then add test. |
| Oblivion | `aura` damage + vulnerability | Defense erase / drain aura | Generic vulnerability only | Add drain/execute-like status later. |
| Laser | Generic `single` | Focused beam / pierce | No beam or line-hit | Add ray/line attack module. |
| Windstorm | `slow` area projectile | AoE slow/tornado support | No moving tornado or persistent field | Add persistent slow-field module. |
| Tidal | `splash` projectile | Wave AoE, often control-adjacent | No wave/slow identity | Add hybrid splash + slow or wave pulse later. |
| Polar | `slow` area projectile + root/snare payload | Deep freeze control | Still uses projectile slow shape | Expand identity later only if runtime replay says it is needed. |
| Nova | `slow` area projectile | AoE slow support | Projectile slow, not tower-centered nova | Add local pulse/field variant. |
| Gold | `single` + own-kill bonus bounty | Gold economy | Values hardcoded in manager | Move bonus percent to config after tests. |
| Enchantment | `aura` damage + armor reduction | Armor reduction support | Still uses generic aura damage shape | Expand identity later only if runtime replay says it is needed. |
| Corrosion | `slow` area projectile + armor-reduction payload | AoE armor reduction | Still retains generic slow projectile shape | Expand identity later only if runtime replay says it is needed. |
| Drowning | Generic `single` | Heavy water/dark single-target damage | No drowning/execute/ramp identity | Add stacking or execute-like single-target debuff later. |
| Muck | `slow` area projectile | AoE slow support | Mostly present, generic | Keep; later consider persistent field. |
| Voodoo | `aura` damage + damage-amp status payload | Damage amplification / delayed damage | No delayed stored damage | Add delayed-damage behavior later only after replay proves it is needed. |
| Flamethrower | `splash` projectile | Sustained flame AoE | No cone/continuous fire/burn | Add cone or burn DoT module later. |
| Roots | `slow` area projectile | Slow/root support | No root/snare hold | Add capped root/snare status. |
| Impulse | Generic `single` | Distance-scaled long-range damage | No distance scaling | Add distance multiplier module. |
| Zealot | Generic `single` | Ramping attack speed damage | No attack-speed ramp | Add per-target or continuous-fire ramp module. |
| Flesh Golem | `splash` projectile | Heavy slam AoE | Generic projectile splash | Add local slam pulse later. |
| Quaker | `splash` projectile | Tower-centered quake AoE | Projectile splash, not tower-centered quake | Add local quake pulse module. |
| Periodic | `chain` projectile, all six elements | Ultimate six-element tower | Chain only; no special ultimate mechanic beyond element set | Add explicit periodic/all-element attack module later. |

## Declared-But-Inert Priority List

These are safest to patch first because they make authored config fields start doing what the descriptions already imply, without changing numbers:

1. Splash towers with configured slow fields: Vapor, Hydro, Tidal if configured, and any future `splash` tower with `slow_percent > 0`. Status: patched in the projectile area-effect path.
2. Chain or projectile towers with vulnerability fields: Jinx-like cursed chain identity needs projectile forwarding before config can work. Status: projectile forwarding patched; family data can now opt into this without another code path.
3. Economy config fields: Life and Gold currently work, but hardcoded manager tables should eventually read from tower config.

## Recommended Patch Order

1. Add focused test/probe coverage for existing mechanics before changing behavior.
2. Patch projectile setup forwarding so vulnerability values reach projectile instances.
3. Add hybrid splash + slow support behind existing config fields. Status: patched.
4. Introduce a shared enemy status layer for DoT, armor reduction, root/snare, delayed damage, HP reduction, and attack ramping. Status: base enemy hooks added for damage amp, armor reduction, DoT, root/snare, and delayed damage; family wiring still pending.
5. Migrate families in identity groups:
   - Support/debuff: Corrosion, Enchantment, Polar, Voodoo, Disease.
   - Control: Windstorm, Nova, Roots, Muck.
   - Special damage: Quark, Laser, Impulse, Zealot, Quaker, Flesh Golem, Flamethrower.
   - Economy cleanup: Life, Gold.

## Verification Requirements

- Run Godot parse/boot after every behavior patch.
- Run relevant refactor audits if touching `main.gd`, controllers, HUD, or interaction flow.
- Runtime replay is required before claiming clearability or balance impact.
- For this documentation-only audit, no runtime replay is claimed.
