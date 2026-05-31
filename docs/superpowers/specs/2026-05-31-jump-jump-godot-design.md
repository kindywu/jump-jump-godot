# Jump Jump Godot — Design Spec

**Date:** 2026-05-31
**Source:** 1:1 port from `C:\ws\game\jump-jump-bevy` (Bevy 0.18 → Godot 4.6)
**Status:** Approved

## Overview

A 3D "Jump Jump" (跳一跳) game: hold LMB to charge power, release to jump to the next platform. Land accurately to score +1, fall to end the game.

## Game Mechanics

| Mechanic | Detail |
|----------|--------|
| Charge | Hold LMB → player compresses (X/Z scale ↑, Y scale ↓), platform sinks |
| Jump | Release LMB → arc trajectory flip toward landing position; distance = `3.0 × charge_time` |
| Perfect land | Land centered on next platform → +1 score, platform becomes current |
| Edge/tilt fall | Land on platform edge → tilt and fall off |
| Straight fall | Land completely off platform → drop straight down |
| Game over | Player falls below ground → Game Over screen |

## State Machine

```
MainMenu ──(Start)──▶ Playing ──(Fall)──▶ GameOver
   ▲                      │                   │
   └──(Home)──────────────┘◀──(Restart)──────┘
```

## Project Structure

```
res://
├── scenes/
│   ├── main.tscn
│   ├── player.tscn
│   └── platform.tscn
├── scripts/
│   ├── game_state.gd          (Autoload)
│   ├── main.gd
│   ├── player.gd
│   ├── platform.gd
│   ├── camera.gd
│   └── ui/
│       ├── main_menu.gd
│       ├── game_over.gd
│       └── scoreboard.gd
├── assets/
│   ├── fonts/num.ttf
│   ├── sounds/*.mp3
│   └── texture/*.png
└── project.godot
```

## Modules

### GameState (Autoload)
- Enum: `MAIN_MENU`, `PLAYING`, `GAME_OVER`
- Signals: `state_changed(new_state)`
- Score: `int score` with increment/reset

### Player
- CapsuleMesh (radius 0.2, height 0.5), pink material
- `_input()`: capture mouse press/release for charge/jump
- Charge: lerp X/Z scale to 1.3, Y to 0.6; spawn particles every 200ms
- Jump: arc rotation around midpoint, self-rotation flip; duration = max(charge_time/2, 0.5)
- Fall: straight drop or tilt-then-drop (Tween-driven)
- Sound: start, accumulation (loop), fall, success

### Platform
- Random shape: Box (1.5×1.0×1.5) or Cylinder (r=0.75, h=1.0)
- Random color (RGB)
- Next platform: random X or Z direction, distance 2.5–4.0 from current
- Charge sync: Y scale decreases while charging, springs back on release
- Collision: math-based (compare landing X/Z against platform bounds)

### Camera
- Start: (-5, 8, 5) looking at origin, perspective
- Smooth follow: lerp toward `initial_pos + player_pos` when player is idle

### UI
- MainMenu: title image + start button
- GameOver: title image + home button + restart button
- Scoreboard: top-left corner, shows current score
- +1 effect: floating text at landing position, rises and fades out

### Audio
- `start.mp3` — on game start
- `accumulation.mp3` — loop while charging
- `fall.mp3` — when falling
- `success.mp3` — on successful landing

### Particles
- GPUParticles3D attached to player
- Emit during charge every 200ms
- Color gradient: white → yellow → red over lifetime
- Size gradient: 0.05 → 0.05 → 0.0

## Bevy → Godot Mapping

| Bevy | Godot |
|------|-------|
| ECS Systems | Node `_process()` / `_input()` |
| `Res<T>` (resources) | Autoload or node property |
| `Query<&Transform>` | `@onready var` references |
| `bevy_hanabi` | `GPUParticles3D` |
| Timer resources | `Timer` node / `SceneTreeTimer` |
| Button `Interaction::Pressed` | `Button.pressed` signal |
| `world_to_viewport()` | `Camera3D.unproject_position()` |
| ECS state transitions | Autoload signals |

## Edge Cases
- Block jump input during ongoing jump or fall
- Short delay (200ms) after entering Playing before accepting input
- Ensure next platform always exists before allowing jump
- Clean up old platforms, effects, and sounds on state transitions
