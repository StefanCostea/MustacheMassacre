# From concept render to source GLB

## Prepare one image

1. Read the game's visual brief and inspect the Don Espino hero reference named in the workspace guide. Use image generation to create and show a polished full-body concept. Save the actual image and prompt in a versioned directory under `desgin/renders/<character>/concepts/`. Respect any requested concept approval before continuing.
2. Use the concept as an image reference for a neutral rigging render of the same character. Keep the proportions, costume, colours and surface detail. Frame the whole figure in a near-front view, with relaxed A-pose arms, open empty hands clear of the torso and space between the boots. Use an isolated background and avoid cast shadows that join the feet. Generate held props separately. A concept already meeting these conditions can serve both purposes.
3. Inspect the saved PNG or JPEG at full size. Check the face, moustache, finger separation and silhouette at the hat, elbows and ankles. Send one view to TRELLIS.2. Keep turnarounds as Blender review references.

## Generate the model

1. Call the Runware MCP tool `model_schema` with `{"model":"microsoft:trellis-2@4b"}`. This also checks account access without generating an asset. If a key is missing, the setup below lets the user enter it privately.
2. For a local render, run the installed helper from the workspace root with the actual image path. It uploads the bytes to the user's Runware account through the media storage API and prints the resulting media UUID. Reuse that UUID for the same render. [Runware media storage](https://runware.ai/docs/models-api/media-storage)

   ```sh
   ~/.local/bin/runware-mcp --upload-reference "$render_path"
   ```

3. Create a versioned source directory such as `desgin/character_models/generated/<character>/v01/`. Before submitting, save the prompt, input path and SHA-256, media UUID and request JSON there. Generate a UUIDv4 with `python3 -c 'from uuid import uuid4; print(uuid4())'`. Replace both placeholders below. Call the MCP tool `run` with these fields at the top level. The settings are a starting point for one textured source model. [TRELLIS.2 model parameters](https://runware.ai/docs/models/microsoft-trellis-2)

   ```json
   {
     "model": "microsoft:trellis-2@4b",
     "taskType": "3dInference",
     "taskUUID": "<new-task-uuid>",
     "inputs": {"image": "<media-uuid>"},
     "settings": {"resolution": 1024, "textureSize": 2048, "remesh": true},
     "outputFormat": "GLB",
     "outputType": "URL",
     "numberResults": 1,
     "includeCost": true
   }
   ```

4. If the call times out or returns a pending task, retrieve it with `get_task_details` using the saved task UUID. Follow that same job to completion and record a provider error if it fails. A timeout alone is insufficient reason to submit another billable generation.
5. Download the GLB from the completed task's `outputs.files[].url` to a temporary file in the versioned directory. Check the glTF 2 binary header, declared length and mesh data before saving it as `source.glb`. Keep the output UUID, seed and cost when returned, and the source SHA-256 beside the request. [Example TRELLIS.2 response](https://runware.ai/docs/models/microsoft-trellis-2/examples)
6. Open a working copy in Blender. Render the actual mesh at the concept angle, then inspect the back and sides, material textures and likely deformation areas. Compare the images before cleaning or reducing the mesh. Continue through neutral FBX export, Mixamo, Blender animation polish and the isolated Godot review scene. [Character Artist guide](../../../../desgin/agents/character_artist.md)

## Local setup

The installed launcher reads `RUNWARE_API_KEY` or the user's private key file at `~/.config/runware-mcp/api-key`. To enter or rotate the key, create it under **API Keys** in Runware, run `~/.local/bin/runware-mcp --set-key` in a terminal, paste at the hidden prompt, and start a fresh Codex session. The key file is readable and writable only by its owner. [Runware authentication](https://runware.ai/docs/models-api/authentication)

To reproduce the installation on Linux with Node 18+, npm, Python 3 and Codex, run these commands from the workspace root. [Official Runware MCP](https://github.com/Runware/mcp)

```sh
npm install --prefix "$HOME/.local/share/runware-mcp" --save-exact --ignore-scripts --no-audit --no-fund @runware/mcp@1.4.0
install -D -m 755 .agents/skills/character-artist/scripts/runware-mcp "$HOME/.local/bin/runware-mcp"
codex mcp add runware -- "$HOME/.local/bin/runware-mcp"
```
