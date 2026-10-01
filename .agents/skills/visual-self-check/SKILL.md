---
name: visual-self-check
description: Use after any change to graphics, UI or the map — render the game headlessly, screenshot it, and inspect the pixels before claiming it looks good. Never report "looks great" without having looked.
---

# Visual self-check (screenshot → inspect → fix)

Never claim something looks good from code alone. Render it and look at the pixels.

## Headless Chromium is available in the sandbox

`/usr/bin/chromium` + node are installed (no GPU — use swiftshader software GL).

```bash
chromium --headless=new --no-sandbox --disable-gpu \
  --use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader \
  --window-size=1280,720 --virtual-time-budget=8000 \
  --screenshot=/tmp/shot.png "http://localhost:PORT/"
```

Notes / pitfalls:
- `--virtual-time-budget` gives the engine time to load assets and render frames; raise it (15000) for big scenes.
- Serve the build over http (`python3 -m http.server`), not `file://` — CORS blocks asset loads from file URLs.
- Software GL is slow: expect a few seconds per frame; don't judge framerate from headless runs.
- If the screenshot is a black/blank frame, that IS a bug — capture the console:
  `--enable-logging=stderr --v=1 2>&1 | grep -iE "error|warn" | head`

## What to check in every screenshot

1. Is the map actually visible (not void / not unlit black)?
2. Are materials textured, not flat grey?
3. Are shadows present and not acne/peter-panning?
4. Is the HUD readable and not overlapping / off-screen?
5. Does it look like a place, not a blockout?

Write findings down as concrete fixes ("walls have no texture — assign concrete material", "spawn faces a wall"), then fix and re-shoot. Iterate until the screenshot would pass as a real game screenshot.

## Native (non-web) builds

For a desktop engine (Godot/Unity/Unreal), run under `xvfb-run` and grab a frame with the engine's own screenshot API (e.g. Godot `get_viewport().get_texture().get_image().save_png()` bound to a debug key, or `--write-movie`/viewport capture), then inspect that PNG. If the engine can't render headlessly at all, say so in the report rather than guessing.

## Inspection without eyes

If you cannot view images, extract objective signals instead of assuming:
- pixel stats: `python3 -c "from PIL import Image;import numpy as np;a=np.asarray(Image.open('/tmp/shot.png').convert('RGB'));print(a.mean(axis=(0,1)), a.std())"` — near-zero std = blank frame
- render counts from the engine (draw calls, loaded meshes/textures, triangles)
- console errors count == 0

Blank frame or zero loaded assets = task not done, regardless of a clean exit code.