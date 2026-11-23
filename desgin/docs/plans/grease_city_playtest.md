# Grease City and General Coo

Play with `./tools/run_natural_demo.sh`. For a packaged build, substitute `./build/releases/MoustacheMassacre-x86_64.AppImage` in the commands below. **Characters & Loadout** remembers the selected hero. Use **Ring the Bell** to start.

| Playable entry | Command |
| --- | --- |
| Wave-three repair crew, with build pieces and a charged special | `./tools/run_natural_demo.sh -- --bottleneck-preview` |
| The sheriff at his half-health attack | `./tools/run_natural_demo.sh -- --freezer-preview` |
| Safe freight route | `./tools/run_natural_demo.sh -- --freight-preview` |
| Fry Line elite with General Coo | `./tools/run_natural_demo.sh -- --general-coo --fry-line-preview` |
| Two consecutive Badlands runs and player reflections | `./tools/run_natural_demo.sh -- --two-run-playtest` |

Equip High Noon for the precision preview, or Tumbleweed Vortex and Saguaro Lance for the crowd-control preview. Use the cover to reach the welder’s flank. A ricochet can interrupt its weld and spread needles. Tumbleweed can throw the damaged fridge into a second outlaw and scatter frozen shrapnel before the beam lands. Practice entries suppress wax payouts. In an ordinary run players earn these pieces through the card draft.

The sheriff gives a 1.45-second striped warning, freezes the lane for 2.4 seconds, and takes 50% extra damage for 2.1 seconds as his coils cool. Completing the Badlands in ordinary play opens two routes. Freight awards 12 wax before the exit. The Fry Line adds an elite that marks incoming hot grease and awards a bonus card for use in the exit fight.

## Two-run session

Give each fresh player two runs. Let them choose the loadout and cards themselves. After the first defeat or sheriff victory, the form asks what they think caused their biggest hit and what they want to try next. After run two, it asks what caused the biggest hit and how the second build compared with expectations. “Unsure” is a valid response. A group using an older build can share the same observations in ordinary notes.

Record the player’s own explanation before showing the recorded best-chain cause. The recorded chain describes linked kills. Players may have had a different hit in mind. Compare the first-run intention with the second hero, abilities and upgrade selections. The file includes the offered cards so an unavailable upgrade can be distinguished from a choice to pass. Note any confusion about the welder, the striped warning, the damage window or the two route rewards.

Completed pairs are local JSON files under `~/.local/share/godot/app_userdata/Mustache Massacre — Last Call/playtests/` on a standard Linux install. The file named `current.json` holds an unfinished session. Launch the same mode to resume between runs. In this mode the sheriff’s defeat leads directly to feedback.

## Art sources

The [Coo concept](../../renders/general_coo/concepts/v01/neutral.png) and [diner concept](../../renders/grease_city/concepts/v01/neutral.png) were generated for this build. Runware TRELLIS.2 reconstructed each textured mesh. The retained sources, requests and audits are under `desgin/character_models/generated/general_coo/v01/` and `desgin/prop_models/grease_city/v01/diner/`. Coo has a 15-bone rig and 11 authored Blender clips. Mixamo was signed out during production. [Godot gameplay frames](../../renders/grease_city/gameplay/)
