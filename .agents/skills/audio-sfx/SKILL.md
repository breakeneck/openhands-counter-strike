---
name: audio-sfx
description: Use when the game needs weapon sounds, footsteps, UI clicks or ambience — synthesize placeholder-quality audio procedurally or download CC0 packs, and wire a full sound mix.
---

# Audio & SFX

Silent FPS feels dead. Every action needs feedback.

## Getting sounds
1. Prefer CC0 packs (see asset-hunting skill): Kenney "Impact Sounds", "RPG Audio", opengameart gun/sfx packs.
2. No suitable file? Synthesize a WAV with pure Python (stdlib `wave` + `math`/`struct`, no deps needed):
   - gunshot = short noise burst: exponential decay envelope × white noise, lowpass for rifle, sharper/highpass for pistol
   - reload = two clicks (short filtered bursts ~10ms) 200ms apart
   - footstep = very short filtered noise thud, randomize pitch ±8% per step
   - UI click = 30ms sine ping 880Hz with fast decay
   Generate at 44100Hz mono 16-bit; convert/normalise freely.
3. Music/ambience: download one CC0 loop; loop it under gameplay at low volume.

## Mix rules
- Master bus + separate SFX/Music/Ambience buses; default volumes ~ SFX 0.8, Music 0.35, Ambience 0.25.
- Distance attenuation for AI gunfire/footsteps; max ~8 concurrent SFX voices, drop the quietest.
- Every weapon: distinct fire sound + reload sounds + empty-click; hit feedback (2D hitmarker sound) regardless of 3D position.
- Mute-safe: game must still be playable if audio init fails — wrap audio setup in try/except and continue.

## Verify
Run the game and assert in logs that N audio files loaded (log it at startup: `audio: loaded 23/23`). Zero loaded with no error = silent failure, fix it.