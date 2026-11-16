# DCS F-14 Ground Crew Mod

A DCS World mod that shows a visible ground crew around a parked F-14.

## Parts
- **Crew people**: DCS's built-in Supercarrier deck crew statics. Set up on the Windows PC (not done yet).
- **Extra props DCS doesn't have** (e.g. a gas cylinder trolley): made from purchased 3D models kept in this folder.
  - `GasCylinder-Trolley_Files/` is a purchased game-asset pack (Unreal Engine export: `.fbx` meshes + PBR `.tga` textures).
    - `Unreal_Export/Trolley/SM_Trolly_01.fbx`: the trolley
    - `Unreal_Export/Gas Cylinder/SM_GasCylinder_01..04.fbx`: 4 cylinder variants
    - `Raw_Textures/`: separate BaseColor/Metallic/Roughness/Normal/Occlusion maps
- **`f14_ground_crew.lua`**: mission script that spawns everything around the jet (F10 radio menu, removes it all when the jet moves). It uses built-in DCS objects as placeholders for now.

## Machines and workflow
- Worked on from a **Fedora laptop** (Linux) and a **Windows PC**, synced through the GitHub repo `fraserbyte/DCS-groud-crew-mod`.
- The DCS EDM exporter for Blender may only work on Windows, so **final `.edm` exports will probably happen on the PC**.
- Blender is driven through the Blender MCP add-on (`blender_mcp/`, not committed).

## Licensing: important
- The purchased models' licence probably doesn't allow redistribution. **Never commit 3D model or texture source files** (`.stl`, `.obj`, `.fbx`, `.blend`, `.tga`, etc.) or the `GasCylinder-Trolley_Files/` folder. `.gitignore` enforces this. Check `git status` before committing.
- Because of this, model files must be copied between the laptop and the PC by hand (USB stick, cloud drive, etc.), not through GitHub.

## Asset pipeline plan
1. Import the model into Blender and inspect it (format, triangle count, size, base/stand, UVs/materials).
2. Prepare it: keep an untouched high-detail copy for baking, delete any base/stand, scale to real-world metres, origin at bottom centre (ground contact), apply transforms, reduce to game-ready triangle count + 2 lower LODs, give everything clear names, save as `.blend` in this folder.
3. Bake detail/textures, export to `.edm` (on Windows), hook into DCS and the Lua script.

## Working with the user
- The user is new to Blender: explain things simply.
- Work in stages and stop after each one for the user to check.
- Ask before deleting or overwriting anything.
