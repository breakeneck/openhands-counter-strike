---
name: asset-hunting
description: Use when the game needs 3D models, textures, HDRIs, sounds or music — download free/open-licensed assets from the internet instead of building everything from primitives.
---

# Asset hunting (internet-first)

You have full internet access. A good-looking game built from quality open assets beats one made of primitives. Search FIRST, generate only as fallback.

## Best sources (no signup, direct download)

| Need | Source | How |
|---|---|---|
| HDRIs, PBR textures, models (CC0) | polyhaven.com | `curl -L -o file.zip https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/<name>_2k.hdr` ; API: `https://api.polyhaven.com/assets` |
| Game textures/models/fonts (CC0) | kenney.nl/media ; kenney.nl/assets | zip downloads, mostly no auth |
| Mixed open game assets | opengameart.org | file URL from the asset page (`/files/...`) |
| Free 3D models | market.pmnd.rs (Sketchfab-free glTF pack), quaternius.com (CC0 character/prop packs) | direct glTF/glb zip |
| Sounds/music (CC0) | freesound.org needs auth — prefer `opengameart.org`, kenney audio packs, mistbank.fm (CC-BY) | direct mp3/wav |
| Fonts | google fonts github `google/fonts` repo raw files | OFL license |

## Rules

1. Prefer CC0 > CC-BY > other permissive. NEVER take "all rights reserved" content.
2. Every downloaded asset: record source URL + license in `ASSET_CREDITS.md` at repo root as you go (one line per asset). CC-BY requires a credits line in the game UI.
3. Verify downloads: `file <path>` shows sane type; unzip to a temp dir, move only what you use; keep `assets/` organized (`models/ textures/ audio/ hdris/`).
4. glTF/GLB is the most portable 3D format — prefer it for any engine.
5. If a download fails or is paywalled, do NOT stall: try another source from the table, then procedural fallback.