# Mustache Massacre — Godot playable demo plan

Status: implemented. See [implementation and verification status](demo_implementation_status.md) and the [project README](../../../README.md). The sections below preserve the agreed design and its initial tuning values.

## The playable experience

**The Crispy Badlands: Last Call** is a five-to-seven-minute, single-player, 3D isometric arena run. Don Espino enters an abandoned saloon street, fights escalating waves of moustached enemies, picks two upgrades, and defeats an oversized refrigerator sheriff. Death and victory both lead to a results screen with immediate restart.

The defining playable moment is: pull a crowd together with Tumbleweed of Doom, land an empowered ricochet shot, trigger a needle chain reaction, then spend the Stache meter on High Noon with golden moustache wings.

This is a deliberately smaller first delivery of the [motivation plan](../motivation/game_motivation.md), whose eventual prototype describes ten minutes, five enemy archetypes, twelve upgrades and three active abilities. This delivery has three enemy archetypes, six upgrades, two active abilities and one ultimate/Frenzy activation. The final roster's precision-shot High Noon and golden-wing transformation guide the design.

## Starting point at planning and engine decisions

- There is no `project.godot` or gameplay code in the workspace. Neither `godot` nor `godot4` was found on PATH during inspection.
- The existing [hero model](../../character_models/DON_ESPINO_hero_v3.blend) is the art master. Its [validation](../../renders/don_espino/v3/validation.json) reports 814,025 base mesh polygons, 70,000 felt fibers and a 25-bone presentation rig. These counts are not a runtime triangle budget. Existing combat scenes contain static poses, not locomotion or complete attack animations.
- Use **Godot 4.7.2 standard edition, GDScript**, and matching export templates, pinned for the demo. This version was listed on the [official Linux download page](https://godotengine.org/download/linux/) when this plan was prepared.
- Target Linux desktop first, keyboard and mouse, 1920 × 1080. Start with Forward+ and restrained lighting; its desktop 3D role fits this target. [Godot renderer guidance](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).
- Keep the Godot project under `game/`. Keep Blender sources outside that directory and import explicit `.glb` runtime exports. Godot recommends glTF 2.0 and supports binary GLB. [Supported formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

## Arena and camera

Build one approximately 28 × 22 metre arena with a single walkable elevation. A saloon facade, broken fence and sandstone perimeter frame the fight. Two groups of permanent stone cover and a central water trough create a loop and two crossing firing lanes. Keep enough space around each obstacle for dashing and circling enemies.

Place six explosive fuel barrels and a few breakable crates at the edges of the lanes. Barrels damage both sides after a visible warning. Permanent cover is part of the navigation bake; destructible decoration does not seal routes or require runtime navigation rebaking.

Use a fixed orthographic camera at approximately 50° elevation and 45° yaw, following Don Espino with light smoothing and boundary clamps. Movement is camera-relative on the XZ plane; mouse aiming is independent of movement. Start with a frame that makes the character roughly 160–220 pixels tall at 1080p, then tune combat visibility in-engine. Fade any foreground prop that obscures the player.

Retain the brown felt hat, chestnut moustache, green cactus, orange shorts, tan boots and warm Badlands palette. Player attacks use gold and green; hostile attacks use clearly different red/magenta telegraphs. Target markings and floor warnings remain visible through special effects.

## Controls and combat rules

All numbers below are initial tuning values, to be adjusted after the first playable test.

| Input | Action | Initial behavior |
| --- | --- | --- |
| WASD | Move | Independent of aiming; immediate direction changes with a short visual blend |
| Mouse | Aim | Ground reticle; horizontal muzzle-height firing direction derived from its XZ position |
| Left mouse | Six-shot revolver | Hold to fire at a controlled cadence; six rounds, 20 base damage, approximately 0.24 seconds between shots |
| R | Reload / active reload | 1.2-second reload; a second press during a visible timing window empowers the next cylinder; a miss completes a normal reload |
| Space | Dash | Approximately 3 metres over 0.18 seconds, brief invulnerability, 1-second cooldown; world collisions remain active |
| Q | Ricochet Rodeo | Arms the next shot with three extra enemy bounces; 8-second cooldown |
| E | Tumbleweed of Doom | Launches a vortex toward the reticle; 12-second cooldown |
| F | High Noon + Stache Frenzy | Spends a full Stache meter; precision-shot sequence and temporary golden wings |
| Escape | Pause | Resume, controls, volume, screen-shake strength and quit |

The original plan introduces Ricochet Rodeo as an upgrade family. Giving it a Q activation is a **demo-specific control decision** so the player can reliably try the mechanic. The permanent extra-bounce upgrade described below still combines with it. Right-click secondary fire is reserved for a later fan-the-hammer addition.

Player health starts at 100. Taking damage gives brief contact-damage protection, a readable hit response and a modest knockback. Dash does not pass through walls. The ground reticle and gun orientation must agree with the actual shot; a nearby wall blocks firing even when the cursor is beyond it.

Normal revolver shots use a physics ray with a visible fast tracer, muzzle flash, recoil and hit feedback. Enemy bullets and cactus needles use moving projectiles with swept collision checks. Damage is calculated by the combat system, independent of whether an optional visual effect is drawn.

## Specials and their interactions

| Mechanic | Playable specification | Readability and limits |
| --- | --- | --- |
| Ricochet Rodeo | The next fired round chains to up to three additional live enemies within 5 metres of the previous hit. Each hop retains 75% of the preceding damage. It expires after firing, including on a miss. | Each hop requires line of sight and cannot revisit a target in the same chain. Draw consecutive gold segments with brief impact flashes. |
| Tumbleweed of Doom | A rolling tumbleweed reaches a valid point within 7 metres, then lasts 3.5 seconds, pulling enemies within a 3-metre radius and dealing small periodic damage. | Collision-aware pull; permanent walls block the effect. Bosses take damage but receive only 20% pull strength. Telegraph the affected ground area. |
| Prickly Situation | An optional upgrade makes a critical-killed enemy emit eight damaging needles. Empowered cylinders from active reload provide a reliable way to trigger it. | Needles originate at the defeated enemy. They can inherit one ricochet when that upgrade is owned, but cannot create further needle bursts in this demo. |
| High Noon | With 100 Stache, mark up to six visible, in-range enemies, briefly slow hostile combat, and resolve six precision-shot attempts. Prioritize targets near the reticle and retarget surviving enemies when necessary. | Each shot rechecks range, target validity and line of sight. With fewer enemies, repeat surviving targets. With no initial target, refuse activation without spending charge. Player control and UI remain responsive. |
| Stache Frenzy | The same F activation grows glowing golden moustache wings for 6 seconds, adding one ricochet and improving firing cadence during that window. | This first demo deliberately shares the ultimate and transformation trigger. Rebuild the wings as lightweight meshes with a shader pulse and short animation. |

Stache rises from kills and successful active reloads, falls on damage, and slowly decays after several seconds without combat. Reward active reload only once per cylinder after ammunition was spent. Suspend new meter gain during Frenzy. Pause meter decay in menus and wave transitions. Tuning must let a competent first-time player use the transformation before the boss and recharge it during the boss fight.

Guard every attack chain with an attack ID, visited targets, a maximum of 32 secondary damage events and one generation of spawned secondary projectiles. These are demo bounds for stable, understandable combinations. They also prevent recursive needle/explosion loops. All ability cooldowns, hostile time dilation and temporary stat modifiers reset on death, restart and return to menu.

## Enemy roster

These are proposed demo enemies based on the motivation's appliance/vegetable/animal theme. Every enemy has a moustache and a distinct silhouette.

| Enemy | Job in the fight | Behavior and counterplay |
| --- | --- | --- |
| Fridge bruiser | Forces movement | Slowly pursues, winds up a short charge, then opens its door for a close hit. A visible wind-up and recovery invite dashing sideways. Start around 60 HP. |
| Chili bandit | Controls firing lanes | Keeps medium distance, aims a visible line, fires a short burst, then repositions. Stone cover blocks its shots. Start around 40 HP. |
| Pigeon bomber | Makes standing still unsafe | Remains near a ground navigation anchor and lobs an explosive egg at the player's last position. A ground circle gives approximately 0.9 seconds to move. Start around 30 HP. |
| El Frigorífico — miniboss | Tests the complete kit | A larger refrigerator sheriff alternates a lane charge, a telegraphed ice-shot fan and a recovery window. Below 50% HP it adds a small escort wave and shortens recovery. Start around 900 HP. |

The pigeon is visually airborne but uses a simple ground anchor for movement and targeting; free-flight navigation is unnecessary for this arena. Reuse the refrigerator enemy's rig and material family for the boss, with a distinctive sheriff silhouette and attacks.

Spawn enemies from marked perimeter points, with a warning and a minimum distance from the player. Limit active enemies to roughly 35. An encounter may queue more enemies, but its active cap must be respected. Never spawn overlapping the player or inside cover. Boss entrance and new spawns have a short grace period before attacking.

## Complete run structure

| Stage | Encounter | Player learning / reward |
| --- | --- | --- |
| Arrival | Short safe area with a target and visible controls | Move, aim, shoot, reload and dash; start the encounter when ready |
| Wave 1 | Fridge bruisers, then a small chili group | Basic shooting and dodging; one health pickup and upgrade choice after clearing |
| Wave 2 | Mixed bruisers and bandits with spaced bomber arrivals | Cover, vortex grouping and ricochets; second upgrade choice after clearing |
| Wave 3 | Denser mixed wave with explosive barrels | Demonstrate an upgrade interaction and charge/use Frenzy |
| Showdown | El Frigorífico plus a bounded escort wave | Dodge telegraphs and use specials during recovery windows |
| Results | Win or death | Show time, kills, highest chain and chosen upgrades; retry or quit |

Wave completion requires both an exhausted spawn queue and no living encounter enemies. Upgrade choices pause combat. Run time excludes pauses and upgrade menus. The five-to-seven-minute duration is a playtest target, not a forced timer or automatic victory.

Offer two choices during the run, each showing three eligible cards from a six-upgrade pool: **Extra Bounce**, **Prickly Situation**, **Explosive Personality** (every fifth primary shot adds a small blast), **Hair Trigger** (faster firing), **Magnetic Tumbleweed** (larger pull radius), and **Quick Draw** (the first shot after a dash is critical). Guarantee at least one behavior-changing card in each offer. Show the exact mechanical change on the card.

## Bring Don Espino into the game

Create a separate runtime asset derived from the preserved hero master. Starting budgets are approximately **25,000–40,000 triangles for the complete player**, a smaller distance LOD, and **3–4 material surfaces**. These are working budgets to profile, not measured results.

1. Simplify or retopologize the body, hat, moustache, hands, boots and weapon while protecting the silhouette and joint deformation. Preserve enough geometry in the moustache tips and hat crown to match the intended style at the actual camera distance.
2. UV unwrap the runtime meshes. Bake cactus pores, cloth weave, felt fibers, hair grooves and leather detail into base-color, normal and roughness/metallic textures. Start with a 2K character atlas and a smaller prop atlas. Retain a sparse set of silhouette spines as geometry. Do not export 70,000 individual felt fibers into the game.
3. Export a clean rest-pose rig, meshes and named animation clips as GLB. Use Godot-compatible PBR materials and verify normals, tangents, scale and forward axis in a small in-engine turntable. Keep render cameras, studio floor and studio lighting out of the runtime character. [Godot export conventions](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html).
4. Author idle, locomotion/strafe, shoot, reload, dash, hurt, death, cast and ultimate clips. The existing presentation rig is a starting point; check its deformation in these movements and revise weights or controls where needed. Blend movement separately from upper-body aim, with the weapon attached to a stable hand socket and its muzzle defining the shot origin.
5. Compare the Godot character with the [hero reference and native renders](../../renders/don_espino/v3/README.md) at gameplay scale and in a close-up. Rebuild warm lighting in Godot and tune PBR materials there. Fine baked detail and silhouette quality matter more than preserving the source polygon count.

The two existing Blender combat scenes provide pose and effects references. Their refrigerator props can seed a simplified enemy mesh. They do not supply enemy AI, damage, navigation, or complete attack animations.

## Godot implementation structure

```text
game/
  project.godot
  scenes/main.tscn
  scenes/arenas/crispy_badlands.tscn
  scenes/player/don_espino.tscn
  scenes/enemies/{fridge,chili,pigeon,boss}.tscn
  scenes/effects/
  scenes/ui/{hud,pause,upgrade_choice,results}.tscn
  scripts/player/
  scripts/combat/{damage,weapon,abilities,stache}/
  scripts/enemies/
  scripts/run/{run_session,wave_director}/
  resources/{weapons,abilities,enemies,upgrades,encounters}/
  assets/{characters,enemies,environment,audio}/
  tests/
```

Use `CharacterBody3D` for the player and grounded enemies, `Camera3D` for the orthographic view, and `AnimationTree`/`AnimationPlayer` for character motion. Use a baked `NavigationRegion3D` and enemy `NavigationAgent3D` nodes; movement code must actually drive the bodies. Stagger path-target refreshes rather than requesting a fresh path every frame, while advancing active paths during physics updates. Godot explicitly separates navigation-agent path calculation from parent-node movement. [Navigation agent guidance](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html).

Store tuning in typed Resource assets: weapon damage/cadence, ability cooldowns and ranges, enemy behaviors, wave definitions and upgrade modifiers. Give damage events explicit source, target, critical flag and chain metadata. Use signals for kills, meter updates, wave completion and UI changes. Keep cosmetic effects separate from authoritative hit detection.

The HUD shows health, six chamber indicators, active-reload timing, Q/E cooldowns, Stache/F readiness and wave/boss progress. Add clear gun, hit, ricochet, dash, vortex, danger and ultimate sounds. Include volume and screen-shake controls. Prioritize threat cues in the audio mix.

## Delivery milestones and acceptance gates

| Milestone | Concrete deliverable | Gate before moving on |
| --- | --- | --- |
| 1 — Running combat foundation | Godot project, simple arena, temporary player visual, movement/aim/dash, revolver, reload, one pursuing enemy, damage/death/restart | The project boots into an actual playable fight. Aim and gun direction agree; walls block shots and dashes; restarting clears the prior run. |
| 2 — Runtime character and arena | Baked GLB Don Espino, required movement/weapon clips, final arena layout and all three basic enemies | The imported character deforms correctly while moving and firing in different directions; enemies navigate the cover and communicate their attacks. |
| 3 — Attack combinations | Ricochet, vortex, Prickly upgrade, Stache, High Noon and Frenzy | Every special changes enemy health or position correctly; combinations are bounded; player control survives the ultimate. |
| 4 — Complete short run | Wave sequence, two upgrade choices, six-upgrade pool, boss, HUD/audio and results | A player can finish or lose a full run, understand the result, and immediately retry with clean state. |
| 5 — Tested demo build | Linux executable, project source, controls/readme and performance notes | The exported build works outside the editor, preserves the intended visual style and passes the checks below. |

The first implementation milestone is a running fight. Art conversion is necessary before the visual acceptance gate and can progress independently of most combat code.

## Verification and performance

Target 60 FPS at 1080p on the current RTX 3060 Laptop class machine. Measure median and 95th-percentile frame time in the busiest mixed wave and during Frenzy; this target is not yet benchmarked. Start with a 35-enemy cap and a bounded projectile/effects budget, reuse effects where profiling justifies it, and limit shadow-casting lights. Dropping excess cosmetic particles must not drop gameplay damage or threat indicators.

Automate focused checks for ammo/reload timing, cooldown spending, critical-hit effects, ricochet visit limits, dead-target handling, wave completion, boss death and restart cleanup. Run a headless project-load smoke check, then real interactive and exported-build checks; a headless pass alone does not establish that aiming, visuals or combat feel work.

Manually verify that every enemy attack can be read and avoided; every special can be triggered in a normal run; the player can move and aim through the ultimate; pause/resume does not consume cooldowns or leave slow motion stuck; no permanent navigation trap occurs around cover; and repeated restarts leave no projectiles, enemies or temporary stat modifiers behind.

**Definition of done:** a downloadable desktop demo with the recognizable Don Espino model, a complete arena run, three enemy behaviors, two active specials, the golden-wing High Noon moment, at least one demonstrable upgrade interaction, a miniboss, win/loss/retry, and recorded performance observations.

After this demo, extend toward the motivation's ten-minute slice: two more enemy archetypes, twelve upgrades, a third active ability, fan-the-hammer, additional mutations and persistent unlocks. Additional zones, characters, multiplayer and web delivery are later scope decisions.
