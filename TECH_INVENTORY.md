# Technical Inventory (Godot-first decisions)

| Subsystem | Native Godot | Existing Solution | Custom Code | Notes |
|---|---|---|---|---|
| Player movement | YES (CharacterBody3D + move_and_slide) | NO | ~120 lines | accel/decel, crouch, sprint, head bob via code |
| Camera | YES (Camera3D) | NO | minimal | mouse look via Input map |
| Physics | YES (Jolt built-in) | NO | 0 | engine=Jolt in project.godot |
| Weapons | YES (RayCast3D, Timer, GPUParticles3D, AudioStreamPlayer3D) | NO | small script + WeaponData Resource | composition per spec §28 |
| Navigation | YES (NavigationRegion3D + NavigationAgent3D) | NO | minimal | navmesh generated at runtime from map geometry |
| AI | PARTIAL (states are game logic) | NO | small FSM | PATROL/INVESTIGATE/ALERT/SEARCH/ATTACK/TAKE_COVER/RETREAT/DEAD |
| UI | YES (Controls/Containers/Theme) | NO | minimal | HUD, menus, screens |
| Audio | YES (AudioStreamPlayer3D, buses) | YES (CC0) | minimal | CC0 SFX from Kenney (CC0) + procedural fallbacks |
| VFX | YES (GPUParticles3D, Decal) | NO | tiny | muzzle flash, impacts, sparks |
| Lighting | YES (DirectionalLight3D, Omni/Spot, WorldEnvironment) | NO | 0 | config only |
| Animation | YES (AnimationPlayer) | NO | minimal | weapon sway/reload via Tween on Node3D transforms |
| Game state | YES (Nodes+Signals) | NO | 1 autoload (GameManager) | justified: global round/score state + scene transitions |
| Map | YES (CSG3D blockout → StaticBody collision) | YES (CC0 textures: Kenney/Polyhaven CC0) | minimal | one detailed tactical map |

Decision rule applied everywhere: configuration + small game script. No frameworks, no ECS, no custom physics/nav/particles.

Assets: everything CC0 or procedural. ASSET_CREDITS.md tracks provenance.