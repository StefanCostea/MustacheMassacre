# Mustache Massacre — Last Call

Run `./play-natural.sh` from a terminal to launch the Linux x86_64 demo. The launcher retries with OpenGL if Vulkan device creation prevents the game window from opening. To select OpenGL directly, run `./play-natural.sh --rendering-method gl_compatibility`. Keep the contents of this folder together.

Choose **Explore the County** or press **Enter** on the title screen. For a direct launch, run `./play-natural.sh -- --open-world`. **M** pauses on the county map. Click a gold job ring to track its direction and distance. **G** starts nearby jobs, uses switches or opens the Garage workshop. The outer fords lead to all four regions from the start.

West lies the Badlands water tower and sheriff. East lies the diner, the Fry Line and Wax Freight. North across the creek are Funland’s runaway bumper cars and the flooded throne of His Royal Flushness. The wheel breaker and freight escort open permanent shortcuts. Collect any bounty and return to the Garage to finish your run.

For the wave campaign, click **Ring the Bell**. Survive three waves, choose three upgrades, and defeat El Frigorífico. Allow about ten minutes for a run. After victory, choose **Travel to Grease City** to keep your hero and upgrades. Wax Freight pays 12 extra wax. The Fry Line awards a fourth upgrade for defeating the Head Fry Cook’s crew. Both paths lead to a drive-thru exit fight.

Choose **General Coo** in **Characters & Loadout** for a heat-driven rotary gun, three-round bursts, a short hop, aimed egg bombs and Carpet Coo-Bombing. Hold LMB to spin up, then tap R in the green vent window for a critical round. To watch his full Fry Line run, use `./play-natural.sh -- --autoplay --general-coo --route-fry-line`.

The sheriff’s half-health freezer attack marks a striped ice lane. Step or hop out and punish the open door. Try it directly with `./play-natural.sh -- --freezer-preview`. Use `--bottleneck-preview`, `--freight-preview` or `--fry-line-preview` in its place for the other encounters.

For a local two-run playtest, use `./play-natural.sh -- --two-run-playtest`. Each Badlands run ends with two short questions. Answers, loadouts and card choices are saved in the Godot user-data folder under `playtests/`.

In **Characters & Loadout**, equip **Slapstache** or **Tumbleweed Vortex** on E independently of High Noon or Saguaro Lance on F. Flank the **Skillet Outlaw**, or fire during his recovery. Follow the teal weld to the **Repair Appliance** and interrupt it before its patient regains health.

Each wave clear awards six Moustache Wax. The results screen pays one more per six kills and a twelve-wax bounty for the sheriff. In the **Grooming Garage**, unlock **Second Helping** for 24 wax or **Powdered Prickles** for 30. They join the pool for future runs. Slapstache strikes twice with Second Helping. Powdered Prickles gives explosive needles to a Prickly Situation build.

Choose **Watch Both Specials** or launch `./play-natural.sh -- --autoplay-specials` for a hands-free run. Don Espino opens with two charged casts, High Noon followed by Saguaro Lance. He then earns Stache, alternates the attacks, and chooses his own upgrades through the boss fight. Your equipped special stays saved for manual play. **Esc** pauses the demo.

Choose **Characters & Loadout** in the main menu to equip one special. Your choice is saved. Press **F** at 100 Stache to activate it.

**Saguaro Lance** brings both forearms together into one cactus launcher. After the close-up, sweep the mouse to guide its stream of spikes. The beam pierces enemies in a line, breaks crates and stops at solid cover. Launch `./play-natural.sh -- --saguaro-lance-preview` for an immediate cast in a playable first wave.

Run `./play-natural.sh -- --high-noon-preview` to open the first wave with High Noon. The camera follows Espino as he drops the revolver, grows moustache wings and takes off. Steer with **WASD** and hold the **left mouse button** to fire cactus spikes from his right arm. When he lands, he recovers his revolver. In a normal run, press **F** with a visible enemy and 100 Stache.

| Control | Action |
| --- | --- |
| WASD | Move |
| Mouse + left button | Aim and fire |
| R | Reload; press again in the green window for critical rounds |
| Right mouse | Fan all remaining chambers, then reload |
| Space | Dash |
| Q | Arm a ricochet shot |
| E | Equipped field ability |
| F | Cast the equipped special at 100 Stache |
| Escape | Pause, settings, retry or quit |

Pink marks warn of enemy attacks. Barrels explode after a warning and hurt both sides. Kills, multikills, close dodges and perfect reloads build Stache. Waves restore 25 health. Cover blocks bullets and movement.

Sound, music volume and screen shake can be changed in the pause menu. Settings are saved in Godot's user-data directory. For fullscreen, run `./play.sh --fullscreen`.

Version 0.1.1 keeps the aiming cursor inside the game window during combat, fixing the crosshair losing visible tracking when the hidden pointer escaped. Escape releases the cursor for menus. Relaunch the game after updating.

Version 0.1.2 adds **play-natural.sh**: launch it to play the same arena with the new neutral-model Don Espino, Mixamo locomotion, animated moustache and a separate revolver. The usual play.sh uses the previous character for comparison. This candidate has all twelve gameplay animation clips; its art review and provenance are in the source project. On laptop touchpads, disable the desktop's "disable while typing" option if holding WASD blocks aiming.

Built with Godot 4.7.2. Engine and font notices are in `licenses/`. Don Espino uses the project's detailed original Blender model, converted to a skinned game asset with baked textures. Version 0.4.0 adds the connected county and regional contracts.

Both launchers use the animated Badlands enemies. Aim at the flying pigeon and move clear of the pink circle before the egg lands. In the gallery, **2** selects the bandit and **3** selects the pigeon. Run `./play.sh -- --enemy-gallery` to view the models up close. Press **1–6** to select an enemy, **←/→** to select an animation, **Space** to cycle automatically and **B** to compare with earlier models. Use `./play.sh -- --original-enemies` to play with the original prototypes.

The updated Crispy Badlands features the Last Call saloon, Dry Gulch water tower, freight wagon, cloth-bound hay, water trough and marked fuel drums. Run `./play-natural.sh --fullscreen` to play the full arena with the refined Don Espino.
