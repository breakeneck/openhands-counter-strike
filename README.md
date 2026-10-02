# Operation: Blackout (openhands-counter-strike)

Tactical single-player FPS built with **Godot 4.3** — one detailed map, 6 weapon
categories, AI bots with navigation/perception/cover behavior, and a capture-point
round loop.

## Run

1. Install [Godot 4.3+](https://godotengine.org/download)
2. Open `project.godot` in the editor, press **F5** (or `godot --path . res://scenes/main/menu.tscn`)

## Controls

| Key | Action |
|---|---|
| WASD | Move |
| Shift / Ctrl | Sprint / Crouch |
| Space | Jump |
| Mouse | Look |
| LMB / RMB | Fire / Aim |
| R | Reload |
| 1, 2, wheel | Switch weapon |
| Esc | Pause |

## Gameplay

Capture **Point Alpha** in the SE compound: stand inside the red ring for 20s.
Enemies patrol, investigate noise, alert nearby bots, take cover when hurt, and
retreat at low health. Kill all hostiles or hold the point to win; death = defeat.

## Weapons

P9 Pistol · VX-9 SMG · AK-CAR Rifle · M870 Shotgun · AWM Sniper · PKM MG —
each tuned in `data/weapons/*.tres` (damage, fire rate, spread, recoil, mag, ADS zoom).

## Architecture (Godot-first)

No custom engine systems. `CharacterBody3D` + `move_and_slide` for movement,
`RayCast3D`/direct-space hitscan for combat, `NavigationAgent3D` + runtime-baked
`NavigationMesh` for AI, `GPUParticles3D`/`Decal` for VFX, native Controls for UI,
`AudioStreamPlayer3D` for spatial audio. Two autoloads only: `GameManager`
(round state) and `Effects` (shared VFX/SFX spawner). See `TECH_INVENTORY.md`.

## Tests

```bash
godot --headless res://tests/validate.tscn     # 27 structural/combat checks
godot --headless res://tests/playthrough.tscn  # 9-step full round loop e2e
xvfb-run godot res://tests/visual_qa.tscn      # 11 scripted screenshots → qa/
```

## Assets

All CC0 — see `ASSET_CREDITS.md` (Poly Haven textures, Kenney/OGA audio,
Quaternius characters/props; weapon viewmodels and map are original).