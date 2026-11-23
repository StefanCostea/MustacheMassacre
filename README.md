# Mustache Massacre — Last Call

A playable Godot 4.7.2 desktop demo. Explore four connected regions as Don Espino or General Coo, or take on the three-wave Badlands arena.

**Play on Linux** by downloading the AppImage from the [latest release](https://github.com/StefanCostea/MustacheMassacre/releases/latest). Run these commands in the download folder.

```bash
chmod +x MoustacheMassacre-x86_64.AppImage
./MoustacheMassacre-x86_64.AppImage
```

To run from a clone, install Git LFS, run `git lfs pull` in the project directory, then run `./tools/run_demo.sh --headless --editor --import --quit` and `./tools/run_natural_demo.sh`. Choose **Characters & Loadout** on the title screen to switch heroes.

Choose **Explore the County** to start at the Grooming Garage. Press **M** for the map, click a gold job ring to track its direction and distance, and press **G** at a job marker or workshop. You can also launch straight into town with `./tools/run_natural_demo.sh -- --open-world`.

| Region | Local jobs |
| --- | --- |
| The Crispy Badlands | Break up the water-tower repair crew. Challenge El Frigorífico at the western crossing. |
| Grease City | Time the Fry Line vents against the Head Fry Cook, or walk beside the wax truck and protect it at the ambush. |
| Funland Forever | Bait the bumper cars into ticket puppets, then shoot or operate the wheel breaker. |
| The Grand Grooming | Fight shaving-brush guards and His Royal Flushness. Turn the flush valve as the cistern fills. |

Both outer fords are open from the start. Completing the freight and Ferris wheel jobs opens two permanent crossings. Return to the Garage after any bounty to finish a run, or visit its workshop to spend wax. The road preserves Stache between fights. **Ring the Bell** starts the wave campaign.

General Coo carries a rotary gun that spins up as you hold fire. Tap **R** in the green vent window to cool it and prime a critical round. **Space** hops over danger, **E** throws an egg, and **F** summons three wingmen while Coo’s moustache splits into firing barrels. Don and Coo draw from the same upgrade pool. [General Coo in the arena](desgin/renders/grease_city/gameplay/coo_fire.jpg)

In wave three, a Skillet Outlaw shields a mechanic repairing a wounded fridge in a narrow alley. Circle the skillet for a perfect-reload ricochet, or pull the fridge into the crew and sweep Saguaro Lance across the survivors. At half health the sheriff opens his freezer door. Get off the marked ice lane, then return fire while his coils are exposed. [Freezer attack](desgin/renders/grease_city/gameplay/freezer_live.jpg)

After the sheriff, choose **Travel to Grease City**. **Wax Freight** pays 12 extra wax for clearing its delivery crew. **The Fry Line** pits you against the armored Head Fry Cook and rewards an extra upgrade before the exit fight. Both routes carry your loadout and picks forward. [Grease City](desgin/renders/grease_city/gameplay/grease_city.jpg)

To watch a full hands-free run with Coo, use `./tools/run_natural_demo.sh -- --autoplay --general-coo --route-fry-line`. For Don’s freight run, use `./tools/run_natural_demo.sh -- --autoplay --route-freight` with Don selected. [Playable shortcuts and two-run playtest](desgin/docs/plans/grease_city_playtest.md)

In **Characters & Loadout**, equip **Slapstache** or **Tumbleweed Vortex** on E independently of High Noon or Saguaro Lance on F. Flank the **Skillet Outlaw**, or fire during his recovery. Follow the teal weld to the **Repair Appliance** and interrupt it before its patient regains health.

Each wave clear awards six Moustache Wax. The results screen pays one more per six kills and a twelve-wax bounty for the sheriff. In the **Grooming Garage**, unlock **Second Helping** for 24 wax or **Powdered Prickles** for 30. They join the pool for future runs. Slapstache strikes twice with Second Helping. Powdered Prickles gives explosive needles to a Prickly Situation build. [Garage](desgin/renders/badlands_expansion/garage.jpg) · [Ground strike](desgin/renders/badlands_expansion/slap.jpg)

The single-file natural-hero release is [MoustacheMassacre-x86_64.AppImage](https://github.com/StefanCostea/MustacheMassacre/releases/download/v0.4.0/MoustacheMassacre-x86_64.AppImage).

The Linux launcher retries with OpenGL if Vulkan device creation prevents the game window from opening. You can also select OpenGL directly with `./build/releases/MoustacheMassacre-x86_64.AppImage --rendering-method gl_compatibility`.

Play the latest environment and the natural-pose Don Espino with `./build/releases/LastCall/play-natural.sh --fullscreen`. The street uses sixteen custom props, including destructible fuel drums and fruit crates, bound hay cover, a water trough and the Last Call saloon. [Arena art review](desgin/docs/art/badlands_environment.md) · [Environment Artist skill](.agents/skills/environment-artist/SKILL.md)

Choose **Watch Both Specials** on the main menu for a hands-free arena run. Don Espino opens with High Noon, lands, then fuses his arms for Saguaro Lance. Both opening casts are charged for the demo. He then earns Stache and alternates the specials while fighting through the waves, choosing upgrades and facing El Frigorífico. To launch directly, run `./build/releases/LastCall/play-natural.sh -- --autoplay-specials`. [Watch the opening](desgin/renders/don_espino/specials_autoplay/opening.mp4)

Choose **Characters & Loadout** in the main menu to equip **High Noon** or **Saguaro Lance**. The game remembers the choice between runs and launches. With Saguaro Lance, both forearms grow into one fluted cactus barrel and fire a sustained beam of thorns. Aim with the mouse to sweep through enemies once the camera pulls back. Solid cover stops the beam, and repeated hits break crates. Try the charged first wave with `./build/releases/LastCall/play-natural.sh -- --saguaro-lance-preview`. [Customization screen](desgin/renders/don_espino/saguaro_lance/loadout.jpg) · [Saguaro Lance in combat](desgin/renders/don_espino/saguaro_lance/saguaro_lance.mp4)

To try High Noon immediately, run `./build/releases/LastCall/play-natural.sh -- --high-noon-preview`. The first wave opens with a charged cast and continues as a playable run. Espino drops his revolver, his brown moustache straightens and turns gold from root to tip as feather-like strands unfurl underneath, and his right forearm sprouts a cactus spike launcher. Steer with **WASD** and hold the **left mouse button** to fire while airborne. [Watch the arena capture](desgin/renders/don_espino/high_noon/high_noon.mp4)

The reusable character-production agent is documented in [AGENTS.md](AGENTS.md)
and [Character Artist](desgin/agents/character_artist.md). Its refined Don Espino
[Blender/Mixamo pilot report](desgin/character_models/refined/don_espino_workflow/README.md)
includes the new neutral-pose generation reference, actual animation samples and
an isolated Godot review scene. The pilot fails visual quality review and does
not replace the playable hero.

The newer [neutral-model candidate](desgin/character_models/refined/don_espino_natural_workflow/README.md)
has the complete twelve-clip gameplay set, a separate revolver and moustache
controls. Play it with `build/releases/LastCall/play-natural.sh` or
`./tools/run_natural_demo.sh`. For individual animation review, run
`./tools/run_demo.sh res://scenes/natural_character_review.tscn`.

All five regular enemies and the sheriff use animated Blender models in the arena. The pigeon takes off, clears cover and throws a visible speckled egg at a marked patch of ground. Aim at its body while it is airborne. The bandit sidesteps and backpedals with a low carry before raising his revolver. [Arena bombing run](desgin/renders/badlands_enemies/v03/bombing_run.mp4) · [Animation reel](desgin/renders/badlands_enemies/v03/enemy_motion.mp4)

Run `./tools/run_demo.sh res://scenes/badlands_enemy_review.tscn` to inspect the animations. Press **4** for El Frigorífico, use the **arrow keys** to select a clip, and press **B** to compare models. [Enemy designs and sources](desgin/docs/art/badlands_enemy_designs.md)

## Play

The self-contained Linux x86_64 build is in `build/releases/LastCall/`. Launch `LastCall.x86_64` or `play.sh`; no Godot editor is needed. Keep `LastCall.pck` beside the executable. The zipped distribution is `build/releases/MustacheMassacre-LastCall-linux-x86_64.zip`.

From this checkout, run:

```sh
./tools/run_demo.sh
```

On a fresh source checkout, run `./tools/run_demo.sh --headless --editor --import --quit` once to import the art. The project imports assets sequentially for a reliable first launch.

This uses the pinned editor in `~/.cache/codex-tools/godot-4.7.2/`. If missing, the launcher downloads the official editor and templates and verifies their SHA512 checksums. Alternatively, open `game/project.godot` in Godot 4.7.2 standard edition and press F6 on `scenes/main.tscn` or F5.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move relative to the camera |
| Mouse / hold left button | Aim / fire Don’s six-shooter or spin up Coo’s rotary |
| R, then R in the green window | Don reloads for critical rounds. Coo vents heat and primes one critical round. |
| Right mouse | Don fans the cylinder. Coo fires a three-round burst. |
| Space | Don dashes. Coo performs a short airborne hop. |
| Q | Coil the moustache and arm the next shot with three ricochets |
| E | Don uses his equipped field skill. Coo drops an egg bomb. |
| F at 100 Stache | Don uses his equipped special. Coo calls Carpet Coo-Bombing. |
| Enter | Activate the focused menu choice |
| M / G | County map / nearby job, workshop or valve |
| Escape | Pause, sound/music/shake settings, retry or quit |

During combat the aiming cursor stays inside the game window. Press Escape to release it for menus or other windows. Version 0.1.1 fixes the hidden cursor escaping the window and making the crosshair stop following visible mouse movement.

If aiming with a laptop touchpad stops while holding WASD and returns after releasing the keys, turn off **Disable touchpad while typing** in your desktop settings. On GNOME, use `gsettings set org.gnome.desktop.peripherals.touchpad disable-while-typing false` (restore it with `true`). This is a desktop preference; the game does not change it automatically. Keyboard suppression happens before mouse input reaches the game, so pausing can make the pointer appear to work again.

Use the practice target before ringing the bell. Pink marks and bullets are hostile; gold and green effects belong to Don Espino. Fuel barrels hurt both sides after a warning. Cover blocks attacks and movement. Wave completion restores 25 health. Death and victory both offer an immediate retry.

Kills, multikills, close dodges and perfect reloads build Stache. Damage and prolonged inactivity reduce it. High Noon needs a visible target and can repeat surviving enemies. Each wave offers three cards from twelve possible upgrades. Offers account for equipped abilities and workshop unlocks.

## Project and art

- `game/`: complete GDScript project, resources, shaders, fonts, original synthesized music and sound effects.
- `game/resources/`: typed combat tuning, enemy specifications and encounter definitions.
- `game/assets/characters/don_espino/`: skinned runtime GLB, baked PBR atlases, animation manifest and optional lower-detail GLB. Godot also generates mesh LODs during import.
- `desgin/character_models/DON_ESPINO_hero_v3.blend`: preserved detailed art master. The original FBX and all earlier models remain intact.
- `tools/build_runtime_espino.py`: repeatable Blender reduction, UV/bake and animation/export pipeline. Its working files are under `build/asset_work/`.
- `desgin/docs/plans/godot_playable_demo.md`: the design plan; `demo_implementation_status.md` links implementation evidence.

The player asset has 34,588 triangles, four material groups, a 25-bone skeleton and 12 clips. Cactus detail, moustache grooves, hat surface, woven shorts and worn leather are baked into three 2K atlases and one 1K prop atlas. The game combines directional locomotion with upper-body actions. The runtime asset is a separate, simplified game version of the native hero; the detailed Blender master is preserved.

The arena uses textured TRELLIS.2 scenery and destructibles, with a painted street laid over detailed hardpan. The enemies use skinned GLBs with embedded Blender animation. The original procedural enemies are available with `./tools/run_demo.sh -- --original-enemies`.

## Build and verification

```sh
python3 tools/bootstrap_godot.py
./tools/export_demo.sh
./tools/run_demo.sh --headless --fixed-fps 60 -- --test
./tools/run_demo.sh --headless --fixed-fps 60 -- --high-noon-test --natural-hero
./tools/run_demo.sh --headless --fixed-fps 60 -- --loadout-test --natural-hero
./tools/run_demo.sh --headless --fixed-fps 60 -- --enemy-animation-test
./tools/run_demo.sh --headless --fixed-fps 60 -- --restart-test
./tools/run_demo.sh --headless --fixed-fps 60 -- --autoplay
./tools/run_demo.sh --fullscreen --resolution 1920x1080 -- --stress
./tools/run_demo.sh -- --review
python3 tools/verify_mouse_tracking.py
```

`--test` exercises combat and encounter rules. `--restart-test` runs three death/results/retry cycles. `--autoplay` uses normal movement, weapons, health and cooldowns to complete a run. Its fixed-frame headless timing is simulation time, **not** a performance benchmark. `--stress` is a separate, deliberately invulnerable 35-enemy diagnostic with recurring Frenzy; it records actual rendered frame times after warm-up. `--review` captures the imported character and poses in Godot.

Reports and screenshots are written to Godot's user-data folder, normally `~/.local/share/godot/app_userdata/Mustache Massacre — Last Call/`. Copies of the recorded checks, screenshots and performance observations are under `build/verification/`; the verification report explains the test conditions and limits.

The mouse regression uses real pointer movement on a private Xvfb display, checks the rendered crosshair and projected gun aim, and exercises window edges, menu transitions and focus return. It requires Pillow, Xvfb, xwininfo and libXtst; these are verification tools, not game runtime dependencies.

To regenerate Don Espino using Blender 4.5.3:

```sh
blender -b -t 4 --python tools/build_runtime_espino.py -- prepare
blender -b -t 4 --python tools/build_runtime_espino.py -- bake
blender -b -t 4 --python tools/build_runtime_espino.py -- export
```

Baking preserves original procedural coordinates when consolidating source objects. Existing baked PNGs are reused; remove only the relevant generated PNGs before rebaking a changed material. Runtime exports never overwrite the art masters. `tools/generate_audio.py` recreates the original score and effects with Python/NumPy.

Linux/Vulkan is the tested target. Controller, web, Windows/macOS packages and multiplayer are outside this demo. Balance has automated playthrough coverage and input checks; broader human playtesting is still useful.

Third-party font and engine notices accompany the distribution. The playable General Coo and diner use generated concepts, TRELLIS.2 geometry and Blender preparation. The arena screenshots are captured in Godot.
