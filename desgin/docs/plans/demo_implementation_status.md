# Playable demo implementation status

Objective: implement the complete [Godot playable demo plan](godot_playable_demo.md) with high detail.

The initial demo shipped on November 12. The November 20 gameplay expansion adds a third upgrade before the boss, twelve possible cards, two more enemy archetypes, Slapstache, fan fire, visible Stache momentum and a persistent Grooming Garage. [Gameplay checks and run timings](../../../build/verification/badlands_expansion.json)

The checklist below records the initial release. The tested Linux build and source archives are under `build/releases/`. See the [project README](../../../README.md) for launching and controls, and the [verification report](../../../build/verification/README.md) for evidence and test conditions.

- [x] Pinned Godot editor and matching Linux export templates available.
- [x] Runtime Don Espino: reduced geometry, baked PBR textures, working rig and animation clips, GLB import verified in Godot.
- [x] Player: camera-relative movement, independent aim, six rounds, active reload, collision-aware invulnerable dash, damage/death/restart.
- [x] Detailed Badlands arena, stone cover, navigation, destructible crates and six explosive barrels.
- [x] Fridge bruiser, chili bandit and pigeon bomber with readable telegraphs and distinct attacks.
- [x] Ricochet, Tumbleweed, Prickly critical-death needles, High Noon and golden-wing Frenzy, bounded interactions.
- [x] Safe arrival, three escalating waves, two upgrade choices from six upgrades, miniboss, win/loss/retry.
- [x] Animated and readable HUD, pause/settings, audio, effects, visual polish.
- [x] Focused gameplay tests, interactive checks, stress/performance observations and repeat-run cleanup.
- [x] Linux release executable/package runs outside editor; source, controls and reproduction documentation supplied.

## Evidence

Initial inspection: project contains art sources and a plan, but no Godot project. Official 4.7.2 editor and template assets are available from the Godot release endpoint. X11 display `:1` and Xvfb are available for rendered testing.

- Official editor and templates verified against the release's SHA512 sums (`build/verification/checksums.log`).
- GLB integrity: 34,588 triangles, four materials, 25 bones, twelve named clips, normalized weights and no studio camera (`build/verification/asset_integrity.json`).
- Character inspected in Godot in idle, movement, shooting, reload, cast, ultimate, rear and death poses (`build/verification/screenshots/character/`).
- Exported executable passes 53 focused checks and three death/results/retry cycles; node count returns to 734 on every restart (`exported_combat.log`, `exported_restarts.log`).
- Normal headless autoplay completes the full run in 332.6 simulated seconds, with both upgrades, 13 High Noon activations and 157 kills. This is a pacing/integration observation, not a benchmark (`autoplay_navigation.log`).
- Real X11 input reaches movement, shooting, reload, dash, Q/E/F, Enter and Escape handlers in the exported build (`input_driver.log`).
- Rendered 1920×1080 Forward+ stress test: 35 mixed enemies, recurring Frenzy, measured frame times; report distinguishes the invulnerable stress harness from normal gameplay (`performance.json`).
- Clean rendered victory in 324.69 seconds, with both upgrade choices and 13 High Noon activations (`rendered_playthrough.json`).
- Stress frame times: 8.33 ms median / 9.09 ms 95th-percentile, physical 1920×1080, 5,314 measured frames.
- Both ZIPs pass CRC checks. The extracted executable passes all 53 checks; the extracted source imports with no existing Godot cache and also passes all 53 checks (`archive_verification.json`). HUD fonts load after import to avoid the cold-import font-loader crash found during verification.

The arena and enemies are generated from native Godot mesh code; the player is the baked Blender asset. Tuning lives in typed combat, enemy and wave resources. Health recovery is granted automatically between waves. Native source files remain preserved; the original FBX SHA256 is unchanged.

Version 0.1.1 fixes the aiming cursor escaping the combat window. The dedicated real-mouse regression covers the painted crosshair, gun aim, four window edges, menus and focus return; its reports are under `build/verification/mouse_tracking_*.json`. Menus continue to release the pointer.
